# AUDITORIA-TOTAL-V1.md — Plan de vulnerabilidades y correcciones (filosofía: MENOS ES MÁS)

> **Origen**: orden del dueño 2026-08-23. Auditoría total del código con 4 auditores paralelos de contexto limpio.
> **Filosofía**: minimalismo extremo. Todo tiene que tener un porqué. Sin parches, sin soluciones momentáneas, sin deuda técnica. Reloj suizo.
> **Alcance**: 59 hallazgos (A:16 IME principal · B:10 Kotlin restante/recursos · C:15 Dart · D:18 tests/CI/contratos).
> **Ejecución**: por tarjetas F1–F11 bajo el protocolo de `MODO-LOOP.md` (escritores paralelos por archivos disjuntos → auditor fresco califica 0–10 → <9 vuelve a escritor limpio → batería final → push con CI monitoreado).

## Severidades

CRÍTICA = crash/pérdida de datos/regla dura de privacidad rota · ALTA = error visible del producto · MEDIA = jank/dato que miente/deuda estructural · BAJA = peso muerto/ruido.

## Hallazgos — Auditor A (VoiceKeyboardService.kt, leído entero)

| ID | Cat | Sev | Líneas | Título | Corrección mínima |
|---|---|---|---|---|---|
| AT-A1 | BUG | ALTA | 933–1017 | Callback de transcripción huérfano: texto cometido en campo equivocado tras cambio de campo/app durante PROCESSING | Token `transcriptionGeneration++` en cancel; onDone/onError capturan y comparan antes de commit |
| AT-A2 | BUG | ALTA | 178–184 | Gate de contraseña omite TYPE_TEXT_VARIATION_VISIBLE_PASSWORD (toggles "mostrar contraseña") | Añadir la variación al when |
| AT-A3 | PERF | MEDIA | 1128–1160,1349–1403 | Escritura de historial (IO+XML parse) en hilo UI justo tras dictar | Mover writableHistoryBase+putStringSet al Thread ya existente |
| AT-A4 | BUG | MEDIA | 888–897 | Mic BUSY zombi: queda atenuado si la burbuja deja de grabar (sin transición BUSY→IDLE) | Reevaluar bubbleBusy() al refrescar visual / onStartInputView |
| AT-A5 | BUG | MEDIA | 761,697–700 | Surrogate pairs partidos: ⌫ borra medio emoji; truncado del query corta pares | Detectar par antes de borrar/truncar |
| AT-A6 | DEAD | BAJA | 1115,1254,1338 | lastHistoryDiscarded solo-escritura (25 líneas de KDoc para nada) | Eliminar campo+asignaciones+KDocs |
| AT-A7 | DEAD | BAJA | 355,468–474 | Guardia `c==' '` inalcanzable en codeRow | Borrar línea |
| AT-A8 | PERF | MEDIA | 210–239,2081–2110 | rebuild golpea SharedPreferences ×3 cada vez; comentario promete caché que no existe | Cachear 3 booleanos junto a heightFactor en loadKeyboardPrefs |
| AT-A9 | BUG | BAJA | 210–212,1456–1481 | rebuild asesina avisos inline; ::root.isInitialized no detecta vista vieja | Guard por identidad de inputView actual; no matar aviso idéntico reciente |
| AT-A10 | BUG | BAJA | 959,682–704 | Dictado en capa snippets alimenta el query (y se trunca a 50) en vez del documento | onDone usa commitText directo al IC |
| AT-A11 | OVER | BAJA | 2005–2017 | Toque largo sin efecto en 9/16 teclas de código (pairCloseFor null) | setOnClickListener plano cuando no hay pareja |
| AT-A12 | BUG | MEDIA·VERIFICAR | 1215–1232,+2 popups | Popups pueden dibujarse con Y negativo (fila superior + perfil alto) | Clamp Y o anclar debajo; verificar en dispositivo |
| AT-A13 | CLARITY | BAJA | 101–107,125,167 | Comentario "prefs UNA VEZ por apertura" pero hay 2 sitios de lectura | Dejar una lectura y corregir comentario |
| AT-A14 | CLARITY | BAJA | 399,408 | contentDescription "snippets"/"enter" sin i18n entre hermanas localizadas | if spanishMode |
| AT-A15 | BUG | BAJA | 707–718,844–848 | CTRL/ALT + ñ se come la pulsación en silencio | Fallback commitText cuando keyCodeFor null |
| AT-A16 | OVER | BAJA | 1909–1975 | UP consumido deja zombi el CheckForLongPress del framework (latente) | Documentar prohibición de OnLongClickListener en teclas con gestos |

## Hallazgos — Auditor B (Kotlin restante + recursos + manifest)

| ID | Cat | Sev | Archivo:líneas | Título | Corrección mínima |
|---|---|---|---|---|---|
| AT-B1 | BUG | ALTA·VERIFICAR | FloatingBubbleService 71–76 + MainActivity 51–56 | FGS tipo microphone sin RECORD_AUDIO → SecurityException Android 14+ en instalación fresca | Gate de permiso mic antes de startForeground con mensaje claro |
| AT-B2 | PRIVACIDAD | MEDIA | SpeechToTextClient 64,100,133–134 | Audio PCM retenido en RAM hasta 9,6 MB tras terminar (contrato propio violado) | pcmBuffer.reset() tras copiar en stop y en cancel |
| AT-B3 | BUG | MEDIA | FloatingBubbleService 234–257 | ValueAnimator del snap sobrevive a onDestroy → IllegalArgumentException | Campo animator + cancel() en onDestroy |
| AT-B4 | BUG | MEDIA·VERIFICAR | SpeechToTextClient 181–217 | Cancelación durante upload ignorada: texto llega igual | Re-chequear cancelRequested antes de onDone/onError |
| AT-B5 | BUG/OVER | MEDIA | SpeechToTextClient 219–224 | catch-all clasifica TODO como "Sin conexión" (200 malformado, OOM…) | catch IOException=red; catch Exception=mensaje genérico honesto |
| AT-B6 | BUG | BAJA | FloatingBubbleService 88 | START_STICKY resucita FGS micrófono desde background (Android 14+) | START_NOT_STICKY |
| AT-B7 | DEAD | BAJA | res/mipmap-*dpi/*.png (5) | PNGs inalcanzables con anydpi-v26 + minSdk 28 | git rm directorios |
| AT-B8 | DEAD | BAJA | drawable-v21/launch_background.xml | Duplicado byte-idéntico del base | git rm |
| AT-B9 | OVER | BAJA | FloatingBubbleService 287–350 | Paleta hardcodeada duplica tokens e ignora modo oscuro | ContextCompat.getColor(R.color.*) existentes |
| AT-B10 | OVER | INFO | SnippetStore 71–74 (+llamador VKS 1524) | reload() alias exacto de load() | Borrar alias; llamador usa load() |

## Hallazgos — Auditor C (Dart lib/ + pubspec)

| ID | Cat | Sev | Archivo:línea | Título | Corrección mínima |
|---|---|---|---|---|---|
| AT-C1 | DEAD | MEDIA | pubspec.yaml:12 | cupertino_icons sin uso | Eliminar |
| AT-C2 | DEAD | MEDIA | pubspec.yaml:16 | path sin uso | Eliminar |
| AT-C3 | DEAD | MEDIA | ui/design_tokens 116,128,300,303 | 4 tokens muertos sostenidos solo por su test | Borrar tokens+asserts |
| AT-C4 | DEAD | BAJA | storage_service 149–152,361–364 | loadSttMirroredApiKey()/clear() sin llamador de producción | Eliminar (+sus tests) |
| AT-C5 | DEAD/CONTRATO | MEDIA | transcription.dart 4,18; history_list 52–56; VKS 1134 | isLocal: peso muerto del motor Local removido; ícono que nunca ocurre | Remover campo de modelo/JSON/Kotlin/tests |
| AT-C6 | CONTRATO | MEDIA | storage_service 126,134 | Clave espejo kb_stt_provider escrita y jamás leída | Eliminar constante+escrituras+asserts |
| AT-C7 | BUG | ALTA | transcription.dart:25 | Timestamp mixto UTC/local: dictados del teclado muestran hora desplazada en historial | DateTime.parse(...).toLocal() en fromJson |
| AT-C8 | BUG | MEDIA | home_screen:573 | Popup muestra DateTime.now() de cada rebuild, no de la transcripción | Guardar timestamp junto a _resultText |
| AT-C9 | BUG | MEDIA | home_screen:109–111 | Permiso de mic solicitado en cada arranque (record.hasPermission solicita) | Quitar llamada de _init; startRecording ya verifica |
| AT-C10 | BUG | MEDIA | home_screen 462–467 + storage.load | Race read-modify-write al resumir: load() puede pisar transcripción nueva | Merge conservador por timestamp en load(); invalidar sheet abierto |
| AT-C11 | CLARITY/BUG | MEDIA | 33 catch(_){} + settings:392 sin try | Política de errores inexistente; read sin protección crashea | Estandarizar: catch solo en fronteras de canal con comentario; envolver :392 |
| AT-C12 | OVER | BAJA | settings 32–33, home 409,594 | Constantes de contrato duplicadas y literales mágicos (20, hold) | static const únicos en StorageService y referenciarlos |
| AT-C13 | OVER | BAJA | floating_bubble_service 8–17; transcription_service 14 | nameString reimplementa Enum.name; canal hardcodeado duplicado | state.name; KeyboardService.channelName |
| AT-C14 | PERF | BAJA | settings 61–70,448 | ~9 setState encadenados al abrir Ajustes + ListView eager | Future.wait + un setState; builder si crece |
| AT-C15 | CLARITY | ALTA (DECISIÓN) | Todo lib/ | i18n es/en prometido en AGENTS §2 e INEXISTENTE (~100 strings es) | DECISIÓN DEL DUEÑO: español-only v1 (corregir AGENTS) o introducir gen-l10n |

## Hallazgos — Auditor D (tests + CI + contratos + higiene)

Tabla de contrato Kotlin↔Dart: 15/16 filas OK; única anomalía dura: kb_stt_provider FANTASMA (=AT-C6) y orden List-vs-Set (AT-D1).

| ID | Cat | Sev | Ubicación | Título | Corrección mínima |
|---|---|---|---|---|---|
| AT-D1 | CONTRATO/TESTS | MEDIO-ALTO | history_bridge_contract_test 68–84 + storage.load | FIFO compartido: Android devuelve Set sin orden y Dart NUNCA ordena → historial desordenado tras restart (CI no lo ve) | Ordenar por timestamp desc en load() + test con siembra desordenada |
| AT-D2 | TESTS DÉBILES | ALTO | cloud_stt_service_fixes_test | ~27/44 tests tautológicos (prueban jsonDecode/literales, jamás pueden fallar); timeout fijo obsoleto | Borrar grupos tautológicos; añadir test de timeoutForBytes real |
| AT-D3 | CI | ALTO | android.yml 95–110 | Cero guarda de paridad del contrato Kotlin↔Dart (romper clave dejaría CI verde) | Paso bash: extraer claves flutter.* de ambos lados y diff contra lista dorada versionada |
| AT-D4 | CI | MEDIO | .gitignore pubspec.lock | Deps flotantes por run; lección 9.1-10 pedía evaluar commitear lock | REQUIERE INFRA: generar lock necesita Flutter (no hay runner local) → decisión/flujo CI |
| AT-D5 | CI | MEDIO | android.yml 41–82 | Scaffold muerto-pero-armado: si corrige, envenena main con scaffold sin teclado | Eliminar paso o convertirlo en fallo explícito |
| AT-D6 | DUPLICACIÓN | MEDIO | recording_design_test 140–261 | ~20 tests de tokens duplicados copy-paste de design_tokens_test | Borrar duplicados; fuente única |
| AT-D7 | TESTS DÉBILES | MEDIO | settings_storage_fixes_test 123–245 | Tests que prueban su propio fake; duplicados verbatim de otros archivos | Eliminar grupos; cobertura real ya existe en settings_screen_test |
| AT-D8 | TESTS DÉBILES | BAJA-MEDIA | clipboard_permissions_test 142–165 | Grupo Clipboard prueba el store del mock, no la app | Conservar solo tests de permisos |
| AT-D9 | TESTS DÉBILES | BAJA | transcription_test 196–252 | Pares equality duplicados; asserts de hash no garantizados por contrato | Deduplicar; hash: equals⇒mismo hashCode |
| AT-D10 | CI | MEDIO | android.yml Guard | Faltan las 2 guardas baratas que las lecciones pidieron: hex de colores válidos + grep anti-filtración de contenido | ~10 líneas YAML |
| AT-D11 | HIGIENE | MEDIO | voice_bubble_stt/{lib,test} commiteados | Copia espejo DESACTUALIZADA versionada (dos fuentes de verdad) | Política única: gitignore espejo no-android + git rm --cached (CI sincroniza cada run) |
| AT-D12 | HIGIENE | BAJA-MEDIA | .agent/ y .agents/ | 296 archivos idénticos duplicados (148×2) versionados | Consolidar a uno (investigar referencias) y git rm el otro |
| AT-D13 | PROCESO | MEDIO | README.md:8 | "API key cifrada" contradice el espejo D7 en texto plano | Redactar con exactitud (secure storage + espejo privado) |
| AT-D14 | PROCESO | BAJA | AGENTS.md:69 | Referencia fantasma a local_stt_service (removido) | Sustituir por cloud_stt_service/keyboard_service |
| AT-D15 | TESTS MUERTOS | BAJA | full_flow_test 206–324 | Numeración muerta (7–9 inexistentes) y modelo re-testeado dentro de integración | Limpiar grupo; los flujos viven en h5_matrix |
| AT-D16 | HIGIENE | BAJA | widget/home_screen/full_flow tests | Bloque de mocks triplicado con comentarios "record 5.x" obsoletos y .m4a heredado | Helper único test/helpers/mock_channels.dart correcto (.wav, 7.x) |
| AT-D17 | CONTRATO | BAJA | storage_service 126,134,144,311 | (=AT-C6) escrita/borrada/testeada y consumida por nadie | Ídem C6 |
| AT-D18 | CONTRATO | BAJA·VERIFICAR | VKS 1137–1144 | Set puede fusionar dos dictados byte-idénticos mismo ms | Documentar comportamiento decidido + verificar en dispositivo |

---

## Tarjetas de corrección (ejecución bajo MODO-LOOP.md)

Regla de paralelismo: solo agentes sobre ARCHIVOS DISJUNTOS. VoiceKeyboardService.kt es serie (F1 → F8). Los escritores marcan sus casillas al completar y cierran.

### F1 — VKS bugs críticos [VoiceKeyboardService.kt] (serie 1)
- [x] AT-A1 token de generación de transcripción (`transcriptionGeneration` campo nuevo; `++` en cancelDictationIfActive; generación capturada en finishDictation y guardas en los 3 runOnMain de isEmptyCapture/onDone/onError)
- [x] AT-A2 VISIBLE_PASSWORD en gate
- [x] AT-A3 historial fuera del hilo UI (addToSharedHistory se invoca en onDone ANTES de runOnMain: corre en el hilo de fondo VbKeyboardStt; callbacks documentados como siempre-background en SpeechToTextClient)
- [x] AT-A4 BUSY→IDLE automático (guarda micState==BUSY && !bubbleBusy() en refreshMicVisual y en onStartInputView antes del rebuild)
- [x] AT-A5 surrogate pairs en ⌫ y truncado (getTextBeforeCursor(2,0)+isSurrogatePair→deleteSurroundingText(2,0); mismo criterio en ⌫ del query; truncado descarta high surrogate suelto final)
- [x] AT-A10 dictado jamás alimenta el query (onDone usa currentInputConnection?.commitText directo; commit()/routeToSnippetQuery ya no participan)
Criterios: diff mínimo; sin nuevos recursos; i18n si aparece texto; sin Log contenido.

### F2 — Burbuja + MainActivity [FloatingBubbleService.kt, MainActivity.kt] (paralelo)
- [x] AT-B1 gate mic antes de FGS microphone (verificado: gate ContextCompat.checkSelfPermission(RECORD_AUDIO) en startBubble de MainActivity, único arranque del servicio; si falta → result.error("MIC_PERMISSION_DENIED") coherente con el catch-all del canal Dart → false y el switch no persiste; contrato settings/home intacto)
- [x] AT-B3 cancel animator en onDestroy (campo snapAnimator + cancel()/null antes de removeView)
- [x] AT-B6 START_NOT_STICKY
- [x] AT-B9 colores vía R.color existentes (kb_recording para pulso; kb_key_bg_accent para glifo mic; 5 tokens nuevos bubble_* en values+values-night: idle_bg #CC1C1C1E, idle_border #4DFFFFFF, active_border #80FFFFFF, recording_bg #E6FF3B30/#E6FF453A, transcribing_bg #D9007AFF/#D90A84FF)

### F3 — SpeechToTextClient [SpeechToTextClient.kt] (paralelo)
- [x] AT-B2 pcmBuffer.reset() tras copiar/cancelar (verificado: stopRecording copia y vacía atómicamente bajo el mismo synchronized (toByteArray→reset→bytes); camino de cancelación YA lo tenía (synchronized(pcmBuffer){reset()} en cancelRecording, línea previa 144) — se verificó presencia, no se duplicó; el reset() de startRecording se mantiene como limpieza defensiva)
- [x] AT-B4 re-chequeo cancelRequested pre-callback (guard tras leer code/body y antes del dispatch onDone/onError; si canceló → onDone(null) según KDoc existente "onDone(null) = cancelacion"; return@Thread evita doble callback; contrato con VKS intacto — firmas startRecording/cancelRecording/transcribe sin cambios y callbacks siguen siempre-background en VbKeyboardStt)
- [x] AT-B5 catch IOException vs Exception con mensajes honestos i18n (IOException → mensaje de red actual es/en; Exception genérica → "No se pudo procesar la respuesta."/"Could not process the response." vía spanishModeProvider; orden catch específico→genérico verificado; mensajes son literales estáticos: jamás incluyen contenido de audio, API key ni headers)

### F4 — Recursos muertos [res/**] (paralelo)
- [x] AT-B7 git rm mipmap-*dpi PNGs (verificado: manifest solo usa @mipmap/ic_launcher(+round) → resuelven vía anydpi-v26; minSdk 28; cero referencias a los PNG en repo; 5 PNG borrados del índice)
- [x] AT-B8 git rm drawable-v21/launch_background.xml (verificado: cmp byte-a-byte idéntico al base; cero referencias explícitas a drawable-v21; borrado del índice)

### F5 — Dart servicios+modelos [lib/models/**, lib/services/**] (paralelo)
- [x] AT-C7 toLocal() en fromJson (ALTA)
- [x] AT-D1 ordenar por timestamp desc en load()
- [x] AT-C5 lado Dart: remover isLocal (modelo+JSON+ícono rama)
- [x] AT-C6/D17 remover kb_stt_provider
- [x] AT-C4 remover clear()/loadSttMirroredApiKey()
- [x] AT-C9 lado servicio: requestPermissions deja de llamarse desde _init (la llamada se quita en F6)
- [x] AT-C10 merge conservador por timestamp en load()
- [x] AT-C12 definir StorageService.maxItems=20, maxSnippets=50, maxSnippetLength=2000, recordModeHold='hold' como static const (nombres EXACTOS estos para F6/F10)
- [x] AT-C13 state.name + KeyboardService.channelName

### F6 — Dart pantallas+ui+pubspec [lib/screens/**, lib/widgets/**, lib/ui/**, pubspec.yaml] (paralelo)
- [x] AT-C1/C2 dependencias muertas fuera
- [x] AT-C3 tokens muertos fuera (los asserts los quita F10)
- [x] AT-C8 timestamp real en popup
- [x] AT-C9 quitar llamada en home_screen._init
- [x] AT-C11 envolver read de settings:392; política catch comentada en fronteras
- [x] AT-C12 usar las constantes de F5 en home/settings
- [x] AT-C14 Future.wait + un setState; ListView.builder para snippets (builder: documentado, se deja inline por riesgo de regresión en tests de viewport)
Contrato entre F5↔F6: usar SOLO los nombres static const definidos arriba.

### F7 — CI guardas [.github/workflows/android.yml] (paralelo)
- [x] AT-D3 guarda de paridad de claves flutter.* Kotlin↔Dart contra lista dorada versionada (docs/contract-keys.txt generado con las 12 claves reales verificadas por grep del árbol; extracción excluye líneas import para no contar io.flutter.embedding/plugin como claves; diff falla con mensaje claro)
- [x] AT-D10 validación hex colores + grep anti-filtración de contenido (hex 3/4/6/8 tras # o referencia @ en values*/colors.xml — detecta la regresión §9.1-19; anti-filtración busca Log.* con texto/contenido/apiKey/token case-insensitive con bordes de palabra — lista blanca natural: "contenidos largos" plural no matchea y los logs numéricos existentes de SnippetStore pasan limpios)
- [x] AT-D5 scaffold ELIMINADO: voice_bubble_stt/android/ ya está versionado con el IME completo, el sync incondicional posterior entrega todo lo compilable y un re-scaffold generaría un shell genérico SIN teclado commiteándolo directo a main (el veneno exacto del hallazgo); si android/ faltara, la nueva guarda `test -d` del paso de contrato + "Guard archivos de teclado presentes" fallan con mensaje explícito. permissions bajadas de write a read (el scaffold era el único que pusheaba)
Reglas: YAML sin ': ' en valores plain; validar con python3-yaml antes de terminar.

### F8 — VKS pulido [VoiceKeyboardService.kt] (serie 2, tras F1)
- [x] AT-A6 lastHistoryDiscarded fuera (campo+@Volatile+KDocs asociados y los discarded++ locales; los catch se conservan porque controlan el flujo)
- [x] AT-A7 guardia muerta codeRow fuera (`if (c==' ') continue`; ninguna llamada pasa espacios)
- [x] AT-A8 cachear booleanos de prefs en loadKeyboardPrefs (+comentario honesto): campos terminalRowVisiblePref/codeKeyVisiblePref/languageKeyVisiblePref junto a heightFactor; rebuild/buildBottomBar usan la caché; caducidad documentada por campo
- [x] AT-A9 avisos sobreviven rebuild inocuo; guard por identidad de inputView (campo con la vista devuelta por onCreateInputView; showStatus compara `view !== inputView` en vez de ::root.isInitialized; aviso idéntico vivo conserva su timer vía statusMessage)
- [x] AT-A11 click plano cuando pairCloseFor null (attachPairLongPress instala setOnClickListener con el mismo commitSymbolText del tap, sin maquinaria de long-press)
- [x] AT-A12 clamp Y de popups (maxOf(gap, loc[1]-altura-gap) en historial, acentos y menú snippet; verificación en dispositivo queda en la lista de la ola)
- [x] AT-A13 una sola lectura de prefs por ciclo + comentario veraz (loadKeyboardPrefs solo en onStartInputView, siempre posterior a onCreateInputView; eliminado del onCreateInputView)
- [x] AT-A14 contentDescription ☰/enter i18n ("fragmentos"/"snippets", "intro"/"enter")
- [x] AT-A15 fallback commitText para Ñ/ñ con modificadores (sendModifiedChar comite el carácter cuando keyCodeFor null)
- [x] AT-A16 KDoc prohibición OnLongClickListener en attachLongPress
- [x] AT-C5 lado Kotlin: quitar .put("isLocal", false)
- [x] AT-B10 llamador usa load() (toggleSnippetsLayer; alias reload ya eliminado por F9 en SnippetStore.kt)

### F9 — SnippetStore [SnippetStore.kt] (paralelo con F8; archivos disjuntos)
- [x] AT-B10 eliminar alias reload()

### F10 — Tests: verdad sobre cobertura [app_source/test/**] (tras F5/F6)
- [x] AT-D2 purgar tautológicos de cloud_stt_service_fixes_test + test timeoutForBytes (44→15: fuera los grupos jsonDecode/literales/modelo/multipart-self y duplicados de validaciones; quedan 12 tests reales con MockClient + 3 de clamp 60–600 s)
- [x] AT-D6 deduplicar recording_design_test (26→4: fuera los 17 asserts de tokens/temas copiados de design_tokens_test y 2 tests que construían RecordConfig para leérselo a sí mismo; queda wiring real del servicio + cleanupTempFile)
- [x] AT-D7 purgar settings_storage_fixes_test (archivo ELIMINADO: grupo del FakeFlutterSecureStorage probaba su propio fake, 2 testWidgets duplicados verbatim de settings_screen_test, grupo JSON duplicado de transcription_test y FIFO/límite duplicado de storage_service_test; cobertura viva en storage_service_test)
- [x] AT-D8 purgar grupo Clipboard (3 tests que solo ejercitaban el store del mock, junto con su mock huérfano; quedan 4 de permisos)
- [x] AT-D9 deduplicar transcription_test + hash según contrato (31→16: pares equality duplicados fuera; hashCode reducido al contrato equals⇒mismo hashCode, sin asserts de hashes distintos no garantizados)
- [x] AT-D15 limpiar full_flow_test (12→7: numeración muerta eliminada con nombres descriptivos; grupo "model edge cases" y test "10" re-testeaban el modelo dentro de integración → transcription_test)
- [x] AT-D16 helper único test/helpers/mock_channels.dart (.wav, record 7.x) usado por widget/home_screen/full_flow (comentario record 7.x por lección 11, stop devuelve .wav por lecciones 12/13; semántica de mocks intacta)
- [x] Ajustes por F5/F6: isLocal fixtures fuera (también en history_list_test/cloud_stt_service_test, no listados), asserts kb_stt_provider/clear()/loadSttMirroredApiKey fuera (storage_service_test y settings_screen_test ahora verifican kb_stt_api_key vía prefs), tokens muertos fuera (design_tokens_test), test FIFO desordenado→ordenado (D1) en storage_service_test, test merge conservador (C10) en storage_service_test, test timestamp local (C7) en transcription_test
Objetivo cumplido: cada test restante puede fallar ante una regresión real. Conteo final: 280 tests (antes 368: purga bruta −94, tests nuevos +6 = D1+C10+C7+3×timeoutForBytes; edits de fixtures sin cambio de conteo).

### F11 — Higiene de repo [raíz/docs/.gitignore] (paralelo)
- [x] AT-D11 política única espejo: .gitignore voice_bubble_stt/{lib,test,pubspec.yaml,analysis_options.yaml} + git rm --cached (android/ permanece) (verificado ANTES de operar: paso "Sincronizar fuente" android.yml:84–89 copia app_source→voice_bubble_stt en cada run antes de pub get/analyze/test/build; el scaffold solo actúa si falta voice_bubble_stt/android, que sigue versionado → nada del CI depende del espejo commiteado; 4 entradas EXACTAS ancladas con "/" inicial en .gitignore; git check-ignore confirma: los 4 paths ignorados, cero bajo android/; 30 archivos fuera del índice y presentes en disco)
- [x] AT-D12 consolidar .agent vs .agents (evidencia: diff -rq exit 0 = idénticos byte-a-byte ×148; grep '\.agents\|\.agent' sobre md/json/yaml/yml sin referencias fuera del propio plan de auditoría → NINGUNO referenciado; se conserva .agents y .agent sale del índice vía git rm -r --cached, queda en disco sin versionar)
- [x] AT-D13 README exactitud del almacenamiento de la API key (redactado: cifrada en flutter_secure_storage en la app + copia espejo en texto plano en preferencias privadas del paquete para consumo del teclado, inaccesible a otras apps, con remisión a INSTALL.md)
- [x] AT-D14 AGENTS.md sin ghost local_stt_service (§5 Código ahora lista cloud_stt_service/keyboard_service, ambas presentes en app_source/lib/services/)

## Fuera de alcance de esta ola (requieren decisión del dueño / dispositivo)
- AT-C15 i18n es/en: DECISIÓN DE PRODUCTO (español-only v1 vs gen-l10n).
- AT-D4 commitear pubspec.lock: requiere generar lock con Flutter (no existe runner local); proponer flujo CI.
- VERIFICACIONES EN DISPOSITIVO: AT-A12 (popups fila superior), AT-B1 (instalación fresca Android 14+), AT-B4 (cancelar durante upload), AT-D18 (dictados idénticos seguidos).

## Registro del loop (MODO-LOOP)

| Ola | Tarjetas | Auditor | Notas | Estado |
|---|---|---|---|---|
| Auditoría | A/B/C/D paralelos | — | 59 hallazgos, 0 colisiones | ✅ |
| Corrección 1 | F1–F7, F9–F11 | — | 9 escritores paralelos, archivos disjuntos | ✅ |
| Corrección 2 (serie) | F8 (+F3 recuperada) | — | F3 detectada sin lanzar y ejecutada antes de auditar | ✅ |
| Auditoría fresca ≥9 | 2 auditores limpios paralelos | G-Kotlin / G-Dart | F1 9.5 · F2 9.3 · F3 9.7 · F4 10 · F5 9.6 · F6 9.4 · F7 9.2 · F8 9.6 · F9 10 · F10 9.5 · F11 9.2 — **0 errores de build; todas >9.0 aprobadas** | ✅ |
| Fixes obligatorios post-auditoría | staging helpers/docs + plan.md:154 isLocal + /.agent/ ignorado | — | aplicados por coordinador | ✅ |
| Batería final + push CI | — | — | ver abajo | ⏳ |

Mejoras registradas no bloqueantes (sugeridas por auditores, pendientes de próxima ola): guarda de contrato también sobre lado Dart (F7-H1); propagar MIC_PERMISSION_DENIED a mensaje visible en Settings (F2-H1/H2); historial en generación vencida documentar o mover bajo guarda (F1-H1); test merge>maxItems (F10); evitar cascade-sort sobre lista posiblemente const (settings_screen:92); comentar ~10 catch(_) heredados de home_screen.

## Batería final

- [ ] git status índice completo (helpers/, docs/, deletions)
- [ ] YAML del workflow parsea (python3-yaml)
- [ ] Guardas grep: hex colores válidos, sin Log de contenido nuevo, balance Kotlin/Dart
- [ ] Commit + push → CI monitoreado hasta completed
- [ ] Éxito → APK r<N> anunciado al dueño
