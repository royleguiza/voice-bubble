# Portapapeles del Teclado (Clipboard Tray) — Plan de Ejecución

> **Estado**: ✅ APROBADO POR EL DUEÑO (2026-08-24, decisiones D-C0…D-C6 cerradas — ver §5). NADA implementado aún.
> **Fecha**: 24 de agosto de 2026
> **Origen**: pedido directo del dueño: poder copiar en otras apps (token de GitHub, usuario y clave de BD) y pegarlos uno por uno desde el teclado en un `.env` o campo de texto.
> **Precedentes internos**: estructura de `teclado-voice.md` (decisiones → arquitectura → hitos CB*); patrón UI de la ventana emergente de historial (`showHistoryPopup`, `VoiceKeyboardService.kt:1535`); puente de preferencias Flutter↔Kotlin del lote K2.1/pulido visual.

---

## 1. Qué vamos a construir (visión en una página)

Una **bandeja de portapapeles dentro del teclado VoiceBubble**: cuando el usuario copia
texto en OTRA app (Chrome, un gestor de contraseñas, WhatsApp) y luego abre el teclado,
puede desplegar una bandeja con los últimos clips capturados y **insertarlos uno por uno**
en el cursor con un toque.

- **NO captura** lo tecleado ni lo transcrito (eso sigue siendo sagrado e intocable).
- Es un *tray/historial* tipo Gboard pero enfocado a datos copiados FUERA del teclado.
- Acceso: tecla `📋` en la barra inferior (ocultable desde Ajustes, mismo patrón que
  `</>` y ES/EN), que abre una ventana emergente idéntica en espíritu a la de historial
  de dictados (`showHistoryPopup`).
- Opt-in: **apagado por defecto**, se activa con un switch en Ajustes.

### Por qué esto amplía el alcance (decisión explícita requerida)

`AGENTS.md` §8 prohibe hoy mismo: *"❌ Features de teclado genérico fuera de alcance:
autocorrector predictivo, temas, emojis, glide typing, **portapapeles multinivel**"*.
`design.md` §12 repite esa prohibición. Esta funcionalidad cae —literalmente— en la
categoría vetada. La app hace UNA cosa (dictar y pegar voz); la bandeja de portapapeles
es una SEGUNDA cosa (pegar texto copiado fuera). Solo procede si el dueño aprueba:

1. Excepción escrita al anti-patrón §8 (acotada a ESTE feature, no reabre la puerta a
   temas/emojis/autocorrector).
2. Actualización de `AGENTS.md`, `design.md` §12 y README con la nueva promesa de
   privacidad (Hito CB0).

Sin esa aprobación formal, este plan queda archivado.

---

## 2. Historia de usuario

> **Como** desarrollador que usa el teléfono para trabajar,
> **quiero** copiar en otra app un token de GitHub o un usuario/clave de base de datos,
> **y luego** abrir el teclado VoiceBubble en mi editor y pegar cada valor con un toque,
> **para** completar un `.env` (o cualquier formulario) sin alternar ventanas ni escribir
> a mano datos largos y propensos a error.

Flujo feliz:

1. El dueño activa "Portapapeles" en Ajustes (una vez).
2. Copia `ghp_xxxx` en Chrome → copia `DB_USER=admin` en el gestor de contraseñas.
3. Abre Acode/Termux con el teclado VoiceBubble → toca `📋` → ve los dos clips →
   toca el primero (se inserta en cursor) → mueve el cursor → toca el segundo.

---

## 3. Alcance

### SÍ incluye

| # | Capacidad |
|---|---|
| 1 | Captura de clips de TEXTO PLANO copiados en otras apps, **solo mientras el teclado tiene el foco de entrada** (ver §4.1 — restricción de plataforma innegociable) |
| 2 | Bandeja emergente con las últimas **20** entradas FIFO (mismo límite que todo el proyecto), dedup de contenido consecutivo idéntico |
| 3 | Inserción en cursor vía `commitText` (soporta multilínea), borrar ítem individual, vaciar bandeja |
| 4 | Vista previa enmascarada (`••••`) para clips marcados sensibles por la app origen |
| 5 | Switch ON/OFF en Ajustes + switch de tecla visible (puente `flutter.`↔Kotlin existente) |
| 6 | i18n ES/EN, Liquid Glass nativo (tokens existentes), Reduced Motion, targets ≥44dp |
| 7 | Retención **volátil en memoria** con expiración por antigüedad (TTL, decisión D-C1) |

### NO incluye (fuera de alcance, explícito)

- ❌ Imágenes, URIs, intents ni HTML rico: solo `MIMETYPE_TEXT_PLAIN`.
- ❌ Persistencia del contenido del portapapeles en disco (ni preferencias, ni SQLite, ni archivos).
- ❌ Pinning/fijado de clips (posible v2 si el dueño lo pide después).
- ❌ Captura en background real (imposible por diseño de Android 10+, ver §4.1).
- ❌ Sincronización entre dispositivos, traducción, sugerencias, nada ajeno al tray.
- ❌ Cualquier registro en Log del contenido capturado (jamás, ni debug).
- ❌ Cambiar el dictado, snippets, capas existentes o el flujo de la burbuja.

---

## 4. Viabilidad técnica verificada (investigación contra developer.android.com)

### 4.1 Restricción de acceso al portapapeles (Android 10+) — VERIFICADO, condiciona el diseño

- Doc oficial: [Privacy changes in Android 10](https://developer.android.com/about/versions/10/privacy/changes) → *"Unless your app is the default input method editor (IME) or is the app that currently has focus, your app cannot access clipboard data on Android 10 or higher."*
- Javadoc de [`ClipboardManager.getPrimaryClip()`](https://developer.android.com/reference/android/content/ClipboardManager): *"If the application is not the default IME or does not have input focus this return null"* (idéntico para `hasPrimaryClip()` y `getPrimaryClipDescription()`).

**Traducción para nuestro caso**: `VoiceKeyboardService` ya es un IME declarado
(`VoiceKeyboardService.kt:60`). Cuando es el teclado **seleccionado** y su ventana tiene
el foco (campo abierto, teclado visible), puede leer el portapapeles global —incluido lo
copiado en otras apps—. Cuando el teclado está oculto o no es el IME activo, las lecturas
devuelven `null`: no hay workaround legítimo ni hace falta pedirlo.

### 4.2 Escucha de clips nuevos: `OnPrimaryClipChangedListener` — VERIFICADO con matiz crítico

- [`addPrimaryClipChangedListener`](https://developer.android.com/reference/android/content/ClipboardManager#addPrimaryClipChangedListener(android.content.ClipboardManager.OnPrimaryClipChangedListener)) registra un callback **global**: se dispara aunque quien copió sea otra app.
- PERO el callback solo avisa de que *algo cambió*: la lectura de datos sigue sujeta a §4.1. Con el teclado oculto, el listener dispara y `getPrimaryClip()` devuelve `null`.
- Costo de batería: despreciable (callback push del sistema, cero polling). Se registra en `onCreate()` del servicio y se libera en `onDestroy()`.

**Modelo de captura resultante (híbrido, sin sorpresas):**

1. **Perezosa**: en `onStartInputView` (ventana recién enfocada) se lee el clip vigente una vez y se agrega si es nuevo (dedup por hash de contenido).
2. **En vivo**: mientras la ventana del IME está mostrada, el listener captura cada cambio nuevo (cubre copiar entre campos con el teclado abierto).
3. Fuera de foco: nada se intenta leer (ahorra trabajo y evita comportamientos raros entre ROMs).

### 4.3 Toast de Android 13+ ("app pegó del portapapeles") — VERIFICADO, impacto bajo con nuestro modelo

- Doc oficial: [Copy and paste](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste) → en Android 12+ el sistema suele mostrar un toast `"APP pasted from your clipboard"` cuando se llama `getPrimaryClip()`. Exenciones documentadas: clips de la propia app, accesos repetidos a clips del MISMO app origen (solo avisa la primera vez por app origen) y lecturas de solo-metadatos (`getPrimaryClipDescription()`).
- Impacto en un IME: cada **primera** lectura de un clip proveniente de una app distinta puede mostrar el toast sobre la app destino. Con el modelo de captura perezosa (§4.2, una lectura por apertura de campo + dedup), el ruido se reduce al mínimo práctico. Es comportamiento del sistema, no suprimible por API; se documenta al dueño como costo de transparencia aceptable (Gboard vive con lo mismo).

### 4.4 Flag `EXTRA_IS_SENSITIVE` — VERIFICADO, política propuesta en D-C2

- Doc oficial: [Copy and paste § Add sensitive content](https://developer.android.com/develop/ui/views/touch-and-input/copy-paste#SensitiveContent) y [Secure Clipboard Handling](https://developer.android.com/privacy-and-security/risks/secure-clipboard-handling): los apps marcan clips sensibles (contraseñas, tarjetas) con `ClipDescription.EXTRA_IS_SENSITIVE` (API 33+; literal `"android.content.extra.IS_SENSITIVE"` en API ≤32) para impedir su vista previa en claro.
- Lectura desde el cliente: `clip.description.extras?.getBoolean(...)` con fallback al literal para minSdk 28.
- Android 13+ además **borra automáticamente el clip primario tras ~1 hora** (comportamiento del sistema, [resumen](https://9to5google.com/2022/08/16/android-13-clipboard)): nuestro TTL no puede prometer más que eso.

### 4.5 Retención: comparativa de enfoques

| Enfoque | Pros | Contras | Veredicto |
|---|---|---|---|
| **Volátil en memoria del proceso** (lista Kotlin viva mientras el IME existe) + TTL | Privacidad máxima: muerte del proceso = cero rastro; cero superficie forense; cero esquema de BD; imposible filtrarse por backup | Se pierde al matar la app desde recientes/reinicio | ✅ **Propuesto** (coincide con el precedente interno: la ventana de historial vive solo en memoria, `VoiceKeyboardService.kt:1530`) |
| Persistente con TTL tipo Gboard (SQLite/prefs, clips 1 h, pinning) | Sobrevive reinicios; Gboard lo normaliza | Un portapapeles GLOBAL captura TODO lo que el usuario copia (contraseñas, OTPs, mensajes): persistirlo crea un depósito de secretos en disco; riesgo forense/backup; contradice "privacidad sagrada" | ❌ Descartado para v1 (requeriría decisión reversa del dueño) |

**Advertencia central de privacidad (repito porque es EL punto)**: una bandeja de
portapapeles global atrapa *todo*, incluidas contraseñas y códigos OTP que el usuario
nunca querría guardados. Mitigaciones estructurales del plan: opt-in OFF por defecto,
memoria volátil, TTL corto (D-C1), máscara de sensibles (D-C2), borrado individual y
total con un toque, y auditoría de cero-logs (CB4).

### 4.6 Encaje en el código existente (archivo:línea)

| Pieza nueva | Patrón del que parte | Referencia |
|---|---|---|
| `ClipboardTray.kt` (lógica pura: FIFO-20, dedup, TTL, máscara) | Estilo `SnippetStore.kt` pero SIN disco | `voice_bubble_stt/.../keyboard/SnippetStore.kt:37` |
| Tecla `📋` en barra inferior | Teclas `</>` / ES/EN / ☰ ocultables | `VoiceKeyboardService.kt:431-477` |
| Ventana emergente del tray | `showHistoryPopup` (PopupWindow, scroll, tope 40% pantalla, AT-A12) | `VoiceKeyboardService.kt:1535-1614`, cierre en `dismissPopup` `:2453` |
| Toque largo/borrado por ítem | Maquinaria `attachLongPress` | `VoiceKeyboardService.kt:2263` |
| Inserción en cursor | `commit(text)` → `currentInputConnection.commitText` | `VoiceKeyboardService.kt:757-760` |
| Detección de campo contraseña (para decidir D-C6) | `isPasswordInput` | `VoiceKeyboardService.kt:217-224` |
| Puente de preferencias `flutter.` | `loadKeyboardPrefs` / `terminalRowVisible` | `VoiceKeyboardService.kt:2469-2531`; lado Dart `storage_service.dart:49-90`; contrato `docs/contract-keys.txt` |
| Switch en Ajustes (tab Teclado) | `_buildKeyboardTab` con `SwitchListTile` | `app_source/lib/screens/settings_screen.dart:613-755` |
| Copia AL portapapeles ya existe (no confundir) | `copySnippetToClipboard` escribe, este plan LEE | `VoiceKeyboardService.kt:2209-2214` |

Nuevas claves de contrato propuestas (sumar a `docs/contract-keys.txt`):
`kb_clipboard_enabled` (bool, default false), `kb_clipboard_key_visible` (bool, default true).
Cero dependencias nuevas, cero permisos nuevos (el IME no necesita ninguno para el portapapeles),
impacto APK ≈ 0 (Kotlin plano + recursos existentes).

---

## 5. Decisiones abiertas (el dueño decide ANTES de ejecutar)

| # | Decisión | Opciones | Recomendación del investigador |
|---|---|---|---|
| D-C0 | ¿Aprobar la excepción al anti-patrón §8 ("portapapeles multinivel") y el alcance dual ampliado? | Aprobar / Archivar plan | Aprobar acotado: solo tray de texto plano, opt-in, volátil. Sin esto, no hay plan. |
| D-C1 | Retención/TTL de los clips en memoria | (a) Solo proceso vivo sin TTL · (b) Proceso vivo + TTL 60 min alineado con Android 13 · (c) Persistente (descartado §4.5) | **(b)** TTL 60 min + FIFO-20: borra solito lo sensible que quedó olvidado |
| D-C2 | Clips marcados `EXTRA_IS_SENSITIVE` | (a) Excluirlos del historial · (b) Capturarlos con vista previa enmascarada `••••` | **(b)**: excluirestos rompería el caso de uso central del dueño (gestores de contraseñas suelen marcar sus copias como sensibles). La bandeja los inserta igual; solo la vista previa va enmascarada |
| D-C3 | Estado por defecto del switch "Portapapeles" | ON / OFF | **OFF** (opt-in): coherente con "privacidad sagrada"; nadie captura clips globales sin pedirlo |
| D-C4 | Acceso a la bandeja | (a) Tecla dedicada `📋` ocultable · (b) Toque largo en otra tecla · (c) Ambos | **(a)**: precedentes claros (`</>`, `☰`), descubrible y apagable; el toque largo del 🎤 ya está tomado por el historial de dictados |
| D-C5 | ¿Permitir INSERTAR desde la bandeja en campos de contraseña? | (a) Sí · (b) No (bandeja oculta ahí, como mic/snippets) | **(a)**: pegar una clave EN un campo de contraseña ES el caso de uso del dueño; el sistema ya permite paste manual ahí. La regla existente prohíbe *dictado/snippets* (texto aprendido), no inserción explícita pedida por el usuario. La bandeja nunca aprende nada tecleado |
| D-C6 | ¿Bandeja compartida con la burbuja o solo teclado? | (a) Solo teclado · (b) También visible en la app principal | **(a)** solo teclado en v1: mínimo alcance, la app principal no toca contenido de portapapeles |

Respuestas registradas aquí al aprobar (estilo §11 de `teclado-voice.md`):

| # | Respuesta del dueño (fecha) |
|---|---|
| D-C0 | **APROBADO** (2026-08-24): excepción acotada al §8 — solo tray de texto plano, opt-in, volátil. |
| D-C1 | **(b)** (2026-08-24): TTL 60 min + FIFO-20 en memoria volátil. |
| D-C2 | **(b)** (2026-08-24): capturar clips sensibles con vista previa enmascarada; inserción igual. |
| D-C3 | **OFF** (2026-08-24): opt-in desde Ajustes. |
| D-C4 | **(a)** (2026-08-24): tecla dedicada 📋 ocultable desde Ajustes. |
| D-C5 | **(a)** (2026-08-24): permitir insertar desde la bandeja en campos de contraseña. |
| D-C6 | **Solo teclado** (2026-08-24): la app principal no muestra ni toca la bandeja. |

---

## 6. Plan por hitos

> Convenciones heredadas: un hito a la vez, commits chinos en español, editar SOLO
> `app_source/` y la carpeta nativa commiteada, push → monitorear CI (§9.4 AGENTS.md) →
> APK al dueño → prueba en dispositivo físico → marcar casillas.

---

### Hito CB0 — Contrato documental (bloqueante, ~media sesión)

**Objetivo**: dejar la excepción de alcance por escrito antes de codear (misma lección que T0).

Tareas:
1. Registrar respuestas D-C0…D-C6 del dueño en §5.
2. `AGENTS.md` §8: reescribir el anti-patrón como "portapapeles multinivel GENÉRICO
   fuera de alcance; EXCEPCIÓN aprobada (fecha): bandeja opt-in de texto plano, volátil,
   del teclado" + §5 reglas de privacidad nuevas (nunca logs de clips, nunca persistencia).
3. `design.md` §12: tokens/reglas de la bandeja (usa `kb_popup_bg`, `kb_menu_item`,
   máscara de sensibles, Reduced Motion) y quitar la mención absoluta.
4. `README.md`: promesa de privacidad del portapapeles (qué se captura, qué nunca).
5. `docs/contract-keys.txt`: sumar `kb_clipboard_enabled` y `kb_clipboard_key_visible`.

Criterios de aceptación:
- [ ] D-C0…D-C6 respondidas y fechadas en §5.
- [ ] Los cuatro documentos reflejan la excepción y quedan commiteados.
- [ ] Ninguna línea de código de esta funcionalidad fue escrita todavía.

---

### Hito CB1 — Núcleo nativo de captura (~1–2 ciclos CI)

**Objetivo**: lógica pura probada y gancho de captura funcionando, aún sin UI.

Tareas:
1. `keyboard/ClipboardTray.kt` SIN dependencias de Android (inyectable `Clock`):
   lista FIFO máx **20**, dedup de contenido consecutivo idéntico, expiración por TTL
   (según D-C1), marca `sensitive` por clip, `clear()` e `remove(id)`.
   Parseo tolerante estilo repo: cualquier error → bandeja vacía, JAMÁS crash en rutas del IME.
2. `VoiceKeyboardService.kt`: registro de `OnPrimaryClipChangedListener` en `onCreate`
   (+ liberación en `onDestroy`), captura perezosa en `onStartInputView`, captura en vivo
   solo con ventana mostrada (§4.2); filtro `MIMETYPE_TEXT_PLAIN` únicamente; lectura de
   extras `IS_SENSITIVE` con fallback al literal (minSdk 28).
3. Respeto del switch: captura inactiva si `kb_clipboard_enabled=false` (default OFF, D-C3).
4. PRIVACIDAD dura: ni `Log.d/i/e` ni cualquier salida con contenido del clip (auditoría grep en CB4).
5. Tests JUnit puros del núcleo (§7).

Criterios de aceptación:
- [ ] FIFO-20 y dedup verificados por JUnit en CI.
- [ ] Con el switch OFF no hay ninguna lectura del portapapeles (JUnit + revisión).
- [ ] Clip sensible llega a la bandeja con bandera `sensitive=true` (JUnit).
- [ ] Ningún `Log.` contiene contenido de clips (grep en diff).
- [ ] CI verde (analyze estricto + tests + APK).

Guion de verificación manual (dispositivo): copiar en Chrome → abrir campo con el
teclado → logcat personal muestra SOLO eventos sin contenido (opcional, sin Log en prod).

---

### Hito CB2 — UI del tray en el teclado (~2 ciclos CI)

**Objetivo**: tecla `📋` + ventana emergente operativa.

Tareas:
1. Tecla `📋` en `buildBottomBar` (peso 1f, `kb_key_alt`), ocultable vía
   `kb_clipboard_key_visible` (patrón `codeKeyVisiblePref`), con `contentDescription` i18n.
2. `showClipboardPopup(anchor)` clonando el patrón de `showHistoryPopup`: PopupWindow
   300dp, ScrollView con tope 40% de pantalla, separadores finos, Y jamás negativa (AT-A12),
   cierre al insertar o tocar afuera, `dismissPopup()` también en `onWindowHidden`/
   `onFinishInputView` (ya cableado).
3. Filas del tray: vista previa a 2 líneas (enmascarada `••••` si `sensitive`, según D-C2),
   timestamp relativo corto; tap = insertar en cursor vía `commit()` (multilínea OK);
   toque largo = mini-menú contextual (insertar / copiar de vuelta al portapapeles /
   eliminar ítem) reutilizando el patrón `showSnippetMenu`; acción "Vaciar bandeja" al pie.
4. Estado vacío elegante ("Sin elementos copiados todavía." / EN equivalente) + hint de
   primer uso explicando que solo entra lo copiado con el teclado abierto (§4.1).
5. Comportamiento en campos contraseña según D-C5 (si (a): tecla visible e inserción
   permitida; previews siempre enmascaradas ahí).
6. Reduced Motion: aparición directa sin rebote; háptico por el gate `haptic()` existente.

Criterios de aceptación:
- [ ] Copiar token en Chrome → abrir teclado en Acode → `📋` → el token aparece → tap lo inserta exacto.
- [ ] Caso de uso completo del dueño: token GitHub + usuario + clave pegados uno por uno en un `.env` de Acode.
- [ ] Dedup: copiar dos veces lo mismo no duplica fila.
- [ ] Clip sensible muestra `••••` en preview e inserta el contenido real.
- [ ] Vaciar bandeja deja estado vacío correcto; ítem individual se elimina.
- [ ] Claro/oscuro correctos con recursos existentes; targets ≥44dp; TalkBack labels.
- [ ] Regresión: dictado, snippets, capa código, shift/caps, insets — todo intacto.
- [ ] CI verde + APK probado por el dueño en dispositivo físico.

---

### Hito CB3 — Ajustes y puente Flutter↔Kotlin (~1 ciclo CI)

**Objetivo**: switches en la app, contrato de claves cerrado.

Tareas:
1. `storage_service.dart`: `loadKeyboardClipboardEnabled/saveKeyboardClipboardEnabled`
   y `loadKeyboardClipboardKeyVisible/saveKeyboardClipboardKeyVisible` (bool, defaults
   false/true) siguiendo el patrón de `storage_service.dart:49-90`.
2. `settings_screen.dart` tab Teclado: dos `SwitchListTile` nuevos con subtítulos claros
   (qué captura la bandeja, que no se guarda en disco, cómo vaciarla) — patrón
   `settings_screen.dart:655-696`; aplicar superficie alta en tests (lección §9.1-21).
3. Kotlin: lecturas tolerantes `flutter.kb_clipboard_enabled` / `flutter.kb_clipboard_key_visible`
   dentro de `loadKeyboardPrefs()` (cache por ciclo de campo, AT-A13).
4. Actualizar `docs/contract-keys.txt` si quedó fuera de CB0.

Criterios de aceptación:
- [ ] Los switches persisten entre aperturas (tests Dart).
- [ ] Instalación limpia = bandeja desactivada, tecla visible (defaults sensatos en cold start, anti-patrón AGENTS.md §8).
- [ ] Con switch ON, el teclado ya captura al abrirse el próximo campo (cadencia honesta AT-A13 documentada en el subtítulo).
- [ ] CI verde (analyze estricto + suite completa 100% verde, regla del dueño §9.2-11).

---

### Hito CB4 — Auditoría de privacidad, pulido y entrega (~1 ciclo CI)

**Objetivo**: sello de calidad estilo K5 antes de darlo por cerrado.

Tareas:
1. Auditoría de privacidad: `grep -rn "Log\." voice_bubble_stt/android/app/src/main/kotlin/` →
   cero coincidencias con contenido de clips; verificar que ningún camino escriba clips
   en disco (ni prefs, ni archivos, ni JSON compartido con la app — D-C6).
2. i18n ES/EN completo de todas las cadenas nuevas del teclado.
3. Matriz manual en dispositivo: copia desde Chrome / gestor de contraseñas / WhatsApp /
   Termux; teclado oculto durante la copia vs visible; rotación con popup abierto;
   proceso muerto desde recientes → bandeja vacía (volatilidad verificada).
4. Verificación del toast Android 13 en dispositivo del dueño: documentado como
   comportamiento esperado, sin sorpresas.
5. Docs finales: AGENTS.md §9 lecciones si las hubo; checklist firmado por el dueño.

Criterios de aceptación:
- [ ] Grep de privacidad limpio (contenido de clips jamás en logs).
- [ ] Volatilidad comprobada: reinicio/proceso muerto = bandeja vacía.
- [ ] Suite CI completa verde + APK arm64 entregado.
- [ ] Dueño verifica el caso de uso real (.env con credenciales) en su teléfono.

---

## 7. Estrategia de tests

| Capa | Qué se prueba | Cómo | Dónde corre |
|---|---|---|---|
| JUnit (Kotlin puro) | `ClipboardTray`: FIFO-20, dedup, TTL/expiración, máscara `sensitive`, `clear/remove`, parseo tolerante | Clase sin Android + `Clock` inyectable; paso `testDebugUnitTest` de Gradle agregado al workflow (runner ubuntu ya tiene JDK 17) | GitHub Actions (no hay runner local — AGENTS.md §6) |
| Widget tests Dart | Dos switches nuevos: render, toggle, persistencia, defaults (false/true) | `SharedPreferences.setMockInitialValues` (precedente lección §9.1-7); import material explícito (§9.2-2); superficie alta física (§9.1-16/17/21); `pump()` puntual si hay animaciones (§9.1-14) | CI (flutter test) |
| Integración Kotlin (manual) | Listener + foco + toast A13 + ROM quirks | Guiones CB2/CB4 en el teléfono físico del dueño | Dispositivo |
| Auditoría | Cero logs de contenido, cero persistencia | grep + revisión de diff en MODO-LOOP (batería final §34 MODO-LOOP.md) | Local/loop |

Mocks necesarios: SharedPreferences en Dart; en JUnit nada externo (clase pura).
El canal `flutter/platform` NO interviene (todo es nativo Kotlin), así que no aplica el
mockeo de SystemChannels.

---

## 8. Riesgos y mitigaciones

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|--------|-------|---------|------------|
| 1 | **Privacidad**: la bandeja global captura TODO (contraseñas, OTPs) | Alta | Alto | Opt-in OFF (D-C3), memoria volátil, TTL (D-C1), máscara sensibles (D-C2), vaciado total a un tap, cero logs auditados, nunca persistencia. Documentado en README |
| 2 | Toast Android 13 "pegó del portapapeles" asusta/algorritmo ruidoso | Media | Medio | Captura perezosa (1 lectura por apertura de campo) + dedup → mínimas lecturas; exención de repetición por app origen (§4.3); se explica al dueño |
| 3 | Expectativa errónea: "captura con el teclado cerrado" | Alta | Medio | Modelo §4.2 documentado en UI (hint) y README: la plataforma lo impone; el flujo del dueño (copiar → abrir editor → pegar) funciona perfecto |
| 4 | Errores de Kotlin visibles solo en CI | Media | Medio | Kotlin plano, imports exactos contra developer.android.com (lecciones §9.1-18/22/23), commits chicos, releer diff (§9.2-7) |
| 5 | Regresión en teclado/burbuja existentes | Baja | Alto | Hitos separados, regresión explícita en criterios de CB2/CB4, nada del dictado se toca |
| 6 | Batería por el listener | Muy baja | Bajo | Callback push del sistema (sin polling), registrado/liberado con el ciclo de vida del servicio |
| 7 | Tamaño APK | — | ≈ 0 | Sin dependencias ni recursos nuevos de peso (Kotlin + drawables existentes) |
| 8 | Scope creep hacia "Gboard" | Alta | Medio | Alcance NO-incluir §3 blindado; la excepción §8 es acotada y textual |
| 9 | Clips multilínea enormes rompen layout | Baja | Bajo | Preview a 2 líneas ellipsize END (patrón `:1561-1562`), inserción íntegra vía commitText (probado con snippets multilínea en K4) |

---

## 9. Estimación

- **5 hitos** (CB0–CB4), ≈ 5–6 ciclos de CI (push→build→prueba en dispositivo).
- Ejecutable idealmente en MODO-LOOP (tarjetas por archivos disjuntos; serie para
  `VoiceKeyboardService.kt`, `settings_screen.dart`, `storage_service.dart`).

---

## 10. Registro del loop

> (Vacío — se completa cuando el dueño apruebe y se ejecute en MODO-LOOP.)

| Tarjeta | Escritor | Ronda | Nota del auditor | Estado |
|---|---|---|---|---|

---
---

> Última actualización: 2026-08-24 — plan generado por investigación (OpenCode).
> Próximo paso: dueño responde D-C0…D-C6 → CB0.
