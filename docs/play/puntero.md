# Play Console · Orison Puntero (T19)

Se publica **después** del lanzamiento de Orison (decisión del dueño, enero).
Todo lo de esta página queda listo para cargar ese día.

## La app

- Identificador: `com.royleguiza.orison.puntero` (Orison Dev usa
  `com.royleguiza.orison.dev.puntero`, ver T20).
- Firma: **la misma clave que Orison**. Al crear la app en Play Console,
  elegir «Usar la misma clave de firma de apps que otra app de esta cuenta»
  (el permiso de firma `…puntero.permission.POINTER` lo exige: si las firmas
  difieren, Orison y el Puntero no se hablan).
- AAB: lo arma el workflow «Release AAB (Play)» junto con el de Orison
  (`orison-puntero-release-aab-rN`).
- Precio: gratis. Sin compras.

## Ficha

**Título (30):** Orison Puntero: toca sin llegar · **EN:** Orison Pointer: reach & tap

**Descripción breve (80):**
- ES: Un puntero para tocar toda la pantalla, también donde el dedo no llega.
- EN: A pointer to tap anywhere on screen, even where your finger can't reach.

**Descripción completa (ES):**

Orison Puntero agrega un puntero que se mueve con un trackpad, como en una computadora, para tocar cualquier parte de la pantalla.

Pensado para personas con dificultades motrices, para usar el teléfono con una sola mano, o cuando una parte de la pantalla dejó de responder: el puntero llega adonde el dedo no.

• Trackpad flotante que se mueve, se achica y recuerda su lugar.
• Tocar es clic; mantener es clic largo; arrastrar en dos pasos.
• Botones de Atrás, Inicio, Recientes y Notificaciones.
• Funciona solo o junto con el teclado Orison, que agrega dictado por voz y una barra flotante.

Privacidad: Orison Puntero no lee el contenido de la pantalla ni guarda lo que tocás. Solo recuerda dónde dejaste la barra. No tiene publicidad, cuenta ni rastreo.

**Full description (EN):**

Orison Pointer adds a pointer you move with a trackpad, like on a computer, to tap anywhere on the screen.

Made for people with motor difficulties, for one-handed use, or when part of the screen stopped responding: the pointer reaches where your finger can't.

• A floating trackpad you can move, shrink and that remembers its place.
• Tap to click; hold for a long click; drag in two steps.
• Back, Home, Recents and Notifications buttons.
• Works on its own or with the Orison keyboard, which adds voice dictation and a floating bar.

Privacy: Orison Pointer does not read screen content or store what you tap. It only remembers where you left the bar. No ads, no account, no tracking.

## Declaración de la API de Accesibilidad

En **Contenido de la app › Accesibilidad**:

- **¿Es una herramienta de accesibilidad?** Sí: `isAccessibilityTool="true"`
  ya está en `res/xml/puntero_service.xml` del Puntero.
- **Función principal que usa la API:** mover un puntero en pantalla y
  realizar toques y gestos (`dispatchGesture`) donde la persona no puede
  tocar con el dedo, por una discapacidad motora, uso con una mano o una zona
  de la pantalla dañada. También dibuja la barra flotante como overlay de
  accesibilidad para que no desaparezca.
- **Datos:** no lee el contenido de las ventanas
  (`canRetrieveWindowContent="false"`), no recolecta ni comparte datos
  personales ni sensibles. No envía nada por internet (no tiene permiso de
  internet).
- **Texto para el aviso destacado** (ya está en la pantalla del Puntero antes
  de activarlo): «Orison Puntero usa el servicio de Accesibilidad solo para
  hacer los toques del puntero y dibujar la barra flotante. No lee lo que hay
  en la pantalla ni guarda nada, salvo dónde dejaste la barra».
- **Video** (lo graba el dueño, 30–60 s): activar el Puntero en Accesibilidad,
  abrir el trackpad, mover el puntero hasta la parte superior de la pantalla y
  tocar un botón; mostrar el clic largo y los botones Atrás/Inicio.

## Seguridad de los datos (Puntero)

- ¿Recolecta o comparte datos? **No**.
- Encriptación en tránsito: no aplica (no usa la red).
- Público: 18+; no dirigido a niños.

## En Orison

Cuando el Puntero esté publicado, el botón «Instalar el Puntero» de Ajustes ›
Trackpad debe abrir su ficha en Play
(`market://details?id=com.royleguiza.orison.puntero`) en vez del APK de
GitHub. Es un cambio chico que se hace ese día (texto `pad_pointer_missing`
y el destino del botón).
