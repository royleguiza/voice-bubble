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
