# AGENTS.md – Guía para Agentes de IA en VoiceBubble STT

> Este archivo es el **manual de onboarding** para cualquier agente de IA (Claude, Cursor, Copilot, etc.) que trabaje en este repositorio. Léelo completo antes de escribir código.

---

## 1. Qué es este proyecto

**VoiceBubble STT**: app Android de transcripción de voz a texto, extremadamente simple.

- Dos motores: **Cloud** (API OpenAI/Groq) y **Local offline** (Whisper tiny/base vía sherpa-onnx o similar).
- Historial de las últimas **20** transcripciones.
- **Burbuja flotante** para transcribir desde cualquier otra app y copiar el resultado.
- Nada más: no sumar features (no notas, no traducción, no resúmenes).

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

Estas decisiones están documentadas en `plan.md` (Hito 0). Si algún agente propone cambiarlas, requiere aprobación explícita del usuario.

## 3. Estructura del repo

```
voice-bubble/                  ← raíz del repo git
├── README.md                  ← spec funcional del producto
├── plan.md                    ← plan de ejecución por hitos (LA FUENTE DE VERDAD del qué y cuándo)
├── design.md                  ← sistema de diseño Liquid Glass (LA FUENTE DE VERDAD del cómo se ve)
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

### Estado actual

Ver sección "Estado" al final de este archivo y los checkboxes de `plan.md`.

## 5. Reglas técnicas

### Código

- Seguir las [convenciones oficiales de Dart](https://dart.dev/effective-dart) y `flutter analyze` ESTRICTO (sin `--no-fatal-*`): infos y warnings también rompen el CI.
- Todo widget test que use widgets Material importa explícitamente `package:flutter/material.dart` (flutter_test NO lo re-exporta).
- Estructura de carpetas sugerida por hito: ver `plan.md` § "Estructura de carpetas sugerida (Flutter)". No inventar estructuras paralelas.
- Comentarios solo cuando aporten contexto no obvio. En inglés o español, consistente.
- Sin lógica de UI dentro de widgets: servicios separados (`transcription_service`, `local_stt_service`, etc.).

### Seguridad y privacidad (crítico)

- **NUNCA hardcodear API keys ni secretos.** La key va en Settings, almacenada con `flutter_secure_storage`.
- Modo **Local: el audio jamás sale del dispositivo.** Verificar que ningún camino de código envíe audio a la red en modo local.
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
- ❌ Enviar audio a internet en modo local, aunque sea "para mejorar calidad".
- ❌ Historial con límite distinto de exactamente 20 elementos FIFO.
- ❌ Overriding de animaciones cuando el sistema pide Reduced Motion.
- ❌ Subir binarios de modelos grandes al repo (usar descarga on-demand).

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

### 9.4 Ritual post-push (obligatorio)

Después de cada push que toque código Dart o el workflow:
1. Verificar en Actions que el run quedó ✓ verde (~5-10 min primer build, ~2-3 min con caches calientes).
2. Si rojo: identificar el step exacto, corregir, re-revisar contra 9.2 antes del push siguiente.
3. Si verde: descargar `voice-bubble-debug-apk-r<N>` desde Artifacts e instalar en teléfono cuando corresponda probar físicamente.

---

## Estado del proyecto

> **Actualizar esta sección al final de cada hito completado.**

- [x] Planificación (README + plan + design + agents)
- [ ] Hito 0 – Setup *(en curso: CI corregido tras auditoría; falta build verde + APK instalado en teléfono)*
- [ ] Hito 1 – Transcripción básica
- [ ] Hito 2 – UX y robustez
- [ ] Hito 3 – Burbuja flotante
- [ ] Hito 4 – Pegado inteligente (Accessibility)
- [ ] Hito 5 – Optimización y pulido
- [ ] Hito 6 – Testing final y entrega
