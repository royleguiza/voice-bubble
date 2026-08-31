# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Usuarios de Android que necesitan transcribir voz a texto de forma rápida y sencilada, especialmente:
- Profesionales que necesitan dictar notas o documentos
- Personas con discapacidades motoras que prefieren voz sobre teclado
- Usuarios que necesitan transcribir mientras usan otras apps (burbuja flotante)
- Desarrolladores que trabajan en terminal (modo código del teclado)

## Product Purpose

VoiceBubble STT es una app Android de transcripción de voz a texto con interfaz de burbuja flotante. Su propósito es hacer la transcripción extremadamente simple: un toque para grabar, resultado inmediato, copiar con un toque. La app existe para eliminar la fricción entre pensamiento y texto escrito.

## Positioning

La única app de transcripción que ofrece:
1. Burbuja flotante que funciona sobre cualquier otra app
2. Teclado nativo del sistema con dictado integrado
3. Diseño Apple Liquid Glass en Android (experiencia visual premium)
4. Modo código con teclas terminal (TAB, ESC, CTRL) para desarrolladores

## Operating Context

- Sistema: Android 9+ (minSdk 28)
- Conexión: Cloud (Groq Whisper) requiere internet; grabación funciona offline
- Hardware: micrófono del dispositivo
- Instalación: APK debug desde GitHub Actions (no Play Store)
- Uso típico: abrir app → grabar → copiar resultado → pegar en cualquier lugar
- Uso avanzado: burbuja flotante → grabar desde otra app → resultado en portapapeles
- Teclado: configurar como teclado del sistema → dictar en cualquier campo de texto

## Capabilities and Constraints

### Capacidades confirmadas
- Transcripción Cloud con Groq (whisper-large-v3)
- Historial de últimas 20 transcripciones (FIFO)
- Burbuja flotante con copiado rápido
- Teclado nativo con 3 capas: QWERTY, Código, Snippets
- Dictado por voz en el teclado
- Modo oscuro/claro automático (sistema)
- Snippets editables con 5 ejemplos precargados

### Restricciones técnicas
- Solo Android (no iOS, no web)
- Flutter + Kotlin nativo (teclado)
- Sin emulador local (build via GitHub Actions)
- Sin Play Store (distribución por APK)
- Almacenamiento GitHub Actions limitado (APKs comprimidos)

### Decisiones pendientes
- (Ninguna pendiente - todas las decisiones están documentadas en plan.md y teclado-voice.md)

## Brand Commitments

- Nombre: VoiceBubble STT
- Diseño: Apple Liquid Glass (documentado en design.md)
- Icono: micrófono + burbuja (círculo)
- Voz: directa, sin rodeos, en español
- Personalidad: simple, rápida, confiable

## Evidence on Hand

- App funcional con 368+ tests
- Diseño documentado en design.md con tokens Liquid Glass
- Backlog de 24 mejoras en MEJORAS-SEPTIEMBRE.md
- Planes aprobados: plan-clipboard.md, plan-ciclar-mayusculas.md
- UI de laboratorio en laboratorio_ui/index.html (24 variantes de diseño)

## Product Principles

1. **Simplicidad radical**: un usuario nuevo debe entender la app en 10 segundos
2. **Velocidad**: desde abrir la app hasta tener texto copiado, menos de 15 segundos
3. **No interrumpir**: la burbuja flotante permite transcribir sin salir de la app actual
4. **Privacidad primero**: audio solo viaja a internet cuando el usuario inicia transcripción
5. **Consistencia nativa**: el teclado se siente como parte del sistema Android

## Accessibility & Inclusion

- TalkBack: labels semánticos en todos los controles
- Targets táctiles ≥ 44×44 dp
- Contraste mínimo 4.5:1 (ideal 7:1)
- Reduced Motion: transiciones directas sin rebote
- Reduce Transparency: opacidad aumentada, blur reducido
- Increase Contrast: elementos casi blanco/negro puros
