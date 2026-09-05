# Hito 4 Híbrido — Burbuja con inyección por Accesibilidad + IME propio — Plan de Ejecución

> **Estado**: 🛑 BLOQUEADO 2026-09-05 (decisión del dueño: perfil anti-Play-Protect). El servicio de accesibilidad se retiró del manifest; sin declaración no hay `SET_TEXT/PASTE` posible. D-HB0…D-HB7 quedan archivadas como spec válida para el día que vuelva (vía Play Store o flavor `full`). La burbuja pega vía IME propio o portapapeles.
> **Fecha**: 5 de septiembre de 2026
> **Origen**: pedido del dueño: usar la burbuja (normal e isla/píldora) con un teclado de terceros (ej. DigiWord, con contraseñas guardadas) y lograr pegado directo en inputs, al estilo WhisperFlow/Wispr Flow, sin perder el path actual con nuestro teclado.
> **Precedentes internos**: `plan.md` Hito 4 (congelado 2026-08-22); `teclado-voice.md` D1–D9; `plan-clipboard.md` (excepción §8, TTL, máscara sensibles); `plan-ciclar-mayusculas.md` (lectura tolerante, degradación honesta); puente Flutter↔Kotlin K2.1.
> **Reglas madre**: `AGENTS.md` (privacidad, anti-patrones §8, lecciones §9), `MODO-LOOP.md`, `design.md` §12.

---

## 1. Qué vamos a construir (visión en una página)

La misma burbuja de siempre (vista clásica + isla/píldora `DynamicIslandController`) gana un **segundo camino de pegado** para cuando el usuario NO usa nuestro teclado:

1. **Modo IME propio (ya existe, intacto, prioritario)**: si `VoiceBubble Keyboard` es el IME activo, la burbuja inserta vía `commitText` en el cursor. Cero permisos extra. Ideal para Termux.
2. **Modo Accesibilidad (nuevo, estilo WhisperFlow)**: si hay otro teclado (DigiWord/Gboard/SwiftKey) Y el servicio de accesibilidad está concedido, la burbuja inyecta vía `ACTION_SET_TEXT` sobre el nodo enfocado, con fallback `clipboard + ACTION_PASTE`.
3. **Modo Portapapeles (ya existe, fallback final)**: si no hay ni IME propio ni accesibilidad/nodo válido, clipboard + aviso `Copiado al portapapeles` para pegado manual.

- NO se captura pantalla, NO hay OCR, NO se viola aislamiento de procesos: solo las dos APIs oficiales de Android (IME + AccessibilityService).
- La accesibilidad **solo** se usa en el instante de transcribir (lectura puntual del foco), nunca monitoreo continuo, nunca logs de contenido.
- Opt-in doble: interruptor del sistema (Accesibilidad) + switch propio en Ajustes. Sin ambos, el modo 2 no existe.

### Por qué esto toca una decisión congelada (aprobación explícita requerida)

`plan.md:225-227` y `AGENTS.md` Estado congelaron el Hito 4 ("el dictado desde el teclado cubre la inserción"). Este plan lo **descongela parcialmente**: solo inyección desde burbuja con tercer teclado, sin reabrir Accessibility para nada más (ni lectura masiva, ni gestos nuevos salvo trackpad MEJ-09 ya existente). Solo procede si el dueño aprueba D-HB0. Sin eso, archivar.

---

## 2. Historia de usuario

> **Como** dueño que usa DigiWord (con sus contraseñas y diccionario) como teclado diario,
> **quiero** dictar con la burbuja VoiceBubble en Termux, WhatsApp o un texto largo,
> **y que** el texto aparezca directo en el campo enfocado sin hacer long-press → Pegar,
> **para** no tener que cambiar de teclado cada vez que dicto.

Flujo feliz A (nuestro teclado, ya funciona hoy):

1. Campo abierto con `VoiceBubble Keyboard` → toco burbuja → dicto → texto en cursor.

Flujo feliz B (tercer teclado, nuevo):

1. Campo abierto con DigiWord → accesibilidad concedida + switch propio ON → toco burbuja → dicto → texto inyectado en el campo.
2. Si la app destino rechaza `SET_TEXT` (campo custom) → reintento `PASTE` → si también falla → clipboard + aviso manual.

Flujo de contraseñas (protegido):

1. Campo de contraseña / `FLAG_SECURE` → jamás se inyecta → solo clipboard + aviso neutro, DigiWord sigue dueño del flujo.

---

## 3. Alcance

### SÍ incluye

| # | Capacidad |
|---|---|
| 1 | Inyección `ACTION_SET_TEXT` puntual desde la burbuja (clásica e isla) cuando hay tercer IME + accesibilidad + nodo editable enfocado |
| 2 | Fallback `clipboard + ACTION_PASTE` cuando `SET_TEXT` es rechazado por el destino |
| 3 | Routing con prioridad fija: IME propio → Accesibilidad → Portapapeles, con feedback distinto por camino |
| 4 | Guardas duras: contraseñas/`FLAG_SECURE` nunca se inyectan; Termux/terminal con trato honesto (ver D-HB4) |
| 5 | Switch opt-in propio + estado visible + deep-link a Ajustes de Accesibilidad (canal ya existente) |
| 6 | i18n ES/EN, Reduced Motion, TalkBack labels, targets ≥44dp en lo nuevo de Ajustes |
| 7 | Auditoría de privacidad: cero `Log` con contenido, cero persistencia del texto inyectado |

### NO incluye (fuera de alcance, explícito)

- ❌ OCR, captura de pantalla, lectura continua de ventanas, `getExtractedText`/`getSurroundingText` masivos.
- ❌ Dictado en campos de contraseña vía burbuja (prohibido por este plan, igual que mic/snippets del teclado).
- ❌ Auto-`ENTER`/`SEND` tras pegar (idea MEJ backlog, no parte de este Hito).
- ❌ Cambiar el dictado del teclado, snippets, capas, trackpad ni el flujo de la app principal.
- ❌ Persistir lo inyectado en disco, prefs o historial extra (el historial FIFO-20 existente sigue igual).
- ❌ Publicación en Play Store en este Hito (sideload por GitHub como hoy; la declaración Play queda como decisión D-HB7).

---

## 4. Comportamiento ACTUAL (evidencia repo)

| Pieza | Evidencia |
|---|---|
| 3 servicios ya declarados en el mismo APK | `voice_bubble_stt/android/app/src/main/AndroidManifest.xml:15,21,34` (`FloatingBubbleService`, `VoiceBubbleAccessibilityService`, `VoiceKeyboardService`) |
| Accesibilidad hoy ciega por diseño | `res/xml/accessibility_service_config.xml:7` `canRetrieveWindowContent="false"`; `VoiceBubbleAccessibilityService.kt:274-276` `onAccessibilityEvent` vacío; cabecera `:13-21` promete CERO monitoreo |
| Accesibilidad hoy solo gestos + isla | `VoiceBubbleAccessibilityService.kt:54-182` `dispatchTap/LongPress/Scroll` vía `dispatchGesture`; `:217-257` hospeda isla con `TYPE_ACCESSIBILITY_OVERLAY` |
| Burbuja solo overlay + FGS micrófono | `FloatingBubbleService.kt:29-106` sin inyección; notifica taps a Dart vía `BubbleActionListener:108-113` |
| Post-transcripción burbuja = clipboard + intento IME | `app_source/lib/screens/home_screen.dart:405-408` `Clipboard.setData + pushHistoryEntry + _pasteOrCopyFeedback`; `:339-356` `_pasteOrCopyFeedback` intenta `commitText`, si `false` muestra `Copiado al portapapeles` |
| IME propio inserta directo | `VoiceKeyboardService.kt:3844-3848` `commitFromExternal()` → `currentInputConnection?.commitText(text, 1)`; canal Dart `keyboard_service.dart:54-61`, nativo `MainActivity.kt:151-154` |
| Isla también intenta IME y copia | `DynamicIslandController.kt:1109-1112` `commitFromExternal + copyToClipboard + closeHistoryModal`; `:1265-1272` `copyToClipboard` |
| Detección de contraseña ya existe (teclado) | `VoiceKeyboardService.kt:217-224` `isPasswordInput()`; mic oculto `:443`, snippets ocultos `:473` |
| Estado accesibilidad ya consultable | `MainActivity.kt:181-190` `isAccessibilityGranted/openAccessibilitySettings` en canal `floating_trackpad` |
| Hito 4 congelado | `plan.md:225-254` objetivo `ACTION_SET_TEXT` + fallback clipboard, criterios sin marcar |

Conclusión: la burbuja clásica y la píldora comparten el mismo flujo Dart (`home_screen.dart`). Ninguna inyecta por accesibilidad hoy. El `commitText` solo gana cuando nuestro IME está activo.

---

## 5. Viabilidad técnica (developer.android.com + AOSP)

### 5.1 Detección del campo: `findFocus(FOCUS_INPUT)` + `isEditable` — SÍ, con permisos

- Contrato: `AccessibilityService.getRootInActiveWindow()` + `root.findFocus(ACCESSIBILITY_FOCUS_INPUT / FOCUS_INPUT)` devuelve el nodo editable enfocado, o null. Requiere `canRetrieveWindowContent="true"` y `eventTypes` con `TYPE_VIEW_FOCUSED` / `TYPE_WINDOW_CONTENT_CHANGED`.
- Fuentes: `AccessibilityService` + `AccessibilityNodeInfo.findFocus` + guía `Develop an accessibility service` (developer.android.com).
- Implicación: hay que subir el config actual (hoy `false`/`flagDefault`) a lectura de contenido. Es el costo de privacidad central (ver §8 R1).

### 5.2 Inyección: `ACTION_SET_TEXT` — SÍ, camino primario

- Contrato: `Bundle(ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE) + node.performAction(ACTION_SET_TEXT, args)`. Retorna Boolean: `true` = aceptado.
- Destinos que lo rechazan (documentado + práctica): campos custom que no implementan el action (algunas terminales, webviews raros, juegos). De ahí el fallback §5.3.
- No requiere `SYSTEM_ALERT_WINDOW` para inyectar; el overlay solo pone el botón flotante (ya lo tenemos).

### 5.3 Fallback: `clipboard + ACTION_PASTE` — SÍ, con límites conocidos

- Secuencia: `ClipboardManager.setPrimaryClip` + `node.performAction(ACTION_PASTE)`. El nodo debe estar enfocado y aceptar paste.
- Límites: Android 10+ restringe lectura de clipboard a IME por defecto o app enfocada — aquí quien LEE es el destino al pegar, no nosotros, así que aplica igual que un paste manual. En Android 13+ el sistema puede mostrar toast de pegado y auto-borrar el clip tras ~1h (mismo costo ya documentado en `plan-clipboard.md:109-118`).

### 5.4 Termux/terminales — MATIZ CRÍTICO (condiciona D-HB4)

- La vista de Termux (`TerminalView`) no es un `EditText` estándar: `findFocus(FOCUS_INPUT)` suele devolver null y `SET_TEXT`/`PASTE` fallan. Precedente interno análogo: `plan-ciclar-mayusculas.md:73-79` documenta que `getSelectedText` devuelve null en `TerminalView`.
- Traducción: para Termux el **Modo IME propio sigue siendo superior** (`InputConnection.commitText` sí entra). El Modo Accesibilidad brillará en inputs estándar (WhatsApp, Gmail, Chrome, Acode, Notes). El plan no promete inyección universal en terminal.

### 5.5 Contraseñas y `FLAG_SECURE` — BLOQUEO POR DISEÑO

- En `TYPE_TEXT_VARIATION_PASSWORD` y ventanas `FLAG_SECURE`/bancarias, el framework oculta contenido y puede negar actions. Aunque algún destino lo aceptara, este plan lo PROHÍBE (D-HB2 recomendada): jamás inyectar ahí. Solo clipboard + aviso neutro, sin leer el contenido previo del campo.

### 5.6 Encaje en código existente (archivo:línea)

| Pieza nueva | Patrón del que parte | Referencia |
|---|---|---|
| `findFocusedEditableNode()` + `injectViaAccessibility(text)` en `VoiceBubbleAccessibilityService` | `dispatchGesture` + `isConnected()` + `instance` singleton | `VoiceBubbleAccessibilityService.kt:22-36,54-108` |
| Config `canRetrieveWindowContent=true` + `eventTypes` + `feedbackType` | config actual mínimo | `res/xml/accessibility_service_config.xml:1-8` |
| Descripción honesta del servicio (strings) | `accessibility_service_name/desc` | `res/values/strings.xml` (actualizar) |
| Routing `IME → A11y → clipboard` en Dart | `_pasteOrCopyFeedback` | `home_screen.dart:339-356,403-409,452-455` |
| Canal `injectViaAccessibility(text)` o reutilizar `commitText` con fallback nativo | canales `floating_bubble` + `keyboard` | `MainActivity.kt:29-119,121-157` + `keyboard_service.dart:54-61` |
| Switch propio + estado + deep-link | switches Teclado + `isAccessibilityGranted/openAccessibilitySettings` | `settings_screen.dart:613-755`, `MainActivity.kt:181-190` |
| Claves contrato `flutter.` | `loadKeyboardPrefs` cache por ciclo (AT-A13) | `VoiceKeyboardService.kt:2509-2531`, `storage_service.dart:49-90`, `docs/contract-keys.txt` |

Cero dependencias nuevas, cero permisos manifest nuevos (`BIND_ACCESSIBILITY_SERVICE` ya declarado `:23`). Impacto APK ≈ solo Kotlin plano + strings.

---

## 6. Decisiones abiertas (el dueño decide ANTES de ejecutar)

| # | Decisión | Opciones | Recomendación |
|---|---|---|---|
| D-HB0 | ¿Descongelar Hito 4 parcial solo para inyección burbuja con tercer teclado? | Aprobar / Archivar | Aprobar acotado: solo `SET_TEXT/PASTE` puntual desde burbuja; sin monitoreo continuo; teclado propio sigue prioritario |
| D-HB1 | Switch propio de inyección | (a) Opt-in OFF por defecto · (b) ON cuando el sistema ya concedió accesibilidad | **(a) OFF**: nadie amplía lectura de ventanas sin pedirlo; coherente con clipboard tray D-C3 |
| D-HB2 | Campos de contraseña / `FLAG_SECURE` | (a) Jamás inyectar, solo clipboard · (b) Permitir inyectar | **(a)**: DigiWord sigue dueño de contraseñas; cero riesgo de filtrado |
| D-HB3 | Fallback `PASTE` | (a) Sí intentarlo tras `SET_TEXT=false` · (b) Ir directo a clipboard manual | **(a)**: cubre campos custom que rechazan `SET_TEXT` pero aceptan paste |
| D-HB4 | Termux sin nodo editable | (a) Intentar igual (un IPC barato) y caer a clipboard · (b) Atajo directo a clipboard con hint "En terminal, pega con tu teclado" | **(a)**: un intento tolerante cuesta poco; si null → clipboard. Sin prometer magia en terminal |
| D-HB5 | Feedback por camino | (a) Silencioso salvo fallo · (b) Snackbars distintos: `Insertado en el campo` / `Pegado` / `Copiado al portapapeles` | **(b)**: el dueño sabe qué camino ganó sin adivinar; respeta Reduced Motion (texto estático) |
| D-HB6 | Isla/píldora vs burbuja clásica | (a) Mismo routing en ambas · (b) Solo clásica | **(a)**: comparten flujo Dart; divergirlas crea dos verdades |
| D-HB7 | Distribución / Play | (a) Seguir sideload GitHub + texto honesto en `INSTALL.md` · (b) Preparar declaración Play de asistencia (discapacidad motora) ya | **(a)** en este Hito; (b) queda backlog si algún día va a Play |

Respuestas del dueño (2026-09-05, con recomendaciones del investigador):

| # | Respuesta (fecha) |
|---|---|
| D-HB0 | **APROBADO acotado** (2026-09-05): descongelamiento parcial solo `SET_TEXT/PASTE` puntual desde burbuja; sin monitoreo continuo; teclado propio sigue prioritario |
| D-HB1 | **(a) OFF por defecto** (2026-09-05): opt-in explícito en Ajustes |
| D-HB2 | **(a) Jamás inyectar en contraseñas/`FLAG_SECURE`** (2026-09-05): solo clipboard neutro |
| D-HB3 | **(a) Sí fallback `PASTE`** (2026-09-05) tras `SET_TEXT=false` |
| D-HB4 | **(a) Intento tolerante en Termux** (2026-09-05): un IPC barato, si null → clipboard; sin prometer magia en terminal |
| D-HB5 | **(b) Snackbars distintos por camino** (2026-09-05): `Insertado en el campo` / `Pegado` / `Copiado al portapapeles` |
| D-HB6 | **(a) Mismo routing en isla y clásica** (2026-09-05) |
| D-HB7 | **(a) Sideload GitHub + texto honesto** (2026-09-05); declaración Play queda backlog |

---

## 7. Plan por hitos

> Convenciones heredadas: un hito a la vez, commits chicos en español, editar nativo directo en `voice_bubble_stt/android/` + `app_source/` para Dart (regla §9.2-1), push → ritual CI §9.4 → APK al dueño → prueba en dispositivo → marcar casillas.

---

### HB0 — Contrato documental (bloqueante, ~media sesión)

**Objetivo**: dejar el descongelamiento parcial por escrito antes de codear (misma lección que T0/CB0).

Tareas:

1. Registrar D-HB0…D-HB7 en §6.
2. `AGENTS.md` §8 + Estado: reescribir "Hito 4 CONGELADO" como "Hito 4 HÍBRIDO aprobado (fecha): excepción acotada a inyección puntual burbuja; prohibido monitoreo continuo, prohibido log de contenido, prohibido inyectar en contraseñas".
3. `README.md`: prometer por escrito los 3 modos (IME → A11y → clipboard) + sección Termux honesta (§5.4) + privacidad burbuja.
4. `INSTALL.md`: guía de activación (burbuja sola vs teclado propio vs ambos) + aviso Play Protect esperado + guía batería/OEM existente.
5. `design.md` §12 si menciona Hito 4: tokens de snackbars del §D-HB5 (reutilizar existentes, sin inventar componentes).
6. `docs/contract-keys.txt`: NO tocar en HB0 — el guard de paridad (`test_master_suite.py:test_contract_keys`) exige que cada clave exista en Kotlin. La clave `kb_bubble_a11y_inject_enabled` (bool, default false según D-HB1) se añade en HB3 junto con su código Dart+Kotlin.
7. `res/values/strings.xml`: borrador honesto de `accessibility_service_name/desc` ("pegar dictados en el campo enfocado al usar otros teclados; no lee ni guarda pantalla").

Criterios de aceptación:

- [x] D-HB0…D-HB7 respondidas y fechadas (2026-09-05, §6).
- [x] Los documentos reflejan la excepción (AGENTS, README, INSTALL, design §12, `strings.xml` desc) — locales, SIN push por pedido del dueño.
- [x] Ninguna línea Kotlin/Dart de esta funcionalidad escrita todavía (solo texto de `strings.xml`, sin lógica; `contract-keys.txt` intacto por el guard de paridad).

---

### HB1 — Núcleo nativo de inyección (Kotlin, ~1–2 ciclos CI)

**Objetivo**: `VoiceBubbleAccessibilityService` capaz de inyectar puntualmente, sin tocar la burbuja todavía.

Tareas:

1. `accessibility_service_config.xml`: `canRetrieveWindowContent="true"`, `eventTypes="typeViewFocused|typeWindowContentChanged"`, mantener `canPerformGestures="true"` (trackpad intacto), `feedbackType="feedbackGeneric"`, `notificationTimeout` corto existente. Validar longitudes hex si se tocan recursos (lección §9.1-19).
2. Nueva API interna (nombres propuestos):
   ```
   fun injectTextInFocusedField(text: String): InjectResult
   enum InjectResult { NO_SERVICE, DISABLED_BY_USER, NO_FOCUS, PASSWORD_BLOCKED, SET_TEXT_OK, PASTE_OK, FAILED_NEEDS_CLIPBOARD }
   ```
   - `instance ?: NO_SERVICE`; switch propio `flutter.kb_bubble_a11y_inject_enabled ?: DISABLED_BY_USER`.
   - `rootInActiveWindow ?: NO_FOCUS` (cerrar con try/finally/recycle donde aplique; jamás guardar el nodo).
   - `node = root.findFocus(FOCUS_INPUT) ?: NO_FOCUS`; si `!node.isEditable → NO_FOCUS`.
   - Bloqueo contraseñas: `node.inputType & TYPE_TEXT_VARIATION_PASSWORD != 0` o `isPassword()` → `PASSWORD_BLOCKED` (reutilizar criterio `isPasswordInput()` del teclado como referencia, sin importar UI).
   - Intento 1 `ACTION_SET_TEXT` con `ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE` → si `true`, `SET_TEXT_OK`.
   - Intento 2 (si D-HB3=a): clipboard `setPrimaryClip` + `performAction(ACTION_PASTE)` → `PASTE_OK` / `FAILED_NEEDS_CLIPBOARD`.
   - CERO `Log` con `text`, CERO lectura del contenido previo (`node.text` jamás se lee ni se guarda).
3. `onAccessibilityEvent` sigue vacío (sin suscripción continua): la consulta ocurre solo bajo llamada explícita post-transcripción. Documentarlo en comentario para auditoría.
4. Imports exactos contra developer.android.com primero (`AccessibilityNodeInfo`, `Bundle`, `ClipData`; lecciones §9.1-18/22/23).

Criterios de aceptación:

- [ ] Con DigiWord + accesibilidad ON + switch ON, `injectText` retorna `SET_TEXT_OK` en WhatsApp/Chrome/Notes (verificación manual §HB4).
- [ ] En contraseña/`FLAG_SECURE` retorna `PASSWORD_BLOCKED` y no modifica el campo.
- [ ] Sin servicio / sin foco retorna el código honesto correspondiente, nunca crash (parseo tolerante estilo repo).
- [ ] `grep -rn "Log\."` sobre el diff: cero líneas con contenido inyectado.
- [ ] CI verde (el Kotlin compila en `build apk --split-per-abi`).

---

### HB2 — Routing híbrido de la burbuja (Dart + canal, ~1–2 ciclos CI)

**Objetivo**: la burbuja (clásica e isla) elige el mejor camino sin que el usuario piense.

Tareas:

1. `MainActivity.kt` (canal `floating_bubble` o `keyboard` — definir uno solo): exponer `injectViaAccessibility(text): String` que devuelva el `InjectResult.name`, o `Boolean` si se prefiere mínimo. Reutilizar `commitFromExternal` existente para el camino IME (no duplicar).
2. `keyboard_service.dart` / `floating_bubble_service.dart`: envoltorio `tryInjectViaAccessibility(text)` tolerante (try/catch → null).
3. `home_screen.dart` `_pasteOrCopyFeedback(text)` → nueva `_pasteHybrid(text)`:
   ```
   1. pasted = commitText() → si true: feedback D-HB5 (Insertado) + fin.
   2. si switch ON: res = injectViaAccessibility() →
      SET_TEXT_OK/PASTE_OK: feedback Pegado + fin.
      PASSWORD_BLOCKED/NO_FOCUS/etc: caer a 3 con mensaje honesto.
   3. Clipboard.setData + pushHistoryEntry (orden actual) + Snackbar Copiado.
   ```
   Preservar `pushHistoryEntry` y `updateBubbleState` en el orden actual (`:405-409`).
4. `DynamicIslandController.kt:1109` modal historial: mismo orden (primero `commitFromExternal`, luego accesibilidad si D-HB6=a, luego clipboard). Sin divergencias.
5. Textos ES/EN según D-HB5 (patrón `spanishMode`), sin animaciones nuevas (Reduced Motion OK).

Criterios de aceptación:

- [ ] Nuestro teclado activo → camino 1, sin pedir accesibilidad, en Termux y Acode.
- [ ] DigiWord + accesibilidad → camino 2 en WhatsApp/Gmail/Chrome; fallback clipboard cuando el destino lo rechaza.
- [ ] Sin accesibilidad → camino 3 idéntico al actual (regresión cero).
- [ ] Contraseña → nunca camino 2, siempre clipboard neutro.
- [ ] CI verde + APK probado por el dueño en ambos teclados.

---

### HB3 — Ajustes y puente Flutter↔Kotlin (~1 ciclo CI)

**Objetivo**: el dueño controla y entiende cada modo.

Tareas:

1. `storage_service.dart`: `loadBubbleA11yInjectEnabled/saveBubbleA11yInjectEnabled` (bool, default false) patrón `:49-90`.
2. `settings_screen.dart` (tab Teclado o Burbuja — definir en HB0): `SwitchListTile` "Pegar dictados de la burbuja en el campo (otros teclados)" + subtítulo honesto (requiere Accesibilidad, no lee pantalla, no funciona en contraseñas, en Termux prefiere nuestro teclado) + fila de estado (Concedida/No concedida) + botón "Abrir Ajustes de Accesibilidad" (usa `isAccessibilityGranted/openAccessibilitySettings` ya existentes).
3. Kotlin: lectura tolerante `flutter.kb_bubble_a11y_inject_enabled` en el chequeo HB1 (cache por llamada, sin persistir texto).
4. `docs/contract-keys.txt` cerrado si quedó fuera de HB0.
5. Tests Dart con superficie alta (lecciones §9.1-17/21): render, toggle, persistencia, defaults; import material explícito (§9.2-2).

Criterios de aceptación:

- [ ] Switch persiste; instalación limpia = OFF.
- [ ] Estado refleja el sistema real al volver a la pantalla (releer al `resume`, precedente historial K-lote).
- [ ] Con switch OFF no hay ninguna llamada a `findFocus` (revisión + matriz manual).
- [ ] Suite Dart 100% verde (regla del dueño §9.2-11).

---

### HB4 — Auditoría de privacidad, matriz real y entrega (~1 ciclo CI)

**Objetivo**: sello K5 antes de cerrar.

Tareas:

1. Auditoría: `grep -rn "Log\.\|node.text\|getText()" voice_bubble_stt/android/.../VoiceBubbleAccessibilityService.kt` → cero lecturas de contenido previo; ningún camino escribe lo inyectado en disco/prefs/archivo.
2. i18n ES/EN completo de strings nuevos (servicio + Ajustes + snackbars).
3. Matriz manual en dispositivo físico (marcar una por una):
   - [ ] DigiWord + burbuja clásica → WhatsApp / Gmail / Chrome / Keep.
   - [ ] DigiWord + isla/píldora → mismo set.
   - [ ] Nuestro teclado + burbuja → Termux / Acode (camino IME, sin accesibilidad).
   - [ ] Campo contraseña (Chrome login / app banco) → bloqueo + clipboard neutro.
   - [ ] Destino que rechaza `SET_TEXT` → `PASTE_OK` o clipboard honesto.
   - [ ] Sin accesibilidad concedida → clipboard idéntico a hoy.
   - [ ] Switch propio OFF + accesibilidad ON → clipboard (sin consultas).
   - [ ] Rotación / cambio de app durante `PROCESSING` → sin commit en campo equivocado (espíritu AT-A1/generación: solo inyectar si el foco sigue válido al momento del callback).
   - [ ] Regresión: dictado teclado, snippets, trackpad gestures, historial FIFO-20.
4. Docs finales: `AGENTS.md` §9 fila si hubo lección; checklist firmado.

Criterios de aceptación:

- [ ] Matriz en verde en teléfono físico del dueño.
- [ ] Grep privacidad limpio.
- [ ] CI verde + artefacto `voice-bubble-arm64-debug-apk-r<N>` entregado con enlace al run.

---

## 8. Riesgos y mitigaciones

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| 1 | **Privacidad**: `canRetrieveWindowContent=true` amplía superficie (lectura de ventanas) | Alta | Alto | Lectura puntual solo post-transcripción, sin `node.text`, sin logs, sin persistencia; opt-in doble (sistema + switch OFF por defecto); auditoría grep HB4; textos honestos en strings/Settings/README |
| 2 | Aviso Play Protect / escrutinio Play por Accessibility | Alta | Medio | `INSTALL.md` documenta el aviso como esperado; distribución sideload (D-HB7=a); si va a Play, backlog de declaración de asistencia motora |
| 3 | Expectativa "pega en Termux como WhisperFlow" | Alta | Medio | §5.4 honesto en UI/README: terminal no es EditText; para Termux se recomienda nuestro IME; degradación a clipboard sin crash |
| 4 | OEMs matan FGS / restringen overlay (Xiaomi, Samsung, Huawei) | Media | Medio | Guía batería por fabricante ya en `INSTALL.md` §5; `START_NOT_STICKY` + relanzado desde app (patrón actual) |
| 5 | Destinations raros (webviews, juegos, campos custom) rechazan ambos actions | Media | Bajo | Fallback clipboard honesto (D-HB3); no parchear por app; matriz documenta app-específicos |
| 6 | Regresión IME/trackpad/isla existentes | Baja | Alto | Hitos separados; camino IME intacto y prioritario; `canPerformGestures` preservado; regresión explícita en HB2/HB4 |
| 7 | Errores Kotlin solo visibles en CI | Media | Medio | Imports verificados contra developer.android.com antes de pushear (§9.1-18/22/23); YAML validado con python3-yaml si se toca workflow (§9.2-8); releer diff íntegro (§9.2-7) |
| 8 | Scope creep ("ya que leemos ventanas, hagamos X") | Media | Alto | Prohibición escrita en HB0/AGENTS: la excepción es SOLO inyección puntual burbuja; cualquier otro uso = nueva propuesta |
| 9 | Commit en campo equivocado tras cambio de app durante PROCESSING | Baja | Alto | Solo inyectar contra foco fresco al momento del callback; si `NO_FOCUS` → clipboard; espíritu AT-A1 |

---

## 9. Estrategia de tests

| Capa | Qué | Cómo | Dónde |
|---|---|---|---|
| Widget Dart | Switch nuevo: render, toggle, persistencia, default OFF | `SharedPreferences.setMockInitialValues`; import material explícito; superficie alta; `pump()` puntual | CI `flutter test` |
| Kotlin | Sin unit puro de `AccessibilityNodeInfo` en este proyecto | Relectura razonada del diff + compilación en CI como red de tipos | `build apk --split-per-abi` en Actions |
| Manual (fuente de verdad) | Matriz HB4 en ambos teclados + ambas burbujas | Guiones checklisteados en teléfono físico del dueño | Dispositivo |
| Auditoría | Cero logs/contenido, cero persistencia, bloqueo contraseñas | grep + revisión diff en MODO-LOOP (batería final) | Local/loop |

Mocks: SharedPreferences en Dart; canal `flutter/platform` no interviene (todo nativo), no aplica mock SystemChannels.

---

## 10. Estimación

- **5 hitos** (HB0–HB4), ≈ 4–6 ciclos CI (push→build→prueba física).
- Ideal en MODO-LOOP: tarjetas por archivos disjuntos (`accessibility_service_config.xml` + `VoiceBubbleAccessibilityService.kt` en serie; `settings_screen.dart` + `storage_service.dart` en serie; `MainActivity.kt` + `home_screen.dart` con cuidado por canales compartidos); auditor con contexto limpio ≥9.0.

---

## 11. Registro del loop

> (Vacío — se completa al ejecutar en MODO-LOOP.)

| Tarjeta | Escritor | Ronda | Nota del auditor | Estado |
|---|---|---|---|---|

---

> Última actualización: 2026-09-05 — D-HB0…D-HB7 aprobadas con recomendaciones; HB0 en ejecución (contrato documental, sin push por pedido del dueño).
> Próximo paso: cerrar HB0 → HB1 núcleo Kotlin.
