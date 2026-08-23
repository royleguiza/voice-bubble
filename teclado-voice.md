# Teclado Voice — Plan de Ejecución Completo

> **Estado**: ✅ INVESTIGACIÓN VERIFICADA · ✅ APROBADO POR EL DUEÑO (2026-08-22): integra el plan general desde la posición del Hito 4 (que queda congelado) · ⏳ Pendiente de ejecución (arranca con T0)
> **Origen**: investigación de factibilidad de agosto 2026 (resumen en §2, evidencia en §12).
> **Alcance**: convertir VoiceBubble STT en una app **dual**: conserva la burbuja flotante
> tal como está hoy y añade un **teclado del sistema Android** con dictado por voz
> (español/inglés) y herramientas para escribir código y comandos.
>
> ⚠️ Este documento NO modifica aún `plan.md` (burbuja). La integración de ambos planes
> se hará después de aprobar este. Antes de empezar K1 hay que actualizar
> `README.md`, `design.md` y `AGENTS.md` (hito T0).

---

## 1. Qué vamos a construir (visión en una página)

La misma app de siempre, instalada con el mismo APK, ofrecerá **dos formas de dictar**:

1. **Modo burbuja** (ya existe): burbuja flotante encima de cualquier app.
2. **Modo teclado** (nuevo): el usuario puede elegir "VoiceBubble Teclado" como su
   teclado del sistema. Ese teclado tendrá:
   - Letras normales QWERTY en español e inglés (tecla para cambiar de idioma).
   - **Capa código**: llaves, corchetes, paréntesis, símbolos raros (`\ | & $ # ~ ^`),
     comillas y backticks, todo accesible sin desplazamientos eternos.
   - **Fila terminal**: TAB, ESC, CTRL, ALT y flechas — para usar Termux de verdad.
   - **Botón de micrófono**: dicta y el texto aparece donde esté el cursor, usando los
     mismos motores de voz de la app (nube con tu API key ahora; local offline más adelante).
   - **Snippets/comandos guardados**: frases o comandos que usás seguido (ej.
     `codex "`, `gemini -p "`, comandos git largos) se guardan una vez desde los
     Ajustes de la app y luego se insertan con un toque desde el teclado.

Público objetivo: gente que programa o usa agentes de IA desde el teléfono.

---

## 2. Veredicto de factibilidad (resumen de la investigación)

| Pregunta | Respuesta |
|---|---|
| ¿Una app puede tener burbuja Y ser teclado a la vez? | ✅ Sí. Son piezas independientes dentro del mismo APK; ya declaramos varias piezas parecidas (la burbuja es una). |
| ¿El teclado puede dictar por voz? | ✅ Sí. Gboard lo hace; existen teclados enteros dedicados a voz (FUTO Voice Input usa Whisper local; Kõnele usa el reconocedor del sistema). |
| ¿Se puede hacer ese teclado con Flutter? | ❌ No de forma práctica: Android exige que el teclado sea una pieza nativa (Kotlin). Embeber Flutter dentro duplicaría el motor (~100 MB extra de RAM en un teléfono de 3.6 GB). → **UI nativa Kotlin ligera**. |
| ¿Rompe nuestro pipeline de CI? | ❌ No. La carpeta nativa ya vive commiteada en el repo desde el Hito 3 (`FloatingBubbleService.kt`); el scaffold solo corre si falta esa carpeta, así que nunca pisa nada nuevo. |
| ¿Funciona en Termux? | ✅ Sí. El propio Termux documenta cómo los teclados de terceros le envían CTRL/TAB/ESC; Hacker's Keyboard es el ejemplo clásico y seguiremos exactamente esos caminos. |
| ¿Permisos nuevos? | Solo el permiso especial `BIND_INPUT_METHOD` (lo firma el sistema, no pide nada al usuario); el resto (micrófono, internet, notificaciones) ya están declarados. |
| Conclusión | **FACTIBLE.** Riesgo principal = iteración lenta (cada prueba requiere compilar en GitHub e instalar a mano) y errores de Kotlin detectados solo en CI. |

Precedentes que validan cada pieza (detalle en §12):
- **CodeBoard** — teclado de código con snippets (open source, MIT). Demanda comprobada.
- **Hacker's Keyboard / Unexpected Keyboard** — símbolos y teclas terminales en móvil.
- **FUTO Voice Input / Kõnele** — dictado dentro de un teclado, incluso offline.
- **Termux** — compatibilidad explícita con teclados externos vía eventos estándar.

---

## 3. Decisiones tomadas (cerradas salvo indicación)

| # | Decisión | Valor elegido |
|---|----------|---------------|
| D1 | Alcance | App dual: burbuja (intacta) + teclado del sistema opcional |
| D2 | Tecnología del teclado | Nativo Kotlin, sin Flutter dentro del teclado |
| D3 | Motor de voz inicial | Nube propia (misma API key Groq/OpenAI que ya usa la app) |
| D4 | Motor local Whisper en teclado | Postergado (fase futura, tras resolverlo para la burbuja) |
| D5 | Idiomas | Subtipos español (es-ES) e inglés (en-US) con tecla de alternancia |
| D6 | Snippets v1 | Texto plano multilínea; se crean/editan en los Ajustes de la app |
| D7 | Ingreso de la API key | **Manual**: el usuario pega su API key de Groq/OpenAI en Ajustes (flujo actual, sin cambios para la burbuja). Los Ajustes escriben además una copia espejo en las preferencias privadas de la app —inaccesibles para otras apps— para que el teclado pueda usarla sin duplicar configuración. |
| D8 | Nombre visible | "VoiceBubble Keyboard" (etiqueta del teclado en Ajustes) — **confirmado por el usuario** |
| D9 | Snippets multi-app (abrir Codex/Grok/Termux) | Opcional en K4, recién después del CRUD básico |

> **Confirmación del dueño (22-08-2026)**: D1–D8 aprobadas tal como figuran arriba.
> D9 queda como opcional dentro de K4. Cualquier cambio sobre esta tabla = actualizar también AGENTS.md §2.

---

## 4. Arquitectura de la solución

```
┌────────────────────────── UN APK, UN PROCESO ──────────────────────────┐
│                                                                        │
│  Flutter (Dart)                    Nativo (Kotlin)                     │
│  ┌────────────────────┐            ┌─────────────────────────────┐     │
│  │ MainActivity       │◄─canal───►│ FloatingBubbleService       │     │
│  │ Home / Settings    │ (Hito 3)  │ (burbuja, intacto)          │     │
│  │ CRUD de snippets   │           ├─────────────────────────────┤     │
│  │ Ajustes de voz     │           │ VoiceKeyboardService (NUEVO)│     │
│  └─────────┬──────────┘           │  · teclado visual por capas │     │
│            │                      │  · botón micrófono → nube   │     │
│            │ escribe/lee          └──────────────┬──────────────┘     │
│            ▼                                     │ lee                 │
│  ┌──────────────────────────────────────────────▼──────────────┐      │
│  │ Preferencias privadas de la app (compartidas Dart↔Kotlin)   │      │
│  │  · voice_snippets_v1 (JSON)   · vb_stt_provider/key/url     │      │
│  │  · historial FIFO-20          · ajustes de teclado           │      │
│  └─────────────────────────────────────────────────────────────┘      │
└───────────────────────────────────────────────────────────────────────┘
```

Principios:

1. **Un solo lugar para los datos**: preferencias privadas del paquete. Flutter las
   escribe (Ajustes) y Kotlin las lee (teclado). Sin bases de datos nuevas.
2. **El teclado no tiene cerebro propio**: toda configuración se hace desde la pantalla
   de Settings que ya existe.
3. **Regla de oro del micrófono**: si la burbuja está grabando, el teclado no graba
   (y viceversa). Un flag en memoria del proceso + audio focus lo garantizan.
4. **Campos de contraseña**: el teclado detecta campos seguros y desactiva dictado,
   snippets y cualquier sugerencia ahí. Nunca aprender ni retener texto de esos campos.

### Archivos que tocará este proyecto

**Nuevos (carpeta nativa, commiteada):**

| Archivo | Para qué |
|---|---|
| `voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt` | El servicio del teclado (ciclo de vida, inserción de texto, dictado) |
| `…/keyboard/KeyboardLayoutController.kt` | Construcción de las capas de teclas (letras/código/snippets) |
| `…/keyboard/SpeechToTextClient.kt` | Grabación WAV + llamada a Groq/OpenAI desde Kotlin |
| `…/keyboard/SnippetStore.kt` | Lectura/escritura de snippets y settings compartidos |
| `voice_bubble_stt/android/app/src/main/res/xml/method.xml` | Registro del teclado ante el sistema + subtipos es/en |
| `voice_bubble_stt/android/app/src/main/res/layout/keyboard_input_view.xml` (+ variantes mínimas) | Diseño visual de las capas |

**Modificados:**

| Archivo | Cambio |
|---|---|
| `voice_bubble_stt/android/app/src/main/AndroidManifest.xml` | Declaración del servicio de teclado (+ `<queries>` solo si D9 avanza) |
| `.github/workflows/android.yml` | Guards defensivos de archivos nuevos (§5) |
| `app_source/lib/models/*` | Modelo Snippet (id, nombre, contenido, orden) |
| `app_source/lib/services/storage_service.dart` | CRUD de snippets + espejo de credenciales (D7) |
| `app_source/lib/screens/settings_screen.dart` | Sección "Teclado": lista de snippets, estado de habilitación, guía de activación |
| `app_source/test/*` | Tests de lógica de snippets y del contrato JSON |
| `README.md` / `design.md` / `AGENTS.md` | Hito T0: alcance dual, tokens del teclado, anti-patrones nuevos |

---

## 5. Cambios al pipeline de CI

No hay cambios estructurales: el scaffold no vuelve a correr (la carpeta existe) y la
sincronización solo toca `pubspec/lib/test`. Se agregan **guards defensivos**
(estilo lección §9.1-4 del AGENTS.md) justo antes del build:

```yaml
- name: Guard archivos de teclado presentes
  run: |
    test -f voice_bubble_stt/android/app/src/main/res/xml/method.xml \
      || { echo '::error::falta method.xml'; exit 1; }
    grep -q 'VoiceKeyboardService' voice_bubble_stt/android/app/src/main/AndroidManifest.xml \
      || { echo '::error::IME no declarado en manifest'; exit 1; }
```

Ritual por push (ya obligatorio según AGENTS.md §9.4): monitorear Actions hasta
`completed`, diagnosticar fallos leyendo jobs/steps, informar Run ID + artefacto.

Validación previa obligatoria del YAML del workflow con python3-yaml (regla §9.2-8).

---

## 6. Plan por hitos

> Convenciones heredadas de `plan.md`: un hito a la vez, commits chicos en español,
> push → monitorear CI → instalar APK → probar en el teléfono físico → marcar casillas.
> Cada hito termina con analyze estricto verde, tests verdes y APK descargable.

---

### Hito T0 — Documentación de alcance (bloqueante, ~1 sesión)

**Objetivo**: dejar el contrato escrito antes de escribir código.

Tareas:
1. Aprobación final de §3 por parte del usuario.
2. `README.md`: nueva sección "Modo Teclado" con spec funcional y promesa de privacidad.
3. `design.md`: tokens simplificados del teclado (altura de tecla, radios, colores de
   capa activa, estados pressed/haptic) derivados del Liquid Glass existente.
4. `AGENTS.md`: §2 decisiones nuevas (tabla §3), estructura de carpetas actualizada,
   anti-patrones nuevos (§8), reglas de micrófono compartido.

Criterios de aceptación:
- [ ] Los tres documentos reflejan el alcance dual y quedaron commiteados.
- [ ] Ninguna línea de código de este proyecto fue escrita todavía.

Guion de verificación: revisión humana de los docs (no aplica CI).

---

### Hito K1 — Esqueleto del teclado funcional (~2–3 ciclos CI)

**Objetivo**: poder habilitar "VoiceBubble Keyboard" en Ajustes y escribir letras en
cualquier app. Sin capa código, sin voz, sin snippets.

Tareas:
1. `VoiceKeyboardService.kt`: ciclo de vida completo
   (`onCreateInputView`, `onStartInputView`, `onEvaluateFullscreenMode=false`,
   insets correctos con `onComputeInsets`).
2. Layout QWERTY programático/XML: 4 filas + fila inferior
   (shift, z, backspace, números-a-símbolos básicos, coma, espacio, enter).
3. Comportamiento de teclas: shift (auto-apagado tras 1 letra), backspace
   (`deleteSurroundingText` con borrado de selección), espacio, enter
   (`KEYCODE_ENTER` vía evento + fallback `commitText("\n")`).
4. `method.xml` con subtipos es/en; tecla de cambio de idioma funcional.
5. Manifest: declaración del servicio con `BIND_INPUT_METHOD` y `exported="true"`.
6. Guard de CI (§5).
7. Pantalla de Settings: tarjeta "Teclado VoiceBubble" con estado (habilitado/
   seleccionado/no instalado) y botones directos a los Ajustes del sistema
   (`ACTION_INPUT_METHOD_SETTINGS`) + mini guía de activación.

Criterios de aceptación:
- [x] El teclado aparece en "Manage keyboards" y se puede seleccionar. (verificado por el dueño, 2026-08-23: configurado como teclado principal)
- [x] Se escribe texto correcto (mayúsculas/minúsculas, acentos es/en) en Chrome, WhatsApp y Acode. (verificado por el dueño, 2026-08-23)
- [x] Enter y backspace funcionan en los tres casos. (verificado tras fix de insets r45)
- [x] Cambio de idioma es↔en visible y operativo.
- [x] En horizontal NO aparece el modo pantalla-completa de extracción. (`onEvaluateFullscreenMode=false`)
- [x] CI verde + APK instalado en el dispositivo físico. (run `32608593576`, APK r45)

Guion de prueba manual:
1. Instalar APK → Ajustes del sistema → Manage keyboards → activar VoiceBubble Keyboard.
2. Abrir Chrome → barra de búsqueda → cambiar de teclado → escribir "Hola ñandú Test".
3. Repetir en WhatsApp y en Acode (archivo nuevo).
4. Rotar a horizontal mientras se escribe → verificar que sigue viéndose la app.
5. Abrir la app VoiceBubble → verificar que la tarjeta de estado muestra "activo".

Riesgos específicos: altura/insets mal calculados (teclado tapa el campo o flota);
mitigación: probar primero en Chrome, ajustar `onComputeInsets`.

---

### Hito K2 — Capa código y teclas terminales (~2 ciclos CI)

**Objetivo**: que Termux sea plenamente operable desde nuestro teclado.

Tareas:
1. Tecla cambiador de capas (icono `</>`), con memoria de última capa usada.
2. **Capa código**: `{ } [ ] ( ) < > ; : ' " \` \ | / ! ? = + * & % $ # @ ^ ~ _`
   organizadas por frecuencia; toque largo = par auto-cerrado (ej. `{` inserta `{}`).
3. **Fila terminal permanente** (visible en todas las capas):
   TAB, ESC, CTRL (toggle), ALT (toggle), flechas ↑ ↓ ← →.
4. Envío correcto de modificadores: eventos con `META_CTRL_ON`/`META_ALT_ON`
   (patrón Hacker's Keyboard, consumido por TerminalView de Termux) +
   fallback `commitText` de caracteres de control para ROMs quisquillosas.
5. Flechas: `KEYCODE_DPAD_*` vía `sendKeyEvent`.
6. Haptic feedback en todas las teclas (`KEYBOARD_TAP`).

Criterios de aceptación:
- [ ] En Termux: `ls` + TAB autocompleta; Ctrl+C corta un proceso; Ctrl+L limpia;
      Ctrl+[ actúa como ESC en vim/nano; flechas navegan el historial de bash.
- [ ] En Acode: llaves/corchetes se insertan correctamente y el par auto-cerrado
      funciona con toque largo.
- [ ] Las teclas terminales no rompen apps normales (Chrome ignora ESC/CTRL sin error).
- [ ] CI verde + APK probado.

Guion de prueba manual (Termux):
1. `mkdir test<TAB>` → autocompleta.
2. `ping github.com` + Ctrl+C → corta.
3. nano archivo → Ctrl+O/Ctrl+X guardan y salen; ESC + `:wq` en vim.
4. Flecha ↑ repite comando anterior.
5. En Acode escribir `{` (toque corto) y toque largo → verificar `{}` vs `{`.

Riesgos específicos: diferencias entre ROMs con meta-keys (documentadas por Termux);
mitigación: matriz de prueba en K2 y registro en AGENTS.md §9 si surge un caso raro.

---

### Hito K3 — Dictado por voz dentro del teclado (~2–3 ciclos CI)

**Objetivo**: botón micrófono que transcribe y deja el texto en el cursor, con la
misma API key de la app.

Tareas:
1. `SpeechToTextClient.kt`: grabación WAV PCM16 con cabecera válida
   (lección §9.1-13: usar contenedor WAV real, extensión `.wav`; Groq rechaza
   extensiones mentirosas), cancelable, timeout de seguridad (60 s).
2. POST multipart a Groq/OpenAI desde Kotlin (sin librerías nuevas: `HttpURLConnection`).
3. Lectura de proveedor/key/URL desde preferencias compartidas (contrato D7).
4. Estados visuales del micrófono: idle → grabando (anillo pulsante, respeta Reduced
   Motion) → procesando → éxito/error (mensaje inline, nunca dialog bloqueante).
5. Inserción del resultado con `commitText` + alta en el historial FIFO-20 compartido.
6. **Exclusión mutua de micrófono** burbuja↔teclado (flag en proceso + audio focus;
   si la burbuja graba, el mic del teclado muestra "ocupado").
7. Campos password (`TYPE_TEXT_VARIATION_PASSWORD` / `NO_PERSONALIZED_LEARNING`):
   botón oculto y sin aprendizaje.
8. Errores de red/key: mensaje claro y opción "abrir Ajustes".
9. Tests Dart del contrato JSON de historial compartido (lo testeable desde Dart).

Criterios de aceptación:
- [ ] Dictado es/en en Chrome, WhatsApp y Acode deja el texto exacto en el cursor.
- [ ] Historial de la app muestra las transcripciones hechas desde el teclado.
- [ ] Si la burbuja está grabando, el teclado muestra estado ocupado (y viceversa).
- [ ] En un campo de contraseña no aparece el micrófono.
- [ ] Sin conexión: mensaje claro, sin crash, sin envíos parciales.
- [ ] CI verde + APK probado.

Guion de prueba manual:
1. Chrome → tocar mic → decir frase larga en español → verificar texto.
2. Repetir en inglés cambiando el idioma del teclado.
3. Abrir burbuja, iniciar grabación → intentar dictar desde teclado → debe avisar ocupado.
4. Campo de contraseña de GitHub → mic invisible.
5. Modo avión → tocar mic → mensaje de error elegante.

Riesgos específicos: permiso de micrófono concedido a la app cubre al teclado (mismo
paquete), pero si el usuario revocó el permiso hay que guiarlo a re-concederlo desde
Settings de la app (no se puede pedir diálogo desde el teclado cómodamente).

---

### Hito K4 — Snippets y comandos (~2 ciclos CI)

**Objetivo**: guardar comandos repetitivos y dispararlos desde el teclado.

Tareas:
1. Modelo Dart `Snippet { id, nombre, contenido, orden }` + persistencia JSON en
   preferencias compartidas (`voice_snippets_v1`, migrable).
2. CRUD completo en Settings: crear/editar/borrar/reordenar, vista previa del
   contenido multilínea, límite razonable (50 snippets, 2000 caracteres c/u).
3. `SnippetStore.kt` en Kotlin: parseo tolerante (si el JSON está roto → lista vacía
   + log, jamás crash del teclado).
4. **Capa snippets en el teclado**: grid de chips con el nombre; scroll si excede;
   búsqueda simple por nombre (campo arriba del grid); toque = insertar contenido
   completo en el cursor.
5. Toque largo en un chip = menú contextual (insertar / copiar al portapapeles /
   editar en la app).
6. (D9, opcional) Acción asociada "abrir app": intent de lanzamiento con
   `FLAG_ACTIVITY_NEW_TASK` + `<queries>` declarados; desactivada por defecto.
7. Seeds de primera vez (**DECISIÓN DEL DUEÑO, 2026-08-22: SÍ, con 5 ejemplos**),
   creados solo en la primera apertura de la capa y editables/borrables:
   1. `codex "`
   2. `gemini -p "`
   3. `git add . && git commit -m "`
   4. `git push origin main`
   5. `supabase db push`

Criterios de aceptación:
- [ ] Crear snippet en la app → aparece en el teclado sin reiniciar nada.
- [ ] Insertar un snippet multilínea en Acode y en Termux funciona íntegro.
- [ ] Editar/borrar en la app se refleja en el teclado en ≤ 2 s.
- [ ] JSON corrupto manualmente → teclado sigue vivo (sin snippets), sin crash.
- [ ] Búsqueda filtra por nombre en tiempo real.
- [ ] CI verde + tests Dart del modelo/JSON en verde + APK probado.

Guion de prueba manual:
1. Crear snippet "deploy" con contenido multilínea → insertarlo en Termux → Enter.
2. Crear 30 snippets de prueba → verificar scroll + búsqueda "git".
3. Matar la app desde recientes → abrir teclado → los snippets siguen.
4. Corromper el JSON con un editor → abrir teclado → no crashea, lista vacía.

---

### Hito K5 — Pulido visual, robustez y entrega (~2 ciclos CI)

**Objetivo**: que se sienta parte de la familia VoiceBubble y sobreviva al uso diario.

Tareas:
1. Tema Liquid Glass simplificado aplicado a todas las capas (claro+oscuro siguiendo
   el sistema, tokens de `design.md` traducidos a recursos nativos).
2. Altura del teclado configurable (baja/media/alta) desde Settings.
3. Vibración configurable (on/off), sonido de tecla OFF por defecto.
4. i18n es/en de todas las etiquetas internas del teclado.
5. Recuperación de escenarios hostiles: rotación a mitad de dictado, cambio rápido de
   campo/app con grabación en curso, teclado abierto al recibir llamada.
6. Performance: medir RAM del proceso durante uso intensivo (debe mantenerse muy por
   debajo de la alternativa Flutter-embebida que descartamos); arranque del teclado < 300 ms.
7. Auditoría de privacidad final: confirmar que ningún camino de código registra
   teclas; grep de `Log.` en archivos del teclado → solo logs de diagnóstico sin contenido.
8. Docs finales: guía de activación con capturas en README; lecciones aprendidas en
   AGENTS.md §9; tag `v0.9.0-keyboard-beta`.
9. APK release candidate + checklist completo firmado.

Criterios de aceptación:
- [ ] Todos los hitos anteriores siguen cumpliendo SUS criterios (regresión completa).
- [ ] Tema correcto en claro/oscuro y al cambiar el modo del sistema en caliente.
- [ ] Ningún log contiene texto tecleado ni transcripciones.
- [ ] Uso de 15 minutos mixto (dictado + código + snippets + Termux) sin crash ni ANR.
- [ ] CI verde, APK RC publicado, docs actualizadas.

---

## 7. Definición de Hecho global (además de la de cada hito)

1. Funciona en Chrome mobile, Acode y Termux (los tres blancos reales del usuario).
2. `flutter analyze` ESTRICTO y `flutter test` en verde en cada push.
3. RLS/reglas de seguridad del repo intactas: sin keys en código, sin secrets en git.
4. Cero telemetría; red SOLO en llamadas STT iniciadas por el usuario.
5. Burbuja pre-existente 100% funcional (ninguna regresión).
6. Manual de activación probado por alguien que no escribió el código (el usuario).

## 8. Anti-patrones nuevos (sumar a AGENTS.md)

- ❌ Registrar/guardar texto tecleado en el teclado (ni debug, ni analytics, jamás).
- ❌ Dictado o snippets activos en campos de contraseña.
- ❌ Segundo motor Flutter embebido en el teclado (descartado por diseño).
- ❌ Features de teclado genérico fuera de alcance: autocorrector predictivo, temas,
  emojis, glide typing, portapapeles multinivel.
- ❌ Que el teclado dependa de que la Activity principal haya sido abierta alguna vez
  para funcionar (todo default debe ser sensato en cold start).
- ❌ Mezclar cambios de burbuja y de teclado en el mismo commit/hito.

## 9. Riesgos y mitigaciones (vista consolidada)

| # | Riesgo | Prob. | Impacto | Mitigación principal |
|---|--------|-------|---------|----------------------|
| 1 | Error de compilación Kotlin visible solo en CI | Alta | Medio | Kotlin plano, cero dependencias nuevas, commits chicos, releer diff (§9.2-7 AGENTS.md) |
| 2 | Ciclo lento de feedback (CI→APK→prueba) | Media | Medio | workflow_dispatch para builds bajo demanda; agrupar tareas afines por hito |
| 3 | Conflicto de micrófono burbuja↔teclado | Media | Alto | Exclusión mutua por flag+audio focus; escenario cruzado probado en K3 y en cada regresión |
| 4 | Quirks de meta-keys por ROM (Termux docs) | Media | Medio | Patrón Hacker's Keyboard + fallback commitText; matriz manual en K2 |
| 5 | Percepción de privacidad (Android advierte sobre teclados) | Media | Medio | Cero logging (audit en K5), código abierto, promesa escrita en README |
| 6 | Regresión en la burbuja | Baja | Alto | Hitos separados; regresión de burbuja incluida en el DoD de cada hito desde K3 |
| 7 | Scope creep (convertirlo en Gboard) | Alta | Medio | Anti-patrones §8; snippets/símbolos/dictado son TODO el alcance |
| 8 | JSON de snippets corrupto rompe teclado | Baja | Alto | Parseo tolerante + lista vacía + log; jamás throw en rutas del IME |

## 10. Estimación global

- **6 hitos** (T0 + K1..K5), ≈ 11–14 ciclos de CI (push→build→prueba).
- En ritmo de sesiones nocturnas estilo Termux: **2–3 semanas** realistas.
- Puede convivir con los Hitos 4–6 originales de `plan.md`, pero NUNCA mezclados en
  el mismo commit. Orden recomendado: terminar Hito 4 (accessibility, pequeño) antes
  de arrancar K1, o congelarlo explícitamente.

## 11. Preguntas abiertas (TODAS RESUELTAS por el dueño)

| # | Pregunta | Respuesta (fecha) |
|---|---|---|
| 1 | ¿D7 (espejo de API key en preferencias privadas)? | Confirmada tal como figura en §3 (22-08-2026) |
| 2 | ¿Nombre "VoiceBubble Keyboard"? | OK, D8 confirmado (ver §3) |
| 3 | ¿K1 tras el Hito 4 o congelarlo? | **Hito 4 CONGELADO**; el teclado ocupa su posición en el plan general (22-08-2026) |
| 4 | ¿Seeds de snippets de primera vez? | **SÍ, 5 ejemplos precargados** (definidos en K4, tarea 7) (22-08-2026) |

## 12. Anexo — Evidencia de la investigación (referencias rápidas)

- Docs oficiales: Create an input method · InputMethodService · InputConnection · SpeechRecognizer (developer.android.com)
- Blog oficial Android Developers: "Add Voice Typing To Your IME"
- Fuente TerminalView.java de termux-app: manejo documentado de commitText y meta-states CTRL/ALT de teclados de terceros
- Precedentes: FUTO Voice Input (Whisper-on-device IME) · CodeBoard MIT (snippets) · Hacker's Keyboard (Ctrl/Esc/Tab) · FlorisBoard · Unexpected Keyboard · Kõnele
- Límite Flutter-in-IME: discusiones Stack Overflow 59754902 / 79864126 (FlutterEngine duplicado, insets frágiles)

---

> **Última actualización**: Agosto 2026 — plan de ejecución completo generado con OpenCode
> Próximo paso: commitear docs de cierre → ejecutar T0 → arrancar K1.
