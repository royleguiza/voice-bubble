# Spec — Ruta IA, etapa 4: idiomas de la app

Contexto: `docs/investigacion-modelos-ia.md` §8 y §12. Hoy todos los textos
están en español dentro del código (Flutter ≈ 570 literales, Kotlin casi
todo fuera de `strings.xml`). Se hace por tandas, una por vez, cada una
auditada por el coordinador antes de la siguiente.

| Tanda | Qué | Quién |
|---|---|---|
| **A** | Flutter: infraestructura `gen-l10n` + sacar los textos de la UI a `app_es.arb` **sin cambiar nada visible** | worker Sonnet |
| B | Kotlin (app y `puntero_android/`): textos a `res/values/strings.xml` sin cambio visible | pendiente |
| C | Traducciones `en` y `pt-BR` (Flutter + Kotlin), idioma por app (Android 13+ `localeConfig`; 9–12 preferencia del puente), selector en Ajustes, «Idioma en que hablo» | coordinador (delicado) |

## Tanda A — encargo del worker

### Reglas
- Editar SOLO `app_source/` (nunca `voice_bubble_stt/lib`), más la línea de
  copia del CI y los tests Python que haga falta ajustar. Sin commit, sin
  push, sin temporizadores ni procesos en segundo plano que queden vivos.
- **Nada visible cambia**: mismo texto exacto (tildes, «», signos, mayúsculas,
  espacios, saltos de línea). La única excepción aceptada son los textos
  propios de Material que pasan a español al sumar
  `GlobalMaterialLocalizations` (tooltips «Atrás», barra de copiar/pegar).
- `flutter analyze` ESTRICTO limpio; no bajar ninguna regla de lint.

### Infraestructura
1. `pubspec.yaml`: `flutter_localizations: {sdk: flutter}`, `intl: any`
   (la versión que fije el SDK) y `flutter: generate: true`. Actualizar
   `pubspec.lock` con `flutter pub get` (Flutter local `~/flutter`, 3.47.9,
   igual que el CI).
2. `app_source/l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file:
   app_es.arb`, `output-localization-file: app_localizations.dart`,
   `output-dir: lib/l10n`, `nullable-getter: false`.
   **Los `.dart` generados se versionan** en `lib/l10n/` (el CI no debe
   depender de generarlos).
3. CI `.github/workflows/android.yml`, paso «Sincronizar fuente»: sumar
   `app_source/l10n.yaml` a la primera línea `cp`. No tocar nada más del yml.
4. `main.dart`: `localizationsDelegates: AppLocalizations.localizationsDelegates`,
   `supportedLocales: AppLocalizations.supportedLocales` (por ahora solo
   `es`), sin `locale` fijo. `title` puede quedar literal.
5. Tests Dart: helper en `test/helpers/` (p. ej. `l10n_app.dart`) que
   arme el `MaterialApp` con los delegados y `locale: Locale('es')`; usarlo
   en los ≈ 16 archivos que crean `MaterialApp`. Los `find.text('…')` en
   español siguen igual (prueba de que nada cambió).

### Qué se saca y qué no
- **Se saca:** todo texto que ve la persona en `lib/screens`, `lib/widgets`,
  `lib/ui`, `lib/controllers`: `Text`, `label`, `tooltip`, `hintText`,
  `semanticsLabel`/`Semantics(label:)`, SnackBars, diálogos, títulos de
  Ajustes, opciones de menús.
- **Avisos que nacen en `lib/services` o `lib/helpers` sin `BuildContext`**:
  no inventar un `context` global. Si el texto se muestra al usuario,
  devolver un código/enum y traducirlo en la UI cuando sea simple; si no es
  simple, dejarlo y anotarlo en la lista de pendientes (ver Entrega).
- **No se saca:** prompts de la IA (son para el modelo, se tratan en la
  tanda C), claves de preferencias, `debugPrint`/logs, ids, nombres de
  modelos, textos de tests, contenido de los snippets de ejemplo (sembrados
  en datos del usuario).
- Claves ARB en inglés camelCase con prefijo de pantalla
  (`settingsTitle`, `homeEmptyNotes`, `editorAiTitleButton`). Una entrada
  por texto; `@clave` con `description` corta cuando el texto sea ambiguo.
  Interpolaciones como placeholders (`{count}`, `{name}`), plurales con ICU
  `{count, plural, =1{…} other{…}}` solo si el código ya distinguía
  singular/plural. Fechas/números: no cambiar cómo se formatean.
- Constantes `const` que contenían el texto: pasan a getters o a funciones
  que reciben `AppLocalizations`; si un `const` widget deja de serlo, está
  bien.

### Suites Python
Varias suites buscan textos en español dentro de los `.dart`. Si un texto
se mudó, la aserción se ajusta para comprobar **lo mismo**: que el texto
exista en `app_es.arb` y que el archivo use su clave. Nunca borrar ni
aflojar una aserción para que pase; reportar cada suite tocada y por qué.

### Verificación obligatoria (resultados reales en la entrega)
Con 2 GB de RAM: nada de Gradle en esta tanda; correr uno por vez.
1. Copia en el scratchpad: `voice_bubble_stt/` + encima `app_source/`
   (`lib`, `test`, `fonts`, `pubspec.*`, `analysis_options.yaml`,
   `l10n.yaml`), igual que el paso del CI.
2. En la copia: `flutter pub get`, `flutter analyze` (0 problemas),
   `flutter test` (línea base 757+ verdes; todos verdes).
3. En el repo (líneas base medidas 2026-11-17): `test_master_suite.py`
   100/102 (solo los 2 de C-34, previos), `test_settings_redesign_suite.py`
   157/0, `test_translate_suite.py` 22/0, `test_turbo_model_suite.py` 18/0,
   `test_widget_notes_suite.py` 161/2 (previos) y toda suite que hayas
   tocado (medir antes y después): mismas cifras o mejores.
4. `grep` final de literales en español que queden en `lib/screens`,
   `lib/widgets`, `lib/ui`, `lib/controllers` con su motivo.

### Entrega
Al final de este archivo, sección «Registro tanda A»: archivos tocados,
cantidad de claves, cifras reales de cada verificación, suites ajustadas y
**lista de pendientes** (textos de servicios que quedaron, dudas).

## Registro tanda A

Hecho por el worker el 2026-11-17. Sin commit ni push.

### Archivos tocados
- Infraestructura: `app_source/pubspec.yaml` (`flutter_localizations`, `intl: any`, `generate: true`), `app_source/pubspec.lock` (regenerado con `flutter pub get`), `app_source/l10n.yaml` (nuevo), `.github/workflows/android.yml` (solo la primera línea `cp` de «Sincronizar fuente»: suma `app_source/l10n.yaml`).
- Nuevos: `app_source/lib/l10n/app_es.arb`, `app_localizations.dart` y `app_localizations_es.dart` (generados, versionables), `l10n_ext.dart` (atajo `context.l10n.clave`), `app_source/test/helpers/l10n_app.dart` (`esMaterialApp`, con delegados y `locale: es`).
- `main.dart`: delegados y `supportedLocales`; sin `locale` fijo; `title` literal.
- UI migrada: `screens/` (home, note_editor, credentials, settings_screen y `settings/{general,teclado,trackpad,snippets}_tab` e `island_page`), `widgets/` (history_list, home_chrome, island_mockup, note_audio_row, note_card, pending_note_tile, record_button, settings_v2), `ui/transcription_feedback.dart`, `controllers/recording_controller.dart`.
- Tests Dart: los 16 archivos que creaban `MaterialApp` pasan a `esMaterialApp` (más `helpers/test_app.dart`). `island_mockup_test` y `history_list_test` usan `AppLocalizationsEs()` (ver «Cambios de API»).
- Suites Python tocadas: ver abajo.

### Claves ARB
448 claves (sin contar `@@locale` ni los `@clave`). Prefijos: `common*`, `settings*`, `keyboard*`, `trackpad*`, `island*`, `home*`, `note*`, `noteEditor*`, `credentials*`, `snippet*`, `pending*`, `record*`. Interpolaciones como placeholders `String`; no había singular/plural en el código, así que no hay plurales ICU.

### Cambios de API (por no tener `BuildContext`)
- `IslandMockup.describe(AppLocalizations l10n, Rect, bool)`: nuevo primer parámetro.
- `RecordingController.getStatusText(AppLocalizations l10n, {hasResult})` (nadie lo usaba en la UI).
- El texto «El audio pendiente ya no está disponible» que el controlador pasaba a `onError` ahora es el objeto `PendingAudioUnavailable`; `HomeScreen._showTranscribeError` lo traduce (`homePendingAudioGone`).
- `SettingsStepperRow.unit` y `unitSpoken` pasan a `String?` (null = `unitPx`/`unitPxSpoken` del ARB).
- Se quitaron las constantes `copyTooltipMessage`, `copiedToClipboardMessage`, `clipboardFailureMessage` y `copyButtonLabel` de `ui/transcription_feedback.dart`; son claves ARB con el mismo nombre.
- Nombres de color de snippets (`azul`…) y de idiomas destino de traducción se traducen en la UI con un `switch`; los ids y el mapa de `StorageService` no cambian.

### Verificación (cifras reales)
Copia en el scratchpad (`voice_bubble_stt/` + `app_source/{lib,test,fonts,pubspec.*,analysis_options.yaml,l10n.yaml}`):
- `flutter pub get`: OK (el lock resultante es el que quedó en `app_source/pubspec.lock`).
- `flutter analyze` estricto: **No issues found**.
- `flutter test` completo en una sola corrida: **781 pasan, 0 fallan, 0 omitidos** (línea base 757+). Por carpeta: screens 162, widgets 87, integration 27, services 385, models 16, ui 91, helpers 12, widget_test 1.
- Suites Python (todas las `test_*.py`, antes y después): `test_master_suite` 100/102 (los 2 de C-34, previos), `test_settings_redesign_suite` 157/0, `test_translate_suite` 22/0, `test_turbo_model_suite` 18/0, `test_widget_notes_suite` 161/2 (previos). Las demás suites dan la misma salida que antes; sin regresiones.

### Suites Python ajustadas y por qué
Muchas buscaban el literal español dentro de un `.dart` que ahora usa `context.l10n.clave`. Sin tocar ninguna aserción, `test_helpers.py` suma `expand_l10n` e `install_l10n_reader()`: al abrir un `.dart` de `app_source/lib` (salvo `l10n/`), cada uso de una clave se sustituye por su texto del `app_es.arb` entre comillas. Así las aserciones siguen comprobando que el texto existe en el ARB y que el archivo usa su clave. Se llama desde: `test_bubble_history`, `test_c22`, `test_c24`, `test_c26`, `test_c45`, `test_c48`, `test_credentials`, `test_floating_dock`, `test_height_profile`, `test_long_press_symbols`, `test_master`, `test_onboarding_and_activation`, `test_pending_notes`, `test_settings_redesign` y `test_trackpad`.
- Única aserción editada: `test_c22_honest_mirrors_suite.py` (SnackBar de «No se pudo guardar la API key»). Quité `const ` del fragmento buscado, porque el `SnackBar` ya no puede ser `const`; el resto de la aserción es idéntico.

### Pendientes y decisiones a revisar
- `pubspec.lock`: el del repo estaba desactualizado (no tenía `audioplayers`, entre otros), así que el diff es grande. AGENTS §6 dice restaurarlo con `git checkout`, pero esta spec pide actualizarlo; lo dejé actualizado. Revisar antes de commitear.
- Textos que nacen en `lib/services` y `lib/helpers` y siguen en español, para la tanda C: `helpers/note_groups.dart` (Hoy, Ayer, Esta semana, meses y abreviaturas; el editor compara con `'Hoy'`/`'Ayer'`; `note_groups_test` los fija); mensajes de `TranscriptionException`, `GeminiException` y de los servicios de IA y notas que la UI muestra con `e.message`; `StorageService.translateTargets` (queda de respaldo).
- Sin sacar a propósito: `ui/horizon_intro.dart` (fichas decorativas de la animación: símbolos, código y palabras `voz`, `nota`, `texto`, `hola`, `dev`, `ssh`, `tmux`); etiquetas de la vista previa del teclado (`espacio`, `ES`, `esc`…, imitan el teclado real, que es Kotlin); nombres propios y de modelo (`VoiceBubble`, `Groq`, `Google`, `Gemini`, `Whisper v3`, `Google AI Studio`, `Groq Whisper`); `Beta`, `12 dp`, `250 ms`, `gsk_…`, `AIza…`; ids y claves de prefs; `debugPrint`/logs; `StateError('Fallo al guardar espejo STT')` (interno).
- `copyButtonLabel` ("Copiar") queda en el ARB sin uso (la constante tampoco se usaba).
- Los textos de Material pasan a español (tooltips «Atrás», barra de copiar/pegar), como acepta la spec.

## Tanda B — encargo del worker (Kotlin)

### Alcance
- App: `voice_bubble_stt/android/app/src/main/` (teclado, burbuja, widget,
  notificaciones, Accesibilidad, dock/trackpad de respaldo). Kotlin del host
  se edita ahí mismo (no hay copia en `app_source/`).
- Complemento: `puntero_android/app/src/main/`.
- Textos a `res/values/strings.xml` de cada módulo (ya existen, con 5 y 3
  entradas: no cambiarlas). Layouts XML con `android:text`,
  `contentDescription`, `hint` literales → `@string/…`.
- **Nada visible cambia**: mismo texto exacto. Escapar bien `'`, `"`, `@`,
  `?`, `\n`, `%` en XML; interpolaciones con `%1$s`/`%1$d`
  (`getString(R.string.x, a)`), plurales con `<plurals>` solo si el código
  ya distinguía.
- Claves en snake_case con prefijo de área (`kb_`, `widget_`, `bubble_`,
  `notif_`, `dock_`, `pad_`, `ptr_`, `a11y_`). Ojo: ya existen recursos
  drawable/raw con prefijos `kb_`/`widget_`; los nombres de string no
  chocan con otros tipos, pero no reutilizar nombres de string existentes.

### Qué NO se toca
- Constantes de protocolo (`PointerProtocol.kt` en los dos módulos debe
  seguir idéntico: `diff` de sus `const val` vacío), acciones/extras de
  Intent, claves de preferencias, nombres de canales usados como id (sí el
  nombre visible del canal), logs `Log.*`, prompts de IA (`NoteAiClients`,
  `GeminiNoteClient`, `KeyboardTranslator`: son para el modelo, tanda C),
  nombres de modelos, rótulos de teclas que son caracteres (letras, ⇧, ⌫,
  «ES/EN» de la tecla de idioma), textos de tests.
- Sin `Context` a mano: pasar el `Context`/`Resources` que ya exista en el
  llamador; no crear singletons globales de contexto. Si no es simple, dejar
  y anotar en pendientes.

### Suites Python
Extender `test_helpers.install_l10n_reader()` (no hacer otro mecanismo):
para `.kt` y layouts `.xml` bajo `voice_bubble_stt/android/app/src/main` y
`puntero_android/app/src/main`, reemplazar `getString(R.string.x[, …])`,
`R.string.x`, `@string/x` por el texto de su `strings.xml` (del mismo
módulo) entre comillas dobles. Las suites que miran `.kt` y aún no llaman
a `install_l10n_reader()` lo suman. Nunca aflojar aserciones; cualquier
aserción editada se lista con su motivo. `strings.xml` mismo no se expande.

### Verificación obligatoria (una cosa por vez, 2 GB de RAM)
1. Complemento en una COPIA del scratchpad: copiar `puntero_android/` y
   `voice_bubble_stt/android/app/debug.keystore` (misma ruta relativa); en
   `gradle.properties` de la copia: `org.gradle.jvmargs=-Xmx1100m
   -XX:MaxMetaspaceSize=512m`, `kotlin.compiler.execution.strategy=in-process`,
   `org.gradle.parallel=false`; `local.properties` con
   `sdk.dir=/home/ubuntu/android-sdk`; correr
   `~/gradle-dist/gradle-9.3.1/bin/gradle --offline --no-daemon --max-workers=1 -q :app:compileDebugKotlin :app:testDebugUnitTest`
   (y `:app:processDebugResources` si hace falta ver errores de XML).
2. Host en otra COPIA: copiar `voice_bubble_stt/` y encima `app_source/lib`,
   `test`, `fonts`, `pubspec.*`, `analysis_options.yaml`, `l10n.yaml`;
   `flutter pub get` en la copia; `android/local.properties` con
   `sdk.dir=/home/ubuntu/android-sdk` y `flutter.sdk=/home/ubuntu/flutter`;
   mismas líneas de `gradle.properties`; correr
   `gradle --offline --no-daemon --max-workers=1 -q :app:compileDebugKotlin -x compileFlutterBuildDebug`
   y `:app:testDebugUnitTest -x compileFlutterBuildDebug`. Si falta algo
   offline (p. ej. tink-android) una corrida sin `--offline`. Si el sistema
   mata Gradle por memoria, repetir con `-Xmx900m` y por tandas.
   Nunca dos Gradle a la vez ni Gradle junto con `flutter test`.
3. Repo: todas las `test_*.py` antes y después (líneas base: master
   100/102 solo C-34, widget_notes 161/2, resto en 0 fallos).
4. `grep` final de literales en español que queden en `.kt`/layouts con su
   motivo.

### Entrega
Sección «Registro tanda B» al final de este archivo (archivos, número de
claves por módulo, cifras reales, suites ajustadas, pendientes). Sin
commit, sin push, sin procesos en segundo plano.

## Registro tanda B

Hecho por el worker el 2026-11-17. Sin commit ni push.

### Archivos tocados
- App (`voice_bubble_stt/android/app/src/main`): 31 `.kt` (BubbleHistoryController, ClipboardFilmstripLayout, ClipboardLayer, CredentialsLayer, DictationController, DockController, DockDictationLogic, DockDictationService, DockTrampolineActivity, EditEngine, FloatingBubbleService, FloatingPadView, FloatingTrackpadService, HistoryCardView, HistoryLayer, KeyFactory, KeyboardTranslator, LayoutLayer, MainActivity, SnippetsCardView, SnippetsLayer, SpeechToTextClient, StatusLayer, ToolbarLayer, TrackpadBridge, VirtualTrackpadView, VoiceKeyboardService, WidgetDictationService, WidgetNoteEditActivity, WidgetNotesListService, WidgetNotesProvider, WidgetReader), 5 layouts (`activity_widget_note_edit`, `widget_note_detail`, `widget_note_item`, `widget_notes`, `widget_pending_item`) y `res/values/strings.xml`.
- Complemento (`puntero_android/app/src/main`): 8 `.kt` (DockController, DockManager, IslandController, IslandView, MainActivity, PadView, TrackpadController, TrackpadPanel) y `res/values/strings.xml`.
- Tests: `test_helpers.py` (extendido), 42 suites que leen `.kt`/layouts suman `install_l10n_reader()`, y `DockDictationLogicTest.kt` (ver «Aserciones editadas»).
- `voice_bubble_stt/android/app/build.gradle.kts`: ver «Cambio de build» (decisión a revisar).
- `PointerProtocol.kt` de ambos módulos: sin tocar; `diff` de sus `const val` vacío.

### Claves
- App: **237 `<string>` + 1 `<plurals>`** nuevos (las 5 previas intactas; 243 recursos de texto en total). Prefijos: `kb_` (teclado, con `kb_a11y_` para descripciones accesibles), `widget_`, `bubble_`, `notif_`, `dock_`, `pad_`.
- Complemento: **74 `<string>`** nuevos (las 3 previas intactas; 77 en total), todas `ptr_`.
- Textos con argumentos usan `%1$s` y `getString(R.string.x, a)`; un solo `<plurals>` (`widget_pending_count`, «· N pendiente(s)», porque el código ya distinguía 1 de N). Las cadenas con espacios al borde o dobles van entre comillas en el XML (Android colapsa espacios).
- Cada texto se derivó mecánicamente del literal Kotlin/XML original (herramienta en el scratchpad, no versionada), así que tildes, «», signos y espacios son los mismos. Verificado: el texto de cada `strings.xml` leído con el lector de `test_helpers` coincide con el literal original en las 312 claves (0 discrepancias).

### Decisiones y adaptaciones
- **Idioma del teclado (`isSpanish()`/`spanishMode`)**: el teclado, el dictado y el cliente STT ya elegían entre un literal en español y otro en inglés según el idioma del teclado (no el de la app). Se migró solo la rama en español a `strings.xml`; las ramas en inglés quedan literales. Unificarlo con `values-en` es trabajo de la tanda C.
- `StatusLayer.NOTICE_DEAD_CONNECTION_ES` pasó de `const val` String a `val` con el id de recurso (`R.string.kb_notice_dead_connection`); los tres usos hacen `service.getString(...)`. Así la aserción de C-06 (`NOTICE_DEAD_CONNECTION_ES = "Conexión perdida"`) sigue valiendo vía el lector.
- `DockDictationLogic.MSG_*`, `errorMessage()` y `doneMessage()` ahora son ids de recurso (Int); `DockDictationService.fail/finishWith` y `DockTrampolineActivity` los resuelven con `getString` antes de mandarlos por el protocolo (el tope `MAX_MIC_MESSAGE` sigue aplicándose al texto ya resuelto).
- `KeyFactory.getString(id)`: atajo para que `LayoutLayer` (que no tiene el servicio) resuelva textos sin crear contexto global. `KeyboardTranslator.translateOnDevice` recibe ahora el `Context` (ya lo tenía `translate`).
- Complemento: `TrackpadPanel.DRAG_LABEL` pasó a ser un id de recurso (se conserva el nombre por la aserción del Trackpad); se quitaron `PadView.DEFAULT_HINT` y `TrackpadController.HINT_GRAB/HINT_DROP` (nadie más los usaba) en favor de strings.
- Descripciones de `VirtualTrackpadView` («CLIC», «IZQ», «DER») también se movieron (solo se leen con TalkBack).

### Verificación (cifras reales)
Con 2 GB, un Gradle por vez, en copias del scratchpad:
1. Complemento (`:app:processDebugResources :app:compileDebugKotlin`, luego `:app:testDebugUnitTest`, `--offline`): compila limpio; **113 tests, 0 fallos**.
2. App: `flutter pub get` en la copia (con `app_source/{lib,test,fonts,pubspec.*,analysis_options.yaml,l10n.yaml}` encima), `-Xmx1100m`. Hizo falta correr **sin `--offline`** (falta `appcompat-1.6.1.aar` en la caché). `:app:compileDebugKotlin -x compileFlutterBuildDebug`: compila limpio (incluye `processDebugResources`, así que el XML de strings y layouts es válido). `:app:testDebugUnitTest -x compileFlutterBuildDebug`: **182 tests, 0 fallos, 0 omitidos**.
3. Suites Python (todas las `test_*_suite.py`, antes y después): sin regresiones atribuibles a esta tanda. `test_settings_redesign` 157/0, `test_translate` 22/0, `test_turbo_model` 18/0, `test_widget_notes` 161/2 (los 2 previos, mismos fallos), `test_trackpad` 214/0, `test_floating_dock` 303/0, `test_c06` 46/0, `test_c34` 3/6 (previo). `test_master_suite`: **98/102** hoy frente a 100/102 de la línea base: los 2 extra (`test_c19_bridge_keys_and_limits_suite` y «CI Guard: Paridad de Claves de Contrato») fallan porque `app_source/lib/services/storage_service.dart` (modificado en el árbol por el trabajo de la tanda C) ya suma `appLocaleKey` a `bridgeKeys` (66 claves) y `docs/contract-keys.txt` y el Kotlin siguen en 65. No dependen de esta tanda (comprobado: ambas miran solo el lado Dart).
4. Literales en español que quedan en `.kt`/layouts (con motivo):
   - `GeminiNoteClient.kt` y `NoteAiClients.kt`: mensajes de error de red/servidor/cuota y `TOO_LONG_MESSAGE` (viajan como `e.message` de `GeminiError`; sin `Context`; los espejea el Dart y lo comprueba C-48) y los prompts de IA. Igual criterio que los `GeminiException` de la tanda A: pendiente.
   - `PointerProtocol.kt` (ambos módulos): `resultMessage()` devuelve 3 frases en español; el archivo debe ser espejo exacto, es JVM puro y lo prueban `PointerProtocolTest` y `test_floating_dock_suite` (`PointerProtocol.resultMessage(null)`). Pendiente.
   - `ClipboardStore.kt`: la vista previa «Imagen (…)» se guarda en las preferencias (dato persistido), no se muestra desde un recurso. `SnippetStore.kt`: snippets sembrados en datos de la persona (no se tocan, como en Flutter).
   - `KeyboardTranslator.kt`: `TARGETS` («inglés», «español»…) son nombres para el prompt de la IA.
   - `DictationController.isRetryableError` busca subcadenas españolas («inválida», «conexión», «límite») en los mensajes que ahora salen de recursos: sigue funcionando mientras el texto sea el español actual; con traducciones (tanda C) hay que reemplazar la heurística por códigos.
   - `TranscriptionHistoryRepository.kt` («No se pudo publicar el historial atómicamente», «historial corrupto», «prefs corruptas»): mensajes de excepciones internas, no se muestran.
   - Etiquetas de `ClipData` («nota», «VoiceBubble STT»), título de notificaciones «VoiceBubble» / «VoiceBubble STT», `android:label="VoiceBubble STT"`: marca o etiquetas internas.
   - Rótulos de teclas/caracteres (`TAB`, `ESC`, `CTRL`, `ALT`, `ABC`, `?123`, `ES`/`EN`, `asdfghjklñ`, acentos de `KeyboardSupport`, badges `IMG`/`MATH`/`URL`/`TXT`) y todas las ramas en inglés de los pares ES/EN.

### Aserciones editadas
- Python: ninguna aserción editada; todo se resuelve con el lector ampliado. `test_helpers.install_l10n_reader()` ahora, además del Dart de la tanda A, abre `.kt` y layouts `.xml` de ambos módulos con `getString(R.string.x[, args])`, `R.string.x`, `R.plurals.x` y `@string/x` ya sustituidos por el texto de su `strings.xml` (del mismo módulo, entre comillas; los argumentos vuelven a ser `$nombre`/`${expr}`; `strings.xml` no se expande). Lo suman las 42 suites que leen Kotlin o layouts sin llamarlo antes.
- Kotlin: `DockDictationLogicTest` (`las frases entran en el mensaje corto del protocolo`): como `MSG_*` y `doneMessage()` ahora son ids, la prueba lee el texto de `res/values/strings.xml` (helper `stringResource`, por reflexión sobre `R.string`) y comprueba lo mismo: cada frase ≤ `MAX_MIC_MESSAGE` y `doneMessage` = «Pegado»/«Copiado». Las aserciones de `errorMessage()` no cambian (comparan ids).

### Cambio de build (a revisar por el coordinador)
`MicrophoneClaimTest` (Robolectric) crea `WidgetDictationService`, que ahora lee su canal de notificación de recursos; sin recursos fallaban 10 tests (`Resources$NotFoundException`). Se agregó en `voice_bubble_stt/android/app/build.gradle.kts` `testOptions { unitTests.isIncludeAndroidResources = true }` y `packageDebugUnitTestForUnitTest` `mustRunAfter("copyFlutterAssetsDebug")` (sin eso Gradle rechaza el grafo con `-x compileFlutterBuildDebug`). Efecto: los tests JVM de la app ahora empaquetan assets, así que en el CI (donde Flutter está instalado antes de los pasos Kotlin) cada `gradle :app:testDebugUnitTest` ejecutará también la tarea de assets de Flutter. **No pude verificarlo sin `-x`** (compilaría el Dart con el trabajo en curso de la tanda C). Alternativa si no se quiere: volver a dejar el canal con texto fijo en `WidgetDictationService.createChannel` y anotarlo como pendiente.

### Pendientes
- Lo listado en el punto 4 (errores de `GeminiNoteClient`/`NoteAiClients`, `PointerProtocol.resultMessage`, heurística `isRetryableError`, vista previa «Imagen (…)» de `ClipboardStore`).
- Claves con el mismo texto repetido a propósito por área (p. ej. `widget_cancel`/`kb_cancel`, `bubble_dictate`/`dock_dictate`): unificar al traducir si se prefiere.
- Durante la tanda alguien dejó `SpeechToTextClient.kt` en el contenido de HEAD (a las 02:12, sin pasar por mí) y volví a aplicar su migración; vale la pena confirmar que nadie más edita archivos Kotlin en paralelo.
- CI (`.github/workflows/android.yml`) no se tocó.

## Tanda C — reparto

Coordinador (hecho o en curso): `app_en.arb`/`app_pt.arb` (448 + fechas +
selector), fechas por idioma (`NoteDateWords`), Ajustes › Idioma
(`kb_app_locale`: `sistema`/`es`/`en`/`pt`), canal
`com.royleguiza.voicebubblestt/locale`, `AppLocale.kt`, `localeConfig` en
los dos manifiestos, contrato 66, heurística de reintento.
**Ojo (incidente tanda B):** `test_c34` restauraba sus mutaciones con lo
leído por el lector expandido y deshizo la migración de
`SpeechToTextClient.kt`. Ya usa `test_helpers.raw_read`. Toda suite que
vuelva a escribir un archivo debe leer el original con `raw_read`.

### Tanda C2 — encargo del worker (Kotlin)
1. **Traducciones:** crear `res/values-en/strings.xml` y
   `res/values-pt/strings.xml` en la app y en `puntero_android/`, con TODAS
   las claves de `values/strings.xml` (`<plurals>` incluido). Portugués de
   Brasil con «você». Si el código ya tenía la versión inglesa de un texto
   (pares `if (spanishModeProvider()) getString(…) else "English"` o
   `if (es) …`), usar ESA frase exacta en `values-en`. Nombres: «VoiceBubble
   Puntero» → en «VoiceBubble Pointer», pt «VoiceBubble Ponteiro» (igual que
   la app Flutter); `ime_name` en pt «Teclado VoiceBubble». Glosario de la app
   Flutter: `app_source/lib/l10n/app_en.arb` y `app_pt.arb` (usar los mismos
   términos: Ajustes→Settings/Ajustes, Notas→Notes/Notas, burbuja→bubble/
   bolha, isla→island/ilha, clave→key/chave, «Traducir»→Translate/Traduzir).
   Mismos `%1$s`/`%1$d` en el mismo orden; escapar `'` como `\'`.
2. **Mensajes por idioma de la app, no por la tecla ES/EN:** en los ≈ 108
   pares de `EditEngine`, `SpeechToTextClient`, `VoiceKeyboardService`,
   `LayoutLayer`, dejar solo `getString(R.string.x)` (el idioma lo pone
   Android). No tocar lo que la tecla ES/EN decide para el DICTADO
   (`language` que se manda a Groq) ni los rótulos de teclas. No tocar
   `DictationController.isRetryableError` (lo hace el coordinador).
3. **Inglés por defecto (como Flutter):** al final, en los dos módulos,
   mover el español a `res/values-es/strings.xml` y dejar el inglés en
   `res/values/strings.xml` (borrar `values-en`). `test_helpers.expand_android`
   debe leer `values-es` (las suites siguen comprobando el español).
4. **Suites:** las que buscaban la frase inglesa dentro de un `.kt` pasan a
   comprobarla en `values/strings.xml` (inglés). Nunca aflojar. Si una suite
   reescribe archivos, `raw_read`.
5. **No tocar:** `MainActivity.kt`, `DictationController.kt`, manifiestos,
   `res/xml/`, `AppLocale.kt`, nada de `app_source/` (son del coordinador).

Verificación: la misma de la tanda B (Gradle en copias, uno por vez; tests
Kotlin de los dos módulos; todas las `test_*.py`) más un script que confirme
que `values`, `values-es` y `values-pt` tienen exactamente las mismas claves
y los mismos marcadores `%n$x` por clave. Entrega: «Registro tanda C2».

## Registro tanda C2

Hecho por el worker el 2026-11-17. Sin commit ni push.

### Claves por idioma y módulo
- App: 242 `<string>` + 1 `<plurals>` (`widget_pending_count`) en cada uno de `values/` (inglés, por defecto), `values-es/` y `values-pt/`.
- Complemento: 77 `<string>` en cada uno de `values/`, `values-es/`, `values-pt/`.
- `values-es/strings.xml` es el `values/strings.xml` anterior (español), sin cambios; `values-en` no llegó a existir (se generó directo el inglés en `values/`). Nombres: «VoiceBubble Pointer» / pt «VoiceBubble Ponteiro»; `ime_name` pt «Teclado VoiceBubble»; portugués con «você» implícito (imperativos «toque», «ative»).
- Las frases del código con versión inglesa (78 claves) se usaron tal cual en `values/`, salvo: `kb_stt_corrupt` (suma `%2$s` como el español) y `kb_credentials_empty` («Settings → Keys», antes «Claves»). Las cuatro cadenas con literal inglés suelto sin par (`kb_a11y_full_keyboard`, `kb_a11y_mini_keyboard`, `kb_a11y_translate_armed/idle`) también usan el inglés del código.
- Palabras de `isRetryableError` (aviso del coordinador): en inglés y portugués `kb_stt_no_internet` («connection»/«conexão»), `kb_stt_rate_limit` («limit»/«Limite…Aguarde»), `kb_stt_server_error` («server»/«servidor»), `kb_stt_invalid_key` («Invalid»/«inválida»).

### Pares colapsados
- 89 usos `if (es/spanish/spanishMode/host.isSpanish()/spanishModeProvider()) getString(…) else "English"` (78 claves) reducidos a `getString(…)` en 17 `.kt` (EditEngine, SpeechToTextClient, VoiceKeyboardService, LayoutLayer, KeyFactory, KeyboardTranslator, ClipboardLayer, CredentialsLayer, HistoryLayer, SnippetsLayer, ToolbarLayer, ...). Más 3 ramas manuales (`warnDeadConnection`, `cycleNotice`, descripción del botón de traducir y del mini-teclado).
- NO tocado, porque lo decide la tecla ES/EN: `isSpanish()`/`spanishMode`, `"ES"/"EN"`, `asdfghjklñ` vs `asdfghjkl;`, `language` del dictado. Los parámetros `isSpanish`/`spanish` de `commitOrWarn`, `warnDeadConnection` y `KeyboardTranslator.translate` siguen en la firma pero ya no se usan (no se cambió para no romper a `DictationController`).
- `StatusLayer.NOTICE_DEAD_CONNECTION_EN` sigue existiendo solo porque `DictationController.kt:760` (del coordinador) todavía lo usa.

### Coordinador (DictationController.kt)
Quedan en `DictationController.kt` unos 14 pares `if (host.isSpanish()) getString(…) else "English"` (líneas ~509-760). No los toqué. Para que sigan el idioma de la app, hay que colapsarlos igual; las frases inglesas de esos pares ya están en `values/strings.xml` (claves `kb_dictation_*`, `kb_notice_dead_connection`). Antes de eso, con la tecla en EN siguen saliendo en inglés aunque la app esté en español.

### Verificación (cifras reales)
- Complemento (copia, `processDebugResources compileDebugKotlin testDebugUnitTest`, `--offline`): compila limpio, 113 tests, 0 fallos.
- App (copia, `compileDebugKotlin` y `testDebugUnitTest -x compileFlutterBuildDebug`): compila limpio, 182 tests, 0 fallos, 0 omitidos (con `DockDictationLogicTest` ajustado, ver abajo).
- Paridad: `test_android_strings_parity_suite.py` (nuevo): mismas claves y mismos marcadores en `values`, `values-es`, `values-pt` en los dos módulos; 0 problemas.
- Suites Python: todas las `test_*_suite.py` corridas; `test_widget_notes` 161/2 (previos), `test_master_suite` 97/102. Fallos: C-34 (2, previo), y 3 por la clave 66 del contrato del coordinador (`test_c19`, `test_floating_dock` y `test_c37`: «65 claves» vs 66). Ninguno atribuible a C2.

### Aserciones editadas
- `test_helpers._android_strings` y su comentario: ahora lee `values-es/strings.xml` (el lector sigue expandiendo español).
- `test_c06_dead_connection_suite`: `"msg = if (isSpanish)" in warn_fn` → `"msg = service.getString(StatusLayer.NOTICE_DEAD_CONNECTION_ES)" in warn_fn` (la rama inglesa ya no existe).
- `test_c10_retry_without_re_record_suite`: `'"Reintentar" else "Retry"'` → `"Reintentar"` en el `.kt` expandido, `val label = if (onClick != null)` y `>Retry<` en `values/strings.xml`.
- `test_shift_case_suite`: las tres frases inglesas (`Lowercase`, `Title Case`, `UPPERCASE`) se comprueban en `values/strings.xml`; las españolas, como antes, en el `.kt` expandido.
- `DockDictationLogicTest.kt`: `stringResource` lee `res/values-es/strings.xml` (siguen las mismas aserciones «Pegado»/«Copiado»).
- Ninguna suite reescribe archivos con lo que cambié; no hizo falta `raw_read` nuevo.

### Pendientes
- Colapsar los pares de `DictationController.kt` (coordinador).
- Mensajes de `GeminiNoteClient`/`NoteAiClients`, `PointerProtocol.resultMessage` y la vista previa de `ClipboardStore` siguen en español (pendientes de la tanda B).
- `ToolbarLayer` conserva el literal «trackpad» como descripción en inglés (igual en todos los idiomas).
- No se tocaron manifiestos, `res/xml/`, `MainActivity.kt`, `AppLocale.kt` ni `app_source/`. Si el manifiesto usa `@string/…`, todas las claves existen en los tres idiomas.

## Registro tanda C (coordinador, 2026-11-17)

- Flutter: `app_en.arb` y `app_pt.arb` (458 claves cada uno, mismas que
  `app_es.arb`); inglés como respaldo si el teléfono está en otro idioma.
  Fechas por idioma (`NoteDateWords`, `noteDateWordsOf`; «Oct 28» en
  inglés). Ajustes › Idioma (`language-selector`): Del teléfono / Español /
  English / Português; cambia en vivo (`ui/app_locale.dart`).
- Android: `AppLocale.kt` + canal `com.royleguiza.voicebubblestt/locale`
  (`setAppLocale`, `getAppLocale`). 13+: `LocaleManager` (idioma por app,
  también desde Ajustes del sistema; al abrir, Flutter lo sincroniza). 9–12:
  `kb_app_locale` y `attachBaseContext` en teclado, burbuja, dock, trackpad,
  trampolín y editor del widget. `localeConfig` (en/es/pt) en los dos
  manifiestos. Contrato 65 → 66 (`kb_app_locale`).
- `DictationController`: 18 pares ES/EN colapsados (los avisos siguen el
  idioma de la app); `isRetryableError` reconoce portugués.
- Suites: `test_c33` y `test_c34` restauran con `raw_read` (las dos únicas
  que reescriben archivos). `test_c06` comprueba «Connection lost» en
  `values/strings.xml`.
- Verificación: `flutter analyze` limpio, `flutter test` todo verde
  (783+), Kotlin app 182/0, complemento 113/0, master 100/102 (solo C-34),
  widget_notes 161/2 (previos), paridad de `strings.xml` 0 problemas.

### Pendientes de la etapa 4
- «Idioma en que hablo» (hoy la app manda `es` fijo a Groq y el teclado
  usa la tecla ES/EN).
- Mensajes que nacen en servicios: Dart (`TranscriptionException`,
  `GeminiException`, IA de notas) y Kotlin (`GeminiNoteClient`,
  `NoteAiClients`, `PointerProtocol.resultMessage`, vista previa de
  imágenes de `ClipboardStore`).
- El complemento es otra app: sigue su propio idioma por app / el del
  teléfono, no el elegido en VoiceBubble. En 9–12 el widget sigue el del
  teléfono.
- Parámetros `isSpanish` sin uso en `commitOrWarn`/`warnDeadConnection`/
  `KeyboardTranslator.translate`.
- Ficha de Play Store por idioma.
