#!/usr/bin/env python3
"""T3 · Valida los AAB de publicación antes de subirlos a Play.

Para cada AAB:
  1. `bundletool validate` (estructura del bundle).
  2. Firma: el certificado del AAB es el de la clave de subida.
  3. `bundletool build-apks --mode=universal` y extrae universal.apk.
  4. 16 KB: zipalign -c -P 16 sobre el APK (si hay zipalign) y cada .so de
     64 bits con segmentos LOAD alineados a 16384 bytes o más (requisito de
     Play para apps que apuntan a Android 15+).

Uso:
  check_aab.py --bundletool bt.jar --keystore ks.jks --out DIR a.aab [b.aab...]
Lee KEYSTORE_PASSWORD, KEY_ALIAS y KEY_PASSWORD del entorno. Nunca imprime
contraseñas. Sale con código 1 ante cualquier falla.
"""
import argparse
import glob
import os
import struct
import subprocess
import sys
import zipfile

PAGE_16K = 16384


def run(cmd, secret=False):
    shown = ' '.join(c if not c.startswith('pass:') else 'pass:***' for c in cmd)
    print('$', shown if not secret else cmd[0] + ' …', flush=True)
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        out = (res.stdout + res.stderr).replace(os.environ.get('KEYSTORE_PASSWORD', '\0'), '***')
        print(out[-4000:])
        raise SystemExit(f'falló: {cmd[0]}')
    return res.stdout + res.stderr


def cert_sha256(path_or_ks, is_keystore=False):
    if is_keystore:
        out = run(['keytool', '-list', '-v', '-keystore', path_or_ks,
                   '-alias', os.environ['KEY_ALIAS'],
                   '-storepass', os.environ['KEYSTORE_PASSWORD']], secret=True)
    else:
        out = run(['keytool', '-printcert', '-jarfile', path_or_ks])
    for line in out.splitlines():
        line = line.strip()
        if line.startswith('SHA256:'):
            return line.split(':', 1)[1].strip().upper()
    raise SystemExit(f'sin certificado SHA-256 en {path_or_ks}')


def elf_load_aligns(data):
    """Devuelve los p_align de los segmentos LOAD de un ELF de 64 bits LE."""
    if data[:4] != b'\x7fELF':
        return None
    if data[4] != 2 or data[5] != 1:  # solo ELF64 little-endian
        return None
    e_phoff = struct.unpack_from('<Q', data, 0x20)[0]
    e_phentsize, e_phnum = struct.unpack_from('<HH', data, 0x36)
    aligns = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type = struct.unpack_from('<I', data, off)[0]
        if p_type == 1:  # PT_LOAD
            aligns.append(struct.unpack_from('<Q', data, off + 0x30)[0])
    return aligns


def check_16k(apk):
    problems = []
    with zipfile.ZipFile(apk) as z:
        for info in z.infolist():
            name = info.filename
            if not (name.startswith('lib/') and name.endswith('.so')):
                continue
            abi = name.split('/')[1]
            if abi not in ('arm64-v8a', 'x86_64'):
                continue
            aligns = elf_load_aligns(z.read(name))
            if aligns is None:
                continue
            bad = [a for a in aligns if a < PAGE_16K]
            if bad:
                problems.append(f'{name}: LOAD alineado a {min(bad)}')
            if info.compress_type == zipfile.ZIP_STORED and info.header_offset is not None:
                pass  # zipalign -P 16 lo verifica abajo
    zipaligns = sorted(glob.glob(os.path.join(os.environ.get('ANDROID_HOME', '/nonexistent'), 'build-tools', '*', 'zipalign')))
    if zipaligns:
        res = subprocess.run([zipaligns[-1], '-c', '-P', '16', '4', apk], capture_output=True, text=True)
        if res.returncode != 0:
            problems.append('zipalign -c -P 16 falló:\n' + (res.stdout + res.stderr)[-1500:])
        else:
            print('  zipalign -P 16: OK')
    else:
        print('  (sin zipalign: solo se revisan los .so)')
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bundletool', required=True)
    ap.add_argument('--keystore', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('aabs', nargs='+')
    args = ap.parse_args()
    for v in ('KEYSTORE_PASSWORD', 'KEY_ALIAS', 'KEY_PASSWORD'):
        if not os.environ.get(v):
            raise SystemExit(f'falta {v} en el entorno')
    expected = cert_sha256(args.keystore, is_keystore=True)
    failures = []
    for i, aab in enumerate(args.aabs, 1):
        print(f'\n== {aab}')
        if not os.path.isfile(aab):
            failures.append(f'{aab}: no existe')
            continue
        run(['java', '-jar', args.bundletool, 'validate', f'--bundle={aab}'])
        print('  bundletool validate: OK')
        got = cert_sha256(aab)
        if got != expected:
            failures.append(f'{aab}: firmado con otro certificado ({got[:17]}…)')
        else:
            print('  firma: clave de subida OK')
        base = os.path.splitext(os.path.basename(aab))[0]
        out = os.path.join(args.out, f'{base}-{i}')
        os.makedirs(out, exist_ok=True)
        apks = os.path.join(out, 'universal.apks')
        if os.path.exists(apks):
            os.remove(apks)
        run(['java', '-jar', args.bundletool, 'build-apks', f'--bundle={aab}',
             f'--output={apks}', '--mode=universal',
             f'--ks={args.keystore}', f'--ks-key-alias={os.environ["KEY_ALIAS"]}',
             f'--ks-pass=pass:{os.environ["KEYSTORE_PASSWORD"]}',
             f'--key-pass=pass:{os.environ["KEY_PASSWORD"]}'], secret=True)
        with zipfile.ZipFile(apks) as z:
            z.extract('universal.apk', out)
        apk = os.path.join(out, 'universal.apk')
        print(f'  universal.apk: {os.path.getsize(apk) // 1024} KB')
        problems = check_16k(apk)
        if problems:
            failures.extend(f'{aab}: {p}' for p in problems)
        else:
            print('  16 KB: OK')
    if failures:
        print('\nFALLAS:')
        for f in failures:
            print(' -', f)
        sys.exit(1)
    print('\nTodo OK.')


if __name__ == '__main__':
    main()
