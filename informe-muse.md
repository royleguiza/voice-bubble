# INFORME-MUSE — Auditoría total de voice-bubble — 2026-09-05

> **Método:** 4 subagentes ultracríticos en paralelo, solo lectura, cero ediciones. Cada archivo fuente leído línea por línea; cada símbolo verificado con `grep -rn`; ningún comentario del código tomado por verdadero.
> **Alcance:** `app_source/` (18 Dart lib + 28 Dart test), `voice_bubble_stt/android/` (14 Kotlin, 10.799 líneas), 8 suites `test_*.py` (1.310 líneas), `.github/workflows/android.yml`, build configs, todos los `.md`, higiene del repo.
> **Veredicto:** app funcional en gama media-alta, con riesgo real de crash/ANR/pérdida de datos en campo y un secreto filtrado en el historial git. No es "un bloque sólido que jamás falle" — este informe lista exactamente por qué, y el plan para llegar ahí.

## Conteo total: 165 hallazgos

| Área | Crítico | Alto | Medio | Bajo | Total |
|---|---|---|---|---|---|
| Dart/Flutter (`app_source/`) | 12 | 26 | 20 | 10 | 68 |
| Kotlin/Android nativo | 9 | 12 | 10 | 5 | 36 |
| Suites, tests, CI, build | 9 | 10 | 7 | 3 | 29 |
| Docs, consistencia, higiene, secretos | 2 | 10 | 13 | 7 | 32 |
| **TOTAL** | **32** | **58** | **50** | **25** | **165** |

Formato de cada hallazgo: **QUÉ → POR QUÉ → QUÉ OCASIONA** + evidencia `archivo:línea`.

---

# PARTE I — LOS 15 CRÍTICOS CONSOLIDADOS (leer primero)

Hallazgos que hoy causan crash, ANR, pérdida de datos, falso verde de CI o fuga de secreto. Los duplicados entre áreas están fusionados con todas sus evidencias.

## CR-1 — Token secreto (PAT `github_pat_*`) versionado en `wait_action.sh` + historial
- **QUÉ:** `wait_action.sh:2` contiene el PAT real (hash idéntico al de `.github_token` y `.agents/secrets.env`), está TRACKED con 4 commits de historial (`491f528,3e3dbce,db99e30,0b8ea45`). `auditoria-muse.md:475` (borrada del disco pero viva en git) también cita el prefijo del token.
- **POR QUÉ:** Viola `AGENTS.md:86,127` y `MODO-LOOP.md:40` (prohibido commitear secretos). Además `AGENTS.md §9.4` ordena imprimir el token en consola, contradiciendo su propia regla de seguridad.
- **OCASIONA:** cualquiera con clone/fork/historial tiene un PAT con scope `repo`: push malicioso, exfiltración, facturación. Revocar no basta mientras viva en `git log --all`.
- **Evidencia:** `wait_action.sh:2-4` vs `git ls-files | grep wait_action` vs `git log --all --oneline -- wait_action.sh`.

## CR-2 — `FloatingTrackpadService` existe, se arranca, pero NO está declarado → crash
- **QUÉ:** el servicio tiene 3 caminos de arranque (`DynamicIslandController.kt:385`, `FloatingTrackpadService.kt:63-66`, `MainActivity.kt:201`) pero el manifest solo declara `FloatingBubbleService` y `VoiceKeyboardService` (`AndroidManifest.xml:14-35`). El `startService()` a componente no declarado lanza `IllegalArgumentException` → FATAL.
- **POR QUÉ:** nadie verificó declaración-vs-arranque tras el retiro anti-Play-Protect.
- **OCASIONA HOY:** tap en botón trackpad de la isla o `startTrackpadBubble` desde Flutter = crash. Además: en Dart la clase `floating_trackpad_service.dart` (95 líneas) tiene cero importadores (código muerto); en Kotlin el 60% del servicio (`showDock/showMiniPad/minimize/toggleMode/expandToMiniPad`, ~120 líneas) es inalcanzable; su suite (`test_trackpad_suite.py:89-214`) da verde verificando strings de un código que jamás ejecuta; y su cabecera promete "clics reales vía Accessibility" imposible con `isConnected()=false`.
- **Evidencia:** `AndroidManifest.xml:14-35` vs `DynamicIslandController.kt:385` vs `FloatingTrackpadService.kt:63-66,73-83,591-626` vs `app_source/lib/services/floating_trackpad_service.dart:5`.

## CR-3 — I/O de disco en hilo principal (Dart sync + Kotlin `readText`) → ANR
- **QUÉ (Dart):** `storage_service.dart` y `home_screen.dart:290-309` usan `existsSync/lengthSync/openSync/readSync/writeAsStringSync/renameSync`; el level-meter muestrea WAV cada 120 ms en UI (`home_screen.dart:274`). `StorageService.load:761` (68 líneas) lee+parsea+ordena+reescribe en cada llamada, y `add:830-837` hace 2 lecturas + 3 escrituras por transcripción.
- **QUÉ (Kotlin):** `TranscriptionHistoryRepository.kt:55` y `ClipboardStore.kt:118` hacen `file.readText()` sincrónico, invocados desde el hilo UI (`MainActivity.kt:102-103`, `VoiceKeyboardService.kt:402,2136,3124`, `DynamicIslandController.kt:943-944`, `BubbleHistoryController.kt:422`).
- **POR QUÉ:** ningún path de lectura/escritura usa isolate/`Dispatchers.IO`/async.
- **OCASIONA HOY:** jank en cada dictado y cada apertura de historial/isla/cinta; ANR en gama baja (eMMC lenta + archivo crecido).

## CR-4 — `SpeechToTextClient` sin `disconnect()` + `AudioRecord` en main + `join(2500)` → sockets agotados y ANR
- **QUÉ:** `SpeechToTextClient.kt:192-218` abre `HttpURLConnection`, cierra streams con `.use` pero jamás `conn.disconnect()`. `startDictation` (main, `VoiceKeyboardService.kt:1770`) crea `AudioRecord` síncrono; `stop/cancelRecording` hacen `recordThread?.join(2500)` (`SpeechToTextClient.kt:131,146`).
- **POR QUÉ:** pool keep-alive nunca liberado; binder de audio + join bloquean UI.
- **OCASIONA:** tras decenas de dictados `SocketException/ENFILE` hasta reiniciar el IME; jank 100-300 ms por dictado; ANR si se rota durante `stop`.

## CR-5 — `commitFromExternal()` sin try binder → crash del IME
- **QUÉ:** `VoiceKeyboardService.kt:3844-3848` llama `currentInputConnection.commitText()` crudo; la app destino puede morir entre el null-check y el commit (`DeadObjectException`). Llamadores (`MainActivity.kt:153`, `BubbleHistoryController.kt:687`, `DynamicIslandController.kt:1109`) sin try útil.
- **OCASIONA:** crash del teclado + del servicio flotante que lo invocó, justo en el momento de pegar.

## CR-6 — `_stopRecording` sin try deja la UI en "Procesando…" eterno
- **QUÉ:** `home_screen.dart:368` setea `_isStoppingRecording=true`, `:381` hace `await stopRecording()` sin try; si `recorder.stop()` lanza, el flag y `_isTranscribing` jamás se resetean. Los llamadores (`:93 _handleBubbleTap`, `:189 _toggleRecording`) tampoco capturan.
- **OCASIONA:** pantalla atascada en transcribiendo con botón muerto; única salida reiniciar la app. El mismo patrón (clipboard sin try, `history_list.dart:71`, `home_screen.dart:406,454,578`) convierte un fallo de portapapeles en "error de red" falso y encima `transcribe()` ya borró el audio → Grabación válida perdida + reintento que falla con "archivo no encontrado".

## CR-7 — Casts duros sin try en el path de transcripción → crash no clasificado
- **QUÉ:** `cloud_stt_service.dart:104-105` (`jsonDecode as Map`, `decoded['text'] as String`), `transcription.dart:17` (`DateTime.parse(json['timestamp'] as String)`), `MultipartFile.fromPath` fuera del guard (`cloud_stt_service.dart:89`).
- **POR QUÉ:** quedan fuera de `_guardNetworkCall`; un JSON inesperado/`text:null`/timestamp int/archivo borrado entre `exists()` y `fromPath` (TOCTOU) lanza `TypeError/CastError/FileSystemException` cruda.
- **OCASIONA:** "Error: type…" sin `kind`, `isRetryable` (definido pero jamás consultado por la UI — `cloud_stt_service.dart:33-34`) inútil, reintento a ciegas; en `load()` la entrada corrupta se salta en silencio → pérdida de historial.

## CR-8 — API key de Groq en texto plano + retención sin purga + backup activado
- **QUÉ:** `saveSttMirror` escribe `kb_stt_api_key` en `SharedPreferences` en claro (`storage_service.dart:506-511`, el propio comentario `:499-501` lo admite), burlando `flutter_secure_storage`. Convive con purga inexistente (funciones `purge/clear` con cero llamadores en ambos lados) y `allowBackup=true + hasFragileUserData` (`AndroidManifest.xml:12-13`); el clipboard copiado jamás se limpia (`BubbleHistoryController.kt:792-798`, `DynamicIslandController.kt:1265-1272`).
- **POR QUÉ:** tres decisiones que por separado parecen menores y juntas exponen secreto + voz del usuario a backup/root.
- **OCASIONA:** robo de cuota/facturación Groq; transcripciones que sobreviven desinstalación vía Drive sin consentimiento visible (riesgo Data Safety).

## CR-9 — Las 8 suites Python jamás corren en CI + `analyze` no es estricto → falso verde estructural
- **QUÉ:** el workflow no invoca ningún `python` (`grep -n python android.yml` vacío); el step "Analyze estricto" es `flutter analyze` pelado (sin `--fatal-infos --fatal-warnings`) sobre un `analysis_options.yaml` de 1 línea.
- **POR QUÉ:** lo verificado en local nunca bloquea un push; infos/warnings entran al APK en verde.
- **OCASIONA HOY:** el "master 10/10" y el "CI verde r111" certifican cosas distintas; una regresión que solo detecta Python llega al APK. Agravantes: `test_clipboard_suite` TEST 6/7 y `clipboard_history_multimodal_test.dart` 3/3 y `test_transcription_history` FIFO testean **mocks/simulaciones locales**, no el código real (la tautología literal `test_clipboard_suite.py:207` siempre `True`); `test_master_suite` duplica checks más débiles que sus suites (7 vs 15 asserts en snippets) en vez de delegar.

## CR-10 — Contrato roto `kb_trackpad_haptic` String-vs-Boolean → crash
- **QUÉ:** Dart guarda `String` (`storage_service.dart:212,345`), Kotlin lee `getBoolean` (`FloatingTrackpadService.kt:469`) → `ClassCastException`.
- **OCASIONA:** crash del servicio trackpad o háptico roto al mover el selector. Es el síntoma visible del problema sistémico: ~50 `getInstance()` sin caché + boilerplate prefs 12×+6× copiado a mano (ya divergido).

## CR-11 — `release` firmada con debug + `debug.keystore` versionado + `versionCode` estancado
- **QUÉ:** `app/build.gradle.kts:44-48` firma release con debug (TODO sin resolver); `debug.keystore` trackeado con password en claro; `version 1.0.0+87` fijo mientras el artefact
...[truncated 20862 chars]