# Plan — Ciclar mayúsculas/minúsculas de la selección con la tecla ⇧

> **Estado**: APROBADO POR EL DUEÑO (2026-08-24, decisiones D-M1…D-M7 cerradas — ver §4).
> **NADA IMPLEMENTADO.** Este documento solo propone: no se ha modificado ningún
> archivo existente del repo, no hay commits ni pushes asociados.
> **Fecha**: 2026-08-24 · **Origen**: pedido del dueño (competencia: Gboard).
> **Reglas madre**: `AGENTS.md` (privacidad sagrada, anti-patrones §8, lecciones §9),
> `MODO-LOOP.md`, `design.md` §12 · estilo de planes: `teclado-voice.md`.

---

## 1. Historia de usuario y alcance

**Como dueño**, cuando edito código o texto en cualquier app con el teclado
VoiceBubble, quiero **seleccionar un identificador/frase y tocar ⇧** para que la
selección cambie de caso sin reescribirla:

```
todo minúsculas → Primera Letra Mayúscula → TODO MAYÚSCULAS → vuelve a todo minúsculas …
```

Caso de uso declarado por el dueño: **renombrar funciones/identificadores en código**
(ej. `mi_funcion` → `MI_FUNCION`) sin borrar ni redactar de nuevo.

**Dentro del alcance**

- Tecla ⇧ de la capa LETRAS (`buildLetterRows`, `VoiceKeyboardService.kt:382-392`):
  si al tocarla HAY texto seleccionado en el campo destino, cicla el caso de la
  selección reemplazándola en el campo.
- Sin selección (o lectura no soportada): ⇧ conserva EXACTO su comportamiento actual
  (máquina OFF → MOMENTARY → CAPS_LOCK).
- Selección multi-línea soportada (el ciclo es sobre el CharSequence completo).

**Fuera del alcance (anti-patrones §8 / menos es más)**

- Ninguna otra tecla gana comportamiento nuevo; sin menús de caso, sin burbujas nuevas,
  sin lectura del documento completo, sin historial/registro del texto tocado
  (regla sagrada: jamás registrar contenido tecleado, ni en debug).
- Sin cambios en la burbuja, en el dictado ni en snippets (salvo guardas defensivas).

---

## 2. Comportamiento ACTUAL de ⇧ (evidencia repo)

| Aspecto | Evidencia |
|---|---|
| Máquina de estados `ShiftState { OFF, MOMENTARY, CAPS_LOCK }` | `VoiceKeyboardService.kt:67` y campo `shiftState` :75 |
| Doble pulso rápido (≤300 ms) escala a CAPS_LOCK | `toggleShift()` :676-687 + `SHIFT_DOUBLE_TAP_MILLIS = 300L` :2565 |
| Aplicación visual (glifo ⇪, fondo accent) | `applyCase()` :689-711 |
| Muerte del shift momentáneo tras cada commit | `releaseMomentaryShift()` :728-733 |
| Reset al abrir campo nuevo | `onStartInputView` → `deactivateShift()` :210 |
| Precedente clave de lectura de selección con tolerancia | `handleBackspace()` usa `ic.getSelectedText(0)` dentro de try/catch → null (:843-847) |
| Commits al campo | `currentInputConnection?.commitText(text, 1)` (:723, :759, :1217…) |
| Campos de contraseña detectados | `isPasswordInput()` :217-224 (4 variaciones); mic oculto :443, snippets ocultos :473 |
| Puente de preferencias Flutter→Kotlin | Kotlin lee `flutter.kb_*` en `FlutterSharedPreferences` (`codeKeyVisible()` :2481-2486, `languageKeyVisible()` :2493-2498, lectura única por ciclo `loadKeyboardPrefs()` :2509-2531); Dart escribe en `storage_service.dart:63-90`; switches en `settings_screen.dart:669-696` |

Hoy, tocar ⇧ con una selección activa solo cambia la máquina shift (y por tanto qué
letra comitaría el próximo toque); la selección NO se transforma. Este plan añade esa
segunda rama SIN tocar la primera.

---

## 3. Viabilidad técnica verificada (developer.android.com + AOSP)

### 3.1 Lectura de la selección: `InputConnection.getSelectedText(int)` — SÍ

- Disponible desde API 3 (GINGERBREAD), muy por encima de nuestro minSdk 28.
  Fuente: developer.android.com/reference/android/view/inputmethod/InputConnection#getSelectedText(int)
- Contrato oficial: devuelve "the text that is currently selected, if any, **or null**
  if no text is selected". El comentario fuente de AOSP agrega que también devuelve
  null si la conexión quedó inválida o el editor tarda demasiado en responder.
  Fuente: cs.android.com `core/java/android/view/inputmethod/InputConnection.java`.
- **Campos custom que devuelven null**: algunos editores propios (TerminalView de
  Termux, webviews, editores raros) no implementan la lectura. El fallback elegido es
  el MÁS conservador posible: tratarlo como "no hay selección" y ejecutar el shift
  normal. NO existe lectura alternativa fiable sin leer texto ajeno masivamente
  (`getExtractedText`/`getSurroundingText` grandes = costo IPC documentado y riesgo de
  privacidad) → queda PROHIBIDO por este plan. La lectura puntual SOLO ocurre en el
  toque explícito de ⇧ (nunca sondeo continuo vía `onUpdateSelection`).
  Nota: `EditorInfo.getInitialSelectedText(int)` existe para evitar IPC al ARRANCAR
  campo, pero no aplica aquí porque leemos bajo demanda del usuario.
- Precedente interno idéntico: `handleBackspace()` ya llama `getSelectedText(0)` con
  try/catch → null (`VoiceKeyboardService.kt:843-847`) y funciona en dispositivo real
  (Chrome, WhatsApp, Acode, Termux verificados en K2/K3).

### 3.2 Reemplazo seguro de la selección: `commitText` + batch edit — SÍ

- Documentación oficial de `commitText(CharSequence, int)`: "the new text is inserted
  at the cursor position, **removing text inside the selection if any**" → comitar
  sobre una selección REEMPLAZA exactamente la selección.
  Fuente: developer.android.com/reference/android/view/inputmethod/InputConnection#commitText(java.lang.CharSequence,%20int)
- `newCursorPosition = 1` deja el cursor justo después del texto comitado (semántica
  verificada en docs y en `BaseInputConnection.replaceText`).
- `beginBatchEdit()/endBatchEdit()`: agrupan operaciones ("batch edits nest"; hay que
  llamar `endBatchEdit` por cada `beginBatchEdit`) y evitan estados intermedios/
  parpadeos suprimiendo `onUpdateSelection` intermedios.
  Fuente: InputConnection#beginBatchEdit.
- **Restauración de la selección**: tras el commit el editor colapsa el cursor; para
  que el dueño pueda seguir tocando ⇧ y seguir ciclando, hay que re-seleccionar con
  `setSelection(start, end)` DENTRO del mismo batch edit. Los docs definen que cursor
  y selección son lo mismo (selección de tamaño cero = cursor) y que `setSelection`
  fija la selección del editor. Si el editor ignora `setSelection` (posible en
  editores raros), el próximo toque simplemente cae al shift normal: degradación
  honesta, nunca pérdida de datos.
- Secuencia propuesta por toque:
  ```
  beginBatchEdit() → commitText(transformado, 1) → setSelection(ini, fin) → endBatchEdit()
  ```
  con `try/finally` garantizando el `endBatchEdit`. Caso borde: si el largo cambia con
  la transformación (ej. `ß`→`SS` bajo reglas ICU), no se re-selecciona: cursor al
  final del reemplazo.

### 3.3 Comportamiento estándar (Gboard) — diseño validado

- Gboard: con texto seleccionado, tap ⇧ cicla minúsculas → sentence case →
  MAYÚSCULAS (y repite). Fuentes: guía "A Nifty Gboard Trick to Change Letter Case"
  (techtrickz.com, 2022) y petición idéntica en Unexpected-Keyboard issue #1316
  (menciona también AnySoftKeyboard como precedente). Nuestro orden pedido por el
  dueño coincide con el de Gboard (arranca en minúsculas).

### 3.4 Campos de contraseña — deshabilitar (recomendado)

- Regla del repo: "Dictado o snippets activos en campos de contraseña" es
  anti-patrón (AGENTS.md §8) y design.md §12: "campos de contraseña: micrófono
  oculto, snippets deshabilitados". Aunque transformar el caso de algo YA seleccionado
  no graba ni transmite nada, el criterio histórico del proyecto es apagar TODA
  función no esencial ahí. Recomendación: en campos donde `isPasswordInput()` sea true,
  ⇧ mantiene su comportamiento actual (sin ciclo). Queda como decisión D-M2.

### 3.5 Definición de los 3 estados de caso para español

| Estado | Definición propuesta | Ejemplo |
|---|---|---|
| 1. todo minúsculas | `texto.lowercase()` (ICU, locale por defecto) | `miFunción` → `mifunción` |
| 2. Primera Letra Mayúscula | primera letra (primer carácter con `isLetter`) de TODA la selección en mayúscula, resto en minúsculas ("sentence case", igual que Gboard) | `hola mundo` → `Hola mundo` |
| 3. TODO MAYÚSCULAS | `texto.uppercase()` | `mi_función` → `MI_FUNCIÓN` |

Alternativa al estado 2 (Title Case por palabra: `Hola Mundo`) → decisión D-M1.
Los caracteres sin caso (dígitos, `_`, símbolos, emojis) quedan intactos; los pares
surrogate (emojis) sobreviven porque la transformación opera sobre el String completo
(mismo criterio AT-A5 del repo para recortes). Acentuadas españolas (í↔Í) mapean 1:1;
si alguna regla ICU cambiara el largo, se aplica la regla de 3.2.

**Veredicto**: VIABLE SIN DEPENDENCIAS NUEVAS, condicionado a las decisiones D-M1…D-M7.

---

## 4. Decisiones (CERRADAS por el dueño, 2026-08-24)

| # | Decisión | Opciones | Recomendación | **Respuesta del dueño** |
|---|---|---|---|---|
| D-M1 | Semántica del estado 2 "Primera Letra Mayúscula" | (a) Sentence case: solo la primera letra de toda la selección (Gboard); (b) Title Case: primera letra de CADA palabra | (a), coincide con Gboard y con el caso de uso de identificadores | **(a)** sentence case |
| D-M2 | Campos de contraseña | (a) ciclo deshabilitado, ⇧ normal; (b) ciclo permitido | (a), coherente con la regla histórica "sin funciones activas en contraseñas" | **(a)** ciclo deshabilitado en contraseñas |
| D-M3 | ¿Toggle en Ajustes? | (a) sin toggle, siempre activo (menos es más; Gboard no ofrece toggle); (b) switch `kb_shift_case_cycle_enabled` en la tarjeta Teclado, default ON, patrón K2.1 (`storage_service.dart:63-75` + lectura Kotlin `loadKeyboardPrefs()` :2509-2531) | (b) si se quiere salida de emergencia barata; (a) si prima simplicidad. El costo de (b) es bajo porque el puente ya existe | **(a)** siempre activo, sin toggle |
| D-M4 | Feedback visual/háptico durante el ciclo | (a) solo el háptico existente (`haptic()` :943-946); (b) aviso inline corto reutilizando `showStatus()` :1826-1858 ("Minúsculas", "Primera mayúscula", "MAYÚSCULAS", i18n es/en, auto-descarte 3.5 s); (c) destello accent en la tecla ⇧ | (b): confirma QUÉ estado aplicó sin adivinarlo, respeta Reduced Motion (texto estático) y no inventa componentes nuevos | **(b)** aviso inline vía showStatus, i18n es/en |
| D-M5 | ⇧ con selección y doble pulso | Mientras HAY selección confirmada: (a) cada tap cicla una vez y la máquina shift queda intacta (sin caps lock por doble toque); (b) respetar también el doble pulso → caps lock | (a): el ciclo reemplaza la función del shift en ese contexto; dos taps rápidos = dos ciclos (comportamiento Gboard) | **(a)** cada tap cicla; sin caps lock con selección |
| D-M6 | Selección perdida entre toques (el editor colapsó o ignoró `setSelection`) | (a) degradación honesta: siguiente tap = shift normal; (b) recordar offsets y forzar re-selección | (a): nunca pelear con el editor ni retener offsets de un campo ajeno (privacidad + robustez) | **(a)** degradación honesta |
| D-M7 | Guardas adicionales del ciclo | Deshabilitar ciclo cuando: CTRL/ALT sticky activos (`ctrlActive \|\| altActive`, para no interferir con combos de Termux), capa SNIPPETS con búsqueda activa, o `currentInputConnection == null` | Sí a todas: el ciclo solo aplica en el caso puro "campo normal + selección + ⇧ desnuda" | **SÍ a todas las guardas** |

---

## 5. Hitos propuestos

> Convenciones heredadas: un hito a la vez, commits chicos en español, push →
> monitoreo CI (ritual §9.4 AGENTS.md) → APK al dueño → marcar casillas.
> El código Kotlin se edita directo en `voice_bubble_stt/android/` (regla §9.2-1:
> solo `{lib,test,pubspec,analysis_options}` viven en `app_source/`).

### M-C1 — Núcleo nativo del ciclo (Kotlin)

**Objetivo**: ⇧ con selección transforma la selección; sin selección, comportamiento
actual byte a byte idéntico.

Tareas:

1. Nueva función privada `cycleSelectionCase()` invocada desde el click de ⇧
   ANTES de `toggleShift()`: si alguna guarda falla (D-M2/D-M7, selección null/vacía),
   delega en la ruta existente `toggleShift()` sin ningún otro cambio.
2. Lectura tolerante de la selección: `getSelectedText(0)` en try/catch → null
   (mismo patrón de `handleBackspace()` :843-847). PROHIBIDO leer documento completo.
3. Transformación pura y testeable por inspección: minúsculas → primera letra
   (según D-M1) → mayúsculas, con memoria del último estado SOLO en variables locales
   del toque (sin persistir jamás el texto).
4. Commit atómico `beginBatchEdit` → `commitText` → `setSelection` → `endBatchEdit`
   en try/finally (§3.2), incluida la regla de largo distinto.
5. Sin `Log.` nuevo; nada del contenido toca disco, red ni historial.

Criterios de aceptación:

- [ ] Con selección en Chrome/Acode: cada tap cicla minúsculas → primera letra → MAYÚSCULAS → minúsculas, y la selección sigue activa para el próximo tap (verificación en dispositivo).
- [ ] Sin selección: shift momentáneo, doble pulso = caps lock y glifos ⇧/⇪ funcionan exactamente igual que hoy (regresión visual manual).
- [ ] En campo de contraseña el ciclo no ocurre (si D-M2 = deshabilitar).
- [ ] CI verde (analyze estricto + test + build APK que compila el Kotlin).

### M-C2 — Preferencia y Ajustes (solo si D-M3 = toggle)

**Objetivo**: switch "Ciclo de mayúsculas" en Ajustes → Teclado, siguiendo el patrón
probado K2.1/lote de pulido (teclas `</>` e idioma).

Tareas:

1. `storage_service.dart`: clave `kb_shift_case_cycle_enabled`, load/save con default true (patrón :63-90).
2. `settings_screen.dart`: SwitchListTile con subtítulo claro, estado inicial cargado en `_loadInitialState()` (paralelo, :67-101) — respetando lección §9.1-21 (superficie alta en TODOS los tests que rendericen la pantalla).
3. Kotlin: lectura única en `loadKeyboardPrefs()` (:2509-2531) cacheada en campo + guarda en el click de ⇧; cambio aplica al abrir el próximo campo (caducidad honesta ya documentada en AT-A13).
4. Tests Dart de persistencia/render/default (ver estrategia §6).

Criterios de aceptación:

- [ ] Switch persiste entre aperturas; instalación nueva = ON.
- [ ] Con switch OFF, ⇧ con selección NO cicla (shift normal).
- [ ] `flutter analyze` estricto y suite Dart completa en verde en CI.

### M-C3 — Feedback, i18n y verificación final

**Objetivo**: el dueño sabe qué estado aplicó y la feature sobrevive casos borde.

Tareas:

1. Aviso inline es/en tras cada ciclo vía `showStatus()` (:1826-1858), textos según D-M4, i18n con el patrón `if (spanishMode)` existente.
2. Matriz manual en dispositivo real (Chrome, WhatsApp, Acode, Termux):
   - [ ] Selección null/no soportada (Termux): ⇧ se comporta como siempre, sin crash.
   - [ ] Selección multi-línea cicla completa.
   - [ ] Emoji dentro de la selección: par surrogate intacto (nada partido).
   - [ ] Texto RTL (ej. árabe) seleccionado: transformación inofensiva, selección estable.
   - [ ] Acentuadas `ñ í á`: mapean 1:1 (`í` ↔ `Í`).
   - [ ] Rotación/cambio de campo entre toques: sin crash ni texto huérfano (guardas estilo AT-A1/K5-T5).
   - [ ] Regresión completa del dictado, snippets, capa código y fila terminal.
3. Ritual post-push obligatorio: monitorear run hasta `completed`; APK arm64 al dueño con checklist.

Criterios de aceptación:

- [ ] Toda la matriz manual en verde en dispositivo físico.
- [ ] Ningún log contiene contenido de la selección (grep de guardas + releer diff, batería final MODO-LOOP).
- [ ] CI verde + APK publicado y verificado por el dueño.

---

## 6. Estrategia de tests

- **CI GitHub Actions** (`.github/workflows/android.yml`, sin cambios estructurales):
  analyze estricto + tests Dart + `build apk --split-per-abi` → compila el Kotlin y
  detecta errores de tipos/imports (lecciones §9.1-18/22/23: verificar rutas de paquete
  y constantes contra developer.android.com ANTES de pushear; ante errores en cascada,
  revisar imports primero).
- **Tests Dart** (solo si D-M3 = toggle): contrato de la nueva clave en
  `storage_service_test`, render y toggling en `settings_screen_test` con superficie
  alta (§9.1-17/§9.1-21). El comportamiento del IME no es testeable en Dart.
- **Kotlin**: sin runner de unit tests de IME en este proyecto; validación razonada
  del diff (relectura íntegra, regla §9.2-7) + matriz manual de M-C3 como fuente de
  verdad funcional.
- **Casos borde cubiertos**: ver lista checklisteada de M-C3 (selección null,
  multi-línea, emojis/graphemas, RTL, acentuadas, rotación, contraseñas).

---

## 7. Riesgos y mitigaciones

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | Editor que no soporta `getSelectedText` devuelve null (Termux, webviews) | Alta | Bajo | Degradación honesta a shift normal (precedente :843-847); jamás lecturas masivas del documento (prohibición explícita de este plan) |
| R2 | Apps con EditText raros donde comitar sobre selección borre en vez de reemplazar (bug documentado Evernote+Gboard, 2021) | Baja | Medio | Secuencia estándar commitText+batch edit (contrato oficial); matriz manual en las apps blanco; si aparece, se documenta app-específica y NO se parchea a ciegas |
| R3 | Pérdida de selección tras commit impide seguir ciclando | Media | Bajo | `setSelection(ini, fin)` dentro del mismo batch edit; si el editor la ignora → degradación honesta (D-M6) |
| R4 | Regresión del shift actual (momentáneo/caps lock) | Baja | Alto | El ciclo vive en una rama previa con guardas; sin selección el código ejecuta `toggleShift()` intacto; regresión manual explícita en M-C1 |
| R5 | Privacidad percibida (leer selección) | Baja | Alto | Lectura ÚNICA y puntual al tocar ⇧, en memoria, jamás persistida/logueada/transmitida; sin sondeo continuo; auditoría grep de la batería final |
| R6 | ANR por IPC lento del editor (caso documentado Stack Overflow 76221524) | Baja | Medio | Una sola llamada por toque explícito del usuario (los docs advierten contra uso repetido, no puntual); try/catch; sin timeouts custom |
| R7 | Scope creep (convertir ⇧ en menú de casos, camelCase, etc.) | Media | Medio | Anti-patrones §8: solo los 3 estados pedidos; cualquier extensión = nueva propuesta del dueño |

---

## Registro del loop

(Sin entradas todavía. Se llenará durante la ejecución en modo loop: tarjetas,
olas de escritores, auditorías y rondas, según `MODO-LOOP.md`.)
