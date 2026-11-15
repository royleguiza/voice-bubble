# Trackpad y puntero: qué hace de verdad

> Fuente única del estado real del trackpad (SPK-23). Si la UI promete
> otra cosa, vale este doc. Actualizado 2026-11-15 (fase 1: trackpad y
> puntero en el complemento, protocolo v2).

## Quién dibuja qué

Hay dos trackpads flotantes; la herramienta «Puntero» de la barra elige uno.

| | Complemento VoiceBubble Puntero (preferido) | `FloatingTrackpadService` (respaldo) |
|---|---|---|
| Cuándo | complemento instalado y su Accesibilidad activa (`PointerLink.isReady`) | el complemento no está listo |
| Ventanas | `TYPE_ACCESSIBILITY_OVERLAY`: puntero y panel quedan por encima de la barra de estado, la cortina de notificaciones, los ajustes rápidos y los diálogos del sistema; Android no les bloquea toques | `TYPE_APPLICATION_OVERLAY`: quedan debajo de la barra de estado y la cortina |
| Gestos | `dispatchGesture` directo desde el panel, siempre AL SOLTAR el dedo | por broadcast al complemento (un broadcast por clic) |
| Quién lo dibuja | `PointerOverlay`, `TrackpadPanel`, `PadView` (en `puntero_android/`) | `PointerOverlayManager`, `FloatingPadView` (en VoiceBubble) |
| Cuenta atrás, hápticos, scroll | mismos valores, llegan en `OPEN_TRACKPAD` | los lee de las prefs de Flutter |

`FloatingTrackpadService` se conserva solo como respaldo (se retira en la
fase 4); dentro de su panel muestra qué falta instalar o activar.

## Dónde vive

- **Barra flotante** (`DockController`, servicio `FloatingBubbleService`):
  un solo objeto de vidrio con dos formas, barra en el borde o burbuja libre.
  Sus herramientas son Micrófono y Puntero (Ajustes › Barra flotante). La
  herramienta Puntero llama a `PointerLink.openTrackpad(...)`; si devuelve
  false (complemento no listo), abre `FloatingTrackpadService`. Mientras el
  trackpad está abierto, sea cual sea, la burbuja se esconde y vuelve al
  cerrarlo (`DockController.setTrackpadOpen`): con el complemento, por el
  broadcast `TRACKPAD_STATE`.
- **Trackpad del complemento** (`TrackpadController` + `TrackpadPanel` dentro
  de `PunteroService`):
  - Panel abajo o ventana flotante (`mode`). Un toque en la línea de arriba lo
    cierra; arrastrarla mueve la ventana (o baja/extiende el panel); la línea
    se acorta mientras corre el cierre automático (`auto_return`, 0 = queda
    abierto).
  - Superficie única como el prototipo (`PadView`, gestos en `PadGestures`):
    deslizar mueve, tocar = clic, mantener = clic largo, dos dedos o la guía
    fina de la derecha = desplazar. Sin botones de mouse.
  - **Fila de sistema** debajo de la línea: Atrás, Inicio, Recientes y
    Notificaciones (`performGlobalAction`) y **Arrastrar**.
  - **Arrastrar** (dos pasos): activo el botón, el primer toque en el pad
    agarra (anillo brasa fijo en ese punto), se mueve el puntero y el segundo
    toque suelta. Sale UN gesto de dos trazos continuos (`willContinue`):
    espera de 550 ms en el origen + recorrido origen → destino en 400 ms
    (`DragPlan`). Después el modo se apaga solo; tocar el botón de nuevo
    cancela.
  - Puntero (`PointerOverlay`): flecha «Horizonte», punto o cruz. La punta
    dibujada ES el punto del clic (se lee con `getLocationOnScreen`); de la
    punta sale el anillo brasa del clic en los tres estilos. Puede llegar a
    cualquier píxel, barra de estado y bordes incluidos.
  - Si el puntero está sobre el propio panel, el panel se vuelve casi
    transparente y deja pasar toques mientras sale el gesto.
  - Al girar el teléfono o cambiar el tamaño de pantalla, las ventanas se
    reacomodan; al cerrarse o desvincularse el servicio se quitan ventanas,
    temporizadores y receptores.
- **Trackpad flotante de respaldo** (`FloatingTrackpadService`): panel abajo o
  ventana flotante (`pointer_open_mode`), superficie única (`FloatingPadView`,
  `PadGestures`), puntero `PointerOverlayManager`. Un toque en la línea de
  arriba lo cierra; clics por [`PointerLink`] (broadcast por clic).
- **Trackpad del teclado** (`TrackpadBridge`): capa dentro del teclado
  propio, independiente de la barra. Sus clics siguen yendo por los
  broadcast `OP_TAP` / `OP_LONG_PRESS` / `OP_SCROLL` (hasta la fase 4).

## Protocolo v2 (`PointerProtocol.kt`, espejo exacto en las dos apps)

Todos los broadcast son explícitos al paquete destino y protegidos con el
permiso de firma `…puntero.permission.POINTER` (declarado en las dos apps, misma
`debug.keystore`).

| Acción | Sentido | Extras |
|---|---|---|
| `ACTION_POINTER` | VoiceBubble → complemento | `op` (`tap`/`long_press`/`scroll`), `x`, `y`, `dy`, `seq` (v1, se conserva) |
| `ACTION_RESULT` | complemento → VoiceBubble | `seq`, `result` (v1, solo para clics por `ACTION_POINTER`) |
| `ACTION_OPEN_TRACKPAD` | VoiceBubble → complemento | `anchor_x`, `anchor_y` (Int px, −1 = sin ancla), `mode` (`panel`/`window`), `sensitivity` (Float 0,5–2,5), `accel` (`dynamic`/`linear`/`precision`), `style` (`arrow`/`dot`/`cross`), `haptic` (`subtle`/`none`/`firm`), `scroll_dir` (`natural`/`traditional`), `auto_return` (Int segundos, 0 = queda abierto) |
| `ACTION_CLOSE_TRACKPAD` | VoiceBubble → complemento | — |
| `ACTION_TRACKPAD_STATE` | complemento → VoiceBubble | `open` (Boolean); se manda al abrir y al cerrar |

- El complemento valida y normaliza `OPEN_TRACKPAD` con
  `PointerProtocol.normalizeTrackpadConfig` (función pura con test JVM): un
  valor desconocido o fuera de rango cae al valor por defecto, nunca rompe. Sin
  las dos coordenadas del ancla queda sin ancla. Abrir con el trackpad ya
  abierto lo vuelve a abrir en el lugar nuevo.
- `PointerLink.openTrackpad` lee las prefs de Flutter (`flutter.pointer_open_mode`,
  `flutter.kb_trackpad_sensitivity`, `…_accel_curve`, `…_pointer_style`,
  `…_haptic`, `…_scroll_direction`, `…_auto_return`) y las normaliza con la misma
  función. Ajustes guarda la dirección invertida como `standard`: el protocolo
  la manda como `traditional`.
- Los hápticos del panel usan `performHapticFeedback` (el complemento no pide
  el permiso `VIBRATE`): respetan «vibración al tocar» del sistema.
- `TRACKPAD_STATE` lo escucha `FloatingBubbleService` mientras vive
  (`PointerLink.listenTrackpadState`). El complemento también manda
  `open = false` si se desvincula o se destruye el servicio con el trackpad
  abierto, para que la burbuja no quede escondida.

## Clics en otras apps: complemento VoiceBubble Puntero

- VoiceBubble **no declara AccessibilityService** (perfil anti-Play-Protect,
  2026-09-05). Los gestos en otras apps los hace la app aparte **VoiceBubble
  Puntero** (`puntero_android/`), que sí tiene un servicio de Accesibilidad.
- El permiso de firma está declarado en las dos apps, así el orden de
  instalación no importa.
- Gestos de los broadcast v1 (trackpad del teclado y respaldo): cada clic lleva
  un número (`EXTRA_SEQ`); el complemento responde (`ACTION_RESULT`, solo a
  VoiceBubble) si Android lo hizo, lo interrumpió o lo rechazó. Si no responde en
  `ACK_TIMEOUT_MS`, el trackpad avisa que hay que apagarlo y prenderlo. Antes de
  cada clic, las ventanas propias de VoiceBubble que tapan el punto se vuelven
  transparentes e intocables durante el gesto (`OverlayPassThrough`): Android
  12+ bloquea toques bajo overlays opacos de otra app.
- Gestos del trackpad del complemento: salen directo con `dispatchGesture`
  (tap 40 ms, clic largo 450 ms, scroll por la cola `ScrollQueue`, arrastre
  950 ms) y siempre al soltar el dedo: Android cancela los gestos inyectados
  mientras haya un dedo real apoyado (el clic largo se arma al mantener y se
  hace al soltar; el scroll se junta y se manda al soltar, en tramos de hasta
  `MAX_SCROLL_PX`). Las ventanas del complemento son de Accesibilidad (de
  confianza): no hace falta apartarlas por la regla de Android 12, salvo el
  panel cuando el puntero está justo debajo de él.
- Sin complemento (o con su Accesibilidad apagada) **el puntero de respaldo se
  mueve pero no hace clic** en otras apps: `PointerLink` devuelve false y el
  trackpad avisa una vez cómo activarlo. El teclado cae a teclas locales
  (DPAD_CENTER / MENU / DPAD_UP-DOWN).

## Privacidad

- El complemento no lee ventanas (`canRetrieveWindowContent=false`), no
  registra eventos (`onAccessibilityEvent` vacío), no pide permisos extra y no
  guarda nada: contadores solo en memoria, cero logs de coordenadas.
- VoiceBubble solo envía la configuración del trackpad y, por el camino v1,
  coordenadas y el tipo de gesto; el complemento solo devuelve si el trackpad
  está abierto.

## Límites conocidos

- El botón de accesibilidad de Android ("Combinación de accesibilidad") del
  complemento lo prende y apaga: no es el puntero. Conviene dejarlo apagado.
- Si el servicio del complemento figura activado pero Android no lo inició,
  tocar «Puntero» no abre nada (VoiceBubble ve «activado» y no hay respaldo
  automático): apagarlo y prenderlo en Accesibilidad lo arregla.
- El trackpad de respaldo (`FloatingTrackpadService`) queda debajo de la barra
  de estado y la cortina de notificaciones; el del complemento no.
- Desenfoque real del vidrio: Android 12+ y solo en rectángulos
  redondeados (burbuja, abanico). La barra del borde, por su cuello cóncavo,
  usa vidrio lechoso propio.
- Con navegación por gestos, deslizar desde el borde es "Atrás": la barra
  reserva su alto (tope de Android 200 dp por borde) y se abre con un toque.
- Algunas pantallas sensibles del sistema pueden ocultar las ventanas
  flotantes.
- Instalado desde GitHub, Android 13+ pide "Permitir ajustes restringidos"
  antes de activar la Accesibilidad del complemento.

## Ajustes de la auditoría (2026-11-15)

- **Arrastre:** el trazo de espera (`willContinue`) y el de recorrido van en dos `dispatchGesture` encadenados: la continuación de un trazo se despacha en el gesto siguiente, al completarse el primero.
- **Complemento activado pero sin servicio:** si no llega `TRACKPAD_STATE` en 1 s tras `OPEN_TRACKPAD`, VoiceBubble abre el trackpad de respaldo (`FloatingTrackpadService`).
