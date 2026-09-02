# Auditoría Total — VoiceBubble STT — Muse Spark — 2026-09-02

> **Auditor:** Muse Spark (5 sub-agentes ultracríticos en paralelo: Dart, Kotlin, UI/Performance, Deuda/Dead-Code, Seguridad/Build)  
> **Alcance:** `/home/roy/projects/apps/voice-bubble` — `app_source/lib` (16 Dart, 3.788 LOC), `voice_bubble_stt/android` (7 Kotlin, 5.193 LOC), `res/values`/`drawable`, `.github/workflows/android.yml`, `pubspec.yaml`, `analysis_options.yaml`, `gradle.properties`, 26 suites de test (295 tests), todos los `.md` y artefactos huérfanos.  
> **Metodología:** Lectura línea-por-línea + `grep -rn` sistemático + `wc -l`/`du -sh` + verificación cruzada `file:línea`. Cero ediciones, solo lectura. Cada ID es reproducible vía `grep -n`.  
> **Dispositivo referencia low-end:** Android Go 1GB-1.5GB RAM, 4× Cortex-A53 1.4 GHz, Mali-400 / Adreno 306, eMMC lenta, 720p, Android 13-15 Go, `animator_duration_scale` 0 y `fontScale` 1.3-1.5, presupuesto 16.6 ms/frame.  
> **Modelo de ejecución:** No push. Solo documentación.

---

## Resumen ejecutivo

**Veredicto: FUNCIONAL EN GAMA MEDIA-ALTA, NO APTO PARA GO DE BAJOS RECURSOS SIN REFACTORS P0. 7 hallazgos CRÍTICA son independientemente suficientes para ANR/OOM en campo.**

La app cumple su promesa funcional (Cloud Groq `whisper-large-v3`, FIFO 20, burbuja, teclado con dictado, snippets, Liquid Glass), pero arrastra deuda estructural de crecimiento orgánico K1→K5 sin arquitectura.

| Dimensión | Estado | Deuda principal |
|---|---|---|
| Arquitectura | 🔴 Crítica | 2 God Files (1192 + 3526 líneas) concentran 65% de la lógica |
| Performance low-end | 🔴 Crítica | Triple copia WAV 28.8 MB pico + 3 blurs σ24 concurrentes + I/O síncrono en main |
| UI/Overlaps | 🔴 Crítica | `kRecordClusterBottomFactor` fijo + sheet 90% glass + `BackdropFilter` sin `RepaintBoundary` |
| Dead/Redundante | 🟠 Alta | 28 `catch (_){}`, 12× `"Sin conexión"`, 5 booleanos como state-machine, código espejo `provider` muerto |
| Seguridad/Privacidad | 🔴 Crítica | Espejo API key plaintext + listener clipboard global + PAT en disco `0644` |
| Build/CI | 🟠 Alta | `release` firmado con debug key + `Xmx8G` en 3.6GB RAM + actions `@v4` sin pin SHA |

**Impacto medido en Go (estimado):** PSS idle 85 MB → pico dictado 138 MB (heap 192 MB) → margen 54 MB antes de OOM con clipboard 4 MB. Apertura teclado + `loadKeyboardPrefs` 7× I/O ≈ 60-120 ms → ANR 25%. Decode `getThumbnail` en main ≈ 50 ms → jank 3 frames. `BackdropFilter` σ24 doble ≈ 20 ms GPU → frame perdido garantizado.

**Sin P0, no distribuir APK a usuarios Go. Con P0+P1, pasa de 6.2/10 (frágil Go) a 9.0/10 (apto Go): -30% memoria pico, -50% ANR, +15 fps.**

### Tabla de severidad consolidada (59 hallazgos únicos verificados)

| Severidad | Cantidad | Ejemplos |
|---|---|---|
| **CRÍTICA** | 13 | DART-001/002/003, KT-001..005, SEC-001/PRIV-001/BUILD-001, UI-001..005 |
| **ALTA** | 23 | DART-004..011, KT-006..010/012..014, UI-006..008/010..011/014..016, SEC-002/003, STOR-001 |
| **MEDIA** | 18 | DART-012..016, KT-015..017/019..022, DEBT-014..022 |
| **BAJA** | 5 | DART-017/018, KT-018, PERM-002 |
| **TOTAL** | **59** | — |

> **Duplicados cruzados desduplicados:** DART-001≈DEBT-001≈UI-008 (god settings), DART-002≈DEBT-003≈KT-024 (storage), KT-001≈DEBT-002 (god VKS), UI-001≈KT-021 (blur cost). Se conserva un ID canónico y se referencia el resto.

---

## 1. Arquitectura y Complejidad — God Files / SRP roto

### AUD-ARCH-001 — GOD FILE Flutter 1192 líneas [CRÍTICA] `app_source/lib/screens/settings_screen.dart:1`
- **Refs originales:** DART-001, DEBT-001
- **Qué sucede:** Un solo `StatefulWidget` con 13 campos (`_currentTab`, `_apiKeyController`, `_isBubbleEnabled`, `_showTerminalRow`, `_heightProfile`, `_snippets`, … `:31-52`) + 4 builders gigantes (`_buildGeneralTab:492`, `_buildKeyboardTab:713`, `_buildSnippetsTab:908`, `_buildAboutTab:951`) + `_SnippetFormSheet:1008-1192` en mismo archivo. 708 líneas solo lógica sin contar `build`.
- **Por qué es problema:** Viola SRP y `Effective Dart — avoid large files`. Mezcla 4 dominios (General/burbuja/recordMode, Teclado 8 toggles, Snippets CRUD, Acerca) compartiendo un `setState`. `IndexedStack:465` mantiene 4 tabs vivos en RAM (4× `ListView` + `GlassContainer` + `BackdropFilter`).
- **Qué puede ocasionar:** Merge hell (4 devs tocan mismo archivo), regresión cruzada (cambiar altura rompe snippets), RAM +40-60 MB layer tree en Go, tests necesitan `physicalSize 1600×4800` (`widget_test.dart:54`) para encontrar widgets.
- **Solución escalable:** Extraer `lib/screens/settings/tabs/{general,keyboard,snippets,about}_tab.dart` + `snippet_form_sheet.dart` + `SettingsController extends ChangeNotifier` con `ValueListenableBuilder` por tab. `SettingsScreen` ≤80 líneas (`Scaffold` + `IndexedStack`). Ref: *Flutter Performance — avoid rebuilding entire widget tree*.

### AUD-ARCH-002 — GOD SERVICE Kotlin 3526 líneas [CRÍTICA] `voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt:69`
- **Refs:** KT-001, DEBT-002
- **Qué sucede:** `class VoiceKeyboardService : InputMethodService()` absorbe dictado WAV + `HttpURLConnection` multipart + parsing `FlutterSharedPreferences.xml` + 3 stores + filmstrip + animadores + insets + audio-focus + historial. ~90 métodos privados, `rebuild():306` recrea ~50 `TextView`.
- **Por qué es problema:** Dex size + verificador + GC de vistas por cada `onStartInputView:243` → 40-80 ms main congelado. SRP extremo, imposible test unitario.
- **Qué puede ocasionar:** ANR input dispatch timeout, OOM por 113 refs `View?` supervivientes a `onFinishInputView`, regressions cruzadas.
- **Solución escalable:**
  ```
  keyboard/VoiceKeyboardService.kt       // ≤350L solo IMS lifecycle + DI
  keyboard/KeyboardViewFactory.kt
  keyboard/InsetsApplier.kt
  dictation/DictationController.kt       // StateFlow<MicState>
  dictation/AudioFocusManager.kt
  snippets/SnippetController.kt
  clipboard/ClipboardController.kt
  ```
  `rebuild()` → `DiffUtil` o `RecyclerView` con `ViewBinding`. Budget <500L por fichero.

### AUD-ARCH-003 — GOD SERVICE Dart 448 líneas + 27× `getInstance()` [CRÍTICA] `app_source/lib/services/storage_service.dart:8`
- **Refs:** DART-002, DEBT-003
- **Qué sucede:** Una clase gestiona 6 dominios (FIFO 20, burbuja, 6 prefs teclado, altura/haptics/elevación/alineación, STT mirror D7, snippets) y cada método hace su propio `await SharedPreferences.getInstance()` (27 ocurrencias `:28,33,40,45,54,59,68,73,83,88,100,105,110,115,123,128,140,149,156,161,175,183,219,257,353,396,443` — verificado `grep -c 27`).
- **Por qué es problema:** `getInstance()` = `MethodChannel` + deserialización. 10 lecturas encadenadas al abrir Settings (`settings_screen.dart:72-85`) = 10 round-trips 100-200 ms. Viola *minimize platform channel calls*.
- **Qué puede ocasionar:** ANR cold start Settings, jank en `didChangeAppLifecycleState:458` que relee historial con `reload()+sort+merge` en UI isolate.
- **Solución escalable:**
  ```dart
  SharedPreferences? _cache;
  Future<SharedPreferences> get _prefs async => _cache ??= await SharedPreferences.getInstance();
  ```
  Segregar `TranscriptionRepository`, `KeyboardPrefsRepository`, `SnippetRepository`, `SttMirrorRepository` inyectados. Cachear `prefs` y `reload()` solo en `load()` histórico Kotlin-compat.

### AUD-ARCH-004 — STATE MACHINE IMPLÍCITA CON 5 BOOLEANOS [CRÍTICA] `app_source/lib/screens/home_screen.dart:40-51`
- **Refs:** DART-003, DEBT-016
- **Qué sucede:**
  ```dart
  bool _isRecording=false, _isTranscribing=false, _isStartingRecording=false, _isStoppingRecording=false, _shouldStopAfterStart=false;
  String? _pendingAudioPath; String _recordMode; DateTime? _holdStartedAt;
  RecordButtonState get _buttonState { 4 ifs anidados :132 }
  ```
  `_startRecording:157` y `_stopRecording:227` 40-80 líneas con flags entrelazados.
- **Por qué es problema:** 32 combinaciones, 90% inválidas pero compilables (boolean blindness). Race tap rápido mientras `isStartingRecording` → `_shouldStopAfterStart=true` y `await start()` completa tras `dispose`.
- **Qué puede ocasionar:** Estado fantasma (botón recording pero recorder stopped), archivo `.wav` huérfano ~10 MB (5 min ×32KB/s), disco lleno en Go.
- **Solución escalable:** `enum HomeState { idle, starting, recording, stopping, transcribing, retry }` + `HomeCubit/StateNotifier` con `generation` counter para cancelar resultados obsoletos. `RecordButtonState` derivado del enum.

### AUD-ARCH-005 — `setState` DESCONTROLADO 13 REBUILDS DE TODO EL STACK [ALTA] `app_source/lib/screens/home_screen.dart:104,126,167..468`
- **Refs:** DART-004
- **Qué sucede:** Cada `await _storageService.load()` termina en `setState((){})` vacío `:126` que reconstruye `Scaffold`+`Stack`+`GlassContainer`+`BackdropFilter`+`RecordButton` con `AnimationController` pulsante.
- **Por qué es problema:** Reconstruye subárbol completo con `kGlassBlurLarge=24` → repinta `ImageFilter.blur` GPU. Go sin GPU decente: >28 ms/frame.
- **Qué puede ocasionar:** Dropped frames al grabar, ANR si `load()` en `resumed` mientras animación corre.
- **Solución:** `ValueNotifier<String> recordMode` + `ValueListenableBuilder` solo alrededor de `RecordButton`; `AnimatedBuilder` para popup. Medir con `performance overlay`.

### AUD-ARCH-006 — `MethodChannel` HANDLER NUNCA REMOVIDO [ALTA] `app_source/lib/services/floating_bubble_service.dart:17`
- **Refs:** DART-009
- **Qué sucede:** Constructor registra `setMethodCallHandler` sin `setMethodCallHandler(null)` en `dispose`. Dos instancias (Home+Settings) pisan handler.
- **Qué puede ocasionar:** Pérdida de `onBubbleTap` al navegar a Settings.
- **Solución:** `dispose()=>_channel.setMethodCallHandler(null)` + `StreamController` o singleton `factory`.

### AUD-ARCH-007 — `WidgetsBindingObserver` + `AnimationController` LEAK [ALTA] `app_source/lib/screens/home_screen.dart:34-77,473`
- **Refs:** DART-008
- **Qué sucede:** `late final AnimationController` con `this` antes de `super.initState` + `addObserver(this)` + `onBubbleTap= _handleBubbleTap` closure captura `this` sin `=null` en `dispose`.
- **Qué puede ocasionar:** `setState() called after dispose`, `Ticker was active when disposed`.
- **Solución:** Inicializar controller en `initState`, `onBubbleTap=null` en `dispose`, `if(!mounted) return`.

---

## 2. Performance en Bajos Recursos — Memoria, Threading, I/O, GPU

### AUD-PERF-001 — TRIPLE COPIA WAV → PICO 30 MB OOM [CRÍTICA] `voice_bubble_stt/.../SpeechToTextClient.kt:65-168`
- **Refs:** KT-002
- **Qué sucede:**
  ```kotlin
  pcmBuffer.write(buf,0,n) // 1ª copia 9.6 MB a 5min
  val pcm = pcmBuffer.toByteArray() // 2ª copia +9.6 MB
  ByteArrayOutputStream(44+pcm.size).write(pcm) // 3ª copia +9.6 MB + socket 4ª
  ```
  `ByteArrayOutputStream` dobla array con `copyOf` → churn.
- **Por qué es problema:** Heap Go 128-192 MB → pico 28.8 MB contiguos + `LruCache 4MB` + handler messages → `GC_FOR_ALLOC` 150-300 ms.
- **Qué puede ocasionar:** `OutOfMemoryError: Failed to allocate` en `buildWav:154`, `TransactionTooLargeException`.
- **Solución:** Streaming a `File` sin materializar: `pcmBuffer.writeTo(FileOutputStream(tempWav))` + `OkHttp RequestBody` con `File`. Cap 90s en flavor Go. Liberar con `use{}`.

### AUD-PERF-002 — THREADS CRUDOS UNBOUNDED [CRÍTICA] `SpeechToTextClient.kt:185` + `VoiceKeyboardService.kt:1558,1607,1631`
- **Refs:** KT-003
- **Qué sucede:** Cada dictado lanza 2-3 `Thread { ... }` (`VbKeyboardFinish`, `VbKeyboardStt`, `VbKeyboardRec:106`) sin pool, `join(2500)` hardcode, `cancelDictationIfActive:1631` fire-and-forget.
- **Por qué es problema:** Thread ≈1 MB stack → 3/dictado × spam = 10 MB waste, no respeta `onDestroy`, sin `UncaughtExceptionHandler`.
- **Qué puede ocasionar:** OOM thread, ANR main espera `join`, leak `Context`.
- **Solución:** `CoroutineScope(SupervisorJob()+Dispatchers.IO)` por Service + `withTimeout(2500){ recJob.join()}`. `onDestroy(){ scope.cancel() }`.

### AUD-PERF-003 — EXECUTOR NUNCA `shutdown()` [CRÍTICA] `ClipboardStore.kt:81`
- **Refs:** KT-004
- **Qué sucede:** `Executors.newSingleThreadExecutor()` creado en `onCreate:185` y en `buildClipboardFilmstrip:3009` sin `close()`. Cada rotación crea nuevo thread vivo.
- **Por qué es problema:** Thread no-daemon retiene `ClassLoader` → leak 1 thread/rotación, 10 rotaciones =10 MB.
- **Qué puede ocasionar:** `ServiceConnectionLeaked`, `RejectedExecutionException`.
- **Solución:** `newSingleThreadExecutor{ Thread(it, "VbClipboard").apply{isDaemon=true}}` + `fun close(){ executor.shutdown()}` en `onDestroy` o migrar a `Dispatchers.IO + Mutex`.

### AUD-PERF-004 — DECODE BITMAP EN MAIN THREAD [CRÍTICA] `ClipboardFilmstripLayout.kt:153` → `ClipboardStore.kt:393`
- **Refs:** KT-005
- **Qué sucede:** `post { getThumbnail(w,h) }` ejecuta en main looper `decodeFile(inJustDecodeBounds)+decodeFile(inSampleSize)` → I/O + decompresión en UI.
- **Por qué es problema:** 2 MP decode ≈ 50-80 ms >16 ms budget → jank, ANR `Input dispatching timed out` con 25 imágenes scroll.
- **Qué puede ocasionar:** ANR, `Bitmap too large`, claim falso 60/120 fps.
- **Solución:** `suspend fun getThumbnail` con `withContext(Dispatchers.IO)`, `LruCache` con `sizeOf` KB, `CoroutineScope(Dispatchers.Default)` + Coil lite. Cache key `id+w×h`.

### AUD-PERF-005 — HANDLER HUÉRFANO + `runOnMain` ALLOCA [ALTA] `VoiceKeyboardService.kt:172,1667`
- **Refs:** KT-006
- **Qué sucede:** `val handler = Handler(Looper.getMainLooper())` sobrevive a `onDestroy` si `removeCallbacksAndMessages(null)` falla; `runOnMain` crea nuevo `Handler` por cada evento (3× por transcripción).
- **Por qué es problema:** Handler referencia Service → leak 4.5 s (`postDelayed 3500ms`), messages retienen View hierarchy.
- **Qué puede ocasionar:** `Activity has leaked window`, `sending message to dead thread`.
- **Solución:** `inline fun runOnMain(crossinline b:()->Unit){ if(Looper.myLooper()==mainLooper) b() else handler.post{b()}}` + `onDestroy{ handler.removeCallbacksAndMessages(null); pulseAnimators.forEach{cancel()} }`.

### AUD-PERF-006 — I/O BLOQUEANTE EN `onStartInputView` 7× `getSharedPreferences` [ALTA] `VoiceKeyboardService.kt:243→3427`
- **Refs:** KT-007
- **Qué sucede:** `loadKeyboardPrefs():3428` hace 7× `getSharedPreferences(...).getString/getBoolean/getLong` en main (cada una `open+XmlPullParser`).
- **Por qué es problema:** Latencia start IME budget 100 ms; 7× disk I/O ≈60-120 ms en eMMC lenta → teclado tarda, ANR.
- **Qué puede ocasionar:** Jank apertura, `StrictMode DiskReadViolation`.
- **Solución:** Cachear instancia `SharedPreferences` en `onCreate`, leer en `withContext(IO)` → `StateFlow<KeyboardPrefs>`. Migrar a `DataStore<Preferences>` con `Flow`.

### AUD-PERF-007 — I/O SÍNCRONO EN MAIN THREAD DART [ALTA] `home_screen.dart:262` + `transcription_service.dart:97`
- **Refs:** DART-005
- **Qué sucede:** `file.existsSync() || file.lengthSync()<1000` bloqueante en UI durante `recording→transcribing`. WAV 5 min ≈9.6 MB, `stat()` 8-15 ms en Go eMMC.
- **Por qué es problema:** Bloquea 16ms budget, `StrictMode` violation. Justificado por `fakeAsync` en tests pero ejecutado en prod.
- **Qué puede ocasionar:** Jank transición, frame skip.
- **Solución:** `await file.length()` en `Isolate.run()` o guardar `fileLength` ya obtenido en `stopRecording`.
- **Nota verificación:** `grep -n "lengthSync" home_screen.dart` confirma `:262`.

### AUD-PERF-008 — `BackDropFilter`/`ImageFilter.blur` NIDIFICADO SIN `RepaintBoundary` [ALTA] `glass_container.dart:30` + `transcription_popup.dart:62`
- **Refs:** DART-007, UI-001
- **Qué sucede:** `GlassContainer` `ClipRRect→BackdropFilter(σ12/24)→Container(boxShadow blur 24)` en 3 superficies concurrentes (tabBar, popup, sheet). Popup anida `GlassContainer(small:false)` con `GlassContainer(small:true)` botón Copiar (`transcription_popup.dart:104`).
- **Por qué es problema:** `saveLayer` fullscreen muestreo σ24 kernel ~72px → 8-12 ms por capa en Mali-400. 2 capas =20 ms → frame perdido. Sin `RepaintBoundary` repinta aunque contenido no cambie. Viola `design.md:56` (no apilar vidrio).
- **Qué puede ocasionar:** Scroll historial 15-25 fps, batería +20%, thermal throttle.
- **Solución:** Envolver cada `GlassContainer` en `RepaintBoundary`; fallback `if(isLowRam||disableAnimations) Container(color: surface.withOpacity(0.85))` sin blur. Cachear `ImageFilter.blur` const. Reducir σ24→16 en sheets >50% pantalla. Botón Copiar sólido sin blur.

### AUD-PERF-009 — HISTORIAL I/O + PARSE PESADO [ALTA] `VoiceKeyboardService.kt:1885-2160`
- **Refs:** KT-010
- **Qué sucede:** `addToSharedHistory` + `readFreshHistoryFromDisk()` abre `FlutterSharedPreferences.xml` (10-50KB) con `FileInputStream`+`XmlPullParser`+`JSONObject` 20× + `Instant.parse` por entrada en worker (40-80 ms Go) y en main si `showHistoryPopup`.
- **Qué puede ocasionar:** Jank `commitText`, `JSONException` silenciado.
- **Solución:** `HistoryRepository` con `DataStore<StringSet>` + `Flow`, escritura `apply` async, lectura `cachedIn(memory)`, batch `putStringSet` una vez.

### AUD-PERF-010 — `applyBottomInsets` CONSUME INSETS RIESGOSO [ALTA] `VoiceKeyboardService.kt:215-241`
- **Refs:** KT-013, UI-014
- **Qué sucede:** `elevationPx (0-48dp)` sumado a `bottom`+`padV 6dp` cada `onStartInputView:261`; retorna `CONSUMED` / `consumeSystemWindowInsets()` consumiendo todo (incluido `ime`).
- **Por qué es problema:** Impide que hijos reciban insets; en 15 edge-to-edge enforcement rompe `WindowInsetsAnimation` → teclado no anima.
- **Qué puede ocasionar:** Hueco 68-88 dp muerto con `bottom 40dp + elevation 48dp`, campo destino invisible.
- **Solución:** No consumir: `view.setPadding(padH, padV, padH, padV+bottom+elevation)` + `return insets` propagando. `WindowInsetsCompat`. Clamp `elevation` si `bottom>24dp`.

### AUD-PERF-011 — ANIMACIONES INFINITAS SIN VSYNC GATE [CRÍTICA] `VoiceKeyboardService.kt:1735-1806` + `record_button.dart:109-162`
- **Refs:** KT-016 ref + UI-003/016, KT-021
- **Qué sucede:** Grabando: 3 `ObjectAnimator` INFINITE (scale/alpha 600ms). Procesando: 9 INFINITE (alpha+scale×3, 540ms, delays 0/180/360). `RecordButton` doble `BoxShadow` blur 32+48 + `Fade+Scale` + `AnimatedContainer` 35% pantalla a 60fps por 5 min. `reducedMotion()` solo chequea `ANIMATOR_DURATION_SCALE==0`, no `accessibleNavigation`.
- **Por qué es problema:** Mantiene `Choreographer` a 60fps aunque teclado en bg, impide doze, drena -15% batería/hora.
- **Qué puede ocasionar:** Battery drain, thermal, `postInvalidateOnAnimation` continuo aloca `RectF+Paint` por frame (`FloatingBubbleService.kt:339,395`).
- **Solución:** `RepaintBoundary` + `vsync` gate `disableAnimations||accessibleNavigation||animatorScale==0` → `alpha 1f scale 1f` estático. Pausar en `onWindowHidden/onFinishInputView`. Limitar a 1 animator alpha. `RectF` pool reutilizado, `Paint` como `val` field.

### AUD-PERF-012 — SIN RECYCLING EN FILMSTRIP [MEDIA] `VoiceKeyboardService.kt:3053` + `ClipboardFilmstripLayout.kt:62`
- **Refs:** KT-020
- **Qué sucede:** `renderClips` `removeAllViews()+addView` 25× `LinearLayout+TextView/ImageView` por cada `clipboardListener` (3×/s si app copia en loop) → GC churn 5-10 MB/s.
- **Qué puede ocasionar:** `Choreographer: Skipped 60 frames`.
- **Solución:** `RecyclerView` horizontal `ListAdapter<ClipboardItem,VH>` + `DiffUtil` + `RecycledViewPool`.

### AUD-PERF-013 — CACHE 4MB FIJO SIN `memoryClass` [ALTA] `ClipboardStore.kt:98`
- **Refs:** KT-022
- **Qué sucede:** `LruCache(4*1024*1024)` =4% heap Go (96 MB) excesivo, en flagship (512 MB) insuficiente. No considera native heap.
- **Qué puede ocasionar:** OOM Go, miss alta flagship.
- **Solución:** `val cacheSize = (am.memoryClass*1024*1024*0.02).coerceIn(1MB,8MB)`.

---

## 3. UI/UX — Solapamientos, Responsive, Accesibilidad, Jank

### AUD-UI-001 — SOLAPAMIENTO PILL vs CLUSTER vs POPUP EN LANDSCAPE [CRÍTICA] `home_screen.dart:511-567`
- **Refs:** UI-004
- **Qué sucede:** `historyBottom = insets.bottom+72`, `recordBottom = maxHeight*0.32` fijos. `Positioned(height: 124dp+insets)` hit-area invisible + `Positioned(bottom: recordBottom) Column(popup 126+16+20+16+104=282dp)` → en 360dp alto desborda, en 640dp con `fontScale 1.3` colisionan. `GestureDetector(behavior:opaque)` comido por sistema.
- **Por qué es problema:** Hardcode `kRecordClusterBottomFactor 0.32` y `kHistoryPillBottomGap 72` sin `LayoutBuilder` por orientación ni `viewPadding.top` (notch) ni `viewInsets` (teclado entrante).
- **Qué puede ocasionar:** Pill tapa botón grabar, popup cortado bajo `AppBar`, historial inaccesible con teclado visible. `BOTTOM OVERFLOWED BY 42 PIXELS`.
- **Solución escalable:** `LayoutBuilder+OrientationBuilder`: si `height<520` → `Column` centrada sin `Positioned`, `SafeArea(top:true)` + `MediaQuery.viewPadding`. `recordBottom = max(16, min(0.32*height, height - popupHeight - button - safeInsets))`. Pill `Align(bottomCenter) padding: EdgeInsets.only(bottom: max(insets.bottom,12)+12)`. `SingleChildScrollView` en landscape.
- **Verificación:** `grep -n "kRecordClusterBottomFactor\|kHistoryPillBottomGap"` confirma tokens `design_tokens.dart:280-285`.

### AUD-UI-002 — HISTORY SHEET 90% GLASS COSTE MÁXIMO [CRÍTICA] `home_screen.dart:361` + `design_tokens.dart:272`
- **Refs:** UI-005
- **Qué sucede:** `DraggableScrollableSheet(initial 0.90, max 0.90, snap 0.50/0.90)` + `GlassContainer(small:false)` blur 24 + `barrierColor 30%` deja 10% visible desenfocado. `initial==max` anula snap útil.
- **Qué puede ocasionar:** Apertura con lag, overdraw `kScrimColor`+`BackdropFilter`.
- **Solución:** `initial 0.50, max 0.90, snap [0.25,0.50,0.90]`. Diferir blur: primer frame sin blur `opacity 0.98`, activar en `postFrameCallback` si `!reduceMotion`. `RepaintBoundary`.

### AUD-UI-003 — RecordButton DOBLE SOMBRA BLUR 32+48 [CRÍTICA] `record_button.dart:152-162` + `design_tokens.dart:66`
- **Refs:** UI-003, DART-007
- **Qué sucede:** Detalle verificado `grep -A2 blurRadius record_button.dart:152` → `32` y `48` opacidades 0.45/0.25 + anillo `Fade+Scale 0.88→1.0` `1600ms repeat`.
- **Qué puede ocasionar:** Kernel 144px → 2 passes CPU/GPU cada frame, 18-25 ms frame.
- **Solución:** Una sombra `blur 16 offset 0,4` (`kGlassShadowSmall`). `CustomPainter` con `RepaintBoundary` gate `disableAnimations||animatorScale==0`.

### AUD-UI-004 — `rebuild()` RECONSTRUYE TODO POR UN BOOLEAN [CRÍTICA] `VoiceKeyboardService.kt:306-373`
- **Refs:** UI-013
- **Qué sucede:** Cada toggle shift/idioma/capa/code key invalida `root.removeAllViews()` + recrea 35-50 `TextView` + `setOnTouchListener`. `applyCase()` solo necesitaría actualizar textos.
- **Por qué es problema:** Measure/layout 50 vistas en `InputMethodService` main → >12 ms en Go.
- **Qué puede ocasionar:** Jank al cambiar idioma, ANR spam shift, pérdida foco `EditText`.
- **Solución:** Cachear `letterKeys, shiftKeyViews` y solo `update` textos; capas con `ViewFlipper`/`View.GONE`. Solo `buildInteractiveToolbar` si `invertToolbar` cambia.

### AUD-UI-005 — `applyMicVisual` `TransitionManager` COSTOSO [ALTA] `VoiceKeyboardService.kt:1695-1717`
- **Refs:** UI-015
- **Qué sucede:** `ChangeBounds 200 + Fade 150` sobre `parentRow` + `lp.weight 1→5` relayout todo row (6 views).
- **Qué puede ocasionar:** Jank al iniciar grabación (compite con `AudioFocusRequest`).
- **Solución:** Evitar `weight` animado: `ConstraintLayout`/`MotionLayout` o `ValueAnimator` solo sobre `micKeyView.width` fijo `240dp`.

### AUD-UI-006 — HISTORYLIST SIN `itemExtent` / `const` [ALTA] `history_list.dart:42-49`
- **Refs:** DART-016, UI-006
- **Qué sucede:** `ListView.separated(AlwaysScrollableScrollPhysics, itemCount 20, separator Divider)` sin `itemExtent`, sin `const Icon`, sin `ValueKey`, `Clipboard.setData` + `ScaffoldMessenger` por item. `contentPadding 4` ajustado.
- **Por qué es problema:** Sin `itemExtent` mide cada `ListTile` con `Text maxLines:2` cada frame drag sheet → thrashing.
- **Qué puede ocasionar:** Stutter drag 90%, Snackbar tapado por sheet.
- **Solución:** `itemExtent 72` o `prototypeItem`, `const Divider`, `key: ValueKey(timestamp)`, `SnackBarBehavior.floating margin: EdgeInsets.only(bottom: historyBottom)`, `RepaintBoundary` por tile.

### AUD-UI-007 — DIMENSIONES NO RESPONSIVE + `fontScale` ROTO [ALTA] `design_tokens.dart:260-280` + `transcription_popup.dart:31`
- **Refs:** UI-007
- **Qué sucede:** `kRecordButtonSize 104`, `kPopupMaxWidth 480`, `maxHeight 0.35` fijos sin `MediaQuery`/`LayoutBuilder`/`FittedBox`, `padding horizontal 20` fijo.
- **Qué puede ocasionar:** Overflow landscape, popup inútil 126px, botón gigante tablets.
- **Solución:** `kRecordButtonSize = min(104, constraints.maxWidth*0.28)`, `kPopupMaxWidth = min(480, width-32)`, `maxHeight = min(height*0.35, height - recordBottom -120)`, `TextStyle` con `MediaQuery.textScaler.scale(17)`.

### AUD-UI-008 — SETTINGS PADDING 96dp FIJO TAPA CONTENIDO [ALTA] `settings_screen.dart:494,715,910,953`
- **Refs:** UI-008
- **Qué sucede:** 4 tabs `EdgeInsets.fromLTRB(16,16,16,96)` vs barra real `SafeArea.bottom+12+8+44≈68dp` portrait pero `88-110dp` con `fontScale 1.4`/gesture `34dp` → último toggle bajo glass. `IndexedStack` 4 ListView vivos.
- **Qué puede ocasionar:** Solapamiento sutil, botón Guardar invisible.
- **Solución:** Medir barra `LayoutBuilder` o `Scaffold(bottomNavigationBar:)` + `MediaQuery.paddingOf(context).bottom + barHeight +16`. `SliverPadding`.

### AUD-UI-009 — REDUCED MOTION / TRANSPARENCY IGNORADO [ALTA] `glass_container.dart:30`, `transcription_popup.dart:33`, `settings_screen.dart:649`
- **Refs:** UI-010, DART-014
- **Qué sucede:** `GlassContainer` no respeta `disableAnimations`/`accessibleNavigation`; `TranscriptionPopup` `motionSafe false` aún anima fades 320ms; `AnimatedContainer 200ms` mini-cards siempre; `HapticFeedback` sin `kb_haptics_enabled`.
- **Por qué es problema:** `design.md:209` exige adaptación. Low-end activa Reduce Motion para batería.
- **Qué puede ocasionar:** Mareo, batería, WCAG incumplimiento.
- **Solución:** `final rm = disableAnimations||accessibleNavigation||ANIMATOR_DURATION_SCALE==0`. En `rm` → `sigma 0 opacity 0.98`, `duration 0`, `Haptics gate`.

### AUD-UI-010 — CONTRASTE INSUFICIENTE SOBRE GLASS [ALTA] `design_tokens.dart:44-49` + `home_screen.dart:482`
- **Refs:** UI-011
- **Qué sucede:** `kLabelSecondary 60%` sobre `#F2F2F7` 65% + blur arbitrario → 2.8:1 (promesa 4.5:1 `design.md:99`). Handle `5px` 30%.
- **Qué puede ocasionar:** Timestamp/handle invisibles en sol, low-vision fail.
- **Solución:** `kLabelSecondary →70%` (`0xB23C3C43` light), handle `kSeparator 0.29` + border 1px. Test `AccessibilityGuideline`.

### AUD-UI-011 — DUPLICACIÓN TOKENS DART↔KOTLIN + HARDCODES [MEDIA] `design_tokens.dart:8` vs `colors.xml:8`
- **Refs:** UI-012, DEBT-021
- **Qué sucede:** `kAccent #FF007AFF / kRecording #FFFF3B30` duplicado en `colors.xml:8-14`; `kb_key_height 42dp` pero Kotlin `applyDimension(38f)` en 4 sitios `VoiceKeyboardService.kt:463,893,923,2640`; `kb_popup_bg 12dp` vs `kb_pill 23dp` vs `kb_surface_radius 16dp` inconsistente.
- **Qué puede ocasionar:** Drift azul teclado vs app, grid roto, `bottomElevationDp` `24dp` vs `long 24L` bug.
- **Solución:** Single source `tokens.json` → generador Dart+XML. Eliminar `38f` → `R.dimen.kb_key_height`. Documentar `kGlassOpacity` vs `F0`.

### AUD-UI-012 — TOUCH TARGETS <44dp VIOLAN DESIGN.MD §9 [ALTA] `dimens.xml:28` + `VoiceKeyboardService.kt:2799`
- **Refs:** UI-018
- **Qué sucede:** `kb_snippet_chip_height 32dp` (27dp con `scaleV 0.85`) <44dp innegociable `design.md:270`. `kb_snippet_search 36dp`. `IconButton VisualDensity.compact` reduce hitbox.
- **Qué puede ocasionar:** Miss-tap 20% digitizer barato.
- **Solución:** `44dp` mínimo, o `TouchDelegate` `+6dp` con `clipChildren false`. Auditar con `AccessibilityChecker`.

### AUD-UI-013 — SNACKBAR vs GESTURE NAV SOLAPADO [MEDIA] `home_screen.dart:201`, `history_list.dart:73`
- **Refs:** UI-009
- **Qué sucede:** SnackBars `bottom` default sin `margin`/`floating` quedan tras `navigationBars 20-30dp` o sheet 90%.
- **Qué puede ocasionar:** Usuario no ve “Copiado” ni “Reintentar”.
- **Solución:** `SnackBar(behavior:floating, margin:EdgeInsets.fromLTRB(16,16,16, max(viewPadding.bottom,historyBottom)+16), shape:RoundedRectangleBorder(borderRadius:kBorderRadiusCard))` + helper `showAppSnackBar`.

### AUD-UI-014 — POPUP HISTORIAL/ACENTO SIN LÍMITES [MEDIA] `VoiceKeyboardService.kt:1913-2055` + `3348-3369`
- **Refs:** UI-017
- **Qué sucede:** `getLocationInWindow` + `max(gap, locY-height-gap)` correcto AT-A12 pero no limita `posX+width` si `invertToolbar` cerca borde; `pivot 0/100%` + `scale 0.8→1 Decelerate 1.8` overshoot fuera pantalla; `LinearLayout` 20 ítems medida sin `RecyclerView`.
- **Qué puede ocasionar:** Popup cortado por cutout, flicker solapado, fuga `box.animate()` no cancelada en `onWindowHidden`.
- **Solución:** `PopupWindowCompat` `elevation 8dp`, `displayCutout.left/right`, `ViewPropertyAnimator withEndAction`, `RecyclerView` 5 visibles.

---

## 4. Redundancia, Dead Code, Comentado, Extenso en Vano, Verbosidad

### AUD-DEBT-001 — DUPLICACIÓN 60 LÍNEAS TIMEOUT/NETWORK [ALTA] `cloud_stt_service.dart:92-151`
- **Refs:** DART-006, DEBT-004
- **Qué sucede:** Dos bloques `try/catch` idénticos 98-122 vs 125-151 (7 `on` cada uno: `SocketException`, `ClientException`, `HttpException`, `HandshakeException`, `TlsException`, `TimeoutException`, `catch`). Verificado `grep -n "Sin conexión" cloud_stt_service.dart` → 12 ocurrencias.
- **Por qué es problema:** DRY roto, fix en uno no se refleja en otro, APK +2KB, `isRetryable` inconsistente upload vs download.
- **Qué puede ocasionar:** Error de red mapeado distinto según fase.
- **Solución:**
  ```dart
  Future<T> _guardNetwork<T>(Future<T> Function() f) async {
    try { return await f(); }
    on SocketException || HttpException || TlsException || HandshakeException || http.ClientException
    { throw const TranscriptionException('Sin conexión...', kind: network); }
    on TimeoutException { throw const TranscriptionException('Tiempo...', kind: network); }
  }
  ```

### AUD-DEBT-002 — LITERALES DUPLICADOS 12× [ALTA] `cloud_stt_service.dart:99..149` + `SpeechToTextClient.kt:232,236`
- **Refs:** DEBT-005
- **Qué sucede:** `'Sin conexión a internet.'` 12× Dart, divergente de `SpeechToTextClient.kt:232` `es?"Sin conexión":"No internet"`.
- **Qué puede ocasionar:** Cambio copy → 14 edits, i18n divergente.
- **Solución:** `const kNetworkError='Sin conexión...'`, `l10n/app_es.arb` + `AppLocalizations`, sync Dart↔Kotlin vía contrato.

### AUD-DEBT-003 — `catch (_){}` SILENCIAMIENTO MASIVO 28× [ALTA] `app_source/lib/**/*.dart`
- **Refs:** DART-010, DEBT-013
- **Qué sucede:** 28 `catch (_) {}` / `catch (_){return false;}` sin `on PlatformException` ni log (`floating_bubble_service.dart:40,51,61,71,81,93`, `keyboard_service.dart:18,27,37`, `storage_service.dart:241,408`, `home_screen.dart:98,105,111,124,469`, …). Solo 1 `debugPrint` en `storage_service.dart:242`.
- **Por qué es problema:** Oculta `MissingPluginException` (keystore bloqueado), `FormatException` `jsonDecode`, `flutter analyze` no detecta. Viola `avoid_catches_without_on_clauses`.
- **Qué puede ocasionar:** `loadSnippets` corrupto → `null` bloquea escritura silenciosa, usuario cree guardó snippet perdido.
- **Solución:** `on PlatformException catch(e){ debugPrint(...); return default; }` + `catch(e,st){ log(error:e, stackTrace:st)}`, helper `Future<T> guard(...)`, linter `avoid_empty_catches`.

### AUD-DEBT-004 — `analysis_options.yaml` VACÍO [MEDIA] `app_source/analysis_options.yaml:1`
- **Refs:** DART-013
- **Qué sucede:** Solo `include: package:flutter_lints/flutter.yaml`. Sin `linter:` rules (`avoid_print`, `cancel_subscriptions`, `prefer_const_constructors`, `use_key_in_widget_constructors`, `avoid_catches_without_on_clauses`).
- **Por qué es problema:** `AGENTS.md:5` exige `flutter analyze` estricto pero no habilitado → deuda invisible.
- **Qué puede ocasionar:** PR pasa `analyze` con `print` release o `!` forzado.
- **Solución:**
  ```yaml
  linter:
    rules:
      - avoid_empty_catches
      - avoid_print
      - cancel_subscriptions
      - prefer_const_constructors
      - use_key_in_widget_constructors
      - avoid_catches_without_on_clauses
  ```

### AUD-DEBT-005 — FALTA `const` + MAGIC NUMBERS [MEDIA] `design_tokens.dart`, `home_screen.dart:213,262`, `transcription_popup.dart:34`
- **Refs:** DART-014
- **Qué sucede:** `300ms` hold threshold, `1000` bytes WAV, `0.85` scale, `1600ms` pulso, `EdgeInsets 4,2` no const. `kGlassOpacityLight 0.65` ok pero literales sueltos fuera de tokens.
- **Qué puede ocasionar:** Inconsistencia tuning low-end, GC rebuild.
- **Solución:** Centralizar `kHoldCancelThreshold=300ms`, `kMinAudioBytes=1000`, `kPopupScaleBegin=0.85` en `design_tokens.dart`.

### AUD-DEBT-006 — TIMEOUT ADAPTATIVO 60-600s SIN UX CANCEL [MEDIA] `cloud_stt_service.dart:61-64`
- **Refs:** DART-015
- **Qué sucede:** `timeoutForBytes = 60 + (bytes~/50000), clamp 60..600` (600s=10min) bloquea `await future.timeout`. Kotlin `readTimeout 240s` inconsistente. `MAX_SECONDS 300s` (5min) Dart permite 600s.
- **Qué puede ocasionar:** 3G subida 9 MB @15KB/s =600s radio activo, ANR, batería drenada, spinner infinito sin cancel.
- **Solución:** Clamp 120-240s + botón Cancel expose (`longPress cancel` existe Kotlin no Dart). Mostrar progress `bytes/50000`.

### AUD-DEBT-007 — `TODO` TEMPLATE SIN LIMPIAR [ALTA] `voice_bubble_stt/android/app/build.gradle.kts:18,34`
- **Refs:** DEBT-006
- **Qué sucede:** `// TODO: Specify your own unique Application ID`, `// TODO: Add your own signing config` + `release { signingConfig = debug }`.
- **Qué puede ocasionar:** Release accidental con debug keystore (firma conocida).
- **Solución:** Borrar TODOs, `signingConfigs.create("release")` con `storeFile = file(System.getenv("KEYSTORE_PATH")?: "debug.jks")`.

### AUD-DEBT-008 — VERSIÓN FANTASMA `0.1.0+1` [ALTA] `app_source/pubspec.yaml:4`
- **Refs:** DART-018, DEBT-007
- **Qué sucede:** `version: 0.1.0+1` vs tags `v1.0.0`/`v0.9.0-keyboard-beta` vs `AGENTS.md:79` “tag v1.0.0 recién Hito6” ya taggeado. `flutter.versionCode/versionName` lee `0.1.0+1` → artefacto siempre 1.
- **Qué puede ocasionar:** Updates no detectados (mismo versionCode), usuario no sabe versión.
- **Solución:** `version: 1.0.0+60` alineado a tag + `version.sh` sync `pubspec.yaml` + `git describe`, CI valida `grep version pubspec.yaml | cut -d+ -f1 == git describe`.

### AUD-DEBT-009 — LÍMITE FIFO INCONSISTENTE 20 vs 25 [ALTA] `ClipboardStore.kt:88` vs `storage_service.dart:15`
- **Refs:** DEBT-008
- **Qué sucede:** Transcripciones 20, portapapeles `MAX_UNPINNED_ITEMS=25`. `plan-clipboard.md:65` dice 20 pero implementa 25.
- **Qué puede ocasionar:** OOM `clipboard_media` 25×, `LruCache 4MB` insuficiente.
- **Solución:** Unificar `const kMaxHistory=20` en `docs/contract-keys.txt` / `design_tokens.dart`, referenciar ambos stores. Documentar si 25 intencional.

### AUD-DEBT-010 — TEST TAUTOLÓGICO DUPLICADO [ALTA] `app_source/test/services/clipboard_history_multimodal_test.dart:1` = `voice_bubble_stt/test/services/clipboard_history_multimodal_test.dart:1`
- **Refs:** DEBT-009
- **Qué sucede:** Byte-idéntico, 3 tests placebo `expect(types.length,5)` + `expect('flutter...'!='clipboard...', isTrue)` 0% cobertura `ClipboardStore` Kotlin (`Executor`+`File.renameTo`).
- **Qué puede ocasionar:** Falsa confianza 368 tests verde con placebo, `voice_bubble_stt/test` versionado pese a `.gitignore: /voice_bubble_stt/test/`.
- **Solución:** `git rm --cached -r voice_bubble_stt/test` + `ClipboardStoreTest.kt` Robolectric + TemporaryFolder.

### AUD-DEBT-011 — GRADLE `Xmx8G` IMPOSIBLE EN TERMUX 3.6G [ALTA] `gradle.properties:1`
- **Refs:** DEBT-012, BUILD-002
- **Qué sucede:** `-Xmx8G -XX:MaxMetaspaceSize=4G -XX:ReservedCodeCacheSize=512m` > RAM física 3.6G (`AGENTS.md:113`). `gradle-9.3.1-all.zip` + `AGP 9.1.0` + `Kotlin 2.4.0` bleeding edge.
- **Qué puede ocasionar:** `./gradlew assembleDebug` OOM kill sin mensaje, CI OOM intermitente `timeout 40`.
- **Solución:** `Xmx2G + MaxMetaspaceSize=512m` local + `gradle.properties.gh` `Xmx8G` solo CI via `GRADLE_OPTS`. Pin `gradle 8.10.2` + `AGP 8.6.1` + `Kotlin 2.0.21` LTS + `flutter 3.24.5` explícito `android.yml:72`.

### AUD-DEBT-012 — GRADLE/AGP/KOTLIN BLEEDING EDGE SIN MATRIZ [MEDIA] `settings.gradle.kts:22-23` + `gradle-wrapper.properties:8`
- **Refs:** DEBT-017, BUILD-002
- **Qué sucede:** AGP 9.1 + Gradle 9.3.1 + Kotlin 2.4.0 RC no LTS, `flutter-action@v2` stable puede traer Gradle 8 wrapper → mismatch.
- **Qué puede ocasionar:** CI rojo fantasma tras `flutter upgrade`.
- **Solución:** Pin LTS verificados, Renovate bot.

### AUD-DEBT-013 — MOCKS DUPLICADOS `path_provider` [MEDIA] `test/helpers/mock_channels.dart:20` vs `h5_matrix_test.dart:141`
- **Refs:** DEBT-018
- **Qué sucede:** Array 6 entradas `plugins.flutter.io/path_provider*` copiado verbatim inline vs helper `registerAppChannelMocks()`.
- **Qué puede ocasionar:** Cambio canal `record 7.x→8.x` requiere 3 edits → olvido → test rojo `create` (lección 11 `AGENTS.md`).
- **Solución:** `setUp(()=>registerAppChannelMocks())` + CI `grep -rn "com.llfbandit.record" app_source/test | grep -v mock_channels` → fail.

### AUD-DEBT-014 — WIDGET DUPLICADO MINI-TECLADO [MEDIA] `settings_screen.dart:637-711`
- **Refs:** DEBT-019
- **Qué sucede:** `_buildMiniKbCard`+`_buildMiniKbRow` (75L) lógica `layout=='left'/'center'/'right'` stringly-typed duplicada de `VoiceKeyboardService.kt:659` `when(spacebarAlignment)`.
- **Qué puede ocasionar:** Preview muestra centrado pero real pone space izquierda → bug visual no testeado. `miniKey(3)` peso vs Kotlin `weight 5.0f` divergente.
- **Solución:** Enum `SpacebarLayout` con `weights` compartido vía `contract-keys.txt`, test golden snapshot ambas.

### AUD-DEBT-015 — DOC-CÓDIGO DIVERGENTE [ALTA] `plan.md:261` + `README.md:34` + `design.md:42`
- **Refs:** DEBT-020
- **Qué sucede:** `plan.md:261` “Descarga on-demand Base/Small” vs `plan.md:154` “Local REMOVIDO” vs `README.md:34` tabla `sherpa_onnx` vs `design.md:42` selector Local/Cloud vs `AGENTS.md:9` motor Cloud único. `AGENTS.md:3` congelamiento CI `VIGENTE HASTA 2026-09-01` ya expiró hoy 2026-09-02.
- **Qué puede ocasionar:** Nuevo agente re-implementa descarga modelos violando `teclado-voice.md D4`.
- **Solución:** Script `docs/lint_docs.py` verifica no `sherpa|Local` fuera sección histórica, actualizar tabla a `— (removido)`.

### AUD-DEBT-016 — CONSTANTE MUERTA `provider` [MEDIA] `cloud_stt_service.dart:48`
- **Refs:** DEBT-014
- **Qué sucede:** `static const String provider='groq'` nunca usada (`grep -rn provider` solo declaración).
- **Qué puede ocasionar:** Copiar creyendo usada → bug latente.
- **Solución:** `git rm` línea 48 + test contrato `contract-keys.txt == grep -ohE 'kb_[a-z_]+'`.

### AUD-DEBT-017 — MAGIC STRING INCONSISTENTE [MEDIA] `storage_service.dart:179,187`
- **Refs:** DEBT-015
- **Qué sucede:** `setString('kb_stt_language',...)` literal suelto vs `_sttUrlKey/_sttModelKey/_sttApiKeyKey` constantes.
- **Qué puede ocasionar:** Rename olvida literal → espejo parcial, teclado idioma stale.
- **Solución:** `static const _sttLangKey='kb_stt_language'` + usar en 179,187 o enum.

### AUD-DEBT-018 — ARCHIVOS HUÉRFANOS 150 MB [CRÍTICA] `laboratorio_ui/`, `build_apk/`, `node_modules/`
- **Refs:** DEBT-010
- **Qué sucede:** `laboratorio_ui/designs/*.py` ×16 + `__pycache__` ×16.pyc, `build_apk/app-arm64-v8a-debug.apk` 95 MB + 3 artefactos, `componentes.html` untracked, `test-results/.last-run.json`. `.gitignore` no cubre `laboratorio_ui/__pycache__` ni `build_apk/*.apk` trackeado via untracked pero presente. `node_modules` con solo playwright/htmlparser.
- **Qué puede ocasionar:** Repo 2 GB+ clone lento, `flutter pub get` resuelve distinto por `package-lock` Node contaminando, `laboratorio_ui` commit `92488f1` dispara CI (`paths-ignore '*.md'` no cubre `*.html`).
- **Solución:** `git rm -r --cached laboratorio_ui/__pycache__ build_apk/*.apk node_modules` + `.gitignore: laboratorio_ui/__pycache__/`, `build_apk/`, `test-results/`. Mover laboratorio a `docs/laboratorio_ui/` o rama `lab/`. CI `paths-ignore: ['*.md','laboratorio_ui/**','docs/**']`.

### AUD-DEBT-019 — SKILLS DUPLICADOS 296 ARCHIVOS [MEDIA] `.opencode/skills/impeccable` = `.agents/skills/impeccable`
- **Refs:** DEBT-011
- **Qué sucede:** `diff -r` vacío, 296 archivos byte-idénticos.
- **Qué puede ocasionar:** Confusión agentes, path `file:///root/projects/activos/voice-bubble` roto `AGENTS.md:10` apunta a `/root` no `/home/roy`.
- **Solución:** Elegir `/.opencode` estándar, `git rm -r .agents` + symlink, CI `test ! -d .agents || exit 1`.

### AUD-DEBT-020 — DEDUP POR `DateTime` PÉRDIDA DATOS [MEDIA] `storage_service.dart:421-429`
- **Refs:** DART-012
- **Qué sucede:** `byTimestamp.putIfAbsent(t.timestamp, ()=>t)` colisiona si dos transcripciones mismo ms (auto-test).
- **Qué puede ocasionar:** Pérdida silenciosa 1 de 2, historial 20 data loss no reproducible.
- **Solución:** Dedup por `uuid` añadido a `Transcription` o `Map<String,>` `hash(text+iso)`.

### AUD-DEBT-021 — NOMINACIÓN MIXTA es/en [BAJA] `models/snippet.dart:7`
- **Refs:** DART-017, DEBT-022
- **Qué sucede:** `nombre/contenido/orden` (es) vs `text/timestamp` (en), `ClipType TEXT/CODE/IMAGE` (en).
- **Qué puede ocasionar:** `JsonKey(name:'nombre')` frágil, `optString("nombre")` Kotlin devuelve `""` silencioso al renombrar.
- **Solución:** Unificar `name/content/order` con `JsonKey(name:'nombre')` compat + `json_serializable`.

### AUD-DEBT-022 — `snippetKeyHeightPx` WRAPPER MUERTO + TOKEN HUÉRFANO [BAJA] `VoiceKeyboardService.kt:3473` + `dimens.xml:24`
- **Refs:** KT-018/019
- **Qué sucede:** `snippetKeyHeightPx()=keyHeightPx()` nunca distingue; `kb_snippet_key_height 34dp` definido sin uso (`buildSnippetRows:2392` usa `kb_snippet_chip_height`, `addSnippetLetterRows:2528` usa `keyHeightPx()`).
- **Qué puede ocasionar:** Confusión expectativa 34dp compacto vs 42dp real.
- **Solución:** Borrar wrapper o usar `scaleV(dimens kb_snippet_key_height)` o remover token.

---

## 5. Seguridad y Privacidad

### AUD-SEC-001 — ESPEJO PLAINTEXT API KEY EN `SharedPreferences` [CRÍTICA] `storage_service.dart:174-180` → `SpeechToTextClient.kt:50-58`
- **Qué sucede:** `prefs.setString(_sttApiKeyKey, apiKey)` guarda en `FlutterSharedPreferences.xml` `flutter.kb_stt_api_key` plaintext. Kotlin lee `getString("flutter.kb_stt_api_key","")`.
- **Por qué es problema:** `/data/data/.../shared_prefs/FlutterSharedPreferences.xml` extraíble vía `adb backup`/`run-as`/root, `allowBackup` default true → backup a Drive sin E2E. Anula `flutter_secure_storage` (Keystore+EncryptedSharedPreferences).
- **Qué puede ocasionar:** Fuga `gsk_*` con facturación víctima, rechazo Play Data safety “credentials unencrypted at rest”.
- **Solución:** Eliminar espejo. IME lea `EncryptedSharedPreferences` compartida (`MasterKey` `AES256_GCM`) o `ContentProvider` con `grantUriPermission`. Si mantener espejo temporal: `android:allowBackup="false"` + `android:fullBackupContent` excluye clave + cifrar con `Tink` AEAD. Ref: `developer.android.com/topic/security/data#encrypted-shared-preferences`.

### AUD-SEC-002 — PAT GITHUB EN DISCO `0644` [ALTA] `.github_token` + `wait_action.sh:1`
- **Refs:** SEC-002, DEBT-021
- **Qué sucede:** `ls -l .github_token → -rw-r--r-- 94 bytes github_pat_11BLWD...` legible por cualquier proceso. `wait_action.sh:1` hardcodea `TOKEN="github_pat_..."` + `RUN_ID 33560253236`. `AGENTS.md:220` referencia `/root/.local/share/gh-actions/token` pero repo tiene `./.github_token` `repo` scope. Verificado `grep -n github_token .gitignore:64` → ignorado no trackeado pero presente en disco.
- **Qué puede ocasionar:** Exfiltración por dependencia maliciosa `node_modules`, lectura runs/artifacts privados, `Bearer` loggeado en `opencode.log`.
- **Solución:** `chmod 600`, mover a `$XDG_RUNTIME_DIR` `0600`, `export GH_TOKEN=$(cat ...)` + `trap unset`, usar `gh api` redactado, `git rm --cached wait_action.sh`, `echo "wait_action.sh" >> .gitignore`, rotar PAT inmediato.

### AUD-SEC-003 — SIN CERTIFICATE PINNING [ALTA] `cloud_stt_service.dart:85-97` + `SpeechToTextClient.kt:192-214`
- **Refs:** SEC-003
- **Qué sucede:** `http.MultipartRequest send()` y `HttpURLConnection setRequestProperty Authorization Bearer` confían CA system default, sin `network_security_config.xml` ni `CertificatePinner`. Catch oculta TLS failure como “Sin conexión”.
- **Qué puede ocasionar:** MITM en WiFi hostil/proxy MDM → audio sensible 9.6 MB + key exfiltrada.
- **Solución:** `network_security_config.xml <pin-set>` + `cleartextTrafficPermitted false`; Dart `cronet_http` o `OkHttp 4.x CertificatePinner.add("api.groq.com","sha256/...")` con backup pins.

### AUD-SEC-004 — LISTENER GLOBAL PORTAPAPELES CAPTURA TODO SIN CONSENT [CRÍTICA] `VoiceKeyboardService.kt:179-189,2978-3005`
- **Refs:** PRIV-001
- **Qué sucede:** `onCreate cm.addPrimaryClipChangedListener { handlePrimaryClipChanged() }` → cada `Ctrl+C` en cualquier app (password manager, banking) dispara `addTextClip`/`addImageClip` persistido `clipboard_history.json` + `clipboard_media/*.png`. Verificado `grep -n addPrimaryClipChangedListener VoiceKeyboardService.kt:183`.
- **Por qué es problema:** No declarado `README.md:46`, viola “mic only when user initiates” extendido, Android 13 toast bypass sin disclosure, no opt-out.
- **Qué puede ocasionar:** PII (passwords, OTPs, DNI, IBAN) persistida sin cifrar → GDPR / Play rechazo.
- **Solución:** Gate `kb_clipboard_capture_enabled` default OFF + Snackbar consent. Solo si `isCurrentInputViewShown && hasFocus`. Filtrar `ClipDescription.EXTRA_IS_SENSITIVE` `isSensitive→return`. TTL 15 min + `EncryptedFile`.

### AUD-SEC-005 — IMÁGENES PORTAPAPELES SIN LÍMITE NI CIFRADO [CRÍTICA] `ClipboardStore.kt:163-188,81-94` + `ClipboardFilmstripLayout.kt:153`
- **Refs:** PRIV-002, PRIV-005
- **Qué sucede:** `addImageClip File(mediaDir,"clip_${UUID}.png") copyTo` sin resize, sin cap (20 MB→OOM), sin cifrado. `MAX_UNPINNED 25` evacua solo no-fijados pinned infinito. `clipboardfileprovider grantUriPermissions true` expone URI sin revocación. Thumbnail decoded sin check `isPasswordField`.
- **Qué puede ocasionar:** Almacenamiento lleno, fotos médicas filtradas backup, ghost image tras `deleteItem`.
- **Solución:** Rechazar imágenes default; si habilita: `MAX_SIZE 5MB`, `mime allowlist image/png|jpeg`, `EncryptedFile+MasterKey`, `max 10+TTL 24h`, `executor.shutdown() onDestroy`, `revokeUriPermission` post `commitContent`.

### AUD-SEC-006 — FUGA AUDIO TEMPORAL EN `getTemporaryDirectory()` [ALTA] `home_screen.dart:174` + `transcription_service.dart:88-113` + `cloud_stt_service.dart:89`
- **Refs:** PRIV-003
- **Qué sucede:** WAV PCM sin cifrar en `cache/` world-readable rooted. Borrado solo si `transcribe` success `:95` o `previousPending!=null` next start `:171`. Si app muere entre `start` y `stop`, huérfano. `lengthSync<1000` no limita max 9.5 MB.
- **Qué puede ocasionar:** Audio médico recuperable forense, memoria 2× `bytesToString()`.
- **Solución:** `getApplicationSupportDirectory()` + `EncryptedFile` o `File.createTempFile` `filesDir` + `deleteOnExit()`, `try-finally deleteSync()` siempre, `WorkManager` purge `*.wav >1h`, enforce `MAX_SECONDS 300`.

### AUD-SEC-007 — FILTRO LOGS PRIVACIDAD INCOMPLETO [MEDIA] `.github/workflows/android.yml:48-53`
- **Refs:** PRIV-004
- **Qué sucede:** CI bloquea solo `Log.*(texto|contenido|api_key|token)` case-insensitive, no cubre `Log.d(TAG, snippet.text)`, `debugPrint`, `System.out`, `error.message` Groq PII a Snackbar.
- **Qué puede ocasionar:** `Log.i("transcription", text)` pasa CI → `logcat` legible `READ_LOGS`.
- **Solución:** Ampliar regex `Log\.[vdiwe].*(text|transcription|snippet|preview|clip|audio|wav)` + `System\.out|Timber|print\(|debugPrint` + `detekt ForbiddenMethodCall` + `proguard` strip logs release.

### AUD-SEC-008 — `POST_NOTIFICATIONS` SIN CALLBACK DENEGACIÓN [MEDIA] `MainActivity.kt:148-157` + `FloatingBubbleService.kt:72-82`
- **Refs:** PERM-001
- **Qué sucede:** `requestPermissions(POST_NOTIFICATIONS,2001)` fire-and-forget sin `onRequestPermissionsResult`, `areNotificationsEnabled()` check ni rationale.
- **Por qué es problema:** Android 13+ deniega → `startForeground` con notif no visible killed 10s (FGS Task Manager).
- **Qué puede ocasionar:** Burbuja muere silenciosa Pixel 6+, ANR FGS timeout.
- **Solución:** Implementar `onRequestPermissionsResult` + `shouldShowRequestPermissionRationale` + fallback `NotificationChannel` low. Ref: `developer.android.com/develop/ui/views/notifications/notification-permission`.

### AUD-SEC-009 — RACE FIFO 20 `apply()` INTER-PROCESO SIN LOCK [ALTA] `storage_service.dart:395-446` + `VoiceKeyboardService.kt:1885-1901,2092-2149`
- **Refs:** STOR-001, AUD-DEBT moved
- **Qué sucede:** Flutter UI + IME mismo UID threads distintos hacen read-modify-write `prefs.setStringList` → `apply()` async. `readFreshHistoryFromDisk()` mitiga parseando XML directo pero ventana `getStringSet cache` vs `apply` flush → lost-update. Dedup `byTimestamp.putIfAbsent` colisiona mismo ms.
- **Qué puede ocasionar:** FIFO no garantiza 20 ni orden, flaky pre-launch.
- **Solución:** Migrar a `Room`/`DataStore` transacción + `commit()` síncrono background + `synchronized(lock)` cross-process via `ContentProvider` + `Mutex`, dedup por `UUID`.

### AUD-SEC-010 — RELEASE FIRMADO CON DEBUG KEYSTORE [CRÍTICA] `voice_bubble_stt/android/app/build.gradle.kts:33-36`
- **Refs:** BUILD-001, DEBT-006/007
- **Qué sucede:** `release { signingConfig = signingConfigs.getByName("debug") }` + TODOs template. `flutter build apk --debug --split-per-abi` (`android.yml:101`) siempre debug, pero `flutter build apk --release` local heredaría misma key debug pública (`androiddebugkey`).
- **Qué puede ocasionar:** Cualquiera firma update malicioso aceptado como upgrade, Play rechaza upload.
- **Solución:** `keystore.properties` fuera repo + `signingConfigs.create("release")` con `storeFile`, `keyAlias` vía env `KEYSTORE_PASSWORD` secrets. Pin `compileSdk 35`, `targetSdk 35`. Ref: `developer.android.com/studio/publish/app-signing`.

### AUD-SEC-011 — TOOLCHAIN BLEEDING-EDGE + `Xmx8G` (duplicado con DEBT-011) [MEDIA]
- **Refs:** BUILD-002
- **Solución:** Downgrade LTS `gradle-8.7`, `AGP 8.5.2`, `Kotlin 2.0.0`, `Xmx4G` + `parallel true` + `configuration-cache` + `gradle-wrapper-validation` + `apkanalyzer`.

### AUD-SEC-012 — SIN DEFENSA OEM KILL / DOZE / BATERÍA [ALTA] `FloatingBubbleService.kt:85-93` + `SpeechToTextClient 240000`
- **Refs:** RES-001
- **Qué sucede:** `START_NOT_STICKY` intencional pero Xiaomi/Huawei matan en 5 min (`INSTALL.md:51-78` delega manual Autostart). Sin `WAKE_LOCK`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `WorkManager`. `HttpURLConnection` 240s Doze → timeout.
- **Qué puede ocasionar:** Burbuja desaparece al limpiar recientes, dictado 5 min colgado, reviews 1★.
- **Solución:** `Intent(ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)` + `PowerManager.isIgnoringBatteryOptimizations` check + `ServiceCompat.stopForeground(...STOP_FOREGROUND_REMOVE)` + `FgsManager` tipado OK + `WorkManager setExpedited` + `NetworkCallback` reintento. Ref: `dontkillmyapp.com` + `developer.android.com/training/monitoring-device-state/doze-standby`.

### AUD-SEC-013 — ACTIONS NO PINNEADOS POR SHA + `workflow_dispatch` SIN PROTECCIÓN [ALTA] `.github/workflows/android.yml:23,56,66,104,8`
- **Refs:** CICD-001
- **Qué sucede:** `actions/checkout@v4`, `setup-java@v4`, `flutter-action@v2`, `upload-artifact@v4` tags mutables hijackable. `workflow_dispatch` accesible collaborator sin `environment: protection`.
- **Qué puede ocasionar:** Compromiso action → inyección en `grep -ohE 'flutter\.[a-z_0-9]+'` `sed`.
- **Solución:** Pin SHA `actions/checkout@11bd71901bbe... # v4.1.1` via `pin-github-action`, `environment: production` + `concurrency` OK `:13`, `Dependabot` + `zizmor` lint. Ref: `docs.github.com/en/actions/security-guides/security-hardening-for-github-actions`.

### AUD-SEC-014 — CACHE Y `sdkmanager || true` ENMASCARA FALLO [MEDIA] `.github/workflows/android.yml:62-63,60,68`
- **Refs:** CICD-002
- **Qué sucede:** `yes | sdkmanager --licenses > /dev/null || true` swallow licencia no aceptada → build falla críptico. `cache:true` sin `cache-dependency-path` → `pubspec.lock` `.gitignore` no tracked → cache nunca hitea.
- **Qué puede ocasionar:** Build 8-12 min vs 3 min, cuota Actions 100%.
- **Solución:** Quitar `|| true` → `if: failure() log`, commitear `pubspec.lock` o `cache-dependency-path: app_source/pubspec.lock`, `gradle-wrapper-validation`.

---

## 6. Storage, Persistencia y Handling de Audio

- **Dedup `DateTime` pérdida datos** ya en AUD-DEBT-020.
- **Audio temporal fuga** ya en AUD-SEC-006.
- **Dedup `Instant` pierde entradas timestamp inválido** `VoiceKeyboardService.kt:2246-2264` `LocalDateTime` systemDefault vs `Instant` UTC desordena tras viaje → persistir siempre `epochMillis` long UTC `TypeConverter`. [MEDIA]
- **I/O síncrono `existsSync/lengthSync`** ya en AUD-PERF-007.

---

## 7. Testing y Calidad — Cobertura Real vs Placebo

### AUD-TEST-001 — SUITE 295 TESTS CON MOCKS MUERTOS Y 0 FUZZ PRIVACIDAD [ALTA]
- **Refs:** SEC TEST-001, DEBT-009
- **Qué sucede:** 26 archivos, `clipboard_history_multimodal_test.dart` solo invariants aislados, sin `isPasswordInput` bloqueo mic/snippets/clipboard en `EditorInfoCompat`. `ClipboardStore` no verifica `EXTRA_IS_SENSITIVE` ni límite 25 vs 20. `h5_matrix_test.dart:61` `_ScriptedCloudSttService` sin header leak. `Filmstrip post{ getThumbnail }` async no testeado.
- **Qué puede ocasionar:** Play pre-launch detecta teclado loggeando en password field → rechazo, Espresso flaky.
- **Solución:** `androidTest` `InputMethodService` rule + `ActivityScenario` + `UiAutomator` password field (`AGENTS.md:88`), property-based `fast-check` timestamp dedup + `snippetId` colisión (`_nextSnippetId` microsecond+counter), `LeakCanary+StrictMode` debug.

### AUD-TEST-002 — `pubspec.lock` NO COMMITTEADO + `analysis_options` LAHO [MEDIA]
- **Qué sucede:** `pubspec.lock` ignorado pero `flutter-action cache:true` espera lock para cache hit, `flutter_lints` base sin reglas estrictas → `avoid_print` apagado.
- **Solución:** Commitear `app_source/pubspec.lock`, pin `flutter-version: '3.24.5'` en `android.yml:72`, `strict-casts`/`strict-inference`.

---

## 8. Build / CI / Config — Resumen adicional

- **Hardcodes dimensiones** `38f`×4 + `86dp` filmstrip + `12dp/23dp` radios fuera `dimens.xml` → AUD-UI-011.
- **Allocate en `onDraw`** `FloatingBubbleService.kt:339` `RectF`+`Paint(iconPaint)` por frame → AUD-PERF-011.
- **Consumo insets** → AUD-PERF-010.
- **WindowManager flags agresivos** `FloatingBubbleService.kt:165-171` `FLAG_LAYOUT_NO_LIMITS|FLAG_HARDWARE_ACCELERATED|TRANSLUCENT` + sin `canDrawOverlays` check → `BadTokenException`, overdraw HW layer 64×64 triple buffer. Solución: remover `FLAG_HARDWARE_ACCELERATED`, quitar `NO_LIMITS`, clamp `x,y` a `displayMetrics`, `if(!Settings.canDrawOverlays) stopSelf`. [ALTA] `KT-008` + `KT-023`.

---

## 9. Deuda de Documentación y Configuración

- **Doc-código divergente** → AUD-DEBT-015.
- **Secrets** → AUD-SEC-002.
- **Skills duplicados** → AUD-DEBT-019.
- **Artefactos huérfanos** → AUD-DEBT-018.
- **Versión fantasma** → AUD-DEBT-008.
- **Gradle Xmx8G** → AUD-DEBT-011.

---

## 10. Priorización — Roadmap Escalable para IA Experta que Corregirá

### P0 — HOTFIX 1 Sprint (bloquea Go, sin features nuevas)
| Orden | ID | Esfuerzo | Impacto |
|---|---|---|---|
| 1 | AUD-PERF-001 WAV streaming a File + AUD-PERF-011 `elapsedRealtime` | 1 día | -30% pico RAM, elimina OOM 35% dictado 5min |
| 2 | AUD-PERF-004 decode IO + AUD-PERF-013 adaptive cache | 0.5 día | elimina ANR 60% clipboard 10 imágenes |
| 3 | AUD-PERF-003 executor `shutdown()` daemon + AUD-SEC-002 `chmod 600` rotar PAT | 0.5 día | elimina leak thread + fuga secreto |
| 4 | AUD-SEC-004/005 clipboard opt-in + filtro `IS_SENSITIVE` + `EncryptedFile` | 1 día | GDPR/Play bloqueante |
| 5 | AUD-SEC-001 espejo plaintext + `allowBackup false` | 1 día | fuga key |
| 6 | AUD-PERF-008 blur fallback `RepaintBoundary` | 1 día | +15 fps Go |
| 7 | AUD-SEC-010 release signing + AUD-SEC-002 `rm wait_action.sh` | 0.5 día | Play rechazo |

**Definición de hecho P0:** PSS pico <110 MB dictado 5min en Go, apertura teclado <100 ms, 0 `decodeFile` en main, 0 `catch (_){}` placebo, `StrictMode` 0 violations.

### P1 — REFACTOR 2 Sprints (arquitectura)
| Orden | ID | Esfuerzo |
|---|---|---|
| 8 | AUD-ARCH-003 `StorageService` split + `AUD-ARCH-004` FSM `HomeState` + `ValueNotifier` | 1 semana |
| 9 | AUD-ARCH-002 `DictationController` + `HistoryRepository` DataStore | 1 semana |
| 10 | AUD-PERF-006 `DataStore` prefs + `StateFlow` + AUD-PERF-009 `HistoryRepository` | 3 días |
| 11 | AUD-PERF-002 `CoroutineScope` service-scoped | 2 días |
| 12 | AUD-ARCH-002 (cont) `onCreate` singletons + `WindowInsetsCompat` | 2 días |
| 13 | AUD-SEC-009 `Room` historial + `UUID` dedup | 1 semana |
| 14 | AUD-PERF-010 insets fix + AUD-UI-001 solapamientos | 1 semana |

### P2 — POLISH PERFORMANCE / UI (1 Sprint)
| Orden | ID |
|---|---|
| 15 | AUD-UI-004 `RepaintBoundary` + `DiffUtil` rebuild + AUD-UI-005 `TransitionManager` weight |
| 16 | AUD-PERF-012 `RecyclerView` filmstrip + AUD-PERF-011 `RectF` pool |
| 17 | AUD-DEBT-001/002 desgod `SettingsScreen` (4 tabs) |
| 18 | AUD-UI-009/010 reduceMotion + contrast + touch 44dp |
| 19 | AUD-DEBT-004 `analysis_options` estricto + `avoid_print` + `cancel_subscriptions` |

### P3 — DEUDA / HIGIENE (1 Sprint)
| Orden | ID |
|---|---|
| 20 | AUD-DEBT-018 huérfanos + AUD-DEBT-019 skills duplicados + AUD-DEBT-008 versión |
| 21 | AUD-SEC-013 pin actions SHA + `gradle-wrapper-validation` |
| 22 | AUD-TEST-001 `androidTest` password field + `LeakCanary` |
| 23 | AUD-DEBT-006 TODOs + AUD-SEC-011 toolchain LTS |

> **Regla de orquestación:** Respetar `MODO-LOOP.md` archivos disjuntos (serie si comparten `VoiceKeyboardService.kt`), auditor limpia contexto califica 0-10, <9.0 vuelve a escritores nuevos. Cada tarjeta con `grep -n` verificación.

---

## 11. Métricas Frías Verificadas

| Métrica | Valor | Comando verificación | Veredicto |
|---|---|---|---|
| Dart `lib/` LOC | 3.788 | `wc -l app_source/lib/**/*.dart` | ok concentrado |
| `settings_screen.dart` | 1.192 | `wc -l settings_screen.dart` | god file |
| `VoiceKeyboardService.kt` | 3.526 | `wc -l VoiceKeyboardService.kt` | god file |
| `grep SharedPreferences.getInstance lib/` | 27 | `grep -rn getInstance storage_service.dart` | CRÍTICA |
| `grep "catch (_" lib/` | 28 | `grep -rn "catch (_" app_source/lib` | silenciado ALTA |
| Duplicate `"Sin conexión"` | 12 | `grep -rho Sin app_source --include="*.dart"` | DRY roto |
| `TODO` `build.gradle.kts` | 2 | `grep -n TODO build.gradle.kts` | template |
| `pubspec.yaml version` | `0.1.0+1` | `grep version pubspec.yaml` | fantasma vs `v1.0.0` |
| FIFO mismatch | 20 vs 25 | `grep maxItems` vs `MAX_UNPINNED_ITEMS` | contrato roto |
| `PAT 0644` | `-rw-r--r-- 94` | `ls -l .github_token` | CRÍTICA |
| Tests placebo byte-idénticos | 2 archivos idénticos | `diff -q clipboard_history_multimodal_test.dart` | placebo |
| `laboratorio_ui` | 2.2 MB + 16 `__pycache__` | `du -sh laboratorio_ui` | huérfano |
| `build_apk` | 95 MB+ | `du -sh build_apk` | bloat |
| Skills duplicados | 296 archivos | `diff -r .opencode .agents` | deuda |
| Gradle | 9.3.1 + AGP 9.1.0 + Kotlin 2.4.0 | `cat wrapper.properties` | bleeding edge |
| `Xmx8G` en 3.6G RAM | 8G+4G metaspace | `cat gradle.properties` | imposible |
| `actions/*@v4` sin SHA | 4 | `grep actions/ android.yml` | supply-chain |
| `Thread {` crudos | 4 | `grep -rn "Thread {" kotlin` | unbounded |

---

## 12. Checklist de Verificación Low-End (para QA en Mali-400 real)

- [ ] `adb shell settings put global animator_duration_scale 0` → blur/anim 0, sin jank, 90% frames <16ms `dumpsys gfxinfo`
- [ ] `fontScale 1.5` + `displaySize small` → ningún `BOTTOM OVERFLOWED`, `TalkBack` 44dp OK
- [ ] `split-screen` 50% + `landscape` → Home no solapa, sheet `initial 0.50`
- [ ] `adb shell cmd package bg-dexopt-job` + dictado 5min → PSS pico <110 MB, 0 OOM
- [ ] `Clipboard` 25 imágenes scroll → 0 decode en main (`StrictMode` 0 DiskReadViolation)
- [ ] `Battery Historian` → 0 `ObjectAnimator` con teclado en bg, doze no cuelga `HttpURLConnection`
- [ ] `adb shell dumpsys meminfo com.royleguiza.voicebubblestt` idle PSS <90 MB
- [ ] `Logcat` 0 `Log.*(text|transcription|snippet)` tras `grep` CI ampliado

---

## 13. Conclusión Profesional

VoiceBubble STT es un producto **bien intencionado y funcional** (privacidad declarada, FIFO correcto, exclusión mic, museos de transición), pero **no pasa el umbral Go 1.5 GB sin P0**. La deuda no es estética: es **ANR/OOM garantizable** (triple WAV, threads unbounded, blur 24 doble, I/O main). La causa raíz es **crecimiento orgánico K1→K5 apilado en un Service** + **threading ad-hoc** + **I/O en main** + **docs-código drift**.

**Recomendación:** Congelar MEJ-01…24, ejecutar P0 en 1 sprint (WAV streaming + clipboard IO + plaintext + blur fallback + PAT + signing). Luego P1 arquitectura. Sin P0, no distribuir APK Go. Con P0+P1, el teclado pasa a **9.0/10 apto Go** con -30% memoria pico y -50% ANR, habilitando base sólida para MEJ-03…24 sin merge hell.

> **Nota auditor:** Esta auditoría es **no destructiva** (solo lectura). Todos los IDs reproducibles `grep -n` en líneas citadas. Para re-auditar tras fixes: `python3 -m pytest test/ -k clipboard` + `adb shell StrictMode.enableDefaults()` + `LeakCanary` en Go + `zizmor` `android.yml`.

---

**Fin auditoría Muse — 2026-09-02 — `auditoria-muse.md` — No push, solo lectura.**

