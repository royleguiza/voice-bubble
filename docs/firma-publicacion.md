# Firma de publicación (T3)

## La clave de subida

- Vive **fuera del repo**, en el servidor: `~/.config/orison/`
  - `upload-keystore.jks` (PKCS12, RSA 4096, alias `upload`, válida hasta 2054)
  - `upload-keystore.properties` (contraseñas; permisos 600)
  - `upload-keystore.base64` (el mismo .jks en una línea, para el secreto de GitHub)
- Certificado: `CN=Orison, O=Orison`
  SHA-256 `0E:05:A1:E6:17:38:01:16:8B:CE:B0:83:7E:F1:A2:11:07:74:47:C1:D1:9D:13:C5:6A:4D:08:3F:B3:49:C0:F3`
- Es la clave de **subida**: con «Firma de apps de Play» Google guarda la clave
  final. Si la de subida se pierde, se pide un reemplazo en Play Console (no se
  pierde la app), pero conviene que el dueño guarde una copia del `.jks` y del
  `.properties` en un lugar seguro propio (gestor de contraseñas o pendrive).
- Orison y Orison Puntero se firman con la **misma** clave (el permiso de firma
  `com.royleguiza.orison.puntero.permission.POINTER` lo exige). Al crear el
  Puntero en Play Console: «usar la misma clave que otra app de esta cuenta».

## Secretos de GitHub (Settings › Secrets and variables › Actions)

| Secreto | Valor |
|---|---|
| `KEYSTORE_BASE64` | contenido de `upload-keystore.base64` |
| `KEYSTORE_PASSWORD` | `KEYSTORE_PASSWORD` del `.properties` |
| `KEY_ALIAS` | `upload` |
| `KEY_PASSWORD` | `KEY_PASSWORD` del `.properties` |

El token actual del servidor no tiene permiso de *Secrets* (403). Con un token
nuevo que lo tenga se cargan así (sin que la contraseña pase por el historial):

```bash
cd ~/.config/orison
GH_TOKEN=$(cat ~/.config/voicebubble/gh-workflow-push.token) gh secret set KEYSTORE_BASE64 -R royleguiza/voice-bubble < upload-keystore.base64
for k in KEYSTORE_PASSWORD KEY_PASSWORD KEY_ALIAS; do
  grep "^$k=" upload-keystore.properties | cut -d= -f2- | GH_TOKEN=$(cat ~/.config/voicebubble/gh-workflow-push.token) gh secret set $k -R royleguiza/voice-bubble
done
```

## Publicar una versión

1. Subir `version:` en `app_source/pubspec.yaml` (y `AppInfo.version`).
2. `git tag v1.0.0 && git push origin v1.0.0` → workflow **Release AAB (Play)**
   (`.github/workflows/release.yml`).
3. Artefactos: `orison-release-aab-rN` (a Play), `orison-puntero-release-aab-rN`
   y `orison-release-universal-apk-rN` (APK de prueba firmado con la clave de
   subida: no se instala encima del APK de prueba del CI, que usa la clave de
   debug).

## Verificado en el servidor (25/11/2026)

`flutter build appbundle --release` + `:app:bundleRelease` del Puntero y
`tools/release/check_aab.py`: bundletool validate OK, firma = clave de subida,
`zipalign -c -P 16` OK y todos los `.so` de 64 bits con LOAD ≥ 16 KB.
AAB de Orison 103 MB (universal 107 MB: incluye las tres ABI y ML Kit; Play
entrega a cada teléfono solo su parte).
