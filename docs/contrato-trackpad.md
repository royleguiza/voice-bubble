# Trackpad y puntero: qué hace de verdad

> Fuente única del estado real del trackpad (SPK-23). Si la UI promete
> otra cosa, vale este doc. Actualizado 2026-10-30 (barra flotante).

## Dónde vive

- **Barra flotante** (`DockController`, servicio `FloatingBubbleService`):
  un solo objeto de vidrio con dos formas, barra en el borde o burbuja libre.
  Sus herramientas son Micrófono y Puntero (Ajustes › Barra flotante).
- **Trackpad flotante** (`FloatingTrackpadService`): lo abre la herramienta
  Puntero. Panel abajo o ventana flotante (`pointer_open_mode`). Un toque en
  la línea de arriba lo cierra; la línea se acorta mientras corre el cierre
  automático (`kb_trackpad_auto_return`).
  - Superficie única como el prototipo (`FloatingPadView`, gestos en
    `PadGestures`): deslizar mueve, tocar = clic, mantener = clic largo,
    dos dedos o la guía fina de la derecha = desplazar. Sin botones de mouse.
  - Puntero (`PointerOverlayManager`): flecha fina con sombra; la punta está
    en coordenadas de pantalla completa y el clic va a la punta tal como se
    ve dibujada (`getLocationOnScreen`).
    La ventana de la flecha empieza 3 px a la derecha y abajo de la punta:
    nunca tapa el punto del clic.
  - Android cancela los gestos del complemento mientras haya un dedo real
    apoyado: el clic largo se arma al mantener y se hace al soltar; el
    scroll se junta y se manda al soltar, en tramos (`scrollChunks`).
  - Con el trackpad abierto la burbuja se esconde y vuelve al cerrarlo
    (`DockController.setTrackpadOpen`); la barra del borde queda.
- **Trackpad del teclado** (`TrackpadBridge`): capa dentro del teclado
  propio, independiente de la barra.

## Clics en otras apps: complemento VoiceBubble Puntero

- VoiceBubble **no declara AccessibilityService** (perfil anti-Play-Protect,
  2026-09-05). Los clics, el clic largo y el scroll en otras apps los hace
  la app aparte **VoiceBubble Puntero** (`puntero_android/`), que sí tiene
  un servicio de Accesibilidad.
- Protocolo: `PointerProtocol.kt` (espejo exacto en las dos apps). VoiceBubble
  manda un broadcast explícito al paquete del complemento; el complemento
  solo lo acepta si quien envía tiene el permiso de firma
  `com.royleguiza.voicebubble.puntero.permission.POINTER`, declarado en las
  dos apps (misma `debug.keystore`), así el orden de instalación no importa.
- Antes de cada gesto, las ventanas propias que tapan el punto (puntero,
  panel, barra) se vuelven transparentes e intocables durante el gesto:
  Android 12+ bloquea toques bajo overlays de otra app con más de 80 % de
  opacidad (`OverlayPassThrough`).
- Cada clic lleva un número (`EXTRA_SEQ`). El complemento responde
  (`ACTION_RESULT`, solo a VoiceBubble y con el mismo permiso de firma) si
  Android lo hizo, lo interrumpió o lo rechazó. Si no responde en
  `ACK_TIMEOUT_MS`, el trackpad avisa que hay que apagarlo y prenderlo.
- Sin complemento (o con su Accesibilidad apagada) **el puntero se mueve
  pero no hace clic** en otras apps: `PointerLink` devuelve false y el
  trackpad avisa una vez cómo activarlo. El teclado cae a teclas locales
  (DPAD_CENTER / MENU / DPAD_UP-DOWN).

## Privacidad

- El complemento no lee ventanas (`canRetrieveWindowContent=false`), no
  registra eventos (`onAccessibilityEvent` vacío) y no guarda nada.
- VoiceBubble solo envía coordenadas y el tipo de gesto.

## Límites conocidos

- El botón de accesibilidad de Android ("Combinación de accesibilidad") del
  complemento lo prende y apaga: no es el puntero. Conviene dejarlo apagado.
- Desenfoque real del vidrio: Android 12+ y solo en rectángulos
  redondeados (burbuja, abanico, trackpad). La barra del borde, por su
  cuello cóncavo, usa vidrio lechoso propio.
- Con navegación por gestos, deslizar desde el borde es "Atrás": la barra
  reserva su alto (tope de Android 200 dp por borde) y se abre con un toque.
- Algunas pantallas sensibles del sistema pueden ocultar las ventanas
  flotantes.
- Instalado desde GitHub, Android 13+ pide "Permitir ajustes restringidos"
  antes de activar la Accesibilidad del complemento.
