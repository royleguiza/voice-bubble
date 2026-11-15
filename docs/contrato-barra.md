# Barra flotante en el complemento: qué hace de verdad

> Fuente única de la barra flotante (borde · burbuja · isla) desde la fase 2A
> (2026-11-15). Si la UI promete otra cosa, vale este doc. El trackpad y el
> protocolo v2 siguen en `docs/contrato-trackpad.md`. Diseño de la isla:
> `laboratorio_ui/isla.html` y `design.md` («Burbuja y barra flotante»).

## Por qué

La barra la dibujaba VoiceBubble desde `FloatingBubbleService`, que solo
arranca al abrir la app y no se relanza solo: si Android cerraba la app
(memoria, batería, reinicio, actualización) la barra DESAPARECÍA. Y el dictado
pasaba por Flutter: con la actividad muerta, tocar el micrófono no hacía nada.

Android mantiene vivo y relanza solo (también tras reiniciar) un servicio de
Accesibilidad. Por eso la barra la dibuja ahora el complemento
`puntero_android/` (VoiceBubble Puntero) como ventanas
`TYPE_ACCESSIBILITY_OVERLAY`, y el dictado lo hace un servicio NATIVO de
VoiceBubble, sin Flutter.

## Quién dibuja qué

| | Complemento VoiceBubble Puntero (preferido) | `FloatingBubbleService` de VoiceBubble (respaldo) |
|---|---|---|
| Cuándo | complemento instalado y su Accesibilidad activa, barra encendida en Ajustes | el complemento no está listo, o dejó de dibujar |
| Formas | borde, burbuja e **isla** | borde y burbuja (la isla se ve como burbuja) |
| Ventanas | `TYPE_ACCESSIBILITY_OVERLAY` (`DockWindow`): por encima de la barra de estado, la cortina y los diálogos; la isla además con `FLAG_LAYOUT_NO_LIMITS`, sin insets y con el recorte de la cámara | `TYPE_APPLICATION_OVERLAY` (`GlassWindow`) |
| Código | `DockManager` (quién dibuja y el enlace con VoiceBubble), `DockController` (borde + burbuja), `IslandController` + `IslandView` (isla), `DockGeometry`, `IslandGeometry`, `HorizonView`, `DockPrefs` | `DockController`, `DockViews`, `GlassWindow` |
| Estado guardado | prefs PROPIAS del complemento (`vb_puntero_dock`): última configuración y posición | prefs de VoiceBubble (`vb_dock_state`, `flutter.dock_*`) |
| Dictado | pide a VoiceBubble que dicte (`DockDictationService`) | Flutter (`MainActivity` → canal → Dart) |
| Puntero | abre el `TrackpadController` directo, sin broadcast | `PointerLink.openTrackpad` (broadcast `OPEN_TRACKPAD`) |
| Historial (toque largo) | NO se porta en esta fase (queda para la fase 4) | sí |

**Nunca se ven dos barras.** El host (`FloatingBubbleService`) esconde la suya
(`DockController.setSuppressed`) mientras el complemento dibuja:

1. Al arrancar, si `PointerLink.isReady` es cierto, la barra de respaldo nace
   ESCONDIDA y el host le manda `DOCK_CONFIG` con `ack=true`. El complemento
   contesta `DOCK_STATE`: `active=true` → sigue escondida; `active=false` → se
   muestra. Si no contesta en 1,2 s (Accesibilidad activada pero Android no
   inició el servicio) → se muestra la de respaldo.
2. Si después el complemento deja de dibujar (se apaga la Accesibilidad, se
   destruye el servicio), manda `DOCK_STATE active=false` en `onUnbind` /
   `onDestroy` y la de respaldo aparece (si el servicio de VoiceBubble sigue vivo).
3. Si el complemento arranca después (la persona activa la Accesibilidad),
   `DOCK_HELLO` → `DOCK_CONFIG` → dibuja → `DOCK_STATE active=true` → el respaldo
   se esconde.
4. El complemento dice `active=true` solo si Android dejó crear la ventana
   (`DockSurface.isDrawing`); si no, VoiceBubble muestra la suya.

Hay un instante (≈ un broadcast) en el caso 3 en que se ven las dos. Si el
sistema mata el proceso del complemento sin pasar por `onUnbind`, el host sigue
escondida hasta que Android relance el servicio (segundos).

## Protocolo v3 (`PointerProtocol.kt`, espejo exacto en las dos apps)

Todo es broadcast explícito al paquete destino con el permiso de firma
`…puntero.permission.POINTER`. No viajan audio ni texto: solo ajustes y estados.

| Acción | Sentido | Extras |
|---|---|---|
| `ACTION_DOCK_CONFIG` | VoiceBubble → complemento | `enabled` (la barra está encendida en Ajustes), `form` (`edge`/`bubble`/`island`), `tool_mic`, `tool_pointer`, `island_x`, `island_y` (centro horizontal y borde superior, px de pantalla completa; −1 = por defecto), `island_w`, `island_h` (px en reposo; −1 = 112 × 30 dp), `island_side` (`left`/`right`: lado del micrófono), la configuración del trackpad (`mode`, `sensitivity`, `accel`, `style`, `haptic`, `scroll_dir`, `auto_return`, sin ancla) y `ack` (Boolean: contestar con `DOCK_STATE` aunque nada haya cambiado) |
| `ACTION_MIC_STATE` | VoiceBubble → complemento | `state` (`idle`/`recording`/`transcribing`/`done`/`error`), `level` (Float 0..1, solo grabando, ≤ 15 Hz), `message` (frase corta FIJA para `done`/`error`, nunca texto dictado), `needs_ui` (Boolean, solo con `error`: VoiceBubble no pudo arrancar en segundo plano) |
| `ACTION_DOCK_HELLO` | complemento → VoiceBubble | — (el servicio arrancó o quiere configuración; VoiceBubble contesta con `DOCK_CONFIG`; receptor en el MANIFIESTO, funciona con la app cerrada) |
| `ACTION_DOCK_STATE` | complemento → VoiceBubble | `active` (Boolean: está dibujando la barra), `form` (opcional: la persona la convirtió con el dedo, barra ↔ burbuja; VoiceBubble lo guarda en `flutter.dock_form` para que Ajustes lo muestre) |
| `ACTION_DICTATION_TOGGLE` / `ACTION_DICTATION_CANCEL` | complemento → servicio `DockDictationService` | `from_trampoline` (Boolean, solo lo manda la actividad trampolín) |

- `PointerProtocol.normalizeDockConfig` y `normalizeMicState` (funciones puras
  con test JVM en las dos apps) validan todo: lo desconocido o fuera de rango
  cae al valor por defecto, nunca rompe. Sin ninguna herramienta queda el
  micrófono. Las medidas de la isla se acotan además a los límites de la maqueta
  (ancho 72–180 dp, alto 22–48 dp) y a la pantalla (`IslandGeometry`).
- Extras agregados a la especificación original: `ack` (para el apretón de
  manos «nunca dos barras» sin inundar de respuestas cuando Ajustes mueve la
  isla en vivo), `form` en `DOCK_STATE` (para no perder la forma que la persona
  eligió con el dedo) y `needs_ui` en `MIC_STATE` (para pedir la actividad
  trampolín).
- Al encender o apagar la barra, Dart guarda `floating_bubble_enabled` DESPUÉS de
  llamar al servicio: por eso `MainActivity` manda `DOCK_CONFIG` con el valor ya
  decidido (`DockLink.sendConfig(enabledOverride = …)`).

## Dictado nativo (`DockDictationService`, host)

- Servicio en primer plano (micrófono), modelado sobre `WidgetDictationService`,
  **exportado SOLO con el permiso de firma** (`android:permission` en el
  manifiesto): ninguna otra app puede arrancarlo. Acciones `TOGGLE` (empezar /
  terminar) y `CANCEL`. Máquina de estados pura: `DockDictationLogic`.
- Lo arranca el complemento con `startForegroundService` explícito (tiene una
  ventana visible, lo que habilita el micrófono «mientras se usa»). Antes
  comprueba que VoiceBubble tenga el permiso de micrófono.
- Si Android igual lo niega (`startForeground` con tipo micrófono falla, o el
  complemento no puede arrancarlo), respaldo: la actividad trampolín
  `DockTrampolineActivity` (translúcida, sin animación, fuera de recientes,
  exportada SOLO con el permiso de firma) arranca el servicio estando en primer
  plano y se cierra sola. El servicio avisa con `MIC_STATE error` + `needs_ui`.
- Misma configuración y clave que el teclado y el widget (`SpeechToTextClient`),
  misma exclusión del micrófono (`BackgroundWork.tryClaimMicrophone`), mismos
  sonidos y hápticos de micrófono (`DockMicFeedback`: `kb_mic_*`).
- Resultado como el de la burbuja de siempre: historial nativo
  (`TranscriptionHistoryRepository`) + portapapeles + pegado si el teclado
  activo es el de VoiceBubble («Pegado») o «Copiado» si no. No crea notas. Audio
  de menos de 8000 bytes: se descarta sin avisar.
- Errores con frase corta fija en español: «Falta la clave de Groq», «Falta el
  permiso del micrófono», «El micrófono está ocupado», «Sin conexión», «La clave
  de Groq no sirve», «Límite de uso alcanzado», «No se pudo transcribir», «No se
  entendió nada». La isla los muestra en su estado «listo»; la burbuja y la barra
  vuelven a reposo como hoy.
- Latidos: grabando manda el nivel cada 70 ms (≤ 15 Hz); transcribiendo repite el
  estado cada 1,5 s. Si el complemento pasa 6 s sin noticias de un dictado en
  curso (el host murió), vuelve solo a reposo (`MicStateTracker`).
- El dictado por Flutter de la app (botón de micrófono de Inicio) también se ve
  en la barra del complemento: `FloatingBubbleService` repite su estado hacia
  `MIC_STATE` mientras el servicio nativo no esté dictando.

## La isla

- Píldora negra siempre (`island_bg`/`island_line`, mismo valor de día y de
  noche), borde de 1 dp. Estados y medidas (dp): reposo `w × h` configurables
  (por defecto 112 × 30); abierta 176 × 58 con micrófono (agujero 42) y puntero;
  grabando 252 × 44 con agujero de 32 (toque = terminar), franja de voz, cronómetro
  mono y ✕; pensando igual con rayitas y arco; listo 128 × 34 (se ensancha si la
  frase no entra) durante 1,3 s (2,6 s si es un error).
- `x` = centro horizontal, `y` = borde superior, en px de pantalla completa. Al
  crecer se mantiene centrada en `x`. Siempre queda dentro de la pantalla, con
  4 dp de margen lateral, en cualquier tamaño de teléfono (`IslandGeometry.bounds`).
- Rebote ≈ 420 ms con overshoot leve. La ventana mide justo lo que la píldora
  salvo durante el rebote (unión del tamaño viejo y el nuevo). Con «quitar
  animaciones» del sistema, el cambio es directo y la voz queda como anillo fijo.
- Con una sola herramienta activa, el toque en reposo la ejecuta directo.
  Abierta se cierra sola a los 4 s. El puntero abre el trackpad y la isla vuelve
  al reposo con el glifo en brasa mientras el trackpad está abierto.
- Accesibilidad: `contentDescription` en español en la isla («Isla de
  VoiceBubble. Tocá para abrirla», «Grabando», «Transcribiendo»…), en cada botón
  («Dictar», «Terminar dictado», «Cancelar dictado», «Abrir el puntero»); la
  isla es una región `polite` (se anuncia «Pegado»/errores). La barra y la burbuja
  ofrecen «Dictar» y «Abrir el puntero» como acciones de TalkBack.

## Ciclo de vida

- `PunteroService.onServiceConnected` crea el `DockManager`, que dibuja lo último
  guardado y manda `DOCK_HELLO`. `onUnbind` y `onDestroy` lo destruyen: se sacan
  las ventanas (barra, burbuja, abanico, isla), los animadores y todos los
  temporizadores, y se manda `DOCK_STATE active=false`. El receptor lo suelta el
  servicio.
- Giro, otro tamaño de pantalla o cambio de tema (`onConfigurationChanged`): la
  isla se reacomoda, el borde y la burbuja rehacen su posición desde lo guardado
  (fracciones de la pantalla) y la paleta se relee.
- Cerrar la barra en VoiceBubble (Ajustes o «Cerrar» en la notificación) manda
  `DOCK_CONFIG enabled=false` y deja `floating_bubble_enabled=false`: la barra
  del complemento no vuelve tras reiniciar. Si Android mata a VoiceBubble sin
  que se cierre el servicio, la barra del complemento SIGUE (es lo que se busca).
- Tras reiniciar el teléfono: Android relanza el servicio de Accesibilidad, que
  dibuja la última configuración guardada y manda `DOCK_HELLO`; VoiceBubble (el
  receptor del manifiesto la despierta) contesta con la configuración al día.

## Privacidad

- `canRetrieveWindowContent="false"`, cero logs, sin permisos nuevos (un solo
  `uses-permission`, el de firma). El audio y el texto nunca pasan por el
  complemento: solo estados, el nivel de voz y frases fijas.
- El complemento guarda en `vb_puntero_dock` solo ajustes de la barra: forma,
  herramientas, medidas de la isla, lado del micrófono, la configuración del
  trackpad que mandó VoiceBubble y la posición de la barra / burbuja. Nada de
  coordenadas de clics, apps ni contenido.

## Pendiente

- Fase 2B (Ajustes de Flutter): elegir la isla, ajuste al píxel con maqueta y en
  vivo. El host ya lee `dock_island_x/_y/_w/_h/_side` y `floating_bubble_enabled`
  con el prefijo compuesto (`FlutterPrefs.key`), SIN el literal `flutter.…`: en 2B
  esas claves se suman a `bridgeKeys` de Dart y a `docs/contract-keys.txt` (hoy
  son 55, con paridad Kotlin == Dart == contrato).
- Fase 4: toque largo (historial) en la barra del complemento; retirar el respaldo.
