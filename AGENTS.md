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
└── voice_bubble_stt/          ← proyecto Flutter (se crea en Hito 0)
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

- Seguir las [convenciones oficiales de Dart](https://dart.dev/effective-dart) y `flutter analyze` sin warnings.
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
- La fuente de la app vive en `app_source/`; el primer run de CI la scaffoldingea a `voice_bubble_stt/` vía `flutter create`, aplica parches (minSdk 28, RECORD_AUDIO) y commitea el scaffold.
- Cada push a `main` (que toque código) ejecuta: pub get → analyze → test → `flutter build apk --debug` → sube el artefacto `voice-bubble-debug-apk`.
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

## Estado del proyecto

> **Actualizar esta sección al final de cada hito completado.**

- [x] Planificación (README + plan + design + agents)
- [x] Hito 0 – Setup: decisiones documentadas, CI configurado; falta primer build verde + APK instalado en teléfono
- [ ] Hito 1 – Transcripción básica
- [ ] Hito 2 – UX y robustez
- [ ] Hito 3 – Burbuja flotante
- [ ] Hito 4 – Pegado inteligente (Accessibility)
- [ ] Hito 5 – Optimización y pulido
- [ ] Hito 6 – Testing final y entrega
