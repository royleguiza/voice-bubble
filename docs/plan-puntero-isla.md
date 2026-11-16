# Plan: puntero por encima de todo + isla flotante

> **Si retomás este trabajo (otro modelo u otra sesión), empezá por la
> sección «Estado y traspaso».** Todo lo necesario está en el repo; no hace
> falta la conversación original.

## Estado y traspaso (actualizado 2026-11-15)

| Fase | Qué es | Estado | Commit | APK |
|---|---|---|---|---|
| 1 | Trackpad y puntero en el complemento, por encima de todo; botones de sistema; arrastre | HECHA, probada por el dueño en su teléfono | `4cdc47c` | r315 |
| 2A | Barra flotante (borde · burbuja · isla) dibujada por el complemento; dictado nativo sin Flutter | HECHA; el dueño confirmó con r317 que la barra y el dictado funcionan (falta probar reinicio y app cerrada) | `30ef040` | r316 |
| 2B | Ajustes de la isla (elegirla, ajuste al píxel, maqueta, en vivo) | HECHA; el dueño confirmó con r317 que la isla funciona | `278cc41` | r317 |
| 2C | Isla sin paso intermedio: cada mitad es su botón (pedido del dueño tras probar r317) | HECHA y subida; falta prueba en teléfono | `fb7fa16` | r318 |
| 2D | Isla sin saltos al crecer y achicarse (pedido del dueño tras probar r318) | HECHA y subida; falta prueba en teléfono | ver `git log` | r319 |
| 3 | Complemento independiente (pestaña propia, mover/achicar trackpad, ajustes mínimos) | PENDIENTE, sin especificación | — | — |
| 4 | Un solo puntero también para el trackpad del teclado; historial; limpieza | PENDIENTE, sin especificación | — | — |

### Ajuste 2C — isla de toque directo (2026-11-15)
Pedido del dueño al probar r317: la isla «iba a saltos» (reposo → abierta
sobre la cámara → grabando) y pedía dos toques. Decisión:
- La isla **ya no se abre**. En reposo, tocar la mitad del agujero dicta y
  tocar la mitad del glifo abre el trackpad (`IslandGeometry.idleTapTool`).
  Con una sola herramienta, toda la isla es esa herramienta.
- El **borde y la burbuja NO cambian**: siguen con dos toques (abrir y
  elegir). Es a propósito.
- Grabando, tocar cualquier parte de la píldora termina (antes solo el
  agujero, que al crecer la isla quedaba lejos del dedo); la ✕ cancela.
- Se borró el estado `OPEN` (enum, medidas 176 × 58, botón de puntero,
  cierre a los 4 s). TalkBack: acciones «Dictar» y «Abrir el puntero».
- La maqueta `laboratorio_ui/isla.html` todavía muestra el estado
  «Abierta»: quedó vieja en ese punto (manda `design.md`).
- Verificado: tests JVM del complemento 106/0, `test_floating_dock_suite`
  301/0, `test_trackpad_suite` 206/0. No se corrió lint (falta
  `lint-gradle` en la caché sin red). Falta la prueba en teléfono.

### Ajuste 2D — isla sin saltos (2026-11-16)
Con r318 el dueño confirmó el toque directo y el pegado desde la isla con
un campo enfocado, pero vio un salto al pasar de la píldora chica a la de
grabar y al volver. Causas y arreglo:
- El agujero y la flecha del reposo se dibujaban con la medida FINAL:
  saltaban a los extremos de la píldora grande. Ahora se dibujan con la
  medida de ese momento y acompañan el borde.
- Las piezas de grabar (agujero, ✕, cronómetro) se ubicaban desde el
  centro con la medida final y aparecían fuera de la píldora; ahora van
  pegadas a su borde (`IslandView.anchoredCx`) y se apagan de a poco al
  pasar a «listo» (antes desaparecían de golpe).
- Curva `OvershootInterpolator(1.1)` → `PathInterpolator(0.4, 0, 0.2, 1)`;
  margen de la ventana de animación 12 → 0 dp (al crecer la ventana ya es
  la final y no se mueve al terminar).
- Nota r318: al actualizar el complemento, Android le apagó la
  Accesibilidad y se vio la burbuja de respaldo de la app en vez de la
  isla; se arregló apagando y prendiendo el permiso. Idea pendiente: que
  la app avise cuando el complemento está instalado pero apagado.

### Pendientes abiertos (además de las fases 3 y 4)
0. **El dictado de la barra no siempre pega el texto** (con r318 el dueño
   confirmó que desde la isla SÍ pega si hay un campo enfocado; reportado con r317:
   desde la isla copió pero no pegó; desde el borde sí). El código es el
   mismo para las tres formas: `DockDictationService.onTranscribed` copia
   al portapapeles y pega con `VoiceKeyboardService.commitFromExternal`,
   que solo funciona si el teclado de VoiceBubble está activo con un campo
   de texto enfocado (en la captura del dueño el campo no tenía el cursor
   ni el teclado abierto). Hipótesis a descartar: que el trampolín, al
   abrir una actividad, le saque el foco al campo. Mejora posible (decisión
   del dueño, NO hecha): que pegue con cualquier teclado usando el
   complemento (API de Accesibilidad `getInputMethod()`, Android 13+); eso
   hace pasar el texto dictado por el complemento y cambia la regla de
   privacidad «el texto nunca pasa por el complemento».
1. **Trackpad viejo debajo del nuevo.** Reportado por el dueño con r315 y
   de nuevo después («sigue quedando»; no confirmó si ya tenía r316): al
   abrir el trackpad del complemento se abre también, escondido debajo, el
   `FloatingTrackpadService` del host (se ven dos punteros) y queda a la
   vista al cerrar el nuevo. Causa conocida: el respaldo por silencio de
   `PointerLink.openTrackpad` (`OPEN_ANSWER_MS`) dispara porque
   `ACTION_TRACKPAD_STATE` no llega a tiempo (o no llega) al host. Mitigado
   en `30ef040` (plazo 2,5 s y cierre del respaldo si la respuesta llega
   tarde) pero NO confirmado. Investigar por qué no llega el broadcast
   (receptor de `FloatingBubbleService`, permiso de firma, proceso en caché)
   o reemplazar el respaldo por tiempo por una comprobación directa. Con la
   barra dibujada por el complemento (2A) este camino ya casi no se usa.
   El dueño pidió dejarlo para más adelante.
2. **Historial con toque largo** sobre la burbuja/barra: no existe en la
   barra del complemento (va en la fase 4).
3. **Probar en teléfono 2A y 2B** (listas en `docs/contrato-barra.md` y en
   los mensajes de commit): barra tras reiniciar, dictado con la app
   cerrada (ruta directa o trampolín), nunca dos barras, isla en vivo desde
   Ajustes, maqueta fiel. Riesgo anotado: tope vertical de la isla en
   teléfonos con barra de navegación de 3 botones.
4. `test_master_suite.py` da 98/100: los dos que fallan son C-34 (firma,
   lockfile, pinning del CI), previos a este plan y fuera de alcance.

### Cómo se viene trabajando (pedido del dueño)
- **Desde 2026-11-15 (después de 2C), SIN SUBAGENTES** (pedido explícito
  del dueño): el mismo asistente planifica, escribe la especificación de
  cada fase (`docs/spec-puntero-fase*.md`), implementa, recompila, corre
  tests y suites, revisa y commitea; todo directo. Mantener la revisión
  final propia antes de cada commit: en las fases anteriores (hechas con
  subagentes) la revisión encontró errores reales (gesto de arrastre mal
  encadenado, servicio de dictado que podía matar la app, respaldo que
  abría dos trackpads).
- **Nunca push sin autorización explícita del dueño.** Él prueba cada APK
  en su teléfono (artefactos `voice-bubble-arm64-profile-apk-rNNN` y
  `voice-bubble-puntero-apk-rNNN`; hay que instalar los dos) y manda
  capturas. Docs solas: commit con `[skip ci]`.
- Responderle en español rioplatense, claro y sin jerga; es el dueño del
  producto, no programa.
- Diseño: Horizonte (`design.md`). Maquetas aprobadas: isla y trackpad en
  `laboratorio_ui/isla.html` (artifact
  https://claude.ai/artifact/QQTNtVoHFwqP6m5h8jy4xk); puntero y animaciones
  en https://claude.ai/artifact/Ko8GmvLFjf9qXVYxx8Sk9G.

### Dónde está cada cosa
- Especificaciones: `docs/spec-puntero-fase1.md`, `-fase2a.md`, `-fase2b.md`
  (modelo para escribir las de las fases 3 y 4).
- Contratos: `docs/contrato-trackpad.md` (protocolo v2), `docs/contrato-barra.md`
  (protocolo v3, quién dibuja qué), `docs/contrato-claves.md` +
  `docs/contract-keys.txt` (61 claves de Ajustes).
- Complemento: `puntero_android/` (Kotlin puro, sin androidx; servicio de
  Accesibilidad `PunteroService`, `TrackpadController`, `DockManager`,
  `IslandController`). Host nativo: `voice_bubble_stt/android/…/voicebubblestt/`
  (`PointerLink`, `DockLink`, `DockDictationService`, `DockTrampolineActivity`,
  `FloatingBubbleService` y `FloatingTrackpadService` como respaldo).
  Flutter editable: `app_source/` (el CI lo copia a `voice_bubble_stt/`).
- Compilar y probar en el servidor (2 GB de RAM): `docs/plan-build-local.md`
  y la sección «Verificación obligatoria» de `docs/spec-puntero-fase1.md`.
  Siempre en copias, una Gradle por vez, nunca junto con `flutter test`; si
  el sistema mata la corrida por memoria, repetir por tandas (complemento,
  host, tests) con `-Xmx900m`.
- Líneas base al cierre de 2B: `flutter analyze` limpio, `flutter test` 757,
  `test_floating_dock_suite.py` 301/0, `test_trackpad_suite.py` 206/0,
  `test_settings_redesign_suite.py` 157/0, `test_master_suite.py` 98/100,
  diff de `const val` entre los dos `PointerProtocol.kt` vacío.
- Historial del servidor y de cada entrega: `/home/ubuntu/entorno.md`.

## Para quién es

Alguien a quien le dejó de funcionar una parte de la pantalla (golpe, zona
muerta) y, en vez de cambiar el teléfono, instala VoiceBubble Puntero: mueve
el dedo en la zona sana y un puntero llega a donde el dedo ya no puede. Por
eso el puntero tiene que alcanzar TODO: apps, barra de estado, cortina de
notificaciones, ajustes rápidos, diálogos del sistema, y dar Atrás / Inicio /
Recientes sin tocar la zona de navegación.

## Hechos de Android que mandan en el diseño

1. Las ventanas flotantes de una app (`TYPE_APPLICATION_OVERLAY`) quedan
   DEBAJO de la barra de estado y de la cortina, y Android 12+ bloquea toques
   que pasan bajo ellas. Solo `TYPE_ACCESSIBILITY_OVERLAY` (ventana de un
   servicio de Accesibilidad) queda por encima de todo y es de confianza.
2. Mientras hay un dedo real en la pantalla, Android cancela los gestos
   inyectados. Todo gesto (clic, clic largo, scroll, arrastre) se despacha AL
   SOLTAR el dedo, nunca durante.
3. VoiceBubble (teclado + micrófono) NO declara Accesibilidad (decisión
   vigente, perfil anti-Play-Protect). Todo lo que necesita Accesibilidad vive
   en el complemento `puntero_android/` (misma firma, permiso de firma
   `…puntero.permission.POINTER`).
4. Una app no puede leer las preferencias de otra: VoiceBubble le manda la
   configuración al complemento por broadcast firmado.
5. La burbuja y la barra lateral siguen en VoiceBubble y funcionan con
   cualquier teclado (Gboard, etc.): no dependen del teclado propio. Eso no
   se toca.

## Arquitectura destino

```
VoiceBubble (host)                     VoiceBubble Puntero (complemento)
- teclado, dictado, notas, widget      - servicio de Accesibilidad
- burbuja y barra lateral (overlay)    - puntero (accessibility overlay)
- Ajustes de todo (Flutter)            - trackpad (accessibility overlay)
        │  broadcasts firmados  ▲      - isla flotante (accessibility overlay)
        ├── OPEN_TRACKPAD + config ──► - gestos: clic, clic largo, scroll,
        ├── CONFIG (isla, puntero) ──►   arrastre, Atrás/Inicio/Recientes/
        ├── MIC_STATE (isla) ────────►   Notificaciones
        ◄── MIC_TOGGLE (isla) ────────┤ - pantalla propia: estado, prueba,
        ◄── TRACKPAD_STATE ───────────┤   ajustes mínimos (uso sin VoiceBubble)
```

## Fases

### Fase 1 — Trackpad y puntero en el complemento (por encima de todo)
- Puntero y panel del trackpad como `TYPE_ACCESSIBILITY_OVERLAY` dentro de
  `PunteroService`; los gestos salen directo (sin broadcast por clic).
- Fila de sistema en el panel: Atrás, Inicio, Recientes, Notificaciones.
- Arrastre en dos pasos (botón «Arrastrar»: toque = agarrar, mover, toque =
  soltar → un solo trazo con espera inicial, despachado al soltar).
- Protocolo v2: `OPEN_TRACKPAD` (ancla + configuración), `CLOSE_TRACKPAD`,
  `TRACKPAD_STATE` de vuelta. La herramienta «Puntero» de la burbuja/barra
  abre el trackpad del complemento; si falta o está apagado, lleva a
  resolverlo.
- Complemento con diseño Horizonte (hoy usa colores genéricos).
- El host conserva `FloatingTrackpadService` solo como respaldo cuando el
  complemento no está listo (se retira en la fase 4). El trackpad
  integrado al teclado (`TrackpadBridge`) queda como está hasta la fase 4.
- Especificación: `docs/spec-puntero-fase1.md`.

### Fase 2 — Barra flotante en el complemento + isla
> Ampliada el 2026-11-15 (aprobado por el dueño): la burbuja y la barra
> desaparecían porque el host solo las enciende al abrir la app. Pasan a
> dibujarse en el complemento (Android lo mantiene vivo y lo relanza tras
> reiniciar); el host queda de respaldo si el complemento no está.
> - **2A** (`docs/spec-puntero-fase2a.md`): barra (borde · burbuja · isla) en
>   el complemento, protocolo v3, dictado nativo del host sin Flutter.
> - **2B** (`docs/spec-puntero-fase2b.md`, implementada en local 2026-11-15): Ajustes de
>   Flutter (elegir Isla, ajuste al píxel, maqueta, en vivo).

- Tercera forma de la barra (burbuja · barra lateral · **isla**): píldora
  negra tipo isla dinámica, dibujada por el complemento para poder vivir en
  la zona de la cámara. Reposo compacto; al tocar se expande con micrófono y
  puntero; grabando muestra la animación de voz; pensando, las rayitas.
- Ajustes › Barra flotante: elegir «Isla» y ajustarla al píxel (pedido del
  dueño, 2026-11-15): posición horizontal y vertical, ancho y ALTO en reposo,
  cada uno con deslizador y botones de ±1 px; lado del micrófono (izquierda
  o derecha; el puntero va del otro). En la misma pantalla, una maqueta de
  la isla, y la isla real se actualiza EN VIVO mientras se ajusta (el host
  manda `CONFIG` en cada cambio). Sirve para cámaras al centro, a un lado,
  más altas o más bajas.
- Protocolo: `CONFIG` (isla), `MIC_TOGGLE` (isla → host), `MIC_STATE`
  (host → isla, con nivel de voz a ≤ 15 Hz).
- Sin el complemento activo, «Isla» no se puede elegir (Ajustes lo explica).
- Diseño aprobado en artifact antes de implementar.

### Fase 3 — Complemento independiente
- Pestaña propia en el borde para abrir el trackpad sin VoiceBubble.
- Mover y achicar el trackpad a la zona sana; recuerda su lugar.
- Ajustes propios mínimos (sensibilidad, estilo, lado) cuando VoiceBubble no
  está instalado.

### Fase 4 — Unificar y cerrar
- El trackpad del teclado usa el puntero del complemento (un solo puntero).
- Limpieza de código muerto, `design.md`, `docs/contrato-trackpad.md`, suites.

## Reglas para cada fase
- Privacidad: `canRetrieveWindowContent=false`, cero logs de coordenadas o
  contenido, contadores solo en memoria.
- Kotlin compila en el servidor en una copia (ver `docs/plan-build-local.md`);
  nunca en paralelo con `flutter test`.
- Suites: se actualizan para describir el diseño nuevo, no se debilitan.
- Sin push: el dueño autoriza cada push. Un commit por fase, auditado.
