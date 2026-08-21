# VoiceBubble STT – App Android de Transcripción de Voz a Texto

Aplicación Android **extremadamente simple** cuyo único propósito es convertir voz en texto, con soporte dual (API cloud + IA local en dispositivo), historial de las últimas 20 transcripciones y **burbuja flotante** para usar desde cualquier otra app.

## Características principales

* Transcripción de voz a texto **solo** (nada de notas, resúmenes, traducción, etc.).
* **Dos motores**:

  * **Cloud**: API key (OpenAI Whisper / gpt-4o-transcribe, Groq, o compatible).
  * **Local (offline)**: Modelo on-device (Whisper Tiny/Base cuantizado vía whisper.cpp / sherpa-onnx / Vosk / ML Kit GenAI Speech Recognition).
* UI minimalista: botón Grabar → texto → **Copiar con un solo click**.
* Historial persistente de las **últimas 20 transcripciones** (FIFO) con timestamp y modo usado.
* **Burbuja flotante** (overlay) arrastrable:

  * Se activa desde cualquier app.
  * Tocar → grabar → transcribir → copiar al clipboard + (opcional) inyectar texto en el campo enfocado mediante Accessibility Service.
* Generación fácil de APK de testing (debug y release).

## Objetivos de diseño

* Máxima simplicidad de uso.
* Privacidad: el modo local **nunca** envía audio fuera del dispositivo.
* Bajo consumo de batería y memoria (modelos pequeños por defecto).
* Funciona en Android 8+ (recomendado Android 12+ / API 31+ para mejor soporte de servicios y ML Kit).

## Stack tecnológico recomendado

Se proponen **dos stacks principales**. Ambos son viables. La decisión final se toma en el Hito 0 del PLAN.md.

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
│  │ - Texto     │  │ - Modelos    │  │ - Copiar       │ │
│  │ - Copiar    │  │ - Permisos   │  └────────────────┘ │
│  └─────────────┘  └──────────────┘                     │
└─────────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
┌─────────────────┐ ┌─────────────┐ ┌──────────────────┐
│ Transcription   │ │ Floating    │ │ Storage          │
│ Engine          │ │ Bubble      │ │ (últimas 20)     │
│                 │ │ Service     │ │                  │
│ ├─ LocalEngine  │ │             │ │ DataStore / Hive │
│ └─ CloudEngine  │ │ + Overlay   │ │                  │
└─────────────────┘ │ + Accessib. │ └──────────────────┘
                    └─────────────┘
```

## Permisos requeridos

```xml
<uses-permission android:name="android.permission.RECORD\_AUDIO" />
<uses-permission android:name="android.permission.SYSTEM\_ALERT\_WINDOW" />
<uses-permission android:name="android.permission.FOREGROUND\_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND\_SERVICE\_MICROPHONE" /> <!-- Android 14+ -->
<uses-permission android:name="android.permission.POST\_NOTIFICATIONS" />
```

* Declaración de `AccessibilityService` en el `AndroidManifest.xml` (el usuario debe activarlo manualmente en Ajustes).

## Flujo de usuario ideal

1. Abrir la app → conceder permisos de micrófono.
2. (Opcional) Configurar API key y/o descargar modelo local.
3. En la pantalla principal: mantener pulsado o tocar “Grabar” → hablar → soltar → ver texto → tocar “Copiar”.
4. Activar burbuja flotante desde Settings o botón dedicado.
5. Desde cualquier otra app: tocar la burbuja → hablar → el texto se copia automáticamente (y se intenta inyectar si hay Accessibility activo).

## Limitaciones conocidas de Android

* Algunos fabricantes (Xiaomi, Huawei, Oppo, etc.) matan agresivamente los servicios en segundo plano → el usuario debe desactivar optimización de batería para la app.
* `SYSTEM\_ALERT\_WINDOW` y Accessibility Service son permisos “especiales” que el usuario debe conceder manualmente.
* En Android Go o dispositivos con poca RAM el overlay puede estar restringido.
* Modelos locales grandes (>150 MB) pueden causar OOM o lentitud en gamas bajas → por defecto se usa Tiny/Base cuantizado.

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

Los APKs se instalan activando “Orígenes desconocidos” / “Instalar apps desconocidas”.

## Privacidad

* Modo **Local**: el audio **nunca** sale del dispositivo.
* Modo **Cloud**: el audio se envía únicamente al proveedor de la API key que el usuario configure.
* La API key se almacena de forma segura (EncryptedSharedPreferences / flutter\_secure\_storage).
* No se recolectan analytics ni se envían datos de uso por defecto.

## Roadmap de alto nivel

Ver **PLAN.md** para el desglose completo de hitos, tareas y criterios de aceptación listos para ejecución por una IA o desarrollador.

\---

**Estado actual del proyecto**: Planificación completa. Listo para iniciar Hito 0.

