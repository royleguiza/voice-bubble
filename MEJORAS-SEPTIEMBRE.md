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

### 2.3 App Flutter y Ajustes (Liquid Glass)
* *(Espacio para registrar nuevas ideas de UI principal, snippets, historial y configuración)*

---

## 3. Registro de Decisiones y Descartes

| Fecha | ID / Idea | Decisión | Motivo |
|---|---|---|---|
| 2026-08-26 | MEJ-03 (Barra Superior Mic/Clipboard) | Aprobada | Descongestiona la barra inferior y agranda la barra espaciadora |
| 2026-08-26 | MEJ-04 (Presets Código / Termux) | Aprobada | Maximiza la productividad en Termux y desarrollo de software móvil |
| 2026-08-26 | Congelamiento CI | Aprobado | Cuota de GitHub Actions pausada hasta el 01-Sep-2026; solo docs y diseño |

