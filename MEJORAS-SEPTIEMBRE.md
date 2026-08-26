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

## 3. Registro de Decisiones y Descartes

| Fecha | ID / Idea | Decisión | Motivo |
|---|---|---|---|
| 2026-08-26 | MEJ-03 (Barra Superior Mic/Clipboard) | Aprobada | Descongestiona la barra inferior y agranda la barra espaciadora |
| 2026-08-26 | MEJ-04 (Presets Código / Termux) | Aprobada | Maximiza la productividad en Termux y desarrollo de software móvil |
| 2026-08-26 | MEJ-05 (Pulsación Larga Símbolos/Acentos) | Aprobada | Permite escribir `;`, `:`, `ñ` y acentos sin conmutar a la capa `?123` |
| 2026-08-26 | MEJ-06 (Menú Rápido de 3 Opciones en Espacio) | Aprobada | Conmutación ultra veloz de modos y personalización total de accesos |
| 2026-08-26 | Congelamiento CI | Aprobado | Cuota de GitHub Actions pausada hasta el 01-Sep-2026; solo docs y diseño |

