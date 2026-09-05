# VoiceBubble STT – App Android de Transcripción de Voz a Texto

Aplicación Android **extremadamente simple** cuyo propósito es convertir voz en texto con motor cloud (API OpenAI/Groq), historial de las últimas 20 transcripciones y **burbuja flotante** para usar desde cualquier otra app. Alcance dual: además de la burbuja, incluye un **teclado del sistema con dictado por voz y snippets** (ver "Modo Teclado" más abajo).

## Características principales

* Transcripción de voz a texto **solo** (nada de notas, resúmenes, traducción, etc.).
* **Motor único Cloud**: Groq `whisper-large-v3` (compatible con OpenAI). La API key la configura el usuario en Settings (detalle: `INSTALL.md` §3). El modo local offline fue **removido** en el Hito 2 (decisión del dueño); su regreso está pospuesto (`docs/archive/teclado-voice.md`, D4).
* UI minimalista: botón Grabar → texto → **Copiar con un solo click**.
* Historial persistente de las **últimas 20 transcripciones** (FIFO) con timestamp y modo usado.
* **Burbuja flotante** (overlay) arrastrable:

  * Se activa desde cualquier app.
  * Tocar → grabar → transcribir → pegado en 2 caminos: 1) nuestro teclado activo → inserción directa en cursor (`commitText`, sin permisos extra); 2) resto → clipboard + pegado manual. (La inyección con tercer teclado vía accesibilidad está bloqueada desde 2026-09-05 por perfil anti-Play-Protect; spec archivada en `plan-hito4-burbuja-hibrida.md`.)
* **Teclado del sistema** "VoiceBubble Keyboard": QWERTY es/en, capa código con fila terminal para Termux/Acode, dictado por voz directo en el cursor y snippets (ver "Modo Teclado").
* Generación fácil de APK de testing (debug y release).

## Objetivos de diseño

* Máxima simplicidad de uso.
* Privacidad: el audio solo viaja a internet cuando el usuario inicia explícitamente una transcripción cloud.
* Bajo consumo de batería y memoria.
* Funciona en Android 9+ (minSdk 28; recomendado Android 12+ / API 31+).

## Stack tecnológico

> **Decisión cerrada (Hito 0)**: Opción A – Flutter (Android únicamente), con piezas nativas Kotlin para burbuja (Hito 3) y teclado (K1+). Las alternativas que siguen se conservan como registro histórico de la evaluación.

### Opción A – Flutter (recomendada para la mayoría)

|Aspecto|Tecnología / Package|
|-|-|
|Framework|Flutter 3.24+|
|UI|Material 3 / Cupertino|
|STT Local|histórico — removido en Hito 2 (solo Cloud vigente; ver `docs/archive/teclado-voice.md` D4)|
|STT Cloud|`http` + cliente OpenAI/Groq|
|Audio recording|`record` o `flutter_sound`|
|Storage|`hive` o `shared_preferences`|
|Secure storage|`flutter_secure_storage`|
|Floating bubble|Platform Channel + WindowManager nativo o plugin `flutter_overlay_window` / similar|
|Accessibility|histórico — BLOQUEADO 2026-09-05 (perfil anti-Play-Protect; sin servicio declarado)|
|Build APK|CI en GitHub Actions (única vía; ver abajo)|

**Ventajas**: desarrollo rápido, packages maduros de Whisper local, builds APK triviales.  
**Desventajas**: el overlay y Accessibility requieren algo de código nativo (Kotlin/Java).

### Opción B – Kotlin nativo + Jetpack Compose (máximo control)

|Aspecto|Tecnología|
|-|-|
|Lenguaje|Kotlin 2.0+|
|UI|Jetpack Compose + Material 3|
|STT Local|histórico — removido en Hito 2 (solo Cloud vigente)|
|STT Cloud|OkHttp / Retrofit + coroutines|
|Audio|MediaRecorder o AudioRecord (16 kHz mono)|
|Storage|DataStore Preferences + (opcional) Room|
|Secure storage|EncryptedSharedPreferences / Keystore|
|Floating bubble|WindowManager (TYPE_APPLICATION_OVERLAY) + Foreground Service|
|Accessibility|AccessibilityService nativo|
|Build APK|Gradle (`assembleDebug` / `assembleRelease`)|

**Ventajas**: control total, mejor rendimiento, integración perfecta de permisos y servicios del sistema.  
**Desventajas**: más código boilerplate y curva de aprendizaje mayor.

### Stack descartado / no recomendado como principal

* **React Native + Expo**: viable pero más fricción para local Whisper de alta calidad y para el overlay real (necesita Dev Client / Bare Workflow + módulos nativos).
* **Pocket Code**: solo útil para edición rápida de scripts o prototipos muy limitados. **No** sirve para overlay de sistema, Accessibility Service ni modelos nativos de STT.

## Arquitectura de alto nivel

```
┌─────────────────────────────────────────────────────────┐
│                    App Principal                        │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │ Home Screen │  │ Settings     │  │ Historial (20) │ │
│  │ - Grabar    │  │ - API Key    │  │ - Lista FIFO   │ │
│  │ - Texto     │  │ - Snippets   │  │ - Copiar       │ │
│  │ - Copiar    │  │ - Permisos   │  └────────────────┘ │
│  └─────────────┘  └──────────────┘                     │
└─────────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌─────────────────┐ ┌─────────────┐ ┌──────────────────┐
│ Transcription   │ │ Floating    │ │ Storage          │
│ Engine (Cloud:  │ │ Bubble      │ │ (últimas 20)     │
│  Groq/OpenAI)   │ │ Service     │ │                  │
│                 │ │             │ │ shared_prefs +   │
│                 │ │ + Overlay   │ │ secure storage   │
└─────────────────┘ └─────────────┘ └──────────────────┘

  (K1+ añade VoiceKeyboardService: teclado nativo Kotlin, ver docs/archive/teclado-voice.md)
```

## Permisos requeridos

Fuente canónica de permisos y justificación: **`INSTALL.md` §4** (única fuente de verdad; no se duplica aquí).

* Sin `AccessibilityService` declarado (perfil anti-Play-Protect desde 2026-09-05): cero fricción de accesibilidad al instalar. La clase nativa queda versionada pero dormida; isla y trackpad usan sus fallbacks locales.

## Flujo de usuario ideal

1. Abrir la app → conceder permisos de micrófono.
2. (Opcional) Configurar API key de Groq/OpenAI en Settings.
3. En la pantalla principal: mantener pulsado o tocar “Grabar” → hablar → soltar → ver texto → tocar “Copiar”.
4. Activar burbuja flotante desde Settings o botón dedicado.
5. Desde cualquier otra app: tocar la burbuja → hablar → el texto se inserta directo en cursor si usás nuestro teclado; si no, queda en portapapeles con aviso para pegado manual. Para Termux se recomienda nuestro teclado (inserción directa).
6. Alternativa: en Ajustes de Android elegir "VoiceBubble Keyboard" como teclado actual → escribir o dictar directamente en el campo de cualquier app.

## Modo Teclado – VoiceBubble Keyboard (hitos K1–K5)

Además de la burbuja, la misma app (mismo APK) ofrece un **teclado del sistema** con nombre visible **"VoiceBubble Keyboard"**, construido nativamente en Kotlin (sin Flutter embebido, por rendimiento). Decisiones cerradas D1–D9: `docs/archive/teclado-voice.md` §3.

### Cómo activarlo

1. Ajustes de Android → Sistema → "Manage keyboards" / Métodos de entrada → activar **VoiceBubble Keyboard** (Android mostrará la advertencia estándar sobre teclados de terceros).
2. Seleccionarlo como teclado actual (botón selector de IME, o la tarjeta "Teclado VoiceBubble" en Settings de la app, que muestra el estado y lleva directo a los Ajustes del sistema).
3. Sin configuración extra: la API key ya guardada se comparte con el teclado (detalle del espejo: **`INSTALL.md`** §3).

### Funciones

* **QWERTY es/en**: subtipos español (es-ES) e inglés (en-US) con tecla de alternancia de idioma (ocultable desde Ajustes).
* **Capa símbolos** básica: números y puntuación habitual.
* **Capa código** (tecla `</>`): llaves, corchetes, paréntesis, símbolos poco comunes (`\ | & $ # ~ ^`), comillas y backticks; toque largo = par auto-cerrado (ej. `{` inserta `{}`).
* **Fila terminal** (presente en todas las capas): TAB, ESC, CTRL (toggle), ALT (toggle) y flechas ↑ ↓ ← → — pensada para usar Termux de verdad y editar en Acode; ocultable desde Ajustes si ya usás un teclado con teclas propias.
* **Dictado por voz dentro del teclado** (botón 🎤): dicta y el texto se inserta donde esté el cursor, con el mismo motor cloud y la misma API key de la app; grabaciones de hasta **5 minutos**; **historial emergente** con toque largo sobre el micrófono en reposo (últimas 20 transcripciones; tocar una la inserta en el cursor).
* **Snippets** (hito K4): atajos de texto/comandos creados y editados en Settings (CRUD completo) e insertables desde una capa de chips con búsqueda por nombre (con filas QWERTY propias para escribir el filtro sin salir de la capa); toque largo en un chip = menú contextual (insertar / copiar al portapapeles / editar en la app). La primera apertura de la capa precarga **5 seeds editables/borrables**: `codex "`, `gemini -p "`, `git add . && git commit -m "`, `git push origin main`, `supabase db push`.
* **Exclusión mutua de micrófono burbuja↔teclado**: si uno está grabando, el otro muestra estado ocupado (flag en memoria del proceso + audio focus).
* **Pulido y personalización** (K5): tema claro/oscuro completo siguiendo el sistema, altura del teclado configurable (baja/media/alta), vibración on/off, e i18n completo es/en de las etiquetas internas (incluidos los avisos de error de red/API).

Spec completa e investigación: **`docs/archive/teclado-voice.md`**.

### Promesa de privacidad del teclado

* El teclado **jamás registra, guarda ni transmite** lo tecleado (ni en logs).
* En campos de contraseña no aparece el micrófono, y sin dictado, snippets ni aprendizaje.
* Red usada **solo** en transcripciones iniciadas explícitamente por el usuario.
* Cero analytics, cero telemetría.

## Limitaciones conocidas de Android

* Algunos fabricantes (Xiaomi, Huawei, Oppo, Samsung, etc.) matan agresivamente los servicios en segundo plano → el usuario debe desactivar la optimización de batería para la app (guía por fabricante en **`INSTALL.md`** §5).
* `SYSTEM_ALERT_WINDOW` es permiso “especial” que el usuario concede manualmente (guía de avisos de Play Protect y ajustes restringidos: `INSTALL.md` §2b).
* En Android Go o dispositivos con poca RAM el overlay puede estar restringido.
* Android muestra la advertencia estándar sobre teclados de terceros al activar un IME; se mitiga con cero logging y código auditable.

## Cómo obtener el APK de testing (CI como única vía)

No hay builds locales (esta máquina es Termux/proot ARM64 sin Flutter/SDK; ver `AGENTS.md` §6).
El APK se compila en GitHub Actions (`.github/workflows/android.yml`):

- Cada push a `main` que toque código ejecuta: pub get → analyze estricto → test → `flutter build apk --debug --split-per-abi` → sube el artefacto `voice-bubble-arm64-debug-apk-r<N>` (retención 7 días).
- Dentro del ZIP está `app-arm64-v8a-debug.apk`.
- Descarga: GitHub → Actions → run verde más reciente → Artifacts. Ver paso a paso en **`INSTALL.md`** §1.

Los APKs se instalan activando “Orígenes desconocidos” / “Instalar apps desconocidas”. Para la instalación paso a paso, la activación de burbuja/teclado y la guía de batería por fabricante, ver **`INSTALL.md`**.

## Privacidad

* El audio se envía únicamente al proveedor configurado por el usuario (Groq/OpenAI) y solo cuando este inicia una transcripción.
* La API key se almacena cifrada (`flutter_secure_storage`); detalle del espejo para el teclado en **`INSTALL.md`** §3.
* No se recolectan analytics ni se envían datos de uso.
* Teclado: jamás registra texto tecleado (ver "Promesa de privacidad del teclado").

## Roadmap de alto nivel

Ver **docs/archive/plan.md** para el desglose completo de hitos, tareas y criterios de aceptación listos para ejecución por una IA o desarrollador.

\---

**Estado actual del proyecto**: Hitos 0–3 completados y verificados en dispositivo real (ago 2026). Hito 4 (Accessibility) → **BLOQUEADO 2026-09-05** (perfil anti-Play-Protect): sin servicio declarado, sin inyección con tercer teclado; la burbuja pega vía IME propio (`commitText`) o portapapeles. Spec archivada en `plan-hito4-burbuja-hibrida.md` §6. Alcance dual según `docs/archive/teclado-voice.md` (T0–K5) completado y auditado. Lote v1.2 completado con CI verde (runs `32679923216` y `32682031857`, APK r64): Configuración reestructurada a 4 tabs glass inferiores C2 (`IndexedStack` persistente en memoria), tecla micrófono M4 con morphing a pastilla roja expandida, cronómetro en vivo `M:SS`, botón cancelar $\ge 44\text{dp}$, ícono vectorial nativo Liquid Glass `kb_ic_mic.xml` (reemplazo definitivo del emoji) y animación de 3 puntos en ola en estado de procesamiento (`PROCESSING`). Pipeline CI optimizado con APK split arm64 que redujo el tamaño de 168 MB a ~54 MB (-67%).

