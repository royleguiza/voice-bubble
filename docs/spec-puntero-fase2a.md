# Especificación — Fase 2A: la barra flotante (burbuja · barra · isla) en el complemento

Leer antes: `docs/plan-puntero-isla.md`, `docs/spec-puntero-fase1.md` (ya
implementada: mirar cómo quedó en `puntero_android/`), `AGENTS.md`,
`design.md`, `docs/contrato-trackpad.md`.
Maqueta de la isla (referencia visual y de tamaños):
`/tmp/claude-1000/-home-ubuntu/bb98441e-f6d9-4685-a786-8638035757a9/scratchpad/isla/isla-voicebubble.html`
(copiarla a `laboratorio_ui/isla.html` del repo como fuente del diseño).

## Problema que resuelve

Hoy la burbuja / barra lateral las dibuja VoiceBubble (host) desde
`FloatingBubbleService`, que solo arranca al abrir la app y no se relanza
solo: si Android cierra la app (memoria, batería, reinicio, actualización) la
barra DESAPARECE. Además el dictado de la burbuja pasa por Flutter
(`MainActivity.onBubbleActionListener` → canal → Dart): si la actividad no
está viva, tocar el micrófono no hace nada.

Android mantiene vivo y relanza solo (también tras reiniciar) un servicio de
Accesibilidad. Por eso la barra flotante pasa a dibujarla el complemento, y
se agrega la tercera forma: la **isla**, que por ser ventana de Accesibilidad
puede vivir sobre la barra de estado / zona de la cámara.

## Resultado esperado

1. Con el complemento activo, la barra flotante (en la forma elegida: borde,
   burbuja o isla) la dibuja `PunteroService` como
   `TYPE_ACCESSIBILITY_OVERLAY`, está siempre (también tras reiniciar el
   teléfono y con VoiceBubble cerrada) y funciona con cualquier teclado.
2. Tocar el micrófono dicta aunque VoiceBubble esté cerrada: lo hace un
   servicio NATIVO nuevo del host, sin Flutter.
3. Sin el complemento (no instalado / apagado) todo sigue como hoy: el host
   dibuja burbuja o barra con su `FloatingBubbleService` (respaldo). Nunca
   deben verse dos barras a la vez.

## Diseño

### A. Complemento: `Dock` (port + isla)
- Portar a `puntero_android` la barra del host: `DockController.kt`,
  `DockViews.kt`, `DockGeometry.kt` (+ `DockGeometryTest`), la animación de
  voz que usan (`HorizonView.kt` / lo que dibuje grabando y pensando) y lo
  necesario de `GlassWindow.kt`, como ventanas `TYPE_ACCESSIBILITY_OVERLAY`
  (ya no hace falta `OverlayPassThrough` salvo para el propio gesto, como en
  el trackpad de la fase 1). Mismo comportamiento: lengüeta en el borde que
  se abre con las herramientas, burbuja libre con abanico, arrastrar entre
  formas, posición recordada. La posición y la forma se guardan en
  SharedPreferences PROPIAS del complemento.
- Nueva forma `ISLAND` (ver maqueta): píldora negra siempre (#000, borde
  1 px #23252E), estados:
  - reposo: `w × h` configurables; agujero chico con anillo brasa de un lado
    y glifo de puntero del otro (lado configurable); el glifo en brasa si el
    trackpad está abierto.
  - abierta (toque): 176 × 58 dp, botón micrófono (agujero 42 dp con anillo
    brasa y micrófono on-hole) y botón puntero (círculo surf2 con flecha);
    se cierra sola a los 4 s. Si solo hay una herramienta activa, el toque
    la ejecuta directo (como la burbuja).
  - grabando: 252 × 44 dp, agujero 32 dp (toque = terminar), animación de
    voz que sigue el nivel (símbolos hacia el agujero, misma estética que
    `HorizonView`), cronómetro mono y ✕ (cancelar); anillo brasa exterior.
  - pensando: mismas medidas, rayitas blancas + arco destello girando.
  - listo: 128 × 34 dp, ✓ destello + «Pegado»/texto corto, 1,3 s y vuelve.
  - Transiciones de tamaño con rebote suave (≈ 420 ms, overshoot leve);
    respetar «quitar animaciones» del sistema (sin animación).
  - Posición: `x` = centro horizontal, `y` = borde superior, en PÍXELES de
    pantalla completa (puede quedar sobre la barra de estado y la cámara:
    `FLAG_LAYOUT_NO_LIMITS`, sin insets, recorte incluido). Al crecer se
    mantiene centrada en `x` y recortada a la pantalla.
- La herramienta Puntero abre el `TrackpadController` de la fase 1
  directamente (sin broadcast), con la última configuración de trackpad
  recibida del host (guardarla también en prefs propias; valores por
  defecto si nunca llegó).
- Toque largo en reposo (historial): NO se porta en esta fase (queda
  anotado como pendiente de la fase 4).

### B. Protocolo v3 (mismas `const val` en los dos `PointerProtocol.kt`)
Host → complemento (permiso de firma, `setPackage` del complemento):
- `ACTION_DOCK_CONFIG`: `enabled` (Boolean: la barra flotante está
  encendida en Ajustes), `form` ("edge"|"bubble"|"island"), `tool_mic`,
  `tool_pointer` (Boolean), `island_x`, `island_y`, `island_w`, `island_h`
  (Int px; −1 = por defecto), `island_side` ("left"|"right": lado del
  micrófono), más la configuración del trackpad de la fase 1 (mismos
  extras que `OPEN_TRACKPAD`). El complemento la normaliza con una función
  pura testeada, la guarda y la aplica EN VIVO.
- `ACTION_MIC_STATE`: `state` ("idle"|"recording"|"transcribing"|"done"|
  "error"), `level` (Float 0..1, solo grabando, ≤ 15 Hz), `message`
  (String corta opcional para done/error).
Complemento → host (`setPackage(HOST_PACKAGE)` + permiso de firma):
- `ACTION_DOCK_HELLO`: el servicio arrancó o quiere configuración → el host
  responde con `DOCK_CONFIG` (receptor declarado en el MANIFIESTO del host,
  para que funcione con la app cerrada).
- `ACTION_DOCK_STATE`: `active` (Boolean: el complemento está dibujando la
  barra) → el host oculta/muestra su barra de respaldo.
- Dictado: ver C.

### C. Host: dictado nativo de la barra (sin Flutter)
- Nuevo servicio `DockDictationService` (foreground, tipo `microphone`,
  `exported="true"` protegido con `android:permission` = permiso de firma
  del puntero), modelado sobre `WidgetDictationService`: acciones
  `TOGGLE` (empezar / terminar) y `CANCEL`. Graba, transcribe con
  `SpeechToTextClient` (misma configuración y clave que el teclado y el
  widget), y con el resultado hace lo mismo que hace hoy la burbuja por
  Flutter (leer `app_source/lib/controllers/recording_controller.dart`,
  `home_screen.dart` `_handleBubbleTap`/`_stopRecording` y
  `transcription_service.dart` para igualar lo observable: guardar en el
  historial nativo `TranscriptionHistoryRepository` y copiar al
  portapapeles; respetar sonidos / hápticos de micrófono y la exclusión
  mutua del micrófono `MicrophoneClaim` que ya usan teclado y widget).
  Emite `MIC_STATE` en cada cambio y el nivel de voz mientras graba.
- Arranque desde el complemento: `startForegroundService` con intent
  explícito al servicio del host (el complemento tiene una ventana visible,
  lo que habilita el micrófono «mientras se usa»). Si Android igual lo
  niega (`SecurityException` / `ForegroundServiceStartNotAllowedException`
  al hacer `startForeground` con tipo micrófono, o el complemento no puede
  arrancarlo), respaldo: el complemento abre una actividad trampolín del
  host (`DockTrampolineActivity`, translúcida, sin animación, fuera de
  recientes, protegida con el permiso de firma) que arranca el servicio
  estando en primer plano y se cierra sola. Un servicio de Accesibilidad
  puede abrir actividades desde el fondo.
- Errores con mensaje corto en español vía `MIC_STATE error` (sin clave,
  sin permiso de micrófono, sin red): la barra los muestra en su estado
  «listo» (isla) o como hoy (burbuja/barra).
- El dictado de la burbuja de respaldo del host (por Flutter) no se toca.

### D. Host: quién dibuja
- `FloatingBubbleService` (respaldo): si llega `DOCK_STATE active=true`, se
  detiene / no muestra su barra; si el complemento no está listo
  (`PointerLink.isReady` falso), funciona como hoy.
- Al cambiar en Ajustes la forma, herramientas o el interruptor de la barra
  (los métodos nativos que hoy llaman `reloadDock` / `startBubble` /
  `stopBubble` en `MainActivity`), además mandar `DOCK_CONFIG`.
- `PREF_FORM` acepta "island" (el respaldo del host la trata como "bubble").
- Las prefs de la isla que leerá el host (las escribirá Ajustes en la fase
  2B): `flutter.dock_island_x`, `_y`, `_w`, `_h` (Int px) y
  `flutter.dock_island_side`. Si no existen: centrada arriba, 112 × 30 dp,
  micrófono a la izquierda.

### E. Tests, suites, docs
- Tests JVM en el complemento: normalización de `DOCK_CONFIG`, geometría de
  la isla (tamaños por estado, centrado y recorte a pantalla), y los
  portados (`DockGeometryTest`).
- Tests JVM en el host para la lógica pura nueva del dictado (máquina de
  estados TOGGLE/CANCEL) si se puede aislar.
- Suites Python: agregar comprobaciones del diseño nuevo (barra en el
  complemento como overlay de accesibilidad, isla, protocolo v3, servicio
  de dictado exportado SOLO con permiso de firma, trampolín, respaldo del
  host, nunca dos barras). No debilitar las existentes.
- `docs/contrato-trackpad.md` (o un `docs/contrato-barra.md` nuevo):
  protocolo v3 y quién dibuja qué. `design.md`: agregar la isla en la
  sección de la barra flotante.

## Restricciones (iguales a la fase 1)
- Privacidad: `canRetrieveWindowContent="false"`; cero logs de audio, texto,
  coordenadas o apps. El audio y el texto NUNCA pasan por el complemento:
  solo estados y nivel.
- `puntero_android` sin androidx ni dependencias externas; un solo
  `uses-permission` propio (el de firma) como hoy, salvo que sea
  estrictamente necesario otro (justificarlo en el informe).
- No tocar `app_source/` (Flutter): Ajustes va en la fase 2B.
- Sin commit ni push. Sin procesos ni temporizadores en segundo plano.
- Compilación SOLO en copias, una Gradle por vez, con los parámetros de la
  «Verificación obligatoria» de `docs/spec-puntero-fase1.md` (mismos
  comandos; sumar los tests nuevos). Las copias de la fase 1 están en
  `/tmp/claude-1000/-home-ubuntu/bb98441e-f6d9-4685-a786-8638035757a9/scratchpad/kbuild/`
  (`puntero_android/` y `vbs/android/`); refrescarlas con los fuentes
  actuales antes de compilar. Si falta una dependencia en caché, repetir esa
  corrida una vez sin `--offline`.
- Línea base: `test_floating_dock_suite.py` 189/0, `test_trackpad_suite.py`
  196/0, `test_master_suite.py` 98/100 (solo C-34), diff de `const val`
  vacío.

## Entrega
Informe en español: archivos creados/modificados; salida real de cada paso
de verificación; decisiones que se apartan de esta especificación y por qué;
lista de lo que solo se puede probar en el teléfono.
