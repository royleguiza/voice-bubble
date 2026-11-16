# Fase 3 — Complemento independiente (implementada 2026-11-16)

> Hecha directo por el coordinador, sin subagentes (pedido del dueño).
> Plan general: `docs/plan-puntero-isla.md`.

## Para qué
Que VoiceBubble Puntero sirva solo, sin VoiceBubble, a quien tiene una zona
muerta en la pantalla: abrir el trackpad desde una pestaña propia, dejarlo
en la parte sana de la pantalla y ajustar lo mínimo.

## Qué hace
1. **Pestaña propia** (`DockManager.effective`): si la barra de VoiceBubble
   está apagada —o VoiceBubble no está instalada, aunque haya quedado
   guardada una configuración encendida— y la persona encendió «Pestaña en
   el borde» en la pantalla del complemento, se dibuja la barra del borde
   (o la burbuja, si la arrastran al centro) con **solo el puntero**.
   Tocarla abre el trackpad. La barra de VoiceBubble siempre manda: con las
   dos encendidas se ve solo la de VoiceBubble. La pestaña propia no le
   cambia la forma a la barra de VoiceBubble ni le escribe nada.
2. **Ventana libre que se mueve y se achica** (`TrackpadGeometry.Placement`,
   `TrackpadPanel.GripTouch`): en el modo «Ventana libre» la agarradera la
   mueve (ya existía) y una esquina abajo a la derecha la agranda o achica
   (mínimo 220 × 200 dp, máximo la pantalla sin la barra de navegación). Al
   soltar se guarda el lugar (fracción de pantalla) y el tamaño (dp) en
   `vb_puntero_dock`; la próxima vez se abre ahí, no junto al ancla. Al
   girar conserva el tamaño elegido. «Volver a poner el trackpad en su
   lugar» borra lo guardado.
3. **Ajustes propios mínimos** (pantalla del complemento): pestaña sí/no,
   lado (izquierda/derecha), y —solo si VoiceBubble NO está instalada—
   forma del trackpad (ventana libre por defecto / panel abajo), estilo del
   puntero (flecha/punto/cruz) y sensibilidad (0,5–2,5). Con VoiceBubble
   instalada esos tres se ajustan en VoiceBubble › Ajustes › Trackpad.
   Todo se aplica en vivo (`PunteroService.refreshOwnSettings`).

## Extra (pedido del dueño el mismo día)
- Host: si el complemento está instalado pero no dibuja la barra (Android le
  apagó la Accesibilidad al actualizar, o quedó activado pero trabado), la
  notificación de VoiceBubble lo dice y al tocarla abre Accesibilidad
  (`FloatingBubbleService.updateComplementWarning`). Se limpia sola cuando
  el complemento vuelve.

## Privacidad
Sin cambios: solo se guardan ajustes y el lugar/tamaño del trackpad; nada de
coordenadas de clics, texto ni apps. Sin `Log`.

## Verificación
- Complemento: `compileDebugKotlin` + tests JVM 112/0 (6 nuevos en
  `TrackpadGeometryTest`: lugar guardado, panel lo ignora, ida y vuelta,
  mínimo/máximo al cambiar tamaño, giro conserva tamaño, pantalla más chica).
- Host: `compileDebugKotlin` OK.
- Suites: barra 301/0, trackpad 213/0 (checks de fase 3 nuevos), ajustes
  157/0; diff de `const val` entre los `PointerProtocol.kt` vacío (el
  protocolo no cambió).

## Para probar en el teléfono
- Con la barra de VoiceBubble apagada: complemento › «Pestaña en el borde»
  encendida → aparece la pestaña; tocarla abre el trackpad; cambiar el lado.
- Ventana libre: mover desde la línea de arriba, achicar desde la esquina,
  cerrar y reabrir → aparece donde quedó; girar el teléfono.
- Encender la barra de VoiceBubble → la pestaña se va y queda la barra.
- Apagar VoiceBubble Puntero en Accesibilidad con la barra encendida → la
  notificación de VoiceBubble avisa; tocarla abre Accesibilidad.
