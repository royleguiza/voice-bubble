# AGENTS.md – Guía para Agentes de IA en VoiceBubble STT

> ⚠️ **ATENCIÓN - CONGELAMIENTO DE PUSH A GITHUB ACTIONS (VIGENTE HASTA EL 1 DE SEPTIEMBRE DE 2026)**:
> **PROHIBIDO REALIZAR `git push` O DISPARAR WORKFLOWS DE CI.**
> Las cuotas mensuales de GitHub Actions están temporalmente saturadas. Hasta el **1 de septiembre de 2026**, el trabajo se centrará exclusivamente en **recopilación de ideas, diseño de arquitectura, refinamiento de planes y backlog de mejoras locales**. Ningún agente debe ejecutar `git push`.

> Este archivo es el **manual de onboarding** para cualquier agente de IA (Claude, Cursor, Copilot, etc.) que trabaje en este repositorio. Léelo completo antes de escribir código.

---

## 1. Qué es este proyecto

**VoiceBubble STT**: app Android de transcripción de voz a texto, extremadamente simple.

- Motor **Cloud** único (Groq `whisper-large-v3`; compatible también con OpenAI). El modo **Local offline fue removido** en el Hito 2 (decisión del dueño, 2026-08-22; restaurable desde git history; su regreso está pospuesto — ver `teclado-voice.md` D4).
- Historial de las últimas **20** transcripciones (FIFO).
- **Burbuja flotante** para transcribir desde cualquier otra app y copiar el resultado (Hito 3, verificada en dispositivo real).
- Próxima extensión planificada: **teclado del sistema con dictado** (`teclado-voice.md`, hitos T0–K5).
- Nada más fuera de alcance (no notas, no traducción, no resúmenes).

## 2. Stack y decisiones tomadas (NO re-decidir)

| Decisión | Valor |
|---|---|
| Framework | **Flutter** (Android únicamente) |
| Package name | `com.royleguiza.voicebubblestt` |
| Carpeta del proyecto Flutter | `voice_bubble_stt/` (dentro de este repo) |
| minSdkVersion | **28** |
| targetSdkVersion | La más actual disponible al crear el proyecto |
| Idioma de la UI | Español e inglés (mínimo) |
| Diseño | Apple **Liquid Glass**, claro + oscuro → ver `design.md` |
| Alcance dual | Burbuja (existente) + **teclado del sistema nativo Kotlin** — decisiones D1–D9 aprobadas en `teclado-voice.md` §3 (2026-08-22) |
| Seeds de snippets | SÍ, 5 ejemplos precargados editables/borrables (`teclado-voice.md`, K4 tarea 7) |

Estas decisiones están documentadas en `plan.md` (Hito 0). Si algún agente propone cambiarlas, requiere aprobación explícita del usuario.

## 3. Estructura del repo

```
voice-bubble/                  ← raíz del repo git
├── README.md                  ← spec funcional del producto
├── plan.md                    ← plan de ejecución por hitos (LA FUENTE DE VERDAD del qué y cuándo)
├── design.md                  ← sistema de diseño Liquid Glass (LA FUENTE DE VERDAD del cómo se ve)
├── teclado-voice.md           ← plan del teclado del sistema (T0–K5); se integra a la secuencia desde la posición del Hito 4
├── AGENTS.md                  ← este archivo
├── app_source/                ← FUENTE DE EDICIÓN de la app (pubspec, analysis_options, lib/, test/)
├── voice_bubble_stt/          ← proyecto Flutter que compila el CI; android/ generado por CI,
│                                 el resto SINCRONIZADO desde app_source en cada run
└── .github/workflows/android.yml  ← pipeline CI: scaffold → sync → analyze → test → build APK
```

## 4. Flujo de trabajo obligatorio

1. Leer `plan.md` completo antes de empezar.
2. **Un hito a la vez.** Nunca mezclar tareas de hitos distintos en un mismo commit/PR.
3. No avanzar al hito siguiente hasta que el actual cumpla **todos** sus criterios de aceptación (están checklisteados en `plan.md`).
4. Toda decisión de UI sigue `design.md`. Si `design.md` no cubre un caso, proponer antes que improvisar.
5. Al completar un hito: actualizar checkboxes de criterios en `plan.md`, commitear y pushear.
6. Después de cada cambio importante: generar APK debug (`flutter build apk --debug`) y avisar al usuario para prueba en dispositivo real.

### Modo loop (estilo de trabajo del dueño)

Cuando el dueño pida "trabajar en modo loop", rige `MODO-LOOP.md`: coordinador + escritores paralelos por archivos disjuntos (serie para archivos compartidos) → auditor ultracrítico SIEMPRE con contexto limpio que califica 0–10 → todo lo < 9.0 vuelve a escritores nuevos limpios hasta aprobar → batería final → push con CI monitoreado → APK al dueño. Cero deuda técnica, cero parches, menos es más. Los planes vigentes (ej. `AUDITORIA-TOTAL-V1.md`, `PLAN-PULIDO-TECLADO.md`) llevan su sección "Registro del loop".

### Estado actual

Ver sección "Estado" al final de este archivo y los checkboxes de `plan.md`.

## 5. Reglas técnicas

### Código

- Seguir las [convenciones oficiales de Dart](https://dart.dev/effective-dart) y `flutter analyze` ESTRICTO (sin `--no-fatal-*`): infos y warnings también rompen el CI.
- Todo widget test que use widgets Material importa explícitamente `package:flutter/material.dart` (flutter_test NO lo re-exporta).
- Estructura de carpetas sugerida por hito: ver `plan.md` § "Estructura de carpetas sugerida (Flutter)". No inventar estructuras paralelas.
- Comentarios solo cuando aporten contexto no obvio. En inglés o español, consistente.
- Sin lógica de UI dentro de widgets: servicios separados (`transcription_service`, `cloud_stt_service`, `keyboard_service`, etc.).

### Seguridad y privacidad (crítico)

- **NUNCA hardcodear API keys ni secretos.** La key va en Settings, almacenada con `flutter_secure_storage`.
- El audio SOLO viaja a internet cuando el usuario inicia explícitamente una transcripción Cloud. Sin transcripción en curso = cero tráfico de red con audio.
- **El teclado JAMÁS registra, guarda ni transmite texto tecleado** (ni en logs de debug). Sin dictado, snippets ni sugerencias en campos de contraseña.
- **Exclusión mutua de micrófono burbuja↔teclado**: si uno está grabando, el otro muestra estado ocupado (flag en memoria del proceso + audio focus).
- Sin analytics, sin telemetría, sin permisos que no estén justificados en README.md.

### Permisos Android (solo los necesarios, declarar en manifest)

```xml
RECORD_AUDIO, SYSTEM_ALERT_WINDOW, FOREGROUND_SERVICE,
FOREGROUND_SERVICE_MICROPHONE, POST_NOTIFICATIONS
```

- `SYSTEM_ALERT_WINDOW` y Accessibility Service se solicitan solo en Hitos 3–4, no antes.

### Dependencias

- Agregar dependencias **solo** si están previstas en el plan o son imprescindibles. Justificar en el commit.
- Preferir packages maduros y mantenidos. Modelos locales: empezar SIEMPRE por Tiny/Base cuantizado (≤ 80 MB).

## 6. Entorno de build (limitaciones reales de esta máquina)

| Recurso | Realidad |
|---|---|
| Máquina de desarrollo | **Termux/proot sobre Android (aarch64)** — no hay PC x86_64 |
| Flutter local | **NO disponible** (no existe build ARM64 del SDK) |
| Android SDK local | **NO instalable** (binarios solo para x86_64) |
| RAM / Disco | ~3.6 GB total, ~13 GB libres → no intentar builds locales |

**Estrategia de build (decisión tomada):**

- El APK se compila con **GitHub Actions** (`.github/workflows/android.yml`) en runners ubuntu x86_64.
- La fuente de la app vive en `app_source/`; el primer run de CI la scaffoldingea a `voice_bubble_stt/` vía `flutter create`, aplica parches (minSdk 28, RECORD_AUDIO, label) y commitea el scaffold.
- **Cada run sincroniza incondicionalmente** `app_source/{pubspec,analysis_options,lib,test}` → `voice_bubble_stt/` antes de compilar: `app_source/` es la única fuente de edición.
- Cada push a `main` (que toque código) ejecuta: pub get → analyze (estricto) → test → `flutter build apk --debug` → sube el artefacto `voice-bubble-debug-apk-r<N>` (retención 7 días).
- El usuario descarga el APK desde GitHub → Actions → run → Artifacts, y lo prueba en el teléfono físico ("Instalar apps desconocidas").
- No intentar correr emuladores ni builds locales. Los unit tests de Dart corren en CI.

## 7. Convenciones de Git

- Commits concisos, imperativos, en español. Ej.: `Hito 1.2: grabación PCM 16kHz mono con package record`.
- Un commit (o serie limpia) por tarea/hito coherente. Nunca commitear secretos.
- Push a `main` directamente (proyecto personal, sin PRs por ahora).
- Tag `v1.0.0` recién en Hito 6.

## 8. Anti-patrones prohibidos

- ❌ Usar Liquid Glass fuera de la capa funcional, o hardcodear colores fuera de los tokens de `design.md`.
- ❌ Toggle de tema claro/oscuro dentro de la app (seguir el sistema, siempre).
- ❌ Añadir features fuera del alcance del README (la app hace UNA cosa).
- ❌ Avanzar de hito sin criterios de aceptación completos.
- ❌ Enviar audio a internet sin que el usuario haya iniciado explícitamente una transcripción.
- ❌ Historial con límite distinto de exactamente 20 elementos FIFO.
- ❌ Overriding de animaciones cuando el sistema pide Reduced Motion.
- ❌ Subir binarios de modelos grandes al repo (usar descarga on-demand).
- ❌ Registrar/guardar texto tecleado en el teclado (ni debug, ni analytics, jamás).
- ❌ Dictado o snippets activos en campos de contraseña.
- ❌ Segundo motor Flutter embebido en el teclado (descartado por diseño: ~100 MB extra de RAM).
- ❌ Features de teclado genérico fuera de alcance: autocorrector predictivo, temas, emojis, glide typing, portapapeles multinivel.
- ❌ Que el teclado dependa de que la Activity principal haya sido abierta alguna vez (defaults sensatos en cold start).
- ❌ Mezclar cambios de burbuja y de teclado en el mismo commit/hito.

---

## 9. Lecciones aprendidas y best practices (CI + Flutter)

> Sección viva: cada build rojo agrega una fila al log y su lección a las reglas. Leer antes de tocar CI o código Dart.

### 9.1 Log de errores

| # | Síntoma en CI | Causa raíz | Fix aplicado |
|---|---|---|---|
| 1 | `The name 'MyApp' isn't a class` (analyze) | El workflow copiaba `lib/` pero NO `test/`: quedó el test generado por `flutter create` | Copiar `test/` propio + paso de sincronización incondicional `app_source → voice_bubble_stt` |
| 2 | `Undefined name 'FloatingActionButton'` (analyze) | flutter_test **NO** re-exporta material.dart; el test usaba widgets sin importarlos | Import explícito de material en tests |
| 3 | pubspec.lock inconsistente (detectado en auditoría, antes de romper) | Constraint `^5.0.0` vs lock resuelto a 6.0.0 (el bot commiteó el lock antes de sobrescribir el pubspec) | Alinear constraint a `^6.0.0` en ambos pubspecs |
| 4 | Cambios en app_source no llegarían al build (trampa estructural) | El scaffold solo corría si faltaba `android/`; después, el CI ignoraba app_source | Paso "Sincronizar fuente" incondicional en cada run |
| 5 | `Invalid workflow file ... yaml syntax on line 92` (el run ni arranca) | `: ` (dos puntos + espacio) dentro del nombre de un step → YAML lo interpreta como mapeo anidado inválido | Sin `: ` en valores plain; validar YAML localmente con python3-yaml antes de pushear workflows |
| 6 | 6 tests de grabación fallan: el botón nunca pasa de mic a stop | Los mocks usaban canales inventados (`com.llcgram.*`); el plugin record 5.x usa `com.llfbandit.record` y `/messages` | Verificar el nombre EXACTO del canal contra el código fuente del plugin antes de mockear |
| 7 | Clipboard.getData devuelve null y el SnackBar nunca aparece | El canal `flutter/platform` no tiene implementación nativa en tests → MissingPluginException en setData/getData | Mockear SystemChannels.platform con un store en memoria |
| 8 | `find.text('item 19')` encuentra 0 widgets con una lista de 20 | ListView es lazy: los ítems fuera del viewport NO se construyen | Hacer scroll (dragUntilVisible) antes del expect |
| 9 | Build nativo: `Could not find method jcenter()` evaluando speech_to_text | speech_to_text 6.6.0 usa `jcenter()`, eliminado en Gradle moderno | Subir a ^7.x (los ajustes Android se corrigieron en 7.0.0); migrar params deprecados de listen() a SpeechListenOptions |
| 10 | kernel_snapshot: `RecordLinux missing implementations` (startStream/hasPermission) | La línea record 5.x tiene una combinación transitiva rota publicada (platform_interface 1.6.0 vs record_linux 0.7.2); sin pubspec.lock commiteado, cada resolve flota a la última | Subir record a ^7.1.1 (sub-paquetes alineados por upstream); evaluar commitear pubspec.lock |
| 11 | Tests fallan "after test completion" con MissingPluginException método `create` | record 7.x: el CONSTRUCTOR de AudioRecorder() ya invoca `create` al canal | Mockear canales llfbandit en TODO archivo de test que construya TranscriptionService sin recorder inyectado |
| 12 | Error 400 de Groq al transcribir en dispositivo real | Grabación con pcm16bits produce bytes WAV pero el path era `.m4a`: Groq valida la extensión de la parte multipart (caso idéntico documentado en vercel/ai#8846) | Extensión `.wav` para grabaciones PCM + propagar el mensaje real del body de error en respuestas no-200 (`_serverErrorDetail`) |
| 13 | Persiste el 400: `could not be processed - is it a valid media file?` con extension .wav correcta | `pcm16bits` en record Android usa RawContainer: PCM CRUDO sin cabecera RIFF (extensión sugerida por el plugin: `.pcm`); `wav` = "pcm16bit with headers" via WaveContainer | Usar `AudioEncoder.wav` (mismo PCM 16 bits pero con cabecera válida). Lección: verificar qué contenedor escribe REALMENTE cada encoder contra el código Kotlin del plugin |
| 14 | pumpAndSettle timeout tras entrar en estado recording | Animaciones infinitas (anillo pulsante) impiden el settle | pump(duracion fija) en tests tras activar animaciones repetitivas |
| 15 | `dependOnInheritedWidgetOfExactType<MediaQuery>() called before initState completed` | MediaQuery.of dentro de initState del widget | Mover a didChangeDependencies |
| 16 | analyze: `The setter 'physicalSizeTested' isn't defined for the type 'TestFlutterView'` | API vieja de TestWindow (`*TestValue`/`*Tested`) confundida con la moderna | En Flutter actual: `tester.view.physicalSize = ...` y `tester.view.devicePixelRatio = ...`, con `addTearDown(tester.view.reset)` |
| 17 | `enterText` falla con `Bad state: No element` en tests que navegan a Settings | Al crecer la página (tarjeta del teclado), el TextField quedó bajo el pliegue del ListView lazy: no se construye si no es visible (ver §9.1-8) | Agrandar superficie en TODOS los tests que rendericen la pantalla (`tester.view.physicalSize`), no solo en los que hacen scroll explícito |
| 18 | Gradle/Kotlin: ~25 errores en cascada (`Unresolved reference 'input'`, `'currentInputConnection'`, `'resources'`, etc.) | Un typo en un import (`android.input.methodservice` vs `android.inputmethodservice`): la clase deja de resolver su superclase y todos sus miembros | Verificar la ruta EXACTA del paquete Android contra developer.android.com antes de pushear Kotlin; ante errores en cascada, buscar PRIMERO imports rotos |
| 19 | `mergeDebugResources`: `Invalid <color> for given resource value` + `Can not extract resource from ParsedResource` (criptico) | Color con 10 dígitos hex (`#FF663C3C43`) en vez de 8: AAPT2 solo acepta #RGB/#ARGB/#RRGGBB/#AARRGGBB; el mensaje no dice cuál línea es | Validar longitudes hex de TODOS los colores con un script local antes de pushear recursos nuevos |
| 20 | En dispositivo real, fila inferior del teclado solapada por barra de gestos + flecha de minimizar + botón selector de IME (Enter tapado) | Con targetSdk moderno la ventana del IME va edge-to-edge: el sistema dibuja navegación ENCIMA de la parte baja de nuestra vista | Padding inferior = `navigationBars`+`displayCutout` insets vía `setOnApplyWindowInsetsListener` en la input view (patrón de FlorisBoard/Unexpected Keyboard); NO usar % fijos |
| 21 | Recurrencia de §9.1-17: `Found 0 widgets with text "API Key de Groq"` en `home_screen_test` y `widget_test` tras agregar otra fila a Settings | Al crecer verticalmente una pantalla, TODO test que la renderice (directo o navegando dentro de la app) puede quedar con contenido bajo el pliegue del ListView lazy | Antes de pushear cambios que agranden UI: `grep -rn "texto-de-esa-pantalla" app_source/test/` y aplicar superficie alta en TODOS los archivos que aparezcan |
| 22 | Gradle/Kotlin: `Unresolved reference 'optString'` + `'it'` en cascada dentro de addToSharedHistory | Faltaba `import org.json.JSONObject` en VoiceKeyboardService.kt: la clase no resolvía y la inferencia de tipos colapsaba aguas abajo | Al usar org.json/media/nuevos paquetes en un archivo Kotlin nuevo, agregar el import PRIMERO; ante errores raros de inferencia, revisar imports del archivo |
| 23 | Gradle/Kotlin: `Unresolved reference 'USAGE_VOICE_INPUT'` | Esa constante NO existe en AudioAttributes; la entrada de voz usa USAGE_ASSISTANT (así lo hace el reconocedor de Google) | Verificar constantes de AudioAttributes/Media contra developer.android.com antes de pushear; alternativas: USAGE_MEDIA o USAGE_GAME según caso |
| 24 | Gradle/Kotlin: `Type mismatch: inferred type is LinearLayout but TextView was expected` (detectado en auditoría M4) | `attachLongPress` exigía `TextView` concreto en vez de la clase base `View`, impidiendo enlazar vistas compuestas | Generalizar firmas de listeners a `key: View` para soportar polimorfismo en teclas complejas |
| 25 | APK Debug universal de 168 MB satura almacenamiento en GitHub Actions (90% consumido) | `flutter build apk --debug` empaqueta 3 ABIs y el upload usaba `compression-level: 0` | `--split-per-abi` + upload arm64 con `compression-level: 6` (reduce el APK a 54 MB y el artefacto a 48 MB, -71% de storage) |

### 9.2 Reglas duras para agentes

1. Editar SOLO en `app_source/`. Nunca editar directamente `voice_bubble_stt/{lib,test,pubspec.yaml,analysis_options.yaml}` (el CI los pisa).
2. flutter_test no exporta material.dart: import explícito siempre que un test use widgets Material.
3. Ningún flag de analyze perdona errores de compilación; los flags solo modulan infos/warnings. La única salida es código correcto.
4. `flutter analyze` corre ESTRICTO. Arreglar código o ajustar la regla puntual en analysis_options, nunca bajar severidad global.
5. Prohibido enmascarar fallos con `|| true` / `|| echo` en steps críticos del CI.
6. Todo parche por sed sobre scaffolds lleva guard posterior (`grep -q ... || exit 1`).
7. Antes de pushear Dart: releer el diff completo buscando imports faltantes y símbolos inexistentes (no hay análisis local posible en Termux).
8. Nunca usar `: ` dentro de nombres o valores plain en YAML (rompe el parseo). Validar SIEMPRE el workflow localmente antes de pushear: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/android.yml'))"` (paquete `python3-yaml` ya instalado).
9. Un push = un run esperado: verificar Actions antes de avanzar de hito (ver 9.4).
10. dart:io asíncrono (`await File.exists/delete`) se cuelga bajo fakeAsync (widget tests): usar variantes síncronas (`existsSync/deleteSync`) en rutas de limpieza que puedan ejecutarse en tests.
11. **REGLA DEL DUEÑO (2026-08-22): ningún push sin la suite de testing completa al 100% en verde.** Como no existe runner local de Flutter en Termux, esto se materializa así: (a) diff re-leído completo antes del push (regla 7), (b) baseline anterior verde confirmada, (c) monitoreo CI obligatorio post-push (§9.4) y corrección inmediata si el run falla, antes de cualquier otra tarea.

### 9.3 Best practices aplicadas al workflow

| Práctica | Fuente |
|---|---|
| concurrency group + cancel-in-progress (mata runs obsoletos) | docs.github.com — workflow syntax #concurrency |
| timeout-minutes: 40 (el default es 360) | docs.github.com — workflow syntax #timeout-minutes |
| cache Gradle integrado en setup-java (`cache: gradle`) | github.com/actions/setup-java #caching |
| cache del SDK + pub vía subosito/flutter-action (`cache: true`) | github.com/subosito/flutter-action #caching |
| aceptación defensiva de licencias SDK (ubuntu-latest suele traerlas OK) | github.com/actions/runner-images issues #7506 |
| AGP ≥8 requiere JDK 17 → setup-java temurin 17 antes del build | developer.android.com/build/jdks |
| artefacto con nombre único por run, retention-days 7, compression-level 0 para APKs, if-no-files-found: error (v4 = inmutables) | github.com/actions/upload-artifact |
| pushes con GITHUB_TOKEN no disparan otros workflows (sin loops infinitos) | docs.github.com/actions/security-guides |
| pump() puntual mejor que pumpAndSettle() cuando no hay animaciones pendientes | api.flutter.dev — WidgetTester.pumpAndSettle |

### 9.4 Ritual post-push y Monitoreo de GitHub Actions (OBLIGATORIO)

Para asegurar la integridad de las compilaciones sin acceso local a SDK:
- **Token de lectura de GitHub Actions**: Ubicado en `/root/.local/share/gh-actions/token` (permisos de solo lectura para workflows/runs/artefactos, vigencia temporal de 7 días).
- **SEGURIDAD**: **NUNCA** exponer, imprimir en consola ni commitear el valor del token en ningún archivo o mensaje.

#### Procedimiento obligatorio tras CADA push:
1. **Monitorear el workflow en segundo plano** consultando la API de GitHub Actions hasta que el estado sea `completed`:
   ```python
   import urllib.request, json, time

   token = open('/root/.local/share/gh-actions/token').read().strip()
   commit_sha = '<SHORT_COMMIT_SHA>'

   # 1. Obtener Run ID correspondiente al commit
   req = urllib.request.Request(
       'https://api.github.com/repos/royleguiza/voice-bubble/actions/runs?per_page=3',
       headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json'}
   )
   runs = json.loads(urllib.request.urlopen(req).read()).get('workflow_runs', [])
   run_id = next(r['id'] for r in runs if r['head_sha'].startswith(commit_sha))

   # 2. Pollear estado cada 15 segundos
   while True:
       req_run = urllib.request.Request(
           f'https://api.github.com/repos/royleguiza/voice-bubble/actions/runs/{run_id}',
           headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json'}
       )
       run = json.loads(urllib.request.urlopen(req_run).read())
       if run['status'] == 'completed':
           break
       time.sleep(15)
   ```
2. **Si el build falla (`conclusion == 'failure'`)**:
   - Consultar los jobs y steps (`/actions/runs/{run_id}/jobs`).
   - Mapear el step exacto que falló (ej. analyze, test o Gradle) y obtener los logs para corregir la causa raíz.
3. **Si el build tiene éxito (`conclusion == 'success'`)**:
   - Consultar los artefactos (`/actions/runs/{run_id}/artifacts`).
   - Proveer al usuario el Run ID, enlace directo a GitHub y el nombre del APK generado (`voice-bubble-debug-apk-r<N>`).

---

## Estado del proyecto

> **Actualizar esta sección al final de cada hito completado.**
> Última actualización: 2026-08-23 (AUDITORÍA TOTAL v1 ejecutada en MODO-LOOP: 59 hallazgos corregidos en 11 tarjetas F1–F11 auditadas >9.0; CI verde run `32666610965`, APK r62, suite depurada a 280 tests reales). Ver `AUDITORIA-TOTAL-V1.md`.

- [x] Planificación (README + plan + design + agents)
- [x] Hito 0 – Setup
- [x] Hito 1 – Transcripción básica (Cloud verificado en dispositivo real, 2026-08-22)
- [x] Hito 2 – UX y robustez (cerrado 2026-08-22; deuda cosmética menor: mocks muertos de speech_to_text en `home_screen_test.dart`, ver abajo)
- [x] Hito 3 – Burbuja flotante (regresión verificada en dispositivo real por el dueño, 2026-08-22: usada para dictar contenido real sin fallos, APK del run `144abaf`)
- [x] T0 – Documentación de alcance dual (README + design + AGENTS actualizados con teclado, 2026-08-22)
- [x] K1 – Esqueleto del teclado funcional (verificado por el dueño en dispositivo real, 2026-08-23: instalado como teclado principal; fix de solape con barra de gestos confirmado en APK r45)
- [x] K2 – Capa código y teclas terminales → **implementado y verificado por el dueño en dispositivo real** (2026-08-23, APK r57: Termux/Acode OK, teclas terminales no rompen apps normales)
- [x] K2.1 – Fila terminal configurable desde Settings (decisión del dueño 2026-08-23: toggle manual, sin auto-detección) → **implementado, CI verde** (run `32611294100`, APK r48, 266 tests); primer uso del puente de preferencias Flutter↔Kotlin (`flutter.` en `FlutterSharedPreferences`) que reutiliza K3 para el espejo D7; verificado por el dueño
- [x] K3 – Dictado por voz dentro del teclado → **implementado, CI verde y verificado por el dueño** (run `32614903180`, APK r53, 284 tests; verificación completa 2026-08-23 con APK r57); SpeechToTextClient.kt nativo WAV PCM16 + multipart Groq; estados mic idle/grabando/procesando/ocupado con anillo rojo que respeta Reduced Motion; avisos inline no bloqueantes con "abrir Ajustes"; timeout 60 s; cancelación por toque largo; exclusión mutua burbuja↔teclado bidireccional vía flag de proceso + canal `isKeyboardRecording` + audio focus transitorio exclusivo; mic oculto en campos de contraseña; historial FIFO-20 compartido reordenado por timestamp. Casos borde pendientes verificados OK por el dueño (2026-08-23): mic ausente en contraseñas, aviso de ocupado con burbuja grabando, dictado en inglés
- [x] Lote de pulido visual del teclado (2026-08-23, avance de K5): switches en Ajustes para ocultar la tecla `</>` (`kb_code_key_visible`) y la de idioma ES/EN (`kb_language_key_visible`, puente Flutter↔Kotlin del patrón K2.1); pesos ampliados de ⇧/⌫/↵ (1.3f/1.3f/1.8f); contraste modo claro con `kb_key_bg_alt` #D6D6DC + stroke 1dp `kb_key_stroke`. CI verde run `32617334365`, APK **r54**, 302 tests. Verificado por el dueño en dispositivo (2026-08-23): switches ocultan/revelan teclas, mejora visible en claro y oscuro, dictado sigue operativo
- [x] Lote historial + audios largos del teclado (2026-08-23): FIX de historial que no mostraba dictados del teclado (HomeScreen ahora relee SharedPreferences al volver al primer plano vía WidgetsBindingObserver); historial emergente desde el teclado (toque largo en 🎤 en reposo → ventana con las últimas 20, tocar inserta en cursor, sin Log, sin duplicar entrada); tope de dictado subido de 60 s a 5 minutos (`SpeechToTextClient.MAX_SECONDS` como fuente única) y readTimeout HTTP a 240 s. CI verde run `32619043596`, APK **r55**, 304 tests. Verificado por el dueño (2026-08-23): los dictados desde el teclado ya se guardan y aparecen en el historial de la app
- [x] K4 – Snippets y comandos (con 5 seeds) → **implementado y auditado** (tarjetas K4-T1..T5 aprobadas por auditoría ≥ 8.9; commit `9901e47`; CI verde r57; verificación en dispositivo pendiente, checklist en `PLAN-EJECUCION-LOOP.md` §11)
- [x] K5 – Pulido, robustez y entrega → **implementado y auditado** (K5-T1..T8 aprobadas ≥ 8.9 tras reproceso de i18n de errores; auditoría de privacidad **LIMPIA**; commit `079f8e8`; CI verde r57)
- [ ] Hito 4 – Pegado inteligente (Accessibility) → **CONGELADO definitivamente para v1**: el dictado desde el teclado nativo cubre la inserción en cursor
- [x] Hito 5 – Robustez Android 14/15 (re-definido) → **implementado y auditado** (FGS tipado micrófono + `POST_NOTIFICATIONS` runtime, icono adaptive + splash, `INSTALL.md` con guía de batería, matriz de tests; commit `d569ab6`; fix-wave `c146c09` tras fallo de test; CI verde r57)
- [x] Hito 6 – Testing final y entrega → push único a `main` (`c146c09`, 6 commits), ritual CI completado: run [`32634338510`](https://github.com/royleguiza/voice-bubble/actions/runs/32634338510) success · **368 tests** · artefacto `voice-bubble-debug-apk-r57`; tags [`v0.9.0-keyboard-beta`](https://github.com/royleguiza/voice-bubble/tree/v0.9.0-keyboard-beta) (commit `079f8e8`) y [`v1.0.0`](https://github.com/royleguiza/voice-bubble/tree/v1.0.0)

- [x] Lote v1.2 – Configuración con Tabs C2, Tecla Micrófono M4 Morph-to-Pill y APK split arm64 (2026-08-24, `plan-v1.2.md`, auditado en MODO-LOOP >9.0): Settings con 4 tabs glass inferiores (`IndexedStack` que preserva estado + 96dp bottom padding); tecla mic M4 en teclado nativo Kotlin con expansión a pastilla roja, punto pulsante, cronómetro M:SS y touch target cancelar >=44dp; ícono vectorial limpio `kb_ic_mic.xml` (reemplazo definitivo del emoji 🎤) y animación de 3 puntos en ola en `PROCESSING` (`kb_proc_dot.xml`); optimización de CI a split arm64 (-67% de peso, 168MB -> 48MB en storage GitHub). CI verde a la primera: run [`32682031857`](https://github.com/royleguiza/voice-bubble/actions/runs/32682031857) success · artefacto `voice-bubble-arm64-debug-apk-r64` (48.35 MB comprimido).

**Siguiente etapa**: verificación del dueño en dispositivo con el APK r64 (`voice-bubble-arm64-debug-apk-r64`).

**Deuda técnica menor (no bloqueante)**:
- (resuelta 2026-08-22 en commit `e5b3c4c`) Los mocks muertos de canales `plugin.speech_to_text.*` en `app_source/test/screens/home_screen_test.dart` fueron eliminados; la nota anterior quedaba desactualizada respecto al árbol real.
- Mejora futura registrada: `<monochrome>` en el icono adaptive (themed icons Android 13+); contador de generación para invalidar callbacks de transcripción obsoletos tras rotación (menor UX detectado en auditoría K5-T5); limpiar PNGs huérfanos de `mipmap-*dpi` (minSdk 28 usa anydpi-v26).
