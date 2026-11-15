# Especificación — Fase 1: trackpad y puntero en el complemento

Leer antes: `docs/plan-puntero-isla.md` (contexto y hechos de Android),
`AGENTS.md`, `design.md` (Horizonte), `docs/contrato-trackpad.md`.

## Objetivo

Que el trackpad flotante y su puntero vivan en el complemento
`puntero_android/` como ventanas `TYPE_ACCESSIBILITY_OVERLAY` del servicio de
Accesibilidad `PunteroService`, para que queden por encima de TODO (barra de
estado, cortina de notificaciones, ajustes rápidos, diálogos del sistema) y
los gestos salgan directo, sin un broadcast por clic. La burbuja / barra
lateral de VoiceBubble (host) solo pide «abrí el trackpad».

## Qué existe hoy (portar, no reinventar)

Host `voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/`:
- `FloatingTrackpadService.kt`: panel (modo `panel` abajo / `window` libre),
  agarradera `HandleView` con cuenta regresiva, lee prefs de Flutter
  (`flutter.kb_trackpad_*`), cierre automático, aviso del complemento.
- `FloatingPadView.kt` + `PadGestures.kt` (lógica pura con test
  `PadGesturesTest`): superficie del trackpad, tap, clic largo armado,
  scroll con riel, hápticos.
- `PointerOverlayManager.kt`: puntero (flecha «Horizonte», punto, cruz),
  cinemática (sensibilidad, curva), coordenadas de pantalla completa.
- `PointerLink.kt`, `PointerProtocol.kt` (espejo exacto en el complemento; el
  CI compara las líneas `const val` de ambos).
- `DockController` / `FloatingBubbleService`: herramienta «Puntero» llama a
  `FloatingTrackpadService.open(context, anchorX, anchorY)`.

Complemento `puntero_android/app/src/main/kotlin/com/royleguiza/voicebubble/puntero/`:
- `PunteroService.kt` (gestos por broadcast, contadores, `testTap`),
  `ScrollQueue.kt`, `PointerProtocol.kt`, `MainActivity.kt` (estado + prueba).

## Qué construir

### 1. Complemento: puntero y trackpad como accessibility overlays
- `PointerOverlay` (port de `PointerOverlayManager`): ventana
  `TYPE_ACCESSIBILITY_OVERLAY`, `FLAG_NOT_TOUCHABLE | FLAG_NOT_FOCUSABLE |
  FLAG_LAYOUT_IN_SCREEN | FLAG_LAYOUT_NO_LIMITS`, pantalla completa real
  (sin insets, recorte de cámara incluido). Estilos flecha Horizonte / punto
  / cruz idénticos al host. Como esta ventana es de confianza ya no hace
  falta correrla 3 px de la punta ni «apartarla»: la punta dibujada ES el
  punto del clic, y el anillo brasa de clic sale de la punta en los tres
  estilos (en clic largo, anillo relleno suave como hoy en punto/cruz).
- `TrackpadPanel`: ventana `TYPE_ACCESSIBILITY_OVERLAY` tocable,
  `FLAG_NOT_FOCUSABLE | FLAG_NOT_TOUCH_MODAL | FLAG_LAYOUT_IN_SCREEN`.
  Mismo aspecto que el panel actual (superficie `surf` + borde `line` 1 dp,
  radio 30, agarradera con cuenta regresiva, superficie única del pad con
  riel de scroll) y mismos modos: `panel` (abajo, ancho completo con margen
  10 dp, respeta la barra de navegación) y `window` (280 dp, junto al ancla,
  se mueve arrastrando la agarradera). Tocar la agarradera cierra.
- **Fila de sistema** debajo de la agarradera: cuatro botones de ícono
  circulares de 44 dp (surf + line, íconos de trazo 2.2 en `fg`): Atrás,
  Inicio, Recientes, Notificaciones → `performGlobalAction(GLOBAL_ACTION_*)`.
  Un quinto botón «Arrastrar» (ver punto 3) con estado activo en brasa.
  `contentDescription` en español en todos.
- Gestos directos desde el panel (sin broadcast): tap → `dispatchGesture`
  40 ms; clic largo → 450 ms; scroll → `ScrollQueue` existente. Todo se
  despacha AL SOLTAR el dedo (Android cancela gestos inyectados con un dedo
  real en pantalla): conservar la semántica actual de `FloatingPadView`
  (tap en ACTION_UP, clic largo al soltar tras armarse, scroll acumulado al
  soltar / por tramos como hoy).
- El puntero puede llegar a cualquier píxel, incluida la barra de estado y
  los bordes. Con la cortina abierta el panel y el puntero siguen visibles
  y usables.
- Cierre automático (`auto_return`), hápticos y dirección de scroll: igual
  que hoy, con los valores que llegan en la configuración.

### 2. Protocolo v2 (ambos `PointerProtocol.kt` con las MISMAS `const val`)
- `ACTION_OPEN_TRACKPAD` (host → complemento, con el permiso de firma):
  extras `anchor_x`, `anchor_y` (Int, −1 = sin ancla), `mode`
  ("panel"|"window"), `sensitivity` (Float), `accel` ("dynamic"|"linear"|
  "precision"), `style` ("arrow"|"dot"|"cross"), `haptic`
  ("subtle"|"none"|"firm"), `scroll_dir` ("natural"|"traditional"),
  `auto_return` (Int segundos, 0 = queda abierto). Validar y normalizar con
  una función pura testeada (valores fuera de rango → valor por defecto).
- `ACTION_CLOSE_TRACKPAD` (host → complemento).
- `ACTION_TRACKPAD_STATE` (complemento → host, `setPackage(HOST_PACKAGE)` +
  permiso de firma): extra `open` (Boolean). Se manda al abrir y al cerrar.
- Los `OP_TAP` / `OP_LONG_PRESS` / `OP_SCROLL` por broadcast se CONSERVAN
  (los usa el trackpad integrado al teclado, `TrackpadBridge`).

### 3. Arrastre en dos pasos
- Botón «Arrastrar» en la fila de sistema. Activo: el primer toque en el pad
  marca el origen (anillo brasa fijo en ese punto, dibujado por
  `PointerOverlay`); se mueve el puntero; el segundo toque suelta: se
  despacha UN gesto de dos trazos continuos (`willContinue`): espera de
  550 ms en el origen + recorrido origen→destino en 400 ms. Luego el modo se
  apaga solo. Tocar el botón otra vez cancela.
- La construcción del gesto (puntos, duraciones, recorte a pantalla) en una
  función pura con test JVM.

### 4. Host (cambio mínimo en esta fase)
- `PointerLink.openTrackpad(context, anchorX, anchorY): Boolean`: si el
  complemento está listo (`isReady`), lee las prefs de Flutter que hoy lee
  `FloatingTrackpadService.buildPanel()` / `readMode()` y manda
  `ACTION_OPEN_TRACKPAD`; devuelve false si no está listo.
- `FloatingBubbleService.onPointerTap`: primero `PointerLink.openTrackpad`;
  si devuelve false, abre el `FloatingTrackpadService` de siempre (que ya
  muestra dentro del panel qué falta instalar o activar). NO borrar
  `FloatingTrackpadService` en esta fase.
- Recibir `ACTION_TRACKPAD_STATE` (receptor con permiso de firma, registrado
  mientras vive `FloatingBubbleService`) → `dock.setTrackpadOpen(open)`.
- Declarar en ambos manifiestos lo que haga falta (`<queries>`, permisos).

### 5. Complemento con diseño Horizonte
- Colores Horizonte día/noche en `res/values` y `res/values-night`
  (copiar los tokens `hz_*` del host: bg, surf, surf2, line, fg, fg2, ember,
  ember_t, ember_soft, on_ember, hot, hole, danger, ok). `MainActivity` usa
  esos tokens (hoy usa azul genérico): botón primario brasa con texto
  on-ember, tarjetas surf + line. Sin cambiar textos ni la prueba de clic.
- Fuentes: copiar `sora_semibold.ttf` e `inter_regular.ttf`/`inter_medium.ttf`
  del host a `res/font` del complemento y usarlas en títulos / texto.

### 6. Tests, suites, CI y docs
- Portar `PadGestures` + `PadGesturesTest` al complemento (el host conserva
  los suyos mientras exista `FloatingTrackpadService`). Tests JVM nuevos:
  validación de la configuración de `OPEN_TRACKPAD` y el gesto de arrastre.
- `.github/workflows/android.yml`: el paso del complemento ya corre
  `:app:testDebugUnitTest`; no hace falta más. El paso «Protocolo del
  puntero idéntico» debe seguir verde.
- Suites Python (`test_floating_dock_suite.py`, `test_trackpad_suite.py`,
  y lo que toque `test_master_suite.py`): AGREGAR comprobaciones del diseño
  nuevo (overlays de accesibilidad en el complemento, fila de sistema,
  arrastre, protocolo v2, `openTrackpad` con fallback). No borrar ni
  debilitar las existentes salvo las que describan algo que cambió de
  verdad; en ese caso reescribirlas para el comportamiento nuevo.
- `docs/contrato-trackpad.md`: actualizar con el protocolo v2 y quién
  dibuja qué.

## Restricciones
- Privacidad: `canRetrieveWindowContent="false"` se mantiene; cero logs de
  coordenadas, texto o apps; contadores solo en memoria.
- `puntero_android` no tiene dependencias externas (solo SDK de Android):
  mantenerlo así (sin androidx). Vistas en código, como hoy.
- minSdk del complemento: el que ya tiene. `dispatchGesture` con trazos
  continuos requiere API 26: ya cubierto.
- No tocar `app_source/` (Flutter) en esta fase.
- No hacer commit ni push: el coordinador audita y commitea.
- No dejar procesos, temporizadores ni servidores en segundo plano.

## Verificación obligatoria (reportar resultados reales)
1. Compilar el complemento en una COPIA (no en el repo):
   copiar `puntero_android/` y `voice_bubble_stt/android/app/debug.keystore`
   (misma ruta relativa) a un directorio temporal; en la copia agregar a
   `gradle.properties`: `org.gradle.jvmargs=-Xmx1100m -XX:MaxMetaspaceSize=512m`,
   `kotlin.compiler.execution.strategy=in-process`, `org.gradle.parallel=false`;
   `local.properties` con `sdk.dir=/home/ubuntu/android-sdk`; correr
   `~/gradle-dist/gradle-9.3.1/bin/gradle --offline --no-daemon --max-workers=1 -q :app:compileDebugKotlin :app:testDebugUnitTest`.
2. Compilar el host: ya hay una copia preparada en
   `/tmp/claude-1000/-home-ubuntu/bb98441e-f6d9-4685-a786-8638035757a9/scratchpad/kbuild/vbs/android`
   (si no existe, recrearla: copiar `voice_bubble_stt/` y encima
   `app_source/lib`, `pubspec.*`, `fonts`; `local.properties` con `sdk.dir` y
   `flutter.sdk=/home/ubuntu/flutter`; mismas líneas de `gradle.properties`).
   Copiar ahí los `.kt` / manifiesto modificados y correr
   `gradle --offline --no-daemon --max-workers=1 -q :app:compileDebugKotlin -x compileFlutterBuildDebug`
   y los tests `:app:testDebugUnitTest --tests '*PointerProtocolTest' --tests '*PadGesturesTest' --tests '*DockGeometryTest' -x compileFlutterBuildDebug`.
   Una sola compilación Gradle por vez (2 GB de RAM).
3. `python3 test_floating_dock_suite.py`, `python3 test_trackpad_suite.py`
   (0 fallos) y `python3 test_master_suite.py` (línea base 98/100: solo
   falla C-34, previo).
4. El diff de `const val` entre los dos `PointerProtocol.kt` vacío.

## Entrega
Lista de archivos creados/modificados, resultados literales de la
verificación, y cualquier decisión tomada que se aparte de esta
especificación (con el motivo).
