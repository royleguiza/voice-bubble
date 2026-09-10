# Plan: build local de APK en el servidor (futuro)

> Estado: PLANIFICADO 2026-09-10. No ejecutar hasta que el dueño confirme
> la ampliación de RAM. GitHub Actions sigue siendo la vía oficial.

## Motivación

Cada cambio hoy cuesta 15–40 min de cola de Actions. El servidor es
x86_64 (FX-6300), así que puede compilar Android por sí mismo y servir el
APK directo al teléfono por Tailscale.

## Punto de partida medido (2026-09-10)

- CPU x86_64, RAM 3.8 GiB (solo ~850 MB libres), disco 57 GB libres.
- Red ~3.8 MB/s contra dl.google.com.
- `adb` presente; sin JDK, sin Flutter, sin cmdline-tools.
- Comedores de RAM: sesión opencode (~1.4 GB) + zombies `drkonqi` (~800 MB).
- `AGENTS.md` §6 dice "ARM/Termux, build imposible": DESACTUALIZADO,
  corregir al activar este plan.

## Pre-requisitos (dueño)

1. Ampliar RAM física (decisión del dueño 2026-09-10).
2. Matar zombies `drkonqi` y evaluar detener el entorno gráfico local
   (KDE ~1 GB) si no se usa.

## Pasos (una sola vez)

1. Instalar Temurin JDK 17.
2. Descargar Android cmdline-tools, aceptar licencias, instalar
   `platform-tools` + `platforms;android-34` + `build-tools`.
3. Descargar Flutter stable x64, `flutter precache`, `flutter doctor`.
4. Primer build: `flutter build apk --debug --split-per-abi` en `tmux`
   (medir tiempo real en HDD; esperado 10–20 min).
5. Servir APK con `preview-start <dir-apk> <puerto>` →
   `http://100.78.99.51:<PUERTO>/app-arm64-v8a-debug.apk`.

## Régimen de uso (tras activar)

- Iteración diaria: build local + descarga directa al teléfono.
- `flutter test` / `flutter analyze` locales antes de cada push
  (se acaba la ceguera Dart).
- GitHub Actions queda como verificación final + artefacto oficial.
- Actualizar `AGENTS.md` §6 con la nueva realidad.

## Criterios de aceptación

- [ ] APK local instala y dicta igual que el de CI (misma versión de código).
- [ ] `flutter test` local verde coincide con CI.
- [ ] Build sin OOM con la RAM ampliada.
- [ ] `AGENTS.md` §6 corregido.

## Rollback

No hay nada que romper: si el tiempo local no convence, se sigue con
Actions. No borrar el toolchain sin avisar (descargarlo costó ~2 GB).
