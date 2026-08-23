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
- [ ] AT-A1 token de generación de transcripción
- [ ] AT-A2 VISIBLE_PASSWORD en gate
- [ ] AT-A3 historial fuera del hilo UI
- [ ] AT-A4 BUSY→IDLE automático
- [ ] AT-A5 surrogate pairs en ⌫ y truncado
- [ ] AT-A10 dictado jamás alimenta el query
Criterios: diff mínimo; sin nuevos recursos; i18n si aparece texto; sin Log contenido.

### F2 — Burbuja + MainActivity [FloatingBubbleService.kt, MainActivity.kt] (paralelo)
- [ ] AT-B1 gate mic antes de FGS microphone (con mensaje i18n es/en coherente con teclado)
- [ ] AT-B3 cancel animator en onDestroy
- [ ] AT-B6 START_NOT_STICKY
- [ ] AT-B9 colores vía R.color existentes

### F3 — SpeechToTextClient [SpeechToTextClient.kt] (paralelo)
- [ ] AT-B2 pcmBuffer.reset() tras copiar/cancelar
- [ ] AT-B4 re-chequeo cancelRequested pre-callback
- [ ] AT-B5 catch IOException vs Exception con mensajes honestos i18n

### F4 — Recursos muertos [res/**] (paralelo)
- [ ] AT-B7 git rm mipmap-*dpi PNGs
- [ ] AT-B8 git rm drawable-v21/launch_background.xml

### F5 — Dart servicios+modelos [lib/models/**, lib/services/**] (paralelo)
- [ ] AT-C7 toLocal() en fromJson (ALTA)
- [ ] AT-D1 ordenar por timestamp desc en load()
- [ ] AT-C5 lado Dart: remover isLocal (modelo+JSON+ícono rama)
- [ ] AT-C6/D17 remover kb_stt_provider
- [ ] AT-C4 remover clear()/loadSttMirroredApiKey()
- [ ] AT-C9 lado servicio: requestPermissions deja de llamarse desde _init (la llamada se quita en F6)
- [ ] AT-C10 merge conservador por timestamp en load()
- [ ] AT-C12 definir StorageService.maxItems=20, maxSnippets=50, maxSnippetLength=2000, recordModeHold='hold' como static const (nombres EXACTOS estos para F6/F10)
- [ ] AT-C13 state.name + KeyboardService.channelName

### F6 — Dart pantallas+ui+pubspec [lib/screens/**, lib/widgets/**, lib/ui/**, pubspec.yaml] (paralelo)
- [ ] AT-C1/C2 dependencias muertas fuera
- [ ] AT-C3 tokens muertos fuera (los asserts los quita F10)
- [ ] AT-C8 timestamp real en popup
- [ ] AT-C9 quitar llamada en home_screen._init
- [ ] AT-C11 envolver read de settings:392; política catch comentada en fronteras
- [ ] AT-C12 usar las constantes de F5 en home/settings
- [ ] AT-C14 Future.wait + un setState; ListView.builder para snippets
Contrato entre F5↔F6: usar SOLO los nombres static const definidos arriba.

### F7 — CI guardas [.github/workflows/android.yml] (paralelo)
- [ ] AT-D3 guarda de paridad de claves flutter.* Kotlin↔Dart contra lista dorada versionada (docs/contract-keys.txt generado ahora)
- [ ] AT-D10 validación hex colores + grep anti-filtración de contenido
- [ ] AT-D5 scaffold: eliminar o fallo explícito con mensaje claro
Reglas: YAML sin ': ' en valores plain; validar con python3-yaml antes de terminar.

### F8 — VKS pulido [VoiceKeyboardService.kt] (serie 2, tras F1)
- [ ] AT-A6 lastHistoryDiscarded fuera
- [ ] AT-A7 guardia muerta codeRow fuera
- [ ] AT-A8 cachear booleanos de prefs en loadKeyboardPrefs (+comentario honesto)
- [ ] AT-A9 avisos sobreviven rebuild inocuo; guard por identidad de inputView
- [ ] AT-A11 click plano cuando pairCloseFor null
- [ ] AT-A12 clamp Y de popups
- [ ] AT-A13 una sola lectura de prefs por ciclo + comentario veraz
- [ ] AT-A14 contentDescription ☰/enter i18n
- [ ] AT-A15 fallback commitText para Ñ/ñ con modificadores
- [ ] AT-A16 KDoc prohibición OnLongClickListener en attachLongPress
- [ ] AT-C5 lado Kotlin: quitar .put("isLocal", false)
- [ ] AT-B10 llamador usa load()

### F9 — SnippetStore [SnippetStore.kt] (paralelo con F8; archivos disjuntos)
- [ ] AT-B10 eliminar alias reload()

### F10 — Tests: verdad sobre cobertura [app_source/test/**] (tras F5/F6)
- [ ] AT-D2 purgar tautológicos de cloud_stt_service_fixes_test + test timeoutForBytes
- [ ] AT-D6 deduplicar recording_design_test
- [ ] AT-D7 purgar settings_storage_fixes_test
- [ ] AT-D8 purgar grupo Clipboard
- [ ] AT-D9 deduplicar transcription_test + hash según contrato
- [ ] AT-D15 limpiar full_flow_test
- [ ] AT-D16 helper único test/helpers/mock_channels.dart (.wav, record 7.x)
- [ ] Ajustes por F5/F6: isLocal fixtures fuera, asserts kb_stt_provider/clear()/tokens muertos fuera, test FIFO desordenado→ordenado (D1), test merge conservador (C10), test timestamp local (C7)
Objetivo: cada test restante puede fallar ante una regresión real. Conteo final informado.

### F11 — Higiene de repo [raíz/docs/.gitignore] (paralelo)
- [ ] AT-D11 política única espejo: .gitignore voice_bubble_stt/{lib,test,pubspec.yaml,analysis_options.yaml} + git rm --cached (android/ permanece)
- [ ] AT-D12 consolidar .agent vs .agents (investigar referencias primero; justificar elección)
- [ ] AT-D13 README exactitud del almacenamiento de la API key
- [ ] AT-D14 AGENTS.md sin ghost local_stt_service

## Fuera de alcance de esta ola (requieren decisión del dueño / dispositivo)
- AT-C15 i18n es/en: DECISIÓN DE PRODUCTO (español-only v1 vs gen-l10n).
- AT-D4 commitear pubspec.lock: requiere generar lock con Flutter (no existe runner local); proponer flujo CI.
- VERIFICACIONES EN DISPOSITIVO: AT-A12 (popups fila superior), AT-B1 (instalación fresca Android 14+), AT-B4 (cancelar durante upload), AT-D18 (dictados idénticos seguidos).

## Registro del loop (MODO-LOOP)

| Ola | Tarjetas | Auditor | Notas | Estado |
|---|---|---|---|---|
| Auditoría | A/B/C/D paralelos | — | 59 hallazgos, 0 colisiones | ✅ |
| Corrección 1 | F1–F7, F9–F11 | pendiente | | ⏳ |
| Corrección 2 (serie) | F8 | pendiente | tras F1 | ⏳ |
| Auditoría fresca ≥9 | todas | pendiente | contexto limpio | ⏳ |
| Batería final + push CI | — | — | | ⏳ |
