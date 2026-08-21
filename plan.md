# PLAN.md – Plan de Ejecución Detallado: VoiceBubble STT

Este documento está diseñado para ser ejecutado paso a paso por un desarrollador o por una IA (Cursor, Claude, Grok, etc.).  
Cada hito tiene **objetivos claros**, **tareas concretas**, **criterios de aceptación** y **notas técnicas**.

**Regla de oro**: No avanzar al siguiente hito hasta que el actual cumpla **todos** los criterios de aceptación.

\---

## Hito 0 – Decisión de Stack y Setup Inicial del Proyecto

**Objetivo**: Elegir el stack definitivo y tener un proyecto vacío que compile y genere un APK instalable.

### Tareas

1. Decidir entre **Opción A (Flutter)** o **Opción B (Kotlin + Compose)**.

   * Criterio de decisión:

     * Si el desarrollador domina Dart/Flutter o quiere máxima velocidad → **Flutter**.
     * Si quiere máximo control del sistema Android y rendimiento nativo → **Kotlin**.
   * Documentar la decisión en este archivo (añadir al final de este hito).
2. Crear el repositorio GitHub (público o privado).
3. Inicializar el proyecto:

   * **Flutter**:

```bash
     flutter create voice\_bubble\_stt --org com.tuorg --platforms android
     cd voice\_bubble\_stt
     ```

   * **Kotlin**:

     * Crear proyecto vacío en Android Studio (Empty Activity + Compose).
     * Package name: `com.tuorg.voicebubblestt`
4. Configurar `minSdkVersion` ≥ 26 (recomendado 28 o 31).
5. Configurar `targetSdkVersion` actual (34 o 35).
6. Añadir permisos básicos al `AndroidManifest.xml` (solo RECORD\_AUDIO por ahora).
7. Generar el primer APK debug e instalarlo en un dispositivo real.
8. Verificar que la app se abre sin crash.

### Criterios de aceptación

* [x] Proyecto crea y compila sin errores.
* [x] Se genera un APK (`app-debug.apk` o equivalente).
* [x] El APK se instala y abre en un teléfono Android real.
* [x] Decisión de stack documentada.

### Notas técnicas para IA

* Preferir siempre builds debug al principio.
* Usar Git desde el día 1 (`git init` + primer commit).
* No añadir todavía dependencias pesadas de STT.

**Decisión de stack (completar aquí):**  
`\[X] Flutter   \[ ] Kotlin nativo`

### Decisiones tomadas (Hito 0 – 2026-08-21)

* **Stack**: Flutter.
  * Motivo: desarrollo rápido, packages maduros de STT local (`sherpa\_onnx`), builds de APK triviales. El overlay y Accessibility (Hitos 3-4) se harán con código nativo Kotlin vía platform channels.
* **Package name**: `com.royleguiza.voicebubblestt`
* **minSdkVersion**: 28 (Android 9+)
* **targetSdkVersion**: la más actual disponible al configurar el proyecto
* **Ubicación del proyecto**: subcarpeta `voice_bubble_stt/` dentro de este repo (el repo raíz queda para docs: README.md, plan.md)
* **Entorno de build**: la máquina de desarrollo es un teléfono Android (Termux/proot, ARM64) sin Flutter ni Android SDK locales → los APK se generan con **GitHub Actions** (workflow `.github/workflows/android.yml`) y se instalan manualmente en el teléfono físico desde los artefactos de Actions.

\---

## Hito 1 – Transcripción Básica (App principal sin floating)

**Objetivo**: Tener una pantalla principal funcional que grabe audio, lo transcriba (cloud + local) y permita copiar el texto con un click. Historial de 20 entradas.

### Tareas

#### 1.1 UI mínima

* Pantalla Home con:

  * Selector de modo: **Local** / **Cloud** (Toggle o SegmentedButton).
  * Botón grande “Grabar” / “Detener” (o hold-to-talk).
  * Área de texto grande que muestra el resultado (seleccionable).
  * Botón “Copiar” (icono Clipboard) que copia al clipboard y muestra Snackbar/Toast “Copiado”.
  * Lista simple de las últimas 20 transcripciones (abajo o en otra pestaña).
  * Botón de Settings (icono engranaje).

#### 1.2 Grabación de audio

* Grabar en formato compatible con Whisper: **16 kHz, mono, 16-bit PCM** (preferible) o WAV/M4A que se convierta.
* Flutter: package `record` o `flutter\_sound`.
* Kotlin: `AudioRecord` o `MediaRecorder` + conversión si es necesario.
* Manejar permisos de micrófono en runtime.

#### 1.3 Motor Cloud

* Campo en Settings para introducir API Key (OpenAI o Groq).
* Almacenar la key de forma segura.
* Endpoint recomendado:

  * OpenAI: `https://api.openai.com/v1/audio/transcriptions` (modelo `whisper-1` o `gpt-4o-transcribe`).
  * Groq: equivalente (más rápido y barato).
* Enviar el archivo de audio y mostrar el texto resultante.
* Manejo de errores (key inválida, sin internet, cuota, etc.).

#### 1.4 Motor Local

* Integrar **uno** de estos (empezar por el más fácil):

  * Flutter: `sherpa\_onnx` o `whisper\_ggml` / `whisper\_edge`.
  * Kotlin: ML Kit GenAI Speech Recognition (más fácil) **o** whisper.cpp vía JNI **o** sherpa-onnx.
* Descargar o empaquetar modelo **Tiny** o **Base cuantizado** (≤ 80 MB).
* Procesar el audio grabado y devolver texto.
* Mostrar indicador de “Procesando localmente…” (puede tardar 2-15 s según dispositivo y modelo).

#### 1.5 Historial

* Guardar cada transcripción exitosa: `{ texto, timestamp, modo: "local"|"cloud" }`.
* Mantener **exactamente las últimas 20** (eliminar la más antigua cuando se supera).
* Flutter: Hive o shared\_preferences (JSON).
* Kotlin: DataStore Preferences o Room.
* Mostrar lista en Home (más reciente arriba).
* Botón “Copiar” en cada ítem del historial.

#### 1.6 Settings básicos

* Input para API Key (con botón “Guardar” y “Borrar”).
* Información del modelo local cargado / botón “Descargar modelo” (si aplica).
* Versión de la app.

### Criterios de aceptación

* \[ ] Se puede grabar y transcribir en modo **Cloud** con API key válida.
* \[ ] Se puede grabar y transcribir en modo **Local** (aunque sea lento).
* \[ ] El botón “Copiar” pone el texto en el clipboard y notifica al usuario.
* \[ ] Las últimas 20 transcripciones se guardan y se muestran correctamente tras reiniciar la app.
* \[ ] No hay crashes al cambiar de modo o al fallar la red/API.
* \[ ] APK de testing instalable y usable.

### Notas técnicas para IA

* Priorizar **calidad de audio** (16 kHz mono) porque afecta mucho la precisión de Whisper.
* Empezar siempre con el modelo local **más pequeño**.
* En cloud, usar `multipart/form-data` para enviar el archivo.
* Nunca hardcodear la API key.

\---

## Hito 2 – Mejoras de UX y Robustez de la App Principal

**Objetivo**: Hacer la app agradable y resistente a errores comunes.

### Tareas

1. Indicadores visuales claros:

   * Estado “Grabando…” (animación o color rojo).
   * Estado “Transcribiendo…” (spinner + texto).
   * Diferenciar visualmente Local vs Cloud.
2. Feedback háptico al empezar/parar grabación (opcional pero recomendado).
3. Manejo de permisos denegados (explicar por qué se necesita el micrófono y redirigir a Settings).
4. Limpieza de archivos temporales de audio después de transcribir.
5. Soporte básico de idioma (al menos español e inglés). Pasar el parámetro `language` al motor cuando sea posible.
6. Botón “Borrar historial”.
7. Mejorar el diseño (Material 3, tipografía legible, contraste alto).
8. Probar en al menos 2 dispositivos reales (uno gama media/baja).

### Criterios de aceptación

* \[ ] La UX es clara e intuitiva para un usuario no técnico.
* \[ ] No quedan archivos de audio huérfanos en el almacenamiento.
* \[ ] La app no crashea si se niega el permiso de micrófono.
* \[ ] Historial se puede vaciar.

\---

## Hito 3 – Burbuja Flotante Básica (Overlay + Clipboard)

**Objetivo**: Tener una burbuja que flote sobre otras apps, grabe, transcriba y copie el resultado al clipboard.

### Tareas

1. Solicitar permiso `SYSTEM\_ALERT\_WINDOW` (abrir Settings.ACTION\_MANAGE\_OVERLAY\_PERMISSION).
2. Crear un **Foreground Service** con notificación persistente (obligatorio).
3. Implementar el overlay con `WindowManager` (TYPE\_APPLICATION\_OVERLAY).

   * Burbuja circular arrastrable (icono de micrófono).
   * Snap to edge opcional.
4. Al tocar la burbuja:

   * Iniciar grabación.
   * Al tocar de nuevo (o soltar si es hold-to-talk) → detener → transcribir con el motor seleccionado actualmente → copiar al clipboard.
5. Mostrar Toast o notificación pequeña “Texto copiado”.
6. Botón en la app principal para “Activar / Desactivar burbuja”.
7. Manejar el ciclo de vida del servicio (start/stop correctamente).

### Criterios de aceptación

* \[ ] La burbuja aparece sobre otras apps (WhatsApp, Chrome, Notas, etc.).
* \[ ] Se puede arrastrar.
* \[ ] Al usarla se graba, se transcribe y el texto queda en el clipboard.
* \[ ] La notificación del Foreground Service es visible y no se puede descartar fácilmente.
* \[ ] Al cerrar la burbuja el servicio se detiene limpiamente.
* \[ ] Funciona después de reiniciar el teléfono (opcional, pero deseable con BootReceiver).

### Notas técnicas para IA

* En Flutter se necesita un **Platform Channel** o un plugin nativo (Kotlin) para el WindowManager.
* Usar `FOREGROUND\_SERVICE\_MICROPHONE` en Android 14+.
* Probar exhaustivamente en Xiaomi / Samsung (son los más agresivos con battery optimization).

\---

## Hito 4 – Pegado Inteligente con Accessibility Service

**Objetivo**: Que el texto se inserte automáticamente en el campo de texto enfocado de la app que el usuario está usando.

### Tareas

1. Crear y declarar un `AccessibilityService` en el manifest.
2. Solicitar al usuario que active el servicio en Ajustes → Accesibilidad.
3. Detectar cuando hay un `EditText` / campo editable enfocado.
4. Al terminar la transcripción desde la burbuja:

   * Intentar inyectar el texto mediante Accessibility (ACTION\_SET\_TEXT o similar).
   * Si falla → fallback a clipboard + notificación.
5. Documentar claramente en la UI por qué se necesita el permiso de Accesibilidad (solo se usa para pegar texto).
6. Manejar el caso en que el usuario no active Accessibility (la app sigue funcionando solo con clipboard).

### Criterios de aceptación

* \[ ] Con Accessibility activado, el texto se pega automáticamente en WhatsApp, Gmail, Notes, etc.
* \[ ] Sin Accessibility, el texto queda en clipboard y se notifica al usuario.
* \[ ] El servicio de accesibilidad **solo** se usa para insertar texto (no lee contenido de pantalla innecesariamente).
* \[ ] La explicación al usuario es clara y transparente.

### Notas técnicas para IA

* Accessibility Service es sensible en Google Play. Si se va a publicar, hay que declarar el uso exacto.
* Probar en múltiples apps (algunas apps bancarias bloquean Accessibility).

\---

## Hito 5 – Optimización, Modelos y Pulido Final

**Objetivo**: App lista para uso diario real.

### Tareas

1. Descarga on-demand de modelos locales más grandes (Base / Small) con barra de progreso.
2. Selector de modelo local en Settings.
3. Optimización de memoria y batería:

   * Liberar modelo de memoria cuando no se use.
   * Usar modelos cuantizados (Q5\_0, Q8\_0, etc.).
4. Manejo robusto de Android 14/15 (foreground service types, restricted settings).
5. Guía de “cómo desactivar optimización de batería” (especialmente Xiaomi, Huawei, Oppo).
6. Icono de la app y de la burbuja profesionales.
7. Splash screen simple.
8. Testing exhaustivo:

   * Grabaciones cortas y largas (hasta 1-2 minutos).
   * Ruido de fondo.
   * Diferentes acentos (español de España, Latam, inglés).
   * Rotación de pantalla (si se soporta).
9. Generar APK **release** firmado.
10. Crear archivo `INSTALL.md` con instrucciones claras de instalación y permisos.

### Criterios de aceptación

* \[ ] La app se siente fluida en un dispositivo de gama media (Snapdragon 7xx / Dimensity 700+).
* \[ ] Modelo Tiny funciona offline sin problemas.
* \[ ] APK release se puede instalar y funciona.
* \[ ] Documentación de instalación clara.

\---

## Hito 6 – Testing Final y Entrega

**Objetivo**: Entregar una versión usable y documentada.

### Tareas

1. Lista de checklist final de funcionalidades.
2. Probar en al menos 3 dispositivos reales diferentes.
3. Grabar un video corto de demostración (opcional pero muy útil).
4. Actualizar README.md con capturas de pantalla e instrucciones finales.
5. Tag de versión en Git (`v1.0.0`).
6. (Opcional) Subir a Google Play Internal Testing o solo distribuir el APK.

### Criterios de aceptación

* \[ ] Todas las features del README funcionan.
* \[ ] No hay crashes conocidos.
* \[ ] El usuario puede instalar, conceder permisos y usar la burbuja en menos de 3 minutos.

\---

## Orden de prioridad de motores STT (recomendado)

1. **Cloud**: OpenAI o Groq (rápido de implementar, excelente calidad).
2. **Local fácil**: ML Kit GenAI Speech Recognition (Kotlin) o sistema SpeechRecognizer.
3. **Local de calidad**:

   * sherpa-onnx (rápido en Android)
   * whisper.cpp (mejor calidad, un poco más lento)
   * Vosk (muy ligero, buena para streaming)

Empezar siempre por Cloud + un local sencillo, luego mejorar el local.

\---

## Estructura de carpetas sugerida (Flutter)

```
lib/
├── main.dart
├── screens/
│   ├── home\_screen.dart
│   └── settings\_screen.dart
├── services/
│   ├── transcription\_service.dart
│   ├── local\_stt\_service.dart
│   ├── cloud\_stt\_service.dart
│   ├── storage\_service.dart
│   └── floating\_bubble\_service.dart   # platform channel
├── models/
│   └── transcription.dart
└── widgets/
    ├── record\_button.dart
    └── history\_list.dart
```

## Estructura de carpetas sugerida (Kotlin)

```
app/src/main/java/com/tuorg/voicebubblestt/
├── ui/
│   ├── HomeScreen.kt
│   ├── SettingsScreen.kt
│   └── theme/
├── service/
│   ├── FloatingBubbleService.kt
│   ├── TranscriptionAccessibilityService.kt
│   └── TranscriptionEngine.kt
├── data/
│   ├── TranscriptionRepository.kt
│   └── PreferencesManager.kt
└── MainActivity.kt
```

\---

## Consejos finales para la IA que ejecute este plan

1. **Un hito a la vez**. No mezclar.
2. Después de cada cambio importante → generar APK y probar en dispositivo real.
3. Commitear al final de cada hito.
4. Si algo falla en un dispositivo específico (Xiaomi, etc.), documentarlo y añadir workaround.
5. Priorizar siempre la **simplicidad** de la UI. El usuario debe entender la app en 10 segundos.
6. Nunca enviar audio en modo Local.
7. Mantener el historial estrictamente en 20 elementos.

Cuando termines el Hito 0, actualiza la sección “Decisión de stack” y avanza.

**¡Éxito con el desarrollo!**

