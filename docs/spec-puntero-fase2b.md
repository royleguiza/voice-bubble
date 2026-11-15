# Especificación — Fase 2B: Ajustes de la isla (Flutter)

Leer antes: `docs/plan-puntero-isla.md`, `docs/spec-puntero-fase2a.md` (ya
implementada), `docs/contrato-barra.md`, `docs/contrato-claves.md`,
`AGENTS.md`, `design.md` (Horizonte; sección de Ajustes y de la isla).
Maqueta de referencia: `laboratorio_ui/isla.html` (panel de controles).

## Objetivo

Que desde Ajustes de VoiceBubble se pueda elegir la forma **Isla** de la
barra flotante y ajustarla al píxel, viendo una maqueta en la misma pantalla
y con la isla real moviéndose EN VIVO en el teléfono.

## Qué existe
- `app_source/lib/screens/settings/general_tab.dart` (selector de forma
  `_dockForm`, herramientas) y `settings_screen.dart` (`_setDockForm`,
  `reloadDock`), `services/storage_service.dart` (`dockForms = ['edge',
  'bubble']`), `services/floating_bubble_service.dart` (canal nativo,
  `reloadDock`).
- Nativo (host): `DockLink.kt` lee `dock_island_x/_y/_w/_h` (Int, píxeles de
  pantalla completa; −1 = por defecto) y `dock_island_side`
  ("left"|"right") con `FlutterPrefs.key(...)`, y `MainActivity` ya manda
  `DOCK_CONFIG` en `reloadDock` / `startBubble` / `stopBubble`.
  `PointerLink.status(context)` da "missing" | "disabled" | "ready".
- Complemento: aplica `DOCK_CONFIG` en vivo; valores por defecto de la isla
  en `IslandGeometry` (112 × 30 dp, centrada arriba).

## Qué construir

### 1. Forma «Isla» en el selector
- `StorageService.dockForms` suma `'island'`. El selector de Ajustes ›
  (donde hoy se elige borde/burbuja) ofrece «Isla».
- Si el complemento no está listo (estado "missing"/"disabled", consultado
  por el canal nativo que ya use Ajustes › Trackpad para mostrar el estado
  del complemento), «Isla» se muestra deshabilitada con una línea que
  explica por qué («Necesita VoiceBubble Puntero activo») y un acceso para
  activarlo (el mismo que usa Ajustes › Trackpad).

### 2. Pantalla «Ajustar isla» (subpágina de Ajustes, estilo existente)
Visible cuando la forma es Isla. Contenido, de arriba hacia abajo:
- **Maqueta**: un widget propio que dibuja la parte superior de un teléfono
  (proporción de la pantalla real, barra de estado simulada y la píldora de
  la isla en reposo con el agujero brasa de un lado y el glifo de puntero
  del otro, lado según el ajuste). Escala fiel: la posición y el tamaño de
  la píldora en la maqueta corresponden a los píxeles reales
  (usar el tamaño físico de pantalla de `MediaQuery`/`View`). Sin
  desenfoque, tokens Horizonte, claro y oscuro.
- **Posición horizontal** (centro de la isla, px), **Posición vertical**
  (borde superior, px), **Ancho en reposo** (px), **Alto en reposo** (px):
  cada uno con deslizador + botones «−» y «+» de 1 px (mantener apretado
  repite), y el valor en mono. Rangos: X de medio ancho mínimo a
  ancho−medio ancho; Y de 0 a un tercio del alto; ancho 72–180 dp en px;
  alto 22–48 dp en px (convertir con devicePixelRatio).
- **Lado del micrófono**: Izquierda / Derecha (el puntero va del otro).
- **Centrar arriba** (botón): X al centro, Y por defecto.
- **Restablecer** (botón de texto): vuelve a −1 (valores por defecto).
- Cada cambio: guarda las prefs y pide al nativo reenviar `DOCK_CONFIG`
  (el `reloadDock` existente sirve). Mientras se arrastra un deslizador,
  enviar como mucho cada ~60 ms (reusar `Debouncer`/throttle del proyecto)
  y siempre el valor final al soltar.
- Accesibilidad: etiquetas semánticas en español, targets ≥ 48 dp, valores
  anunciados; sin depender solo del color.

### 3. Claves y contratos
- Nuevas claves de Ajustes: `dock_island_x`, `dock_island_y`,
  `dock_island_w`, `dock_island_h` (int) y `dock_island_side` (string).
  Sumarlas donde corresponda para mantener la paridad que exigen las suites
  (lista `bridgeKeys` / `docs/contract-keys.txt` / `docs/contrato-claves.md`
  y los conteos de la suite C-19 y master). En Kotlin, si la suite lo exige,
  pasar `DockLink` a leerlas con el literal del contrato en vez del rodeo
  que quedó en la fase 2A (ver la decisión 3 del informe en
  `docs/contrato-barra.md`). `floating_bubble_enabled` igual.
- `PREF_FORM` del host ya acepta "island".

### 4. Tests y docs
- Tests de widget para la pantalla nueva: deslizadores y ±1 px guardan y
  piden recarga, lado, restablecer, «Isla» deshabilitada sin complemento,
  maqueta refleja los valores. Usar los fakes/harness existentes
  (`test/settings_harness.dart`).
- `flutter analyze` sin avisos (estricto) y `flutter test` completo en
  verde (línea base: 672 tests).
- Suites Python: sumar comprobaciones (forma isla en Ajustes, claves,
  ajuste en vivo). Línea base: `test_floating_dock_suite.py` 274/0,
  `test_trackpad_suite.py` 204/0, `test_settings_redesign_suite.py` 145/0,
  `test_master_suite.py` 98/100 (solo C-34).
- `design.md`: describir la pantalla «Ajustar isla».

## Restricciones
- Seguir los tokens y componentes de Ajustes existentes (`settings_v2.dart`):
  nada de estilos nuevos sueltos; tamaños de ícono de `AppIcons`.
- No tocar el complemento salvo que haga falta un valor por defecto.
- Si se toca Kotlin del host: compilar en la COPIA
  (`/tmp/claude-1000/-home-ubuntu/bb98441e-f6d9-4685-a786-8638035757a9/scratchpad/kbuild/vbs/android`,
  refrescar con `rsync -a voice_bubble_stt/android/app/src/ <copia>/app/src/`)
  con `~/gradle-dist/gradle-9.3.1/bin/gradle --offline --no-daemon
  --max-workers=1 -q :app:compileDebugKotlin -x compileFlutterBuildDebug`.
  NUNCA Gradle y `flutter test` a la vez (2 GB de RAM). `flutter` está en
  `~/flutter/bin`; correr `flutter test`/`analyze` desde `app_source/` y
  al terminar restaurar `app_source/pubspec.lock` con `git checkout`.
- Sin commit ni push. Sin procesos ni temporizadores en segundo plano.

## Entrega
Informe en español: archivos creados/modificados; salida real de analyze,
tests y suites; decisiones que se apartan de la especificación; qué hay que
probar en el teléfono.
