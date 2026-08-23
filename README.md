# VoiceBubble STT – App Android de Transcripción de Voz a Texto

Aplicación Android **extremadamente simple** cuyo propósito es convertir voz en texto con motor cloud (API OpenAI/Groq), historial de las últimas 20 transcripciones y **burbuja flotante** para usar desde cualquier otra app. Alcance dual: además de la burbuja, incluye un **teclado del sistema con dictado por voz y snippets** (ver "Modo Teclado" más abajo).

## Características principales

* Transcripción de voz a texto **solo** (nada de notas, resúmenes, traducción, etc.).
* **Motor único Cloud**: Groq `whisper-large-v3` (compatible con OpenAI). La API key la configura el usuario en Settings y se guarda cifrada. El modo local offline fue **removido** en el Hito 2 (decisión del dueño); su regreso está pospuesto (`teclado-voice.md`, D4).
* UI minimalista: botón Grabar → texto → **Copiar con un solo click**.
* Historial persistente de las **últimas 20 transcripciones** (FIFO) con timestamp y modo usado.
* **Burbuja flotante** (overlay) arrastrable:

  * Se activa desde cualquier app.
  * Tocar → grabar → transcribir → copiar al clipboard + (opcional) inyectar texto en el campo enfocado mediante Accessibility Service.
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
|STT Local|`sherpa\_onnx` o `whisper\_ggml` / `whisper\_edge`|
|STT Cloud|`http` + cliente OpenAI/Groq|
|Audio recording|`record` o `flutter\_sound`|
|Storage|`hive` o `shared\_preferences`|
|Secure storage|`flutter\_secure\_storage`|
|Floating bubble|Platform Channel + WindowManager nativo o plugin `flutter\_overlay\_window` / similar|
|Accessibility|Platform Channel|
|Build APK|`flutter build apk`|

**Ventajas**: desarrollo rápido, packages maduros de Whisper local, builds APK triviales.  
**Desventajas**: el overlay y Accessibility requieren algo de código nativo (Kotlin/Java).

### Opción B – Kotlin nativo + Jetpack Compose (máximo control)

|Aspecto|Tecnología|
|-|-|
|Lenguaje|Kotlin 2.0+|
|UI|Jetpack Compose + Material 3|
|STT Local|whisper.cpp (JNI) / sherpa-onnx / Vosk / ML Kit GenAI Speech Recognition|
|STT Cloud|OkHttp / Retrofit + coroutines|
|Audio|MediaRecorder o AudioRecord (16 kHz mono)|
|Storage|DataStore Preferences + (opcional) Room|
|Secure storage|EncryptedSharedPreferences / Keystore|
|Floating bubble|WindowManager (TYPE\_APPLICATION\_OVERLAY) + Foreground Service|
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

  (K1+ añade VoiceKeyboardService: teclado nativo Kotlin, ver teclado-voice.md)
```

## Permisos requeridos

```xml
<uses-permission android:name="android.permission.RECORD\_AUDIO" />
<uses-permission android:name="android.permission.SYSTEM\_ALERT\_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND\_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND\_SERVICE\_MICROPHONE" /> <!-- Android 14+ -->
<uses-permission android:name="android.permission.POST\_NOTIFICATIONS" />
<uses-permission android:name="android.permission.INTERNET" /> <!-- solo transcripciones iniciadas por el usuario -->
```

* Declaración de `AccessibilityService` en el `AndroidManifest.xml` (el usuario debe activarlo manualmente en Ajustes). **CONGELADO**: reevaluar tras K3.
* El servicio de teclado (K1) se declara con `android:permission="android.permission.BIND_INPUT_METHOD"` (la firma el sistema; no requiere acción del usuario).

## Flujo de usuario ideal

1. Abrir la app → conceder permisos de micrófono.
2. (Opcional) Configurar API key de Groq/OpenAI en Settings.
3. En la pantalla principal: mantener pulsado o tocar “Grabar” → hablar → soltar → ver texto → tocar “Copiar”.
4. Activar burbuja flotante desde Settings o botón dedicado.
5. Desde cualquier otra app: tocar la burbuja → hablar → el texto se copia automáticamente (y se intenta inyectar si hay Accessibility activo).
6. Alternativa: en Ajustes de Android elegir "VoiceBubble Keyboard" como teclado actual → escribir o dictar directamente en el campo de cualquier app.

## Modo Teclado – VoiceBubble Keyboard (hitos K1–K5)

Además de la burbuja, la misma app (mismo APK) ofrece un **teclado del sistema** con nombre visible **"VoiceBubble Keyboard"**, construido nativamente en Kotlin (sin Flutter embebido, por rendimiento). Decisiones cerradas D1–D9: `teclado-voice.md` §3.

### Cómo activarlo

1. Ajustes de Android → Sistema → "Manage keyboards" / Métodos de entrada → activar **VoiceBubble Keyboard** (Android mostrará la advertencia estándar sobre teclados de terceros).
2. Seleccionarlo como teclado actual (botón selector de IME, o la tarjeta "Teclado VoiceBubble" en Settings de la app, que muestra el estado y lleva directo a los Ajustes del sistema).
3. Sin configuración extra: la API key ya guardada se comparte con el teclado vía copia espejo en las preferencias privadas de la app (D7).

### Funciones

* **QWERTY es/en**: subtipos español (es-ES) e inglés (en-US) con tecla de alternancia de idioma (ocultable desde Ajustes).
* **Capa símbolos** básica: números y puntuación habitual.
* **Capa código** (tecla `</>`): llaves, corchetes, paréntesis, símbolos poco comunes (`\ | & $ # ~ ^`), comillas y backticks; toque largo = par auto-cerrado (ej. `{` inserta `{}`).
* **Fila terminal** (presente en todas las capas): TAB, ESC, CTRL (toggle), ALT (toggle) y flechas ↑ ↓ ← → — pensada para usar Termux de verdad y editar en Acode; ocultable desde Ajustes si ya usás un teclado con teclas propias.
* **Dictado por voz dentro del teclado** (botón 🎤): dicta y el texto se inserta donde esté el cursor, con el mismo motor cloud y la misma API key de la app; grabaciones de hasta **5 minutos**; **historial emergente** con toque largo sobre el micrófono en reposo (últimas 20 transcripciones; tocar una la inserta en el cursor).
* **Snippets** (hito K4): atajos de texto/comandos creados y editados en Settings (CRUD completo) e insertables desde una capa de chips con búsqueda por nombre (con filas QWERTY propias para escribir el filtro sin salir de la capa); toque largo en un chip = menú contextual (insertar / copiar al portapapeles / editar en la app). La primera apertura de la capa precarga **5 seeds editables/borrables**: `codex "`, `gemini -p "`, `git add . && git commit -m "`, `git push origin main`, `supabase db push`.
* **Exclusión mutua de micrófono burbuja↔teclado**: si uno está grabando, el otro muestra estado ocupado (flag en memoria del proceso + audio focus).
* **Pulido y personalización** (K5): tema claro/oscuro completo siguiendo el sistema, altura del teclado configurable (baja/media/alta), vibración on/off, e i18n completo es/en de las etiquetas internas (incluidos los avisos de error de red/API).

Spec completa e investigación: **`teclado-voice.md`**.

### Promesa de privacidad del teclado

* El teclado **jamás registra, guarda ni transmite** lo tecleado (ni en logs).
* En campos de contraseña no aparece el micrófono, y sin dictado, snippets ni aprendizaje.
* Red usada **solo** en transcripciones iniciadas explícitamente por el usuario.
* Cero analytics, cero telemetría.

## Limitaciones conocidas de Android

* Algunos fabricantes (Xiaomi, Huawei, Oppo, Samsung, etc.) matan agresivamente los servicios en segundo plano → el usuario debe desactivar la optimización de batería para la app (guía por fabricante en **`INSTALL.md`** §5).
* `SYSTEM\_ALERT\_WINDOW` y Accessibility Service son permisos “especiales” que el usuario debe conceder manualmente.
* En Android Go o dispositivos con poca RAM el overlay puede estar restringido.
* Android muestra la advertencia estándar sobre teclados de terceros al activar un IME; se mitiga con cero logging y código auditable.

## Cómo generar APK de testing

### Flutter

```bash
flutter build apk --debug          # testing rápido
flutter build apk --release        # más optimizado
```

### Kotlin nativo

```bash
./gradlew assembleDebug
./gradlew assembleRelease
```

### Expo (si se elige RN)

```bash
eas build --platform android --profile preview
```

Los APKs se instalan activando “Orígenes desconocidos” / “Instalar apps desconocidas”. Para la instalación paso a paso, la activación de burbuja/teclado y la guía de batería por fabricante, ver **`INSTALL.md`**.

## Privacidad

* El audio se envía únicamente al proveedor configurado por el usuario (Groq/OpenAI) y solo cuando este inicia una transcripción.
* La API key se almacena cifrada (`flutter_secure_storage`); el teclado accede a una copia espejo en preferencias privadas del paquete, inaccesibles para otras apps.
* No se recolectan analytics ni se envían datos de uso.
* Teclado: jamás registra texto tecleado (ver "Promesa de privacidad del teclado").

## Roadmap de alto nivel

Ver **PLAN.md** para el desglose completo de hitos, tareas y criterios de aceptación listos para ejecución por una IA o desarrollador.

\---

**Estado actual del proyecto**: Hitos 0–3 completados y verificados en dispositivo real (ago 2026). Hito 4 (Accessibility) congelado: el dictado desde el teclado cubre la inserción en cursor. Alcance dual según `teclado-voice.md` (T0–K5): teclado activable y QWERTY es/en verificados en dispositivo (K1, K2.1); capa código + fila terminal y dictado por voz (hasta 5 minutos, con historial emergente) implementados (K2/K3), pendiente verificación de casos borde; K4 (snippets con CRUD, capa en teclado, búsqueda propia y 5 seeds) y K5 (tema claro/oscuro completo, altura configurable baja/media/alta, vibración on/off, i18n es/en incluidos errores de red/API, escenarios hostiles robustecidos) implementados; Hito 5 re-definido como robustez Android 14/15 y también implementado localmente (FGS tipado de micrófono + `POST_NOTIFICATIONS` en runtime, icono adaptive + splash, `INSTALL.md` con guía de batería por fabricante, matriz de tests nueva). Todo esto vive en commits locales sin pushear: **pendiente la verificación del dueño en dispositivo y el CI del push final** (ver `PLAN-EJECUCION-LOOP.md` §11).

