# Fase 4 — Unificar y cerrar (implementada 2026-11-16)

> Hecha directo por el coordinador, sin subagentes (pedido del dueño).
> Plan general: `docs/plan-puntero-isla.md`.

## Qué hace
1. **Un solo puntero** (`TrackpadBridge.openComplementTrackpad`): con el
   complemento listo (instalado y activado), el botón de trackpad del
   teclado abre el trackpad del complemento, anclado arriba del teclado
   (por encima de todo, con Atrás/Inicio/Recientes/Notificaciones y
   arrastre). Sin complemento, sigue la capa de trackpad dentro del teclado
   de siempre (con sus respaldos DPAD de C-36).
2. **Historial con toque largo en la barra del complemento** (pendiente 2):
   toque largo de 500 ms en la barra del borde o la burbuja → broadcast
   firmado `ACTION_DOCK_HISTORY` (x, y, lado) → VoiceBubble muestra SU panel
   de historial (`FloatingBubbleService.showHistoryFromComplement`), solo si
   la barra está viva y el historial encendido en Ajustes. El texto dictado
   nunca pasa por el complemento. La isla no tiene toque largo (cada mitad
   es un botón). La pestaña propia (fase 3) no tiene historial.
3. **Sin respaldo por tiempo** (pendiente 1, «trackpad viejo debajo del
   nuevo»): si el complemento está listo pero no contesta a `OPEN_TRACKPAD`
   en 2,5 s, ya NO se abre `FloatingTrackpadService`; se avisa (Toast + la
   notificación de la barra explica y abre Accesibilidad). El trackpad viejo
   solo se abre cuando el complemento NO está listo (explica qué falta).

## Protocolo
v3 + `ACTION_DOCK_HISTORY` y `EXTRA_HISTORY_X/Y/SIZE` en los dos
`PointerProtocol.kt` (diff de `const val` vacío); receptor del manifiesto
`DockLinkReceiver` con la acción nueva (permiso de firma).

## Limitación conocida
El panel de historial es una ventana de la app (`TYPE_APPLICATION_OVERLAY`):
queda por debajo de la barra del complemento, que se sigue viendo encima.

## Verificación
Complemento: compila + JVM 112/0. Host: `compileDebugKotlin` OK. Suites:
barra 301/0, trackpad 214/0, ajustes 157/0, master 98/100 (C-34 previo).

## Para probar en el teléfono
- Teclado de VoiceBubble › botón de trackpad → se abre el trackpad del
  complemento (no la capa dentro del teclado); un solo puntero.
- Ajustes › Barra flotante › Historial encendido; toque largo en la barra
  del borde o la burbuja → aparece el historial.
- Apagar y prender el complemento varias veces y abrir el puntero desde la
  barra → nunca dos trackpads; si no responde, aparece el aviso.
