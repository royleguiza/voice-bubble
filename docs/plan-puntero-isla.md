# Plan: puntero por encima de todo + isla flotante

> Estado: en curso (2026-11-15). Coordina y audita la sesión principal; cada
> fase la implementa UN subagente por vez. Fuente de diseño: `design.md`
> (Horizonte) y el artifact de la isla (enlace en la fase 2).

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

### Fase 2 — Isla flotante
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
