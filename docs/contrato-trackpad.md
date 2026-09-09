# Trackpad: puntero local, sin clics fuera

> Fuente única del estado real del trackpad (SPK-23). Si la UI promete
> otra cosa, vale este doc.

- El puntero se mueve SOLO dentro del overlay propio
  (`PointerOverlayManager` sobre `TYPE_APPLICATION_OVERLAY`).
- Los clics/scrolls hacia otra app están **dormidos**: sin
  `AccessibilityService` declarado en el manifest,
  `VoiceBubbleAccessibilityService.isConnected()` es siempre falso y
  `dispatchTap/LongPress/Scroll` son no-ops (con guard explícito en
  `FloatingTrackpadService` + fallback a `DPAD_CENTER`/`MENU` en
  `TrackpadBridge` para el teclado).
- La UI lo vende como **"puntero local"**: no hace clic fuera sin
  accesibilidad. No dejar promesa rota.
- Privacidad: cero monitoreo de ventanas, cero registro de eventos
  (`onAccessibilityEvent` vacío, sin logs).
- Si algún día se declara el servicio, este doc + la UI + los guards se
  actualizan juntos. Hoy: dormido.
