# Modo Trackpad y Puntero de Mouse Virtual Flotante (MEJ-09) — Plan de Ejecución

> **Estado**: ✅ APROBADO POR EL DUEÑO (2026-09-03, decisiones D-TP0…D-TP7 cerradas — ver §6). NADA implementado aún en código productivo.
> **Fecha**: 3 de septiembre de 2026
> **Origen**: Pedido explícito del dueño tras evaluar las 6 alternativas de diseño en `laboratorio_ui/trackpad_lab.html`. Decisión final: **Opción 2: Split Wings Trackpad** con adición de control de posición de barra de scroll (`left`, `right`, `disabled`), expansión vertical al 100% de los botones de clic y **estricta prohibición de monitoreo o registro de eventos**.
> **Precedentes internos**: Estructura canónica de `plan-clipboard.md`, `plan-ciclar-mayusculas.md` y `teclado-voice.md`; especificación base `MEJORAS-SEPTIEMBRE.md` §2.7 (MEJ-09); arquitectura de vistas y capas de `VoiceKeyboardService.kt`; tokens de diseño Apple Liquid Glass en `design.md` y `laboratorio_ui/trackpad_lab.html`.

---

## 1. Qué vamos a construir (visión en una página)

Un **Modo Trackpad y Puntero de Mouse Virtual Flotante** integrado en el teclado VoiceBubble STT: al presionar el botón de trackpad en la barra superior interactiva del teclado (o activarlo desde el flujo de entrada), la zona de teclas QWERTY realiza una transición fluida (*morphing*) hacia una **superficie de control táctil de ultra-precisión** basada en la **Opción 2: Split Wings Trackpad (Alas Laterales para Pulgares)**.

Simultáneamente, el sistema proyecta un **puntero de mouse virtual flotante en pantalla** mediante un overlay nativo liviano de Android (`WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY`). Al deslizar los dedos sobre la superficie central del trackpad, el cursor se desplaza con física de aceleración natural; al pulsar los botones de las alas laterales o realizar toques en la superficie, se despachan clics, clics secundarios y desplazamientos (*scroll*) reales sobre cualquier aplicación visible en el sistema operativo mediante un servicio de accesibilidad complementario (`AccessibilityService.dispatchGesture`).

### Elementos aprobados de la arquitectura:
1. **Diseño Seleccionado: Opción 2 Split Wings**:
   - **Ala Izquierda (Flanco Izquierdo)**: Botón ergonómico para el pulgar izquierdo destinado a **Clic Izquierdo (L-Click)**.
   - **Superficie Central de Precisión**: Área táctil amplia y suave con cuadrícula tenue Liquid Glass para el desplazamiento milimétrico del puntero de mouse con soporte para *Tap-to-Click*.
   - **Ala Derecha (Flanco Derecho)**: Área ergonómica para el pulgar derecho con **Barra Táctil de Desplazamiento (Scroll Strip)** vertical y botón de **Clic Derecho (R-Click / Menú Contextual)**.
2. **Nueva Opción de Configuración: Posición de la Barra de Scroll**:
   - Selector en Ajustes y en el teclado con 3 modos: **Izquierda (`left`)**, **Derecha (`right` - default)** y **Desactivada (`disabled`)**.
   - **Comportamiento de auto-expansión al 100%**: Cuando la barra de scroll está en un ala, el botón del ala opuesta se expande verticalmente para ocupar el **100% de la altura de su sección (200dp)**. Cuando el scroll está desactivado, **ambos botones (izquierdo y derecho) se expanden al 100% de la altura**, ofreciendo áreas de toque gigantescas e imposibles de errar con los pulgares.
3. **Regla Sagrada de Privacidad: CERO Telemetría / CERO Monitoreo de Eventos**:
   - **Demanda explícita e intransigente del dueño**: El teclado y la aplicación **JAMÁS** monitorean, almacenan, muestran en un HUD ni envían a logs las interacciones táctiles, coordenadas de pantalla, clics, scrolls ni nombres de ventanas.
   - Se elimina de forma definitiva el "Monitor de Eventos y Gestos" que existía en el laboratorio exploratorio. Cero código espía, cero logs de telemetría.
4. **Cero Regresión en Funcionalidades Existentes**:
   - Las capas de letras (QWERTY), símbolos (`?123`), código (`</>`), snippets (`ic_snippets`), el historial de dictados por voz (micrófono STT Cloud) y la bandeja de portapapeles (`ClipboardStore`) permanecen 100% aislados e intactos.
   - Salir del trackpad restaura exactamente la capa anterior sin alterar el cursor ni el texto del campo de entrada.

---

## 2. Historia de usuario y casos de uso

> **Como** desarrollador y usuario avanzado que utiliza el teléfono para administrar servidores, programar y editar contenido en pantalla pequeña,
> **quiero** alternar el teclado de VoiceBubble a un trackpad con puntero de mouse virtual y botones dedicados para los dos pulgares,
> **y además** poder configurar si la barra de scroll está a la derecha, a la izquierda o apagada para que los botones de clic aprovechen toda la altura disponible,
> **para** seleccionar texto diminuto en Termux/SSH, pulsar enlaces pequeños en Chrome o interactuar con menús contextuales en editores web sin frustrarme por la falta de puntería táctil.

### Flujo feliz:
1. El usuario está editando un archivo en Acode o conectado por SSH en Termux.
2. Toca el botón `[ Trackpad 🖱️ ]` en la barra superior del teclado VoiceBubble.
3. El teclado se transforma inmediatamente en la vista **Split Wings**:
   - Pulgar izquierdo listo sobre el botón Clic Izquierdo (100% alto si scroll está a la derecha).
   - Dedo índice o pulgar derecho mueve el puntero virtual por la pantalla hasta una palabra específica.
   - Pulgar derecho desliza sobre el Scroll Strip para mover el buffer hacia abajo.
   - Pulgar izquierdo presiona Clic Izquierdo para fijar el cursor exactamente entre dos caracteres.
4. Toca nuevamente el botón de retorno `[ Teclado ⌨️ ]` (o expira el temporizador de inactividad si está configurado) y continúa escribiendo normalmente.

---

## 3. Alcance

### SÍ incluye (capacidades verificadas y comprometidas)

| # | Capacidad | Detalle técnico |
|---|---|---|
| 1 | **Capa Nativa Trackpad Split Wings** | Nueva capa nativa en `VoiceKeyboardService.kt` con geometría de alas laterales (`width: 68dp`, `height: 200dp`) y pad central adaptativo. |
| 2 | **Puntero de Mouse Virtual Flotante** | Overlay `TYPE_APPLICATION_OVERLAY` gestionado por `WindowManager`, con 3 estilos visuales: Flecha clásica (`arrow`), Punto óptico (`dot`) y Cruz de precisión (`cross`). |
| 3 | **Física de Aceleración y Sensibilidad** | Algoritmo con 3 curvas (Lineal, Dinámica con inercia, Precisión micrométrica) y slider de sensibilidad de 0.5x a 2.5x. |
| 4 | **Inyección Real de Gestos (OS)** | Inyección de toques (`dispatchGesture`) mediante `AccessibilityService` nativo: Clic primario (tap o botón L), Clic contextual (botón R o doble dedo) y Scroll vertical fluido. |
| 5 | **Configuración de Posición del Scroll Strip** | Ajuste con 3 estados: `right` (default), `left`, `disabled`. |
| 6 | **Expansión Vertical Dinámica al 100%** | Botones de clic en las alas se expanden automáticamente a la altura completa (`flex: 1`, 200dp) cuando no comparten el flanco con el scroll strip. |
| 7 | **Tocar para Clic (Tap-to-Click)** | Toque rápido (<200ms) con desplazamiento menor al umbral de arrastre (`touchSlop`) en el pad central dispara un clic izquierdo. |
| 8 | **Retroalimentación Háptica** | Confirmación física sutil o firme vía el subsistema `haptic()` existente al accionar clics o scroll. |
| 9 | **Auto-retorno por Inactividad (Opcional)** | Retorno automático al teclado tras 5s, 15s o 30s sin toques (apagado por defecto para no interrumpir al usuario). |
| 10 | **Puente de Ajustes Flutter ↔ Kotlin** | Claves en `storage_service.dart`, persistencia en `SharedPreferences` (`flutter.kb_trackpad_*`) y lectura única por ciclo en `loadKeyboardPrefs()`. |

### NO incluye (fuera de alcance explícito y prohibiciones)

- ❌ **CERO Monitoreo de Eventos / CERO Telemetría**: Estrictamente prohibido cualquier HUD, registro en memoria, salida en `Logcat` o envío de eventos táctiles, coordenadas o nombres de ventanas.
- ❌ **Sin Captura de Pantalla ni OCR**: El puntero no lee el contenido gráfico del frame buffer; la inyección de eventos es puramente posicional.
- ❌ **Sin Interferencia en Campos de Contraseña**: Si el campo activo es de contraseña (`isPasswordInput() == true`), el modo trackpad se desactiva o se repliega para garantizar que no haya capas de superposición activas.
- ❌ **Sin Modificación de Rutas de Audio ni STT**: El cliente de dictado Whisper Cloud (`SpeechToTextClient`) y los servicios de audio no se tocan en absoluto.
- ❌ **Sin Modificación de Datos de Snippets o Portapapeles**: La base volátil de `ClipboardStore` y la base persistente de `SnippetStore` se mantienen 100% aisladas.

---

## 4. Viabilidad técnica verificada (Android OS, AOSP, APIs)

### 4.1 Puntero Virtual Flotante vía `WindowManager` (Android API 28+) — VERIFICADO
- **API Oficial**: `android.view.WindowManager` con `WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY`.
- **Permiso Requerido**: `android.permission.SYSTEM_ALERT_WINDOW` (ya declarado en el `AndroidManifest.xml` del proyecto para la burbuja flotante).
- **Flags de ventana requeridos para el cursor**:
  ```kotlin
  flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
          WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
          WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
          WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
  ```
  - `FLAG_NOT_TOUCHABLE` es **crítico**: asegura que el puntero visual sea un "fantasma" que no intercepte los toques de los dedos ni bloquee las apps que están debajo.
  - `FLAG_NOT_FOCUSABLE`: impide que el puntero robe el foco de entrada del teclado o del campo de texto.
  - Al actualizar las coordenadas `(x, y)` mediante `windowManager.updateViewLayout(pointerView, layoutParams)`, el refresco se realiza sincronizado con el ciclo de renderizado (`Choreographer` / VSYNC), garantizando 60–120 FPS sin parpadeos.

### 4.2 Inyección de Clics y Scroll vía `AccessibilityService.dispatchGesture` — VERIFICADO
- **API Oficial**: [`AccessibilityService.dispatchGesture(GestureDescription, GestureResultCallback, Handler)`](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService#dispatchGesture(android.accessibilityservice.GestureDescription,%20android.accessibilityservice.GestureResultCallback,%20android.os.Handler)).
- Disponible desde **Android 7.0 (API 24)**; minSdk del proyecto es **28**, por lo que es soportado en el 100% de los dispositivos objetivo.
- **Construcción de gestos**:
  - **Clic Izquierdo (Tap)**:
    ```kotlin
    val path = Path().apply { moveTo(pointerX, pointerY) }
    val stroke = GestureDescription.StrokeDescription(path, 0L, 40L)
    val gesture = GestureDescription.Builder().addStroke(stroke).build()
    accessibilityService.dispatchGesture(gesture, null, null)
    ```
  - **Clic Derecho / Menú Contextual (Long Press)**:
    ```kotlin
    val path = Path().apply { moveTo(pointerX, pointerY) }
    val longPressMillis = ViewConfiguration.getLongPressTimeout().toLong() // ~400ms
    val stroke = GestureDescription.StrokeDescription(path, 0L, longPressMillis)
    val gesture = GestureDescription.Builder().addStroke(stroke).build()
    accessibilityService.dispatchGesture(gesture, null, null)
    ```
  - **Scroll / Desplazamiento Vertical**:
    ```kotlin
    val path = Path().apply {
        moveTo(pointerX, pointerY)
        lineTo(pointerX, pointerY + scrollDeltaY)
    }
    val stroke = GestureDescription.StrokeDescription(path, 0L, 100L)
    val gesture = GestureDescription.Builder().addStroke(stroke).build()
    accessibilityService.dispatchGesture(gesture, null, null)
    ```
- **Tolerancia y Fallback**: Si el usuario no tiene habilitado el servicio de accesibilidad, el teclado muestra un aviso sutil y directo guiando al usuario para activarlo en Ajustes de Accesibilidad de Android, evitando cualquier crash o bloqueo.

### 4.3 Límites de Pantalla (Bounds) e Insets
- El puntero virtual nunca debe desplazarse fuera de la pantalla visible.
- Mediante `DisplayMetrics` y `WindowInsetsCompat`, se calculan los límites seguros:
  - `minX = 0`, `maxX = screenWidth - pointerSize`
  - `minY = statusBarHeight`, `maxY = keyboardTopY - pointerSize` (el puntero se detiene justo por encima de la barra del teclado para no superponerse con los controles táctiles).

### 4.4 Encaje en la Arquitectura de `VoiceKeyboardService.kt`
- En el enum `Layer` de `VoiceKeyboardService.kt`:
  ```kotlin
  private enum class Layer { LETTERS, SYMBOLS, CODE, SNIPPETS, TRACKPAD }
  ```
- Al cambiar a `Layer.TRACKPAD`:
  - Se ocultan temporalmente las filas de teclas alfabéticas/símbolos y la fila terminal.
  - La barra superior interactiva (`buildInteractiveToolbar`) permanece visible con el botón de Trackpad resaltado (`mode-active`) y su etiqueta cambiada a "Teclado" para permitir un retorno instantáneo.
  - Se monta `buildTrackpadLayer()` que contiene las dos alas y el pad central.
  - Al destruirse o esconderse la ventana (`onWindowHidden`, `onFinishInputView`, `onDestroy`), el puntero flotante se retira inmediatamente de `WindowManager` para no dejar artefactos visuales colgados en pantalla.

### 4.5 Encaje exacto en el código existente (archivo:línea)

| Pieza nueva / modificada | Patrón del que parte | Referencia en repo |
|---|---|---|
| Enum de capas: `Layer.TRACKPAD` | Capas `LETTERS`, `SYMBOLS`, `CODE`, `SNIPPETS` | `VoiceKeyboardService.kt:71` |
| Reconstrucción y montaje `buildTrackpadLayer()` | Método `rebuild()` gobernado por variable `layer` | `VoiceKeyboardService.kt:318` |
| Botón de acceso rápido `[ Trackpad ]` | Botones de barra interactiva superior (`mic`, `snippets`, `terminal`) | `VoiceKeyboardService.kt:391-419` |
| Retiro de overlay al ocultar teclado | Ciclo de vida `onWindowHidden()`, `onFinishInputView()`, `onDestroy()` | `VoiceKeyboardService.kt:282-305` |
| Supresión segura en contraseñas | Detección estricta `isPasswordInput(info)` | `VoiceKeyboardService.kt:272-279` |
| Lectura de preferencias `flutter.kb_trackpad_*` | `loadKeyboardPrefs()` en `onStartInputView` (cache por ciclo AT-A13) | `VoiceKeyboardService.kt:3293-3330` |
| Puerta de feedback háptico | Función centralizada `haptic(view)` | `VoiceKeyboardService.kt:1340` |
| Permiso de overlay en AndroidManifest | Declaración existente `android.permission.SYSTEM_ALERT_WINDOW` | `voice_bubble_stt/.../AndroidManifest.xml:4` |
| Servicio de Accesibilidad para inyección gestual | Antecedente en `README.md:107` (congelado en K3, reactivado exclusivamente para MEJ-09) | `voice_bubble_stt/.../AndroidManifest.xml`, `README.md:107` |
| Getters/setters de configuración Flutter | Métodos `loadKeyboard*` / `saveKeyboard*` en `StorageService` | `app_source/lib/services/storage_service.dart:55-90` |
| Sección de configuración en pantalla Ajustes | Pestaña Teclado `_buildKeyboardTab` con switches y segmentados | `app_source/lib/screens/settings_screen.dart:751` |
| Guard de paridad CI de claves de contrato | Validación estricta 1:1 entre Kotlin y `docs/contract-keys.txt` | `test_master_suite.py:30-41` |

---

## 5. Especificación de UI y Diseño (Opción 2: Split Wings)

El diseño responde al estándar de diseño **Apple Liquid Glass** establecido en `design.md` y probado exhaustivamente en `laboratorio_ui/trackpad_lab.html`.

### 5.1 Anatomía y Geometría de la Opción 2

```
+-------------------------------------------------------------------------------+
| [🎤 Mic]   [🖱️ Teclado (Active)]   [📋 Clips]   [>_ Term]   [⚙️ Ajustes]     | <- Toolbar (42dp)
+-------------------------------------------------------------------------------+
| +------------+ +--------------------------------------------+ +------------+ |
| |            | |                                            | |  ▲ Scroll  | |
| |            | |                                            | |  | Strip   | |
| |    CLIC    | |                                            | |  ▼ (flex)  | |
| |    IZQ     | |            ÁREA CENTRAL TÁCTIL             | +------------+ |
| |  (100% H)  | |          Superficie Glass Suave            | |            | |
| |            | |              (Mueve Puntero)               | |    CLIC    | |
| |  (flex 1)  | |                                            | |    DER     | |
| |            | |                                            | | (flex 0.8) | |
| +------------+ +--------------------------------------------+ +------------+ |
|  Flanco Izq                      Centro                       Flanco Der      |
|    (68dp)                       (flex 1)                        (68dp)        |
+-------------------------------------------------------------------------------+
```

### 5.2 Variantes de la Barra de Scroll y Auto-expansión al 100%

#### Variante A: Scroll a la Derecha (`scroll_position = right`) — Configuración Estándar
- **Flanco Izquierdo**: Contiene **únicamente** el botón Clic Izquierdo.
  - Altura: `flex: 1` -> Ocupa el **100% de la altura del ala (200dp)**.
  - Contenido: Icono chevron/flecha izquierda, etiqueta `CLIC`, subtítulo `IZQ`.
- **Centro**: Superficie táctil central expansiva (`flex: 1`).
- **Flanco Derecho**:
  - Elemento superior: `scroll-strip-v` (`flex: 1.4`), con micro-guías táctiles y flechas de dirección.
  - Elemento inferior: Botón Clic Derecho (`flex: 0.8`), con etiqueta `CLIC DER`.

#### Variante B: Scroll a la Izquierda (`scroll_position = left`) — Modo para Zurdos
- **Flanco Izquierdo**:
  - Elemento superior: `scroll-strip-v` (`flex: 1.4`).
  - Elemento inferior: Botón Clic Izquierdo (`flex: 0.8`), con etiqueta `CLIC IZQ`.
- **Centro**: Superficie táctil central expansiva (`flex: 1`).
- **Flanco Derecho**: Contiene **únicamente** el botón Clic Derecho.
  - Altura: `flex: 1` -> Ocupa el **100% de la altura del ala (200dp)**.
  - Contenido: Icono chevron/flecha derecha, etiqueta `CLIC`, subtítulo `DER`.

#### Variante C: Scroll Desactivado (`scroll_position = disabled`) — Modo Máxima Superficie de Clic
- **Flanco Izquierdo**: Contiene **únicamente** el botón Clic Izquierdo.
  - Altura: `flex: 1` -> Ocupa el **100% de la altura (200dp)**.
- **Centro**: Superficie táctil central expansiva (`flex: 1`).
- **Flanco Derecho**: Contiene **únicamente** el botón Clic Derecho.
  - Altura: `flex: 1` -> Ocupa el **100% de la altura (200dp)**.
- *Beneficio*: Superficies de accionamiento para pulgares gigantescas de 68dp x 200dp en ambos lados. Ideal para navegación de enlaces o selecciones rápidas.

### 5.3 Tokens de Diseño Liquid Glass Aplicados

| Token / Recurso | Valor Modo Oscuro | Valor Modo Claro | Propósito |
|---|---|---|---|
| `--trackpad-surface` | `rgba(15, 23, 42, 0.65)` | `rgba(241, 245, 249, 0.85)` | Fondo traslúcido de la superficie táctil central |
| `--trackpad-border` | `rgba(56, 189, 248, 0.28)` | `rgba(2, 132, 199, 0.32)` | Borde de contorno con tinte cian/azul vidrio |
| `--trackpad-active` | `rgba(56, 189, 248, 0.15)` | `rgba(2, 132, 199, 0.12)` | Iluminación de contacto al tocar el pad |
| `--kb-key-bg` | `rgba(255, 255, 255, 0.08)` | `#FFFFFF` | Fondo de los botones de las alas laterales |
| `--kb-key-border` | `rgba(255, 255, 255, 0.10)` | `rgba(0, 0, 0, 0.08)` | Borde fino de las teclas laterales |
| `--accent-container`| `rgba(10, 132, 255, 0.16)` | `rgba(0, 122, 255, 0.12)` | Estado presionado de botones y scroll strip |
| `Border Radius` | `14dp` (botones/scroll), `16dp` (pad) | `14dp` / `16dp` | Esquinas redondeadas orgánicas Liquid Glass |

---

## 6. Decisiones aprobadas por el dueño (D-TP0 a D-TP7)

| # | Decisión | Selección del Dueño | Fundamento |
|---|---|---|---|
| **D-TP0** | Aprobación del alcance MEJ-09 | **APROBADO** | Incorporar control de precisión milimétrica para terminales y navegación densa. |
| **D-TP1** | Selección del diseño base | **Opción 2: Split Wings Trackpad** | Ergonomía insuperable para uso con dos pulgares sin cruzar las manos. |
| **D-TP2** | Control de posición de barra de scroll | **Configurable (`left`, `right`, `disabled`) con auto-expansión al 100% de los botones** | Permite adaptar a zurdos/diestros o maximizar los botones a 200dp de altura si no se usa scroll. |
| **D-TP3** | Monitoreo de eventos y HUD | **ESTRICTAMENTE PROHIBIDO / CERO LOGS** | Cero telemetría, cero buffers de eventos, respeto total a la privacidad del usuario. |
| **D-TP4** | Activación del modo trackpad | **Botón dedicado en toolbar superior + switch en Ajustes** | Acceso en un toque junto al micrófono; fácil de alternar entre texto y cursor. |
| **D-TP5** | Inyección de eventos en el sistema | **`AccessibilityService.dispatchGesture`** | Método oficial de Android sin requerir root ni herramientas ADB en producción. |
| **D-TP6** | Auto-retorno al teclado por inactividad | **Configurable (Off por defecto, 5s, 15s, 30s)** | No interrumpe a quien está leyendo, pero permite regresar solo si se olvida abierto. |
| **D-TP7** | Comportamiento en contraseñas | **Desactivación de seguridad** | En campos de contraseña (`isPasswordInput()`), se oculta el trackpad y se muestra el teclado seguro. |

---

## 7. Plan por hitos de implementación

> **Regla de ejecución**: Un hito a la vez. Commits atómicos con descripciones claras. Cero regresión en suites existentes.

---

### Hito TP0 — Contrato documental y claves de configuración (~1 sesión)

**Objetivo**: Establecer las claves del puente `FlutterSharedPreferences`, registrar la documentación y dejar el contrato cerrado antes de escribir código nativo.

Tareas:
1. Actualizar `docs/contract-keys.txt` con las nuevas claves:
   - `kb_trackpad_enabled` (bool, default true)
   - `kb_trackpad_toolbar_visible` (bool, default true)
   - `kb_trackpad_scroll_position` (string: `'right'`, `'left'`, `'disabled'`, default `'right'`)
   - `kb_trackpad_sensitivity` (double, default 1.2)
   - `kb_trackpad_accel_curve` (string: `'dynamic'`, `'linear'`, `'precision'`, default `'dynamic'`)
   - `kb_trackpad_tap_to_click` (bool, default true)
   - `kb_trackpad_secondary_click` (string: `'2fingers'`, `'button'`, `'hold'`, default `'2fingers'`)
   - `kb_trackpad_scroll_direction` (string: `'natural'`, `'standard'`, default `'natural'`)
   - `kb_trackpad_haptic` (string: `'subtle'`, `'none'`, `'firm'`, default `'subtle'`)
   - `kb_trackpad_pointer_style` (string: `'arrow'`, `'dot'`, `'cross'`, default `'arrow'`)
   - `kb_trackpad_auto_return` (int, default 0)
2. Documentar la promesa de privacidad del trackpad en `README.md` y `AGENTS.md` (cero monitoreo de gestos ni coordenadas).
3. Añadir especificaciones de tokens en `design.md` para las alas y superficie táctil.

Criterios de aceptación:
- [ ] Claves añadidas a `docs/contract-keys.txt` en orden alfabético.
- [ ] `test_master_suite.py` pasa la prueba de paridad de claves.
- [ ] Documentación sincronizada y verificada.

> **Nota crítica de CI Guard**: `test_master_suite.py:30-41` comprueba la paridad 1:1 exacta entre `docs/contract-keys.txt` y los patrones `flutter.kb_*` encontrados en el código Kotlin (`VoiceKeyboardService.kt`). Por lo tanto, la modificación de `contract-keys.txt` debe sincronizarse atómicamente con las lecturas en `loadKeyboardPrefs()` (TP0/TP1) para que el CI de GitHub Actions se mantenga 100% verde en cada commit.

---

### Hito TP1 — Componente de UI Nativa: `VirtualTrackpadView` y Split Wings (~1–2 sesiones)

**Objetivo**: Construir la capa visual Split Wings dentro de `VoiceKeyboardService.kt` con soporte de morphing y adaptación dinámica de alas según la posición del scroll strip.

Tareas:
1. Crear `VirtualTrackpadView.kt` en `voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/keyboard/`:
   - Layout horizontal contenedor con altura de 200dp (`opt2-wing-left`, `opt2-center`, `opt2-wing-right`).
   - Ala Izquierda: botón Clic Izquierdo (altura dinámica `flex: 1` ó `flex: 0.8`).
   - Centro: superficie táctil con guía de cuadrícula tenue Liquid Glass y escucha de eventos táctiles (`ACTION_DOWN`, `ACTION_MOVE`, `ACTION_UP`).
   - Ala Derecha: botón Clic Derecho (altura dinámica `flex: 1` ó `flex: 0.8`).
   - Barra de Scroll Táctil (`VerticalScrollStripView`): se posiciona en el ala izquierda, ala derecha o se oculta (`GONE`) según `kb_trackpad_scroll_position`.
   - Expansión automática al 100% de altura para botones no compartidos.
2. Añadir `Layer.TRACKPAD` en `VoiceKeyboardService.kt`:
   - Función `buildTrackpadLayer()` integrada en el método `rebuild()`.
   - Botón `[ Trackpad ]` en `buildInteractiveToolbar()`, con alternancia de estado e icono.
3. Cablear lectura de preferencias en `loadKeyboardPrefs()`:
   - Lectura segura de `flutter.kb_trackpad_*` desde `FlutterSharedPreferences`.

Criterios de aceptación:
- [ ] Al pulsar el botón de Trackpad en el teclado, la vista transmuta instantáneamente al modo Split Wings.
- [ ] Al cambiar `scroll_position` a `left`, `right` o `disabled`, el layout responde de inmediato expandiendo los botones correspondientes al 100% de la altura.
- [ ] Regresión cero: escribir texto, cambiar a símbolos, abrir snippets y dictado por voz funcionan exactamente igual que antes.

---

### Hito TP2 — Puntero Virtual Flotante y Motor de Física (~1–2 sesiones)

**Objetivo**: Implementar el overlay del cursor flotante en pantalla mediante `WindowManager` y el cálculo de movimiento con aceleración e inercia.

Tareas:
1. Crear `PointerOverlayManager.kt`:
   - Inflado y control del cursor flotante con `WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY`.
   - Renderizado de los 3 estilos de cursor (Flecha vector, Punto óptico y Cruz de precisión) con aceleración por hardware.
   - Restricción de movimiento dentro de los límites visibles de la pantalla (`minX, maxX, minY, maxY`).
2. Implementar el motor de física cinemática:
   - Cálculo de deltas `(dx, dy)` multiplicados por la sensibilidad configurada.
   - Curva dinámica con aceleración cuadrática para movimientos rápidos y deceleración suave.
3. Vincular el ciclo de vida del teclado:
   - Al entrar a `Layer.TRACKPAD`, el puntero aparece con fade-in en su última posición (o centro de pantalla).
   - Al salir a QWERTY o esconderse el teclado (`onWindowHidden`), el puntero se oculta de inmediato.

Criterios de aceptación:
- [ ] Deslizar el dedo en el centro del trackpad desplaza el puntero flotante con fluidez (60 FPS+).
- [ ] El cursor respeta los límites de la pantalla sin desbordarse sobre la barra de estado ni sobre el teclado.
- [ ] El puntero desaparece inmediatamente al cerrar el teclado o volver a modo letras.

---

### Hito TP3 — Inyección Gestual en el OS vía Accesibilidad (~1–2 sesiones)

**Objetivo**: Realizar clics, pulsaciones largas y scroll reales en las aplicaciones subyacentes mediante el `AccessibilityService`.

Tareas:
1. Crear o extender `VoiceBubbleAccessibilityService.kt`:
   - Declaración de servicio de accesibilidad en `AndroidManifest.xml` con capacidad `canPerformGestures="true"`.
   - Métodos públicos estáticos / singleton seguro: `dispatchTap(x, y)`, `dispatchLongPress(x, y)`, `dispatchScroll(x, y, deltaY)`.
2. Conectar las acciones de la vista Split Wings con el despachador:
   - Pulsar botón Clic Izquierdo o Tap en el pad -> `dispatchTap(pointerX, pointerY)`.
   - Pulsar botón Clic Derecho o gesto de 2 dedos -> `dispatchLongPress(pointerX, pointerY)`.
   - Deslizar en el Scroll Strip vertical -> `dispatchScroll(pointerX, pointerY, deltaY)`.
3. Manejo de estado de permisos:
   - Si Accesibilidad no está otorgada, mostrar toast/banner explicativo invitando a activarla, sin crashear.

Criterios de aceptación:
- [ ] En Chrome / Termux / WhatsApp, el clic izquierdo presiona botones o ubica el cursor de texto en la coordenada del puntero.
- [ ] El clic derecho despliega el menú contextual de Android en la posición del cursor.
- [ ] La barra de scroll desplaza el contenido hacia arriba y hacia abajo con respuesta instantánea.

---

### Hito TP4 — Panel de Ajustes en Flutter (Dart) y Puente de Preferencias (~1 sesión)

**Objetivo**: Proveer la interfaz de usuario en la aplicación Flutter para configurar todas las opciones del trackpad.

Tareas:
1. Actualizar `storage_service.dart`:
   - Getters y setters con valores por defecto sensatos para todas las claves `kb_trackpad_*`.
2. En `settings_screen.dart` (Tab Teclado):
   - Sección dedicada **"Modo Trackpad y Puntero Virtual"**.
   - Switch maestro ON/OFF para habilitar el modo trackpad.
   - Switch para visibilidad del botón en la barra superior del teclado.
   - Selector segmentado: **Posición de Barra de Scroll** (`Izquierda`, `Derecha`, `Desactivada`).
   - Slider de sensibilidad del puntero (0.5x a 2.5x).
   - Selector segmentado de Curva de Aceleración (`Lineal`, `Dinámica`, `Precisión`).
   - Toggle Tap-to-Click.
   - Selector segmentado de Clic Secundario (`2 Dedos`, `Botón R`, `Mantener`).
   - Selector segmentado de Dirección de Scroll (`Natural iOS`, `Estándar PC`).
   - Selector de Estilo Visual del Puntero (`Flecha`, `Punto`, `Cruz`).
   - Selector de Auto-retorno por Inactividad (`Off`, `5s`, `15s`, `30s`).
3. Pruebas widget tests Dart para verificar renderizado y persistencia de las opciones.

Criterios de aceptación:
- [ ] Cada ajuste persiste en `SharedPreferences` y se refleja inmediatamente al abrir el teclado.
- [ ] Widget tests 100% verdes (`flutter test`).
- [ ] Análisis estricto de Dart limpio (0 errors, 0 warnings, 0 infos).

---

### Hito TP5 — Auditoría de Privacidad, Cero-Logs y Validación en Dispositivo (~1 sesión)

**Objetivo**: Certificar la ausencia total de logs/telemetría y verificar el funcionamiento en hardware real.

Tareas:
1. **Auditoría de Cero-Logs (Regla sagrada)**:
   - Ejecutar grep estricto: ninguna clase de trackpad, puntero o accesibilidad debe contener `Log.d/i/v/w` con coordenadas, eventos o texto.
   - Verificar que no exista ningún buffer de eventos en memoria ni telemetría oculta.
2. Matriz de verificación en dispositivo físico:
   - Termux: selección de comandos y navegación de logs.
   - Chrome / Web: clic en hipervínculos diminutos y scroll con el flanco derecho e izquierdo.
   - Alternancia rápida: teclado -> trackpad -> dictado por voz -> teclado.
   - Campos de contraseña: verificación de repliegue de seguridad.
3. Ejecutar la suite completa `python3 test_master_suite.py` y verificar resultado 8/8 verde.

Criterios de aceptación:
- [ ] Auditoría de logs 100% limpia.
- [ ] Cero regresión en la suite completa de verificación.
- [ ] Aprobación final firmada por el dueño tras prueba manual en su dispositivo.

---

## 8. Estrategia de tests y contratos de verificación

| Capa | Qué se prueba | Método / Herramienta | Entorno |
|---|---|---|---|
| **JUnit (Kotlin)** | Cálculo de cinemática/aceleración del puntero; acotación estricta a bounds; lógica geométrica de alas según `scroll_position` (`left`, `right`, `disabled`) | Tests unitarios puros sin dependencias pesadas de Android | CI / Gradle |
| **Widget Tests (Dart)** | Renderizado del panel de ajustes de trackpad; toggle de switches; selección de posición de scroll strip; persistencia en SharedPreferences | `flutter test` con `SharedPreferences.setMockInitialValues` | CI / Local |
| **CI Guard (Python)** | Paridad de claves en `docs/contract-keys.txt`; ausencia de filtraciones en logs (`test_clean_logs`) | `test_master_suite.py` | Local / CI |
| **Prueba Manual Hardware** | Inyección de clics y scroll en Termux, Chrome y apps de mensajería; ergonomía a dos pulgares; auto-expansión vertical al 100% | Teléfono físico del dueño | Dispositivo |

---

## 9. Riesgos y mitigaciones

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| 1 | **Permiso de Accesibilidad no otorgado por el usuario** | Alta | Medio | Detección preventiva con aviso amigable y modal instructiva; el teclado no crashea si el servicio no está activo. |
| 2 | **Puntero flotante bloqueando clics físicos del usuario** | Media | Alto | Flag `FLAG_NOT_TOUCHABLE` innegociable en `WindowManager.LayoutParams`: el cursor visual nunca intercepta eventos táctiles directamente. |
| 3 | **Interferencia con campos de contraseña** | Baja | Crítico | Detección estricta vía `isPasswordInput()`: el modo trackpad se desactiva en contraseñas para evitar superposiciones. |
| 4 | **Regresión en dictado por voz STT** | Muy baja | Crítico | Aislamiento completo: el módulo STT (`SpeechToTextClient`) se gobierna en su propio ciclo y tiene prioridad de audio focus. |
| 5 | **Regresión en snippets o portapapeles** | Muy baja | Alto | Capas modulares independientes en `VoiceKeyboardService.kt`; cada capa tiene su propia función de montaje. |
| 6 | **Fatiga de mano por layout asimétrico** | Media | Bajo | Posición configurable del scroll strip (`left`/`right`/`disabled`) y expansión vertical al 100% para maximizar el área de contacto de los pulgares. |
| 7 | **Fugas de memoria por retención de overlay** | Media | Medio | Limpieza garantizada en `onWindowHidden()`, `onFinishInputView()` y `onDestroy()`. |
| 8 | **Tentación de añadir analíticas o telemetría** | Media | Crítico | Prohibición explícita por política del dueño; auditoría con grep en TP5. |

---

## 10. Plan de Rollback (Reversión segura)

Si durante cualquier etapa de prueba el dueño detectara algún comportamiento indeseado o conflicto en el teclado:
1. **Desactivación Inmediata (Feature Flag)**:
   - Conmutar `kb_trackpad_enabled = false` en `FlutterSharedPreferences`.
   - El botón de trackpad desaparece de la barra superior del teclado y la capa QWERTY estándar opera con normalidad sin ejecutar ninguna línea de código del trackpad.
2. **Reversión de Código Nativo**:
   - Al estar estructurado en componentes modulares separados (`VirtualTrackpadView.kt`, `PointerOverlayManager.kt`), revertir a la versión anterior no afecta ninguna clase central de transcripción, snippets ni portapapeles.

---

## 11. Estimación

- **6 hitos** (TP0 a TP5), estimados en aproximadamente 5–6 ciclos controlados de implementación y verificación en dispositivo físico.
- Ejecución recomendada en **MODO-LOOP**: tarjetas atómicas por archivos disjuntos (`VirtualTrackpadView.kt`, `PointerOverlayManager.kt`, `storage_service.dart`, `settings_screen.dart`, `VoiceKeyboardService.kt`).

---

## 12. Registro del loop

> (Espacio reservado para el seguimiento de rondas de auditoría al iniciar la fase de implementación bajo MODO-LOOP.)

| Tarjeta | Archivo / Componente | Ronda | Auditor | Nota / Veredicto | Estado |
|---|---|---|---|---|---|
| TP0 | `docs/contract-keys.txt` & docs | — | — | Pendiente inicio | ⏳ En espera |
| TP1 | `VirtualTrackpadView.kt` | — | — | Pendiente inicio | ⏳ En espera |
| TP2 | `PointerOverlayManager.kt` | — | — | Pendiente inicio | ⏳ En espera |
| TP3 | `VoiceBubbleAccessibilityService.kt` | — | — | Pendiente inicio | ⏳ En espera |
| TP4 | `settings_screen.dart` & `storage_service.dart` | — | — | Pendiente inicio | ⏳ En espera |
| TP5 | Auditoría Cero-Logs & Master Suite | — | — | Pendiente inicio | ⏳ En espera |

---
---

> **Documento maestro de especificación y arquitectura técnica generado el 2026-09-03.**
> **Próximo paso**: El dueño autoriza el inicio del Hito TP0 en MODO-LOOP.
