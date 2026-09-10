# AGENTS.md – Guía para Agentes de IA en VoiceBubble STT

> ⚠️ **POLÍTICA DE PUSH VIGENTE (sin fechas vencidas)**:
> - **Ningún push de código sin autorización explícita del dueño** (`app_source/`, `voice_bubble_stt/`, etc.). Tras HB0/B1–B7 en local, el CI solo se dispara con su visto bueno.
> - **Ventana de docs**: los pushes que solo tocan `*.md` están excluidos del CI por `paths-ignore: '*.md'` en `.github/workflows/android.yml` y **SIEMPRE deben incluir `[skip ci]`** en el mensaje. No tocar el `.yml` para esto: es la ventana documentada.
> - El backlog de mejoras (MEJ-01 a MEJ-24) vive en [`docs/archive/MEJORAS-SEPTIEMBRE.md`](docs/archive/MEJORAS-SEPTIEMBRE.md).

> Este archivo es el **manual de onboarding** para cualquier agente de IA (Claude, Cursor, Copilot, etc.) que trabaje en este repositorio. Léelo completo antes de escribir código.

---

## 1. Qué es este proyecto

**VoiceBubble STT**: app Android de transcripción de voz a texto, extremadamente simple.

- Motor **Cloud** único (Groq `whisper-large-v3`; compatible también con OpenAI). El modo **Local offline fue removido** en el Hito 2 (decisión del dueño, 2026-08-22; restaurable desde git history; su regreso está pospuesto — ver `docs/archive/teclado-voice.md` D4).
- Historial de las últimas **20** transcripciones (FIFO).
- **Burbuja flotante** para transcribir desde cualquier otra app y copiar el resultado (Hito 3, verificada en dispositivo real).
- Próxima extensión planificada: **teclado del sistema con dictado** (`docs/archive/teclado-voice.md`, hitos T0–K5).
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
| Alcance dual | Burbuja (existente) + **teclado del sistema nativo Kotlin** — decisiones D1–D9 aprobadas en `docs/archive/teclado-voice.md` §3 (2026-08-22) |
| Seeds de snippets | SÍ, 5 ejemplos precargados editables/borrables (`docs/archive/teclado-voice.md`, K4 tarea 7) |

Estas decisiones están documentadas en `docs/archive/plan.md` (Hito 0). Si algún agente propone cambiarlas, requiere aprobación explícita del usuario.

## 3. Estructura del repo

```
voice-bubble/                  ← raíz del repo git
├── README.md                  ← spec funcional del producto
├── docs/archive/plan.md       ← plan de ejecución por hitos (histórico; LA FUENTE DE VERDAD del qué y cuándo en su momento)
├── design.md                  ← sistema de diseño Liquid Glass (LA FUENTE DE VERDAD del cómo se ve)
├── docs/archive/teclado-voice.md ← plan del teclado del sistema (T0–K5, histórico)
├── docs/archive/MEJORAS-SEPTIEMBRE.md ← backlog de mejoras (MEJ-01 a MEJ-24, histórico)
├── docs/archive/plan-clipboard.md ← bandeja de portapapeles (MEJ-01 / MEJ-08, histórico)
├── docs/archive/plan-ciclar-mayusculas.md ← ciclar mayúsculas con Shift ⇧ (MEJ-02, histórico)
├── AGENTS.md                  ← este archivo
├── app_source/                ← FUENTE DE EDICIÓN de la app (pubspec, analysis_options, lib/, test/)
├── voice_bubble_stt/          ← proyecto Flutter que compila el CI; android/ generado por CI,
│                                 el resto SINCRONIZADO desde app_source en cada run
└── .github/workflows/android.yml  ← pipeline CI: scaffold → sync → analyze → test → build APK
```

## 4. Flujo de trabajo obligatorio

1. Leer `docs/archive/plan.md` completo antes de empezar.
2. **Un hito a la vez.** Nunca mezclar tareas de hitos distintos en un mismo commit/PR.
3. No avanzar al hito siguiente hasta que el actual cumpla **todos** sus criterios de aceptación (están checklisteados en `docs/archive/plan.md`).
4. Toda decisión de UI sigue `design.md`. Si `design.md` no cubre un caso, proponer antes que improvisar.
5. Al completar un hito: actualizar checkboxes de criterios en `docs/archive/plan.md`, commitear y pushear.
6. Después de cada cambio importante: avisar al usuario para prueba en dispositivo real con el APK del CI (ver §6; no hay builds locales).

### Modo loop (estilo de trabajo del dueño)

Cuando el dueño pida "trabajar en modo loop", rige `MODO-LOOP.md`: coordinador + escritores paralelos por archivos disjuntos (serie para archivos compartidos) → auditor ultracrítico SIEMPRE con contexto limpio que califica 0–10 → todo lo < 9.0 vuelve a escritores nuevos limpios hasta aprobar → batería final → push con CI monitoreado → APK al dueño. Cero deuda técnica, cero parches, menos es más. Los planes archivados (ej. `docs/archive/PLAN-PULIDO-TECLADO.md`) llevan su sección "Registro del loop".

### Estado actual

Ver sección "Estado" al final de este archivo y los checkboxes de `docs/archive/plan.md`.

## 5. Reglas técnicas

### Código

- Seguir las [convenciones oficiales de Dart](https://dart.dev/effective-dart) y `flutter analyze` ESTRICTO (sin `--no-fatal-*`): infos y warnings también rompen el CI.
- Todo widget test que use widgets Material importa explícitamente `package:flutter/material.dart` (flutter_test NO lo re-exporta).
- Estructura de carpetas sugerida por hito: ver `docs/archive/plan.md` § "Estructura de carpetas sugerida (Flutter)". No inventar estructuras paralelas.
- Comentarios solo cuando aporten contexto no obvio. En inglés o español, consistente.
- Sin lógica de UI dentro de widgets: servicios separados (`transcription_service`, `cloud_stt_service`, `keyboard_service`, etc.).

### Seguridad y privacidad (crítico)

- **NUNCA hardcodear API keys ni secretos.** La key va en Settings, almacenada con `flutter_secure_storage`.
- El audio SOLO viaja a internet cuando el usuario inicia explícitamente una transcripción Cloud. Sin transcripción en curso = cero tráfico de red con audio.
- **El teclado JAMÁS registra, guarda ni transmite texto tecleado** (ni en logs de debug). Sin dictado, snippets ni sugerencias en campos de contraseña.
- **Exclusión mutua de micrófono burbuja↔teclado**: si uno está grabando, el otro muestra estado ocupado (flag en memoria del proceso + audio focus).
- Sin analytics, sin telemetría, sin permisos que no estén justificados en INSTALL.md.

### Permisos Android (solo los necesarios — fuente canónica: `INSTALL.md` §4)

Ver `INSTALL.md` §4 para la lista vigente y su justificación (única fuente de verdad para usuario).

- Sin `AccessibilityService` declarado (BLOQUEADO 2026-09-05, perfil anti-Play-Protect).

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
- Cada push a `main` (que toque código) ejecuta: pub get → analyze (estricto) → test → `flutter build apk --debug --split-per-abi` → sube el artefacto `voice-bubble-arm64-debug-apk-r<N>` (retención 7 días; dentro: `app-arm64-v8a-debug.apk`).
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
- ❌ Dictado, snippets o inyección de burbuja activos en campos de contraseña (la burbuja híbrida jamás inyecta ahí: solo clipboard neutro).
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
12. Tests widget nuevos: localizar por `Key` (`find.byKey`), jamás por copy de usuario (`find.text('...')` rompe con renombres legítimos); `findsWidgets` solo con comentario que justifique el duplicado; todo tab nuevo entra con su key en `settings_tab_bar_test` (conteo exacto) y en el test de navegación de `settings_screen_test`.
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
- **Auth**: usar `gh` con la autenticación ya existente en la máquina (`gh auth status`).
  No crear ni leer archivos de token, no exportar `GITHUB_TOKEN` salvo que el entorno
  ya lo provea, y **NUNCA** imprimir, redirigir a logs ni commitear ningún secreto.
- **Redacción**: si un comando pudiera mostrar credenciales, anteponer
  `GH_TOKEN="<redacted>"` en el reporte y usar `gh` (que no imprime el token).

#### Procedimiento obligatorio tras CADA push (sin exponer secretos):
1. **Monitorear el workflow** con `gh` hasta que el estado sea `completed`:
   ```bash
   SHORT_SHA="<SHORT_COMMIT_SHA>"
   RUN_ID=$(gh run list --repo royleguiza/voice-bubble --limit 5 --json databaseId,headSha \
     --jq ".[] | select(.headSha | startswith(\"$SHORT_SHA\")) | .databaseId" | head -n 1)
   test -n "$RUN_ID" || { echo "run no encontrado para $SHORT_SHA"; exit 1; }
   gh run watch "$RUN_ID" --repo royleguiza/voice-bubble --interval 15
   gh run view "$RUN_ID" --repo royleguiza/voice-bubble --json status,conclusion
   ```
2. **Si el build falla (`conclusion == 'failure'`)**:
   - Listar jobs fallidos sin exponer secretos: `gh run view "$RUN_ID" --repo royleguiza/voice-bubble --json jobs`.
   - Mapear el step exacto que falló (ej. analyze, test o Gradle) y leer solo sus logs
     (`gh run view "$RUN_ID" --log-failed --repo royleguiza/voice-bubble`).
3. **Si el build tiene éxito (`conclusion == 'success'`)**:
   - Listar artefactos: `gh api repos/royleguiza/voice-bubble/actions/runs/"$RUN_ID"/artifacts --jq '.artifacts[].name'`.
   - Proveer al usuario el Run ID, enlace directo a GitHub y el nombre del APK generado (`voice-bubble-arm64-debug-apk-r<N>`).

---

## Estado del proyecto

> **Actualizar esta sección al final de cada hito completado.**
> Última actualización: 2026-08-23 (AUDITORÍA TOTAL v1 ejecutada en MODO-LOOP: 59 hallazgos corregidos en 11 tarjetas F1–F11 auditadas >9.0; CI verde run `32666610965`, APK r62, suite depurada a 280 tests reales).

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
- [ ] Hito 4 – Pegado inteligente (Accessibility) → **BLOQUEADO 2026-09-05** (perfil anti-Play-Protect): el servicio `VoiceBubbleAccessibilityService` se retiró del manifest (clase versionada pero dormida, `isConnected()` siempre falso). Sin declaración no hay inyección con tercer teclado: la burbuja pega vía IME propio (`commitText`) o portapapeles. Isla exacta sobre cámara y clics de trackpad, dormidos (fallbacks locales intactos). Ver `plan-hito4-burbuja-hibrida.md` §6.
- [x] Hito 5 – Robustez Android 14/15 (re-definido) → **implementado y auditado** (FGS tipado micrófono + `POST_NOTIFICATIONS` runtime, icono adaptive + splash, `INSTALL.md` con guía de batería, matriz de tests; commit `d569ab6`; fix-wave `c146c09` tras fallo de test; CI verde r57)
- [x] Hito 6 – Testing final y entrega → push único a `main` (`c146c09`, 6 commits), ritual CI completado: run [`32634338510`](https://github.com/royleguiza/voice-bubble/actions/runs/32634338510) success · **368 tests** · artefacto `voice-bubble-arm64-debug-apk-r57` (dentro: `app-arm64-v8a-debug.apk`; retención 7 días); tags [`v0.9.0-keyboard-beta`](https://github.com/royleguiza/voice-bubble/tree/v0.9.0-keyboard-beta) (commit `079f8e8`) y [`v1.0.0`](https://github.com/royleguiza/voice-bubble/tree/v1.0.0)

- [x] Lote v1.2 – Configuración con Tabs C2, Tecla Micrófono M4 Morph-to-Pill y APK split arm64 (2026-08-24, auditado en MODO-LOOP >9.0; evidencia verificable: `IndexedStack` en `app_source/lib/screens/settings_screen.dart:719`, icono `kb_ic_mic` en `VoiceKeyboardService.kt:1577`, `SpeechToTextClient.MAX_SECONDS`): Settings con 4 tabs glass inferiores (`IndexedStack` que preserva estado + 96dp bottom padding); tecla mic M4 en teclado nativo Kotlin con expansión a pastilla roja, punto pulsante, cronómetro M:SS y touch target cancelar >=44dp; ícono vectorial limpio `kb_ic_mic.xml` (reemplazo definitivo del emoji 🎤) y animación de 3 puntos en ola en `PROCESSING` (`kb_proc_dot.xml`); optimización de CI a split arm64 (-67% de peso, 168MB -> 48MB en storage GitHub). CI verde a la primera: run [`32682031857`](https://github.com/royleguiza/voice-bubble/actions/runs/32682031857) success · artefacto `voice-bubble-arm64-debug-apk-r64` (48.35 MB comprimido; dentro: `app-arm64-v8a-debug.apk`).

**Siguiente etapa (Reinicio Septiembre 2026)**: Ejecución del backlog de 24 mejoras estructurado en [`docs/archive/MEJORAS-SEPTIEMBRE.md`](docs/archive/MEJORAS-SEPTIEMBRE.md) (MEJ-01 a MEJ-24), comenzando por los planes aprobados [`docs/archive/plan-clipboard.md`](docs/archive/plan-clipboard.md), [`docs/archive/plan-ciclar-mayusculas.md`](docs/archive/plan-ciclar-mayusculas.md) y [`plan-hito4-burbuja-hibrida.md`](plan-hito4-burbuja-hibrida.md) (HB0 en ejecución local, sin push por pedido del dueño).

**Burbuja clásica + modal historial (B1–B7, [`plan-burbuja-historial.md`](plan-burbuja-historial.md))**: implementado local 2026-09-05 (controlador nativo + switch `bubble_history_enabled` + suite `test_bubble_history_suite.py` 55/55 + master 10/10 en verde), pendiente CI tras autorización de push del dueño.

**Cierre SPARK pendientes (2026-09-09, local sin push)**: SPK-09/10/11/15/17/21/23/26/27/28 en `auditoria-spark.md` §Cierre (contratos `docs/contrato-{stt,trackpad,claves,iconos}.md` + `docs/congelamiento-features.md`, flag `kb_clipboard_images_enabled` OFF, `HistoryCardView`+`SnippetsCardView`, iconos 18/22/28, versión `1.0.0`); CI (analyze/test/compilación) debe verificar antes de cualquier push. (SPK-17 Dart quedó en sync por regla §9.2-10: async cuelga testWidgets; el fix real es el lock Kotlin.)

**Cierre librería de tests (2026-09-10, local sin push)**: test 5→6 tabs + conteo exacto en tab bar; cobertura flag `kb_clipboard_images_enabled` (default OFF, toggle, round-trip) + snapshot `bridgeKeys`==33 + `floating_bubble_enabled` solo-Dart; smoke único en `widget_test`; handler record unificado en `mock_channels.dart`; guard de dictado (MAX_SECONDS/timeouts) en master (13/13); CI subido a nivel master (triángulo Dart, bóveda, manifest, regex amplio); regla §9.2-12 (keys, no copy). Deuda que queda: unificar `buildTestableWidget` de los 4 settings-tests y recortar plantillas triplicadas (solo test, sin riesgo funcional).

**CI verde 2026-09-10 (run `34421034892`, artefacto `voice-bubble-arm64-debug-apk-r127`)**: push forzado de 237 commits tras divergencia total con remoto (solo compartían init; remoto sin nada que local no tuviera salvo borrados intencionales SPK-01/12). Camino al verde: import sin uso en `app_icons` → 6 tests defensivos por `assert` en `ChannelGuard` (quitado, contra contrato "sin lanzar nunca") → 31 errores Kotlin del refactor SPK-05 nunca compilado (`Layer` a público, imports `Color`/`InputContentInfoCompat`, delegados `dictation`/`editor`/`layout`, cuerpos de asignación a bloque, default `makeIconKey` solo en `ToolbarLayer.UiHost`, override `consumeModifiers` faltante, tints explícitos). Workflow remoto retenido (token sin scope `workflow`; mejoras de `android.yml` quedan en `/tmp/android.yml.local` + commits locales pendientes de token con scope).

**Deuda reportada en dispositivo (2026-09-10, r127, APARCADA por el dueño)**: (1) clipboard no guarda imágenes aun con el switch ON — no mirar por ahora; (2) capa snippets del teclado perdió minimalismo: al abrirla, shift (izq. de Z) y borrar quedan bajos vs resto, y la selección en edición hoy rellena en verde/azul completo en vez del borde punteado azul por tarjeta de antes — solo tener en cuenta; (3) editando un snippet no andan gestos del teclado (deslizar borrando, deslizar en barra espaciadora).

**Espaciado anti-fantasma (2026-09-10, local sin push, pedido del dueño)**: pref `kb_key_spacing` (compacto/normal/amplio, default normal sin cambio de conducta) en triángulo Kotlin==contrato==Dart; `VKS.dimenPx` escala solo los 3 gaps (alturas intactas); SegmentedButton en Ajustes→Teclado + tests (storage, snapshot bridge 34, widget); master local 13/13.

**Estilo háptico (2026-09-10, CI verde run `34432445249`, artefacto `voice-bubble-arm64-debug-apk-r131`)**: pref `kb_haptic_style` (nitido/firme/suave, default nitido) en puente (35 claves); `VKS.haptic` deja el `KEYBOARD_TAP` del sistema y vibra directo (nítido 12ms/255, firme 30ms/220, suave 15ms/90). Camino al verde: `.wait` de records limitado a 9 (estilo fuera del record) + `areAllPrimitivesSupported` inexistente en el SDK (one-shot garantizado en vez de Composition).

**Settings v2 (2026-09-10, CI verde run `34526053530`, artefacto `voice-bubble-arm64-debug-apk-r136`)**: réplica fiel de `laboratorio_ui/settings-redesign-v2.html` con skill impeccable (Operate) + Playwright (10 capturas claro/oscuro crystal). 5 tabs (General fusiona Inicio+Burbuja), tab bar glass crystal (blur 10, borde 1.5px, highlight diagonal), kit `settings_v2.dart`, tema Sistema/Claro/Oscuro solo-Dart en Acerca (excepción al anti-patrón §8 por pedido del dueño), buscador de snippets, modal crystal con grabber, sin AppBar (Back del sistema). Contrato Kotlin==Dart intacto. Camino al verde: null-safety en `main`, chips sin const-double, `child`-last en lint,Caption duplicada en trackpad, tests migrados a 5 tabs + `handlePopRoute`. Master local 16/16.

**Lote teclado + mic (2026-09-10, CI verde run `34538931166`, artefacto `voice-bubble-arm64-debug-apk-r141`)**: dock crystal simétrico; espaciado `Extra` (factor 2.0, puente 41→43); filas sin baseline + shift/borrar completos en Snippets + símbolos/código en negrita; sección Micrófono colapsable (hápticas por evento independientes + sonidos opt-in con 4 opciones inicio/fin, default opción 3, 10 WAVs propios); snippets compacta (4 cuartos, lupa expansible por tap/tipeo, punteados). Camino al verde: doc `<n>`, default-3 en test, `setBaselineAligned` + overload `makeIconKey` sin defaults en conflicto. Master local 18/18.

**Snippets barra slim + clipboard overlay (2026-09-10, CI verde run `34543156993`, artefacto `voice-bubble-arm64-debug-apk-r143`)**: búsqueda 70% slim 28dp con lupa placeholder (se oculta al tipear) + 3 botones 10%; chips dinámicos (4→2×2, resto ≤3) a altura Enter con gap uniforme; clipboard como popup centrado (exclusivo, no empuja teclas). Camino al verde: altura Enter vía `scaledDimen` del host. Master local 18/18.

**Deuda técnica menor (no bloqueante)**:
- (resuelta 2026-08-22 en commit `e5b3c4c`) Los mocks muertos de canales `plugin.speech_to_text.*` en `app_source/test/screens/home_screen_test.dart` fueron eliminados; la nota anterior quedaba desactualizada respecto al árbol real.
- Mejora futura registrada: `<monochrome>` en el icono adaptive (themed icons Android 13+); contador de generación para invalidar callbacks de transcripción obsoletos tras rotación (menor UX detectado en auditoría K5-T5); limpiar PNGs huérfanos de `mipmap-*dpi` (minSdk 28 usa anydpi-v26).
