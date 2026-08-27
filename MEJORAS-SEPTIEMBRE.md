# Plan y Registro de Mejoras — Septiembre 2026

> 📅 **Periodo de Recopilación y Diseño**: 26 de agosto – 1 de septiembre de 2026
> 📌 **Regla Operativa**: CERO cambios de código en `app_source/` o `voice_bubble_stt/`. Solo documentación, diseño de arquitectura y especificación de features.
> 🚀 **Gestión de Git**: Los commits y pushes a este archivo y documentación `.md` están permitidos (los cambios en archivos `.md` están excluidos del CI por `paths-ignore: '*.md'`, y además se usará `[skip ci]` en los mensajes de commit para total seguridad).

---

## 1. Planes Listos para Ejecución (Septiembre 2026)

Estos planes ya fueron analizados y aprobados previamente por el dueño:

1. **Bandeja de Portapapeles (Clipboard Tray)**: [`plan-clipboard.md`](file:///root/projects/activos/voice-bubble/plan-clipboard.md)
   * Captura de clips copiados fuera de la app (opt-in).
   * Tecla `📋` en barra inferior o superior para insertar clips en cursor.
2. **Ciclar Mayúsculas/Minúsculas con ⇧**: [`plan-ciclar-mayusculas.md`](file:///root/projects/activos/voice-bubble/plan-ciclar-mayusculas.md)
   * Ciclo `minúsculas` → `Mayúscula Inicial` → `MAYÚSCULAS` en texto seleccionado.

---

## 2. Registro de Nuevas Ideas y Propuestas

### 2.1 [MEJ-03] Barra Superior de Acciones (Top Action Bar) para Micrófono y Portapapeles
* **Origen / Necesidad**: La barra inferior del teclado acumula actualmente muchas teclas (`?123`, `</>`, `ES/EN`, `🎤`, `,`, `espacio`, `.`, `☰`, `↵`), lo que reduce el ancho de la barra espaciadora. Mover herramientas clave a una barra superior (toolbar/strip) mejora la ergonomía y amplía la superficie de tipeo.
* **Comportamiento Esperado**:
  - **Ajustes**: Switch/selector en Ajustes de Teclado: *"Ubicación de Herramientas"* (`Barra Inferior` vs `Barra Superior / Toolbar`).
  - **En Barra Superior**:
    - Se renderiza una franja superior estilizada con estética Glass por encima de la primera fila de letras.
    - Aloja:
      - 🎤 **Micrófono** (con su animación de pastilla roja, cronómetro y cancelación de K3/v1.2).
      - 📋 **Portapapeles** (acceso a bandeja de clips de MEJ-01).
      - ☰ **Snippets** (acceso a fragmentos de K4).
      - Accesos rápidos adicionales (ej. flechas de cursor o selector de idioma).
    - **Impacto en Barra Inferior**: Al liberar el mic y snippets de abajo, la barra espaciadora crece un 40-50% en ancho, evitando toques accidentales de puntuación o comandos.
* **Impacto Técnico**:
  - *Flutter (Dart)*: Clave SharedPreferences `flutter.kb_top_bar_enabled` y selector visual en `SettingsScreen` (Tab Teclado).
  - *Kotlin nativo*: En `VoiceKeyboardService.kt`, función `buildTopBar()` que se inserta antes de las filas de letras y reubica condicionalmente `makeMicKey()` y el botón de clipboard.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.2 [MEJ-04] Layouts y Presets Configurables de Barras de Código y Termux
* **Origen / Necesidad**: El uso del teclado en programación y terminal móvil (Termux / Acode / Neovim / SSH) requiere acceso rápido a distintos conjuntos de símbolos y teclas de control sin tener que cambiar de pantalla constantemente.
* **Comportamiento Esperado**:
  - **Selector de Presets en Ajustes**:
    - **Preset Código Estándar**: `{ } [ ] ( ) < > ; : ' " \ | / ! = +` (actual de K2).
    - **Preset Termux / CLI**: Teclas de control dedicadas (`Ctrl`, `Alt`, `Tab`, `Esc`, `~`, `|`, `-`, flechas direccionales `← ↑ ↓ →`).
    - **Preset Web / JavaScript / Dart**: Optimizado para sintaxis web (`=>`, `===`, `&&`, `||`, `{}`, `$`, `?`).
  - **Activación Dinámica**: Posibilidad de fijar el preset preferido desde Ajustes o conmutar entre ellos desde la tecla `</>`.
* **Impacto Técnico**:
  - *Flutter (Dart)*: Selector de preset en Ajustes (`flutter.kb_code_layout_preset`).
  - *Kotlin nativo*: `VoiceKeyboardService.kt` interpreta el preset configurado para generar las filas de `buildCodeRows()` o la fila superior de terminal correspondiente.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.3 [MEJ-05] Presión Larga para Símbolos y Menú Emergente de Puntuación
* **Origen / Necesidad**: Cambiar a la capa de símbolos (`?123`) solo para escribir `;`, `:`, `!`, `?` o vocales con acento ralentiza el flujo continuo de tipeo y programación. La pulsación larga resuelve esto sin fricción.
* **Comportamiento Esperado**:
  - **Pulsación Larga en Punto (`.`)**:
    - Al mantener presionado `.` (ej. ~300ms), aparece una micro-ventana emergente (popup glass) por encima de la tecla con opciones: `;`, `:`, `...`, `!`, `?`, `/`.
    - **Comportamiento por Deslizamiento**: Al deslizar el dedo hacia el símbolo y soltar, se comita dicho carácter. Si se suelta de inmediato sin mover, se comita el carácter secundario predeterminado (`;`).
  - **Pulsación Larga en Coma (`,`)**:
    - Opciones emergentes: `:`, `;`, `_`, `-`, `\`.
  - **Pulsación Larga en Letras (Tildes y Caracteres Especiales)**:
    - `a` → `á, à, â, ä`
    - `e` → `é, è, ê, ë`
    - `i` → `í, ì, î, ï`
    - `o` → `ó, ò, ô, ö`
    - `u` → `ú, ù, û, ü`
    - `n` → `ñ`
  - **Ajustes y Personalización**:
    - Switch para activar/desactivar menús de pulsación larga (`flutter.kb_long_press_symbols`).
    - Selector de tiempo de retardo: Rápido (250ms), Normal (350ms, default), Relajado (450ms).
* **Impacto Técnico**:
  - *Kotlin nativo*: Extensión de `attachLongPress` en `VoiceKeyboardService.kt` con un `PopupWindow` / vista superpuesta ligera (`showKeyPopup()`) que trackea el `ACTION_MOVE` y `ACTION_UP` para seleccionar el glifo.
  - *Flutter (Dart)*: Controles en Ajustes > Teclado.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.4 [MEJ-06] Gesto en Barra Espaciadora con Menú Rápido de 3 Opciones Superpuesto
* **Origen / Necesidad**: Alternar rápidamente entre modos (Código, Termux, Snippets, Portapapeles o Idioma) sin tener que buscar botones pequeños o realizar múltiples pulsaciones.
* **Comportamiento Esperado**:
  - **Gesto de Activación**: Al realizar una pulsación larga (~300ms) o deslizar hacia arriba desde la barra espaciadora (`Spacebar`), se despliega un **menú rápido flotante superpuesto** (Overlay Glass) sobre el teclado con 3 opciones/ranuras principales.
  - **Interacción Fluida**:
    - El usuario puede deslizar el dedo hacia cualquiera de las 3 opciones y soltar para activar el modo de inmediato.
    - O tocar directamente una de las 3 ranuras si el menú permanece abierto.
  - **Personalización Completa desde Ajustes (Tab Teclado)**:
    - El usuario puede asignar qué acción ejecuta cada una de las 3 ranuras desde un selector:
      - Slot 1 (Izquierda): ej. `Capa Código (</>)` o `Modo Terminal Termux`.
      - Slot 2 (Centro): ej. `Bandeja de Portapapeles (📋)` o `Selector de Teclado del Sistema (IME Picker)`.
      - Slot 3 (Derecha): ej. `Fragmentos (☰)` o `Cambiar Idioma (ES/EN)`.
    - Opciones adicionales disponibles para asignar a las ranuras:
      - `Abrir Ajustes VoiceBubble`
      - `Capa Símbolos (?123)`
      - `Modo Cursor / Trackpad` (deslizar espacio para mover cursor).
* **Impacto Técnico**:
  - *Kotlin nativo*: En `VoiceKeyboardService.kt`, captura de `ACTION_DOWN` + `ACTION_MOVE` ascendente en `spaceKeyView`. Creación de `showSpaceQuickMenu()` superpuesto con 3 píldoras Glass y ejecución de callback de cambio de capa o servicio.
  - *Flutter (Dart)*: 3 preferencias configurables en `StorageService` (`flutter.kb_space_slot_left`, `flutter.kb_space_slot_center`, `flutter.kb_space_slot_right`) con dropdowns intuitivos en `SettingsScreen`.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.5 [MEJ-07] Control Avanzado de Altura de Teclas y Posición / Elevación del Teclado
* **Origen / Necesidad**: La ergonomía varía según el tamaño de la mano y de la pantalla del dispositivo. Poder calibrar por separado el **tamaño/altura de las teclas** (para precisión táctil) y la **posición/elevación del teclado** (para evitar doblar los pulgares hacia la base de la pantalla) previene la fatiga en sesiones largas de desarrollo y escritura.
* **Comportamiento Esperado**:
  - **Ajustes > Tab Teclado > Sección Dimensiones y Ergonomía**:
    1. **Menú de Altura de Teclas (Key Height)**:
       - Escala el tamaño vertical de las teclas y fuentes proporcionalmente.
       - 5 opciones claras:
         - `Muy Compacto (85%)`
         - `Compacto / Bajo (92%)`
         - `Estándar / Medio (100%)` [Default]
         - `Alto (108%)`
         - `Extra Alto (120%)`
    2. **Menú de Posición / Elevación Inferior (Bottom Offset / Lift)**:
       - Sube todo el cuerpo del teclado hacia arriba, despegándolo del borde inferior del teléfono.
       - Ideal para teléfonos con bordes delgados o pantallas alargadas (>6.5"), alejando la fila inferior de la barra de gestos de Android.
       - Opciones:
         - `Pegado al borde (0 dp)`
         - `Elevación Baja (12 dp)`
         - `Elevación Media (24 dp)` [Recomendada]
         - `Elevación Alta (36 dp)`
         - `Ajuste Personalizado (Slider 0 – 48 dp)`
* **Impacto Técnico**:
  - *Flutter (Dart)*: Claves `flutter.kb_height_profile` (con 5 perfiles) y `flutter.kb_bottom_elevation_dp` en `StorageService` y selectores ergonómicos en `SettingsScreen`.
  - *Kotlin nativo*: En `VoiceKeyboardService.kt`, actualización del factor de escala `scaleV()` y aplicación de `bottomElevationPx` en el contenedor `inputView` respetando los insets del sistema.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.6 [MEJ-08] Flujo de Pegado Secuencial Multi-Clip (Portapapeles Global Persistente)
* **Origen / Necesidad**: Llenar formularios, configurar variables en un `.env` o autenticar accesos suele requerir copiar múltiples datos en apps distintas (ej. una URL en Chrome, un ID en un correo y un PIN en el autenticador). Tener que alternar entre 3 apps de ida y vuelta para copiar y pegar de a uno por vez genera fricción extrema.
* **Comportamiento Esperado**:
  1. **Fase de Copia Acumulativa**:
     - El usuario copia el dato 1 en la app A (`https://api.ejemplo.com`).
     - Copia el dato 2 en la app B (`USER_ID=49281`).
     - Copia el dato 3 en la app C (`PIN=839201`).
     - La bandeja de portapapeles de VoiceBubble acumula los clips en su cola FIFO (20 elementos).
  2. **Fase de Pegado Secuencial Multi-Campo**:
     - El usuario abre el destino (ej. formulario web o editor Acode/Termux).
     - Abre la **Bandeja de Portapapeles** (vía botón `📋` en barra superior/inferior o menú rápido de espacio `MEJ-06`).
     - **Modo Pegado Secuencial / Sticky Tray (Opcional o conmutador de chincheta 📌)**:
       - Toca el primer clip (URL) → se inserta en el campo activo.
       - Toca el siguiente campo de texto → la bandeja permanece abierta o con acceso a 1 toque.
       - Toca el segundo clip (USER_ID) → se inserta.
       - Toca el tercer campo y toca el PIN → se inserta.
     - Permite completar formularios de múltiples campos en un solo paso sin salir del teclado.
  3. **Gestión de Clips**:
     - Vista previa clara de cada clip.
     - Botón para fijar clips favoritos/frecuentes (📌) para que no se borren por rotación FIFO.
     - Botón de vaciar papelera/portapapeles con 1 toque.
* **Impacto Técnico**:
  - *Kotlin nativo*: Ampliación del motor de [`plan-clipboard.md`](file:///root/projects/activos/voice-bubble/plan-clipboard.md) en `VoiceKeyboardService.kt`: soporte para modo "Keep Open / Sticky" en `showClipboardPopup()`, inserción sucesiva mediante `currentInputConnection?.commitText()`, y flags de retención de clips fijados.
  - *Flutter (Dart)*: Switch en Ajustes > Portapapeles: *"Mantener bandeja abierta tras pegar (Pegado secuencial)"*.
* **Estado**: **En Diseño (Aprobada como extensión clave de MEJ-01 para Septiembre)**.

---

### 2.7 [MEJ-09] Modo Trackpad y Puntero de Mouse Virtual Flotante
* **Origen / Necesidad**: En interfaces densas (páginas web completas, Termux con interfaces CLI/TUI, editores como Acode o paneles de servidores), seleccionar texto pequeño o acertar a botones diminutos con los dedos resulta impreciso. Un modo Trackpad que transforme el teclado en una superficie de control con puntero de mouse en pantalla brinda precisión milimétrica.
* **Comportamiento Esperado**:
  - **Activación Rápida**: Desde el menú rápido de espacio (`MEJ-06`), acceso en barra superior (`MEJ-03`) o botón de capa.
  - **Superficie Táctil del Teclado (Trackpad View)**:
    - La vista del teclado se convierte en un panel táctil suave Glass con un cuadrado/área central de navegación.
    - Fila inferior con botones táctiles dedicados:
      - `[ Clic Izquierdo (L) ]` (Área amplia a la izquierda)
      - `[ Rueda Scroll / Desplazamiento ]`
      - `[ Clic Derecho / Menú Contextual (R) ]`
      - `[ ✕ Salir a Teclado ]`
  - **Puntero de Mouse Flotante en Pantalla**:
    - Al activar el modo, se dibuja un puntero de mouse estilizado en pantalla (Overlay `SYSTEM_ALERT_WINDOW`).
    - Al mover el dedo en el trackpad, el puntero se desplaza con aceleración fluida e inercia natural.
    - **Acciones**:
      - **Clic Izquierdo / Tap**: Tocar la superficie del trackpad o pulsar el botón `L` dispara un clic en las coordenadas exactas del puntero en pantalla (`AccessibilityService.dispatchGesture`).
      - **Clic Derecho / Pulsación Larga**: Tocar el botón `R` o doble toque sostenido ejecuta un toque prolongado / menú contextual.
      - **Desplazamiento / Scroll**: Deslizar con dos dedos en el trackpad emula scroll arriba/abajo.
  - **Ajustes y Sensibilidad**:
    - Ajuste de sensibilidad del puntero (Lento, Normal, Rápido) y velocidad de aceleración.
* **Impacto Técnico**:
  - *Kotlin nativo*: En `VoiceKeyboardService.kt` se implementa `buildTrackpadLayer()`. Vinculación con el servicio de accesibilidad (`VoiceBubbleAccessibilityService`) para inyectar gestos de clic (`dispatchGesture`) y con el `WindowManager` para el puntero flotante (`PointerOverlayView`).
  - *Flutter (Dart)*: Configuración de sensibilidad y habilitación en Ajustes > Teclado.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.8 [MEJ-10] Gestos Duales en Burbuja Flotante: Toque vs Mantener + Acceso Rápido al Historial
* **Origen / Necesidad**: La burbuja flotante actualmente solo responde a un toque simple para grabar. Cuando el usuario está usando otra app y necesita consultar, copiar o pegar una transcripción anterior del historial, tiene que salir y abrir la app principal o el teclado. Asignar el gesto complementario al historial unifica la experiencia flotante.
* **Comportamiento Esperado**:
  - **Selector de Modo en Ajustes (Tab Burbuja)**:
    - **Modo 1: Toque Simple (Tap-to-Record) [Default]**:
      - `Toque simple`: Inicia grabación (1er tap) / Detiene y transcribe (2do tap).
      - `Pulsación Larga (~400ms en reposo)`: Abre la **modal flotante con el Historial de Transcripciones** (las últimas 20).
    - **Modo 2: Mantener Presionado (Push-to-Talk / Hold-to-Record)**:
      - `Mantener presionado`: Graba mientras se sostiene el dedo sobre la burbuja; al soltar, finaliza y transcribe inmediatamente.
      - `Toque Simple (Tap rápido en reposo)`: Abre la **modal flotante con el Historial de Transcripciones**.
  - **Modal Flotante de Historial (Liquid Glass)**:
    - Se despliega anclada a la posición de la burbuja en pantalla.
    - Lista las últimas 20 transcripciones con fecha/hora relativa.
    - Tocar una transcripción la copia al portapapeles con confirmación háptica/visual instantánea (y la inserta si hay accesibilidad activa).
    - Tocar fuera o el botón cerrar descarta la modal.
* **Impacto Técnico**:
  - *Kotlin nativo*: En `FloatingBubbleService.kt`, actualización del listener táctil `onTouch` para discriminar entre `ACTION_DOWN` sostenido (Long Press / Hold) y `ACTION_UP` rápido (Tap), y despliegue del popup `FloatingHistoryOverlayView` vía `WindowManager`.
  - *Flutter (Dart)*: Switch en `SettingsScreen` (Tab Burbuja) para elegir `flutter.bubble_trigger_mode` (`tap` vs `hold`).
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.9 [MEJ-11] Modelos de Burbuja Dinámica Expandible (Morph-to-Pill, Cronómetro, Botones Rápidos y Auto-Enter)
* **Origen / Necesidad**: La burbuja flotante fija puede resultar demasiado estática. Incorporar una versión dinámica que se expanda visualmente (al estilo de la tecla M4 del teclado y Dynamic Island), muestre el tiempo de grabación en vivo y permita acciones inmediatas como cancelar, enviar con `Auto-Enter` o insertar espacios agiliza el flujo en mensajería y terminal.
* **Comportamiento Esperado**:
  1. **Selector de Modelos de Burbuja en Ajustes (Tab Burbuja)**:
     - **Modelo A: Clásica Mínima**: Círculo Liquid Glass discreto (56x56dp), animación pulsante sutil.
     - **Modelo B: Dinámica Expandible (Pill Island)**:
       - **En reposo**: Círculo Glass compacto en el borde de pantalla.
       - **Al iniciar grabación**: La burbuja se expande horizontalmente a una **pastilla roja flotante (Floating Pill)** con:
         - Punto pulsante indicador de grabación.
         - Cronómetro `M:SS` en vivo.
         - Botón táctil `[ ✕ Cancelar ]` para descartar el audio sin consumir tokens/API.
       - **Al procesar**: Animación de 3 puntos en ola Liquid Glass.
       - **Combo de Botones Auxiliares Rápidos (Opcional / Mini-Barra Adyacente)**:
         - Mini píldoras adyacentes de 1 toque: `[ ↵ Enter ]`, `[ ␣ Espacio ]`, `[ ⌫ Borrar ]`.
  2. **Opción Auto-Enter / Auto-Envío**:
     - Switch en Ajustes: *"Auto-Enter al finalizar dictado en burbuja"*.
     - Al concluir la transcripción, la burbuja pega el texto e inmediatamente inyecta un `ENTER / ACTION_SEND`, enviando el mensaje o ejecutando el comando en Termux sin requerir toques extra.
* **Impacto Técnico**:
  - *Kotlin nativo*: En `FloatingBubbleService.kt`, animación interpolada de `LayoutParams.width` en `windowManager` para transicionar de círculo a pastilla durante `recording`. Manejo de botones de acción rápida e inyección de `KEYCODE_ENTER` vía accesibilidad.
  - *Flutter (Dart)*: Controles en `SettingsScreen` (Tab Burbuja): `flutter.bubble_style_model` (`classic` vs `dynamic_pill`) y `flutter.bubble_auto_enter_enabled`.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.10 [MEJ-12] Conmutación Fluida Teclado ↔ Burbuja y Modo Micro-Teclado Flotante (Command Strip)
* **Origen / Necesidad**: En sesiones de terminal (Termux / SSH / Neovim) o lectura de chats, tener el teclado completo abierto tapa el 45% de la pantalla y oculta logs o respuestas. Un modo "Micro-Teclado Flotante" (una tira delgada de una sola fila) permite mantener acceso permanente a dictado, comandos y edición viendo el 95% de la pantalla.
* **Comportamiento Esperado**:
  1. **Conmutación Instantánea Teclado ↔ Burbuja**:
     - **Desde el Teclado**: Botón en barra superior (`MEJ-03`) o menú de espacio (`MEJ-06`): *"Minimizar a Burbuja Flotante"*.
     - **Desde la Burbuja**: Toque de acción en menú: *"Desplegar Teclado Completo"*.
  2. **Modo Micro-Teclado Flotante / Command Strip**:
     - Tira horizontal compacta Glass (altura ~44dp) que se puede mover o anclar en la parte inferior o flotante.
     - Contiene únicamente los controles esenciales de alta frecuencia:
       - `[ 🎤 Dictado por Voz ]` (con estado en vivo)
       - `[ ⌫ Backspace / Borrar ]` (soporta borrado rápido y swipe-to-delete)
       - `[ ␣ Espacio ]`
       - `[ ↵ Enter / Ejecutar ]`
       - `[ ⇥ Tab ]` (o flechas si está en modo terminal)
       - `[ ⌨️ Expandir a Teclado Completo ]`
     - **Utilidad Extrema**: Permite dictar comandos por voz en Termux o enviar mensajes en chats sin que el teclado tradicional tape la pantalla.
* **Impacto Técnico**:
  - *Kotlin nativo*: Comunicación bidireccional entre `VoiceKeyboardService.kt` y `FloatingBubbleService.kt` para orquestar la transición entre vista completa de IME, barra horizontal `CommandStripView` y burbuja circular `BubbleView`.
  - *Flutter (Dart)*: Configuración de la barra mínima en Ajustes > Teclado / Burbuja.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.11 [MEJ-13] Capa de Emojis, Emoticones ASCII/Kaomoji y Soporte de Stickers (Rich Content)
* **Origen / Necesidad**: Enviar reacciones rápidas, emojis y stickers en apps de mensajería sin tener que alternar a otro teclado del sistema exclusivamente para buscar un emoticon o sticker.
* **Comportamiento Esperado**:
  - **Acceso a la Capa**: Tecla `😀` (ubicable en la barra superior `MEJ-03`, menú rápido de espacio `MEJ-06` o capa de símbolos). Ocultable desde Ajustes si se prefiere un teclado estrictamente de código.
  - **Pestañas de la Capa**:
    1. **Recientes / Favoritos**: Últimos 30 emojis usados para inserción a 1 toque.
    2. **Emojis Unicode Nativos**: Cuadrícula por categorías (Caritas, Gestos, Objetos, Símbolos) renderizada con la fuente del sistema (cero consumo extra de APK o memoria).
    3. **Emoticones ASCII / Kaomojis**: Pestaña dedicada con kaomojis listos para programadores y usuarios de chat (`¯\_(ツ)_/¯`, `(╯°□°)╯︵ ┻━┻`, `(•_•)`, `(◕‿◕)`).
    4. **Bandeja de Stickers / GIFs (Opt-in)**: Soporte de inserción de imágenes/stickers mediante la API estándar de Android `InputConnection.commitContent()` (compatible con WhatsApp, Telegram, Discord).
  - **Rendimiento y Privacidad**: Cero telemetría, carga bajo demanda y switch para activar/desactivar en Ajustes.
* **Impacto Técnico**:
  - *Kotlin nativo*: Implementación de `buildEmojiLayer()` en `VoiceKeyboardService.kt` con `commitText()` para Unicode/Kaomoji y `commitContent()` para Rich Content/Stickers.
  - *Flutter (Dart)*: Switch `flutter.kb_emoji_key_visible` en Ajustes > Teclado.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.12 [MEJ-14] Modo Gaming y Gamepad Virtual (Joystick / D-Pad y Botones para Juegos Web y PWAs)
* **Origen / Necesidad**: Jugar videojuegos web (HTML5, Phaser, emuladores web en navegador, Progressive Web Apps o juegos en terminal) desde el teléfono suele ser problemático por la falta de controles táctiles o la necesidad de teclas de dirección y botones de acción simultáneos. Un modo Gaming transforma el teclado en un mando virtual táctil de respuesta instantánea.
* **Comportamiento Esperado**:
  1. **Activación Rápida**: Desde el menú rápido de la barra espaciadora (`MEJ-06`), barra superior (`MEJ-03`) o botón de capa.
  2. **Controles Táctiles (Estilo Xbox / PlayStation Liquid Glass)**:
     - **Cruceta Direccional / D-Pad**: Arriba, Abajo, Izquierda, Derecha (`▲`, `▼`, `◄`, `►`).
     - **Botones de Acción Principales**: 4 botones ergonómicos `[ A ]`, `[ B ]`, `[ X ]`, `[ Y ]` (o `✕`, `○`, `□`, `△`).
     - **Gatillos y Control**: `[ L1 / LB ]`, `[ R1 / RB ]`, `[ SELECT / ESC ]`, `[ START / PAUSE ]` y `[ ✕ Salir ]`.
  3. **Multi-Touch Real y Orientación Dual**:
     - **Multi-Touch Simultáneo**: Permite mantener presionada una dirección para moverse mientras se pulsa `A` (saltar) o `B` (disparar) sin conflicto.
     - **Modo Vertical (Portrait)**: Disposición compacta en la mitad inferior de la pantalla.
     - **Modo Horizontal (Landscape)**: Controles divididos en las esquinas izquierda/derecha para sujetar el dispositivo con ambas manos.
  4. **Modos de Mapeo de Teclas (Configurable en Ajustes)**:
     - **Preset Teclado Gamer**: Mapeo directo a `WASD` / `Flechas` + `Espacio` (Salto) + `Enter` + `Shift` (compatibilidad inmediata con el 100% de páginas web y juegos HTML5).
     - **Preset Gamepad Android**: Inyección de `KEYCODE_BUTTON_A/B/X/Y/START` para emuladores y apps compatibles con mando.
* **Impacto Técnico**:
  - *Kotlin nativo*: En `VoiceKeyboardService.kt`, implementación de `buildGamepadLayer()` con una vista multi-touch dedicada (`GamepadTouchView`) que procesa múltiples punteros `MotionEvent.getPointerId()` e inyecta `sendDownUpKeyEvents()`.
  - *Flutter (Dart)*: Selector de mapeo y switch en Ajustes > Teclado > Modo Gaming.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.13 [MEJ-15] Motor de Temas Visuales y Personalización Tecla por Tecla (Paleta Cromática Arcoíris)
* **Origen / Necesidad**: Ofrecer libertad estética absoluta para que cada usuario cree su identidad visual: desde temas de alto contraste o bajo consumo OLED hasta paletas radiantes Neón, cyberpunk o esquemas funcionales con colores distintos por grupo de teclas (letras, modificadores, código).
* **Comportamiento Esperado**:
  1. **Temas Globales Predeterminados (Ajustes > Tab Temas)**:
     - `Liquid Glass (Oscuro / Claro)` [Estilo por defecto]
     - `OLED Negro Puro` (fondos #000000 para ahorro máximo de batería en pantallas AMOLED).
     - `Neón Cyberpunk` (Bordes brillantes cian/magenta/azul eléctrico sobre fondo oscuro).
     - `Terminal Matrix` (Verde fósforo clásico hacker sobre negro azabache).
     - `Atardecer / Sunset Glow` (Gradientes cálidos naranja/violeta).
     - `Blanco Nieve / Minimal Light` (Estilo limpio blanco puro).
  2. **Personalización Tecla por Tecla (Editor Interactivo & Paleta de Pintor)**:
     - En Ajustes > Tab Temas se muestra una vista previa interactiva del teclado.
     - Al tocar cualquier tecla (o grupo: vocales, números, `Shift`, `Enter`, `Espacio`, `Código`), se abre una **Paleta de Pintor / Selector Arcoíris** con rueda cromática HSV/RGB y paletas de colores prearmadas.
     - Permite personalizar:
       - Color de fondo de la tecla.
       - Color de la letra / glifo.
       - Color y grosor del borde (stroke neón / glass).
  3. **Guardado y Perfiles**:
     - Guardar esquemas personalizados del usuario.
     - Botón de restablecer al tema original Liquid Glass en 1 toque.
* **Impacto Técnico**:
  - *Flutter (Dart)*: Editor interactivo de teclado con selector de color cromático en `SettingsScreen` (Tab Temas), almacenamiento en `StorageService` (`flutter.kb_theme_preset`, `flutter.kb_custom_colors_json`).
  - *Kotlin nativo*: En `VoiceKeyboardService.kt`, renderizado dinámico de fondos con `GradientDrawable` tintados en tiempo real según el mapa de colores configurado.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.14 [MEJ-16] Rediseño y Potenciación de la Modal de Historial de Transcripciones (Dimensiones, Estilo Glass y Funcionalidades)
* **Origen / Necesidad**: La ventana emergente actual del historial es básica (una lista de texto simple sin búsqueda ni gestión). Rediseñarla a nivel de proporciones, diseño Liquid Glass y funcionalidades avanzadas convierte al historial en una herramienta de productividad de primer nivel.
* **Comportamiento Esperado**:
  1. **Mejoras de Tamaño y Proporciones**:
     - **Dimensiones Adaptables**: Ocupa el 55–65% de la pantalla con bordes amplios y scroll suave.
     - **Vista Acordeón / Expandible**: Las transcripciones largas se pueden expandir con un toque para leer el texto completo sin cortes de elipsis.
  2. **Diseño Visual Liquid Glass Pulido**:
     - **Tarjetas Flotantes Individuales**: Cada transcripción reside en una tarjeta con fondo translúcido, borde suave (`kb_key_stroke`) y elevación ligera.
     - **Header con Controles**: Título *"Historial de Dictados"*, contador visible (`N/20`), botón *"Vaciar"* y botón de cierre `✕`.
     - **Metadatos Visuales**: Timestamp relativo amigable (*"Hace 3 min"*, *"Hoy 11:20"*) e icono indicador de procedencia (🎤 Teclado vs 🫧 Burbuja).
  3. **Nuevas Funcionalidades**:
     - **Búsqueda / Filtro en Vivo**: Barra superior para escribir y filtrar al instante entre las 20 transcripciones.
     - **Fijar Transcripciones (Pin 📌)**: Marcar notas de voz importantes para que no se borren por la rotación FIFO.
     - **Acciones Rápidas por Tarjeta**:
       - *Toque simple*: Insertar en cursor (en teclado) o Copiar (en burbuja).
       - *Botón Copiar `📋` directo*: Copia al portapapeles sin cerrar la modal.
       - *Botón Borrar `🗑️` individual*: Eliminar una transcripción puntual.
     - **Copiar Selección Múltiple**: Posibilidad de marcar varias transcripciones y copiarlas o insertarlas concatenadas en bloque.
* **Impacto Técnico**:
  - *Kotlin nativo*: En `VoiceKeyboardService.kt` (y compartido con `FloatingBubbleService.kt`), sustitución del `ScrollView` básico por un `HistoryDialogFragment` / `PopupWindow` estructurado con `RecyclerView`, búsqueda en memoria y botones de acción.
  - *Flutter (Dart)*: Consistencia visual con el historial de `HomeScreen`.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.15 [MEJ-17] Sistema Modular de Micro-Widgets en el Teclado (Notas, Portapapeles, Comandos y Calculadora)
* **Origen / Necesidad**: Durante la jornada móvil, salir del teclado para abrir una app de notas, calcular una operación o buscar un comando común genera interrupciones constantes. Integrar micro-widgets ligeros directamente en la barra del teclado aporta máxima productividad a 1 toque.
* **Comportamiento Esperado**:
  1. **Franja Modular de Widgets (Widget Strip / Toolbar)**:
     - Franja superior o menú lateral con micro-widgets intercambiables Liquid Glass.
  2. **Widgets Disponibles**:
     - 📝 **Widget de Notas Rápidas (Scratchpad)**: Mini bloc de borrador flotante para apuntar ideas temporales, números o textos y copiarlos/insertarlos con 1 toque.
     - 📋 **Widget de Portapapeles en Vivo (Live Clipboard Strip)**: Carrusel horizontal con los últimos clips para pegar sin desplegar la modal completa.
     - ⚡ **Widget de Comandos y Terminal**: Chips de acceso directo a comandos frecuentes (`git status`, `docker`, `npm`, `ssh`, scripts) listos para enviar al cursor.
     - 🔢 **Widget de Calculadora Rápida (Mini Calc)**: Resuelve cálculos matemáticos al vuelo (ej. `150 * 1.21 = 181.5`) y permite comitar el resultado al texto.
  3. **Configuración y Personalización en Ajustes**:
     - Selector para activar/desactivar y reordenar qué widgets aparecen en la barra principal.
* **Impacto Técnico**:
  - *Kotlin nativo*: En `VoiceKeyboardService.kt`, contenedor `WidgetStripLayout` con micro-vistas modulares (`ScratchpadView`, `LiveClipboardView`, `QuickCommandsView`, `MiniCalcView`).
  - *Flutter (Dart)*: Gestión de widgets y orden de visualización en `SettingsScreen` (Tab Teclado).
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

### 2.16 [MEJ-18] Modo Isla Dinámica / Notch Interactivo Superior (Apple-style Dynamic Island & Camera Notch Docking)
* **Origen / Necesidad**: Ofrecer una alternativa a la burbuja flotante tradicional integrando la interfaz de voz en la parte superior de la pantalla / orificio de la cámara frontal (Dynamic Island / Notch), de modo que nunca tape botones laterales ni el contenido central y se expanda suavemente solo cuando se interactúa con ella.
* **Comportamiento Esperado**:
  1. **Selector de Posicionamiento en Ajustes (Tab Burbuja)**:
     - *Modo 1: Burbuja Flotante Libre*: Flota en los bordes laterales (actual).
     - *Modo 2: Isla Dinámica / Notch Superior*: Anclada en el centro superior / cutout de cámara frontal.
  2. **Estados y Animaciones Fluidas (Liquid Glass Island)**:
     - **Reposo Compacto (Compact Pill)**: Píldora delgada discreta alrededor de la cámara frontal con micro-icono `🎤`.
     - **Expansión al Grabar (Recording Island)**:
       - Se expande hacia los laterales y hacia abajo de forma elástica.
       - Muestra: Onda de audio / punto pulsante rojo + Cronómetro en vivo `M:SS` + Botón `[ ✕ Cancelar ]`.
     - **Procesando / Transcribiendo**: Indicador de 3 puntos en ola Liquid Glass.
     - **Resultado / Mini-Vista Previa**: Muestra brevemente las primeras palabras dictadas con animación de éxito y botón de auto-pegado o copia.
  3. **Gestos en la Isla**:
     - *Toque simple*: Iniciar / Detener grabación.
     - *Deslizar hacia abajo (Swipe Down)*: Despliega la tarjeta expandida con el historial reciente o controles completos (`Enter`, `Espacio`, `Portapapeles`).
     - *Deslizar hacia arriba (Swipe Up)*: Colapsa de inmediato a reposo.
  4. **Compatibilidad con Display Cutout de Android**:
     - Detección automática de la posición de la cámara (API 28+ `DisplayCutout`) para centrar la píldora perfectamente según el modelo de teléfono.
* **Impacto Técnico**:
  - *Kotlin nativo*: En `FloatingBubbleService.kt`, nuevo controlador `DynamicIslandController` con anclaje `Gravity.TOP | Gravity.CENTER_HORIZONTAL`, lectura de `DisplayCutout` y animaciones elásticas de interpolación de tamaño.
  - *Flutter (Dart)*: Selector `flutter.bubble_docking_mode` (`free_floating` vs `dynamic_island`) en Ajustes > Tab Burbuja.
* **Estado**: **En Diseño (Aprobada como idea para Septiembre)**.

---

## 3. Registro de Decisiones y Descartes

| Fecha | ID / Idea | Decisión | Motivo |
|---|---|---|---|
| 2026-08-26 | MEJ-03 (Barra Superior Mic/Clipboard) | Aprobada | Descongestiona la barra inferior y agranda la barra espaciadora |
| 2026-08-26 | MEJ-04 (Presets Código / Termux) | Aprobada | Maximiza la productividad en Termux y desarrollo de software móvil |
| 2026-08-26 | MEJ-05 (Pulsación Larga Símbolos/Acentos) | Aprobada | Permite escribir `;`, `:`, `ñ` y acentos sin conmutar a la capa `?123` |
| 2026-08-26 | MEJ-06 (Menú Rápido de 3 Opciones en Espacio) | Aprobada | Conmutación ultra veloz de modos y personalización total de accesos |
| 2026-08-26 | MEJ-07 (Altura de Teclas y Elevación Inferior) | Aprobada | Ergonomía desacoplada: teclas más grandes y elevación para descanso del pulgar |
| 2026-08-26 | MEJ-08 (Pegado Secuencial Multi-Clip) | Aprobada | Permite copiar 3+ datos en distintas apps y pegarlos sucesivamente sin alternar |
| 2026-08-26 | MEJ-09 (Modo Trackpad y Puntero Virtual) | Aprobada | Control milimétrico de precisión con puntero de mouse, clic izq/der y scroll |
| 2026-08-26 | MEJ-10 (Gestos Duales en Burbuja + Historial) | Aprobada | Simetría de gestos (Tap vs Hold) y acceso al historial flotante sin abrir la app |
| 2026-08-26 | MEJ-11 (Burbuja Dinámica Pill + Auto-Enter) | Aprobada | Expansión a pastilla con cronómetro, cancelación rápida y auto-envío/enter |
| 2026-08-26 | MEJ-12 (Conmutación Teclado↔Burbuja y Micro-Barra) | Aprobada | Barra mínima de 1 sola fila para terminal/chats que deja ver el 95% de pantalla |
| 2026-08-27 | MEJ-13 (Capa de Emojis, Kaomojis y Stickers) | Aprobada | Expresividad completa y soporte de stickers sin cambiar a otro teclado |
| 2026-08-27 | MEJ-14 (Modo Gaming y Gamepad Virtual) | Aprobada | Mando táctil multi-touch (D-Pad + ABXY) para juegos web, PWAs y emuladores |
| 2026-08-27 | MEJ-15 (Motor de Temas y Color Tecla por Tecla) | Aprobada | Paleta arcoíris interactiva, temas Neón/OLED/Matrix y colores por tecla |
| 2026-08-27 | MEJ-16 (Rediseño Integral de Modal de Historial) | Aprobada | Tarjetas Glass, buscador, Pin 📌, borrado individual y dimensiones ampliadas |
| 2026-08-27 | MEJ-17 (Sistema Modular de Micro-Widgets) | Aprobada | Widgets de notas rápidas, live clipboard, comandos y calculadora en teclado |
| 2026-08-27 | MEJ-18 (Isla Dinámica / Notch Superior Apple-style) | Aprobada | Anclaje elástico en cámara/notch superior con animaciones elásticas Glass |
| 2026-08-26 | Congelamiento CI | Aprobado | Cuota de GitHub Actions pausada hasta el 01-Sep-2026; solo docs y diseño |

