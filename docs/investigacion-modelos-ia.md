# Investigación: modelos de transcripción y de notas (2026-11-16)

> Pedido del dueño: sumar más opciones de transcripción (con un desplegable
> para elegir modelo), los enlaces donde cada usuario saca su clave gratis
> (pensando en el Play Store), qué se puede usar con cada suscripción
> (Google, OpenAI, OpenRouter, Anthropic), y resolver la lentitud de
> «ordenar nota» / «generar título» con la clave de Google.
>
> Estado: **investigación, nada implementado todavía.** Precios y límites
> leídos de las páginas oficiales el 2026-11-16 (cambian seguido: volver a
> mirarlos antes de implementar).

## 1. Lo que usa la app hoy

| Para qué | Plataforma | Modelo | Dónde está |
|---|---|---|---|
| Transcribir (app, burbuja, teclado, widget) | Groq | `whisper-large-v3-turbo` (fijo) | `app_source/lib/services/cloud_stt_service.dart`, `SpeechToTextClient.kt` |
| Título y resumen de notas | Google (Gemini API) | `gemini-3.5-flash`, `thinkingLevel: minimal`, espera máx. 30 s | `gemini_note_service.dart`, `GeminiNoteClient.kt` |

- El modelo «más preciso pero más lento que puntuaba mejor» que recuerda el
  dueño es **`whisper-large-v3`**. La app lo cambia sola por el turbo
  (`SpeechToTextClient.resolveModel`): para volver a ofrecerlo hay que sacar
  esa migración.
- Ya existe la clave del puente `kb_stt_model` (Flutter ↔ teclado nativo), así
  que un desplegable de modelos de Groq necesita poco trabajo.

## 2. Transcripción: opciones por plataforma

### Groq (la de hoy) — gratis con límites
Clave: <https://console.groq.com/keys>

| Modelo | Precisión (error por palabra) | Velocidad | Precio pago | Notas |
|---|---|---|---|---|
| `whisper-large-v3-turbo` | 12 % | 216× tiempo real | US$ 0,04 / hora | El actual. El más rápido y barato. |
| `whisper-large-v3` | **10,3 %** | 189× tiempo real | US$ 0,111 / hora | El «de antes»: más preciso, mejor puntuación, apenas más lento. |

Plan gratis (los dos modelos): 20 pedidos por minuto, 2000 por día, 2 horas
de audio por hora y 8 horas por día. Archivo máx. 25 MB. Cobra mínimo 10 s
por pedido. **Recomendación: desplegable con estos dos, primera cosa a hacer.**

### Google (Gemini API / AI Studio) — gratis con límites
Clave: <https://aistudio.google.com/apikey> (es la misma que ya usa la app para las notas)

| Modelo | Plan gratis | Precio pago | Notas |
|---|---|---|---|
| `gemini-3.5-transcribe` | **Sí** | US$ 0,003/min de audio + texto | Modelo dedicado a transcribir: rápido, detecta idioma, separa hablantes y marca tiempos. |
| `gemini-3.5-flash-lite` (modelo general con audio) | Sí | US$ 0,30 por millón de tokens | Sirve, pero el dedicado conviene más. |

- Con el plan gratis, Google puede usar los datos para mejorar sus productos
  (hay que decirlo en la app y en la política de privacidad).
- Ventaja grande: **una sola clave de Google sirve para transcribir y para
  las notas.**
- La API de Google no usa el mismo formato que Groq/OpenAI: hay que escribir
  un cliente propio (el audio va adentro del pedido).

### OpenAI — solo pago (no tiene plan gratis)
Clave: <https://platform.openai.com/api-keys>

| Modelo | Estado | Precio |
|---|---|---|
| `gpt-transcribe` | Actual, el recomendado | ≈ US$ 0,0045/min |
| `whisper-1`, `gpt-4o-transcribe`, `gpt-4o-mini-transcribe` | **Se apagan el 26-02-2027** | — |

Solo conviene sumar `gpt-transcribe`. Usa el mismo formato que Groq (cambia
la dirección y el nombre del modelo), pero `gpt-transcribe` pide el campo
`languages` en vez de `language`.

### OpenRouter — una clave, muchos modelos (pago con crédito)
Clave: <https://openrouter.ai/settings/keys> · se carga saldo y se paga por uso.
Punto de acceso propio para transcribir: `/api/v1/audio/transcriptions`
(ninguno de sus 25 modelos de voz es gratis; tope de 60 s de procesamiento
por pedido, así que dictados muy largos pueden fallar).

| Modelo (id en OpenRouter) | Precio aprox. por hora de audio | Para qué |
|---|---|---|
| `openai/whisper-large-v3-turbo` | US$ 0,01 | El más barato |
| `qwen/qwen3-asr-0.6b` | US$ 0,01 | Barato |
| `openai/whisper-large-v3` | US$ 0,03 | Preciso y barato |
| `microsoft/mai-transcribe-2` | US$ 0,10 | **Nº 1 en precisión multilenguaje (FLEURS)** |
| `x-ai/grok-stt-2.0` | US$ 0,10 | — |
| `mistralai/voxtral-mini-transcribe-3-0` | US$ 0,21 | — |
| `elevenlabs/scribe-v2` | US$ 0,22 | Muy preciso, 90+ idiomas |
| `openai/gpt-transcribe` | US$ 0,27 | El de OpenAI |
| `deepgram/nova-3` | desde US$ 0,26 | — |
| `google/gemini-3.5-transcribe` | por tokens | El de Google |

Ventaja: con una sola clave el usuario prueba muchos modelos y compara
costo y precisión, que es justo lo que pidió el dueño.

### Otras con crédito de regalo (más adelante: cada una pide su propio cliente)
Deepgram (≈ US$ 200 de crédito al registrarse), AssemblyAI (≈ US$ 50),
Gladia (50 €), ElevenLabs (≈ 30 min/mes gratis), Mistral Voxtral
(≈ US$ 0,0035/min; no se confirmó plan gratis). No se recomiendan en la
primera etapa: casi todas también están en OpenRouter.

## 3. Suscripciones: qué sirve y qué no

| Si el usuario tiene… | ¿Lo puede usar en VoiceBubble? |
|---|---|
| Suscripción de Google (Gemini / Google One) | **No directamente.** La app necesita una clave de AI Studio, que es aparte y tiene su propio plan gratis. |
| ChatGPT Plus / Pro | **No.** La API de OpenAI se paga aparte, por uso. |
| Claude Pro / Max | **No.** Anthropic prohíbe usar el inicio de sesión de la suscripción en apps de terceros (desde 2026). Hace falta una clave de API (pago por uso). |
| Saldo en OpenRouter | **Sí**, con la clave de OpenRouter. |
| Cuenta gratis de Groq o de Google AI Studio | **Sí**, es el camino gratis. |

Conclusión para el Play Store: la app siempre trabaja con **claves de API**
que el usuario pega en Ajustes. Los planes gratis reales son **Groq** y
**Google AI Studio**.

## 4. Notas (ordenar / título): por qué es lento y qué hacer

**Causa más probable:** la app pide `gemini-3.5-flash`, que **ya no figura en
la lista oficial de modelos de Google**: los vigentes son `gemini-3.8-flash`,
`gemini-3.6-flash` y `gemini-3.5-flash-lite` («el más rápido y económico»,
recomendado para proyectos nuevos). Un modelo fuera de la lista puede estar
redirigido o con menos prioridad. Además, título y resumen se piden de a uno.

Arreglos propuestos, de menor a mayor esfuerzo:
1. Pasar a **`gemini-3.5-flash-lite`** (gratis, el más rápido), manteniendo
   `thinkingLevel: minimal`. Hay que medir el tiempo antes y después con la
   clave real (desde el servidor no se puede, no hay clave).
2. Pedir título y orden **en paralelo**, o los dos en un solo pedido.
3. Ofrecer otros proveedores para las notas, con desplegable:

| Proveedor | Modelo sugerido | Costo | Comentario |
|---|---|---|---|
| Google | `gemini-3.5-flash-lite` | Gratis (plan gratis) | Arreglo inmediato |
| **Groq** | `openai/gpt-oss-20b` (o `-120b`) | **Gratis** (30 pedidos/min, 1000/día) | Muy rápido y **con la misma clave que ya transcribe**: una sola clave para todo |
| Anthropic | Claude Haiku 5.5 | US$ 0,10 / 0,50 por millón de tokens (una nota cuesta fracciones de centavo) | Requiere clave de API (no la suscripción). Clave: consola de Anthropic → API keys |
| OpenRouter | cualquiera (Haiku, Gemini, GPT…) | según modelo | Misma clave que la transcripción por OpenRouter |

## 5. Cómo quedaría en Ajustes (propuesta)

```
Transcripción
  Proveedor      [ Groq ▾ ]   (Groq · Google · OpenAI · OpenRouter)
  Modelo         [ whisper-large-v3 (más preciso) ▾ ]
  Clave          ••••••••  [Probar]
  ¿No tenés clave? Sacala gratis acá →  (enlace según proveedor)

Notas con IA (ordenar y título)
  Proveedor      [ Groq ▾ ]   (Groq · Google · Anthropic · OpenRouter)
  Modelo         [ gpt-oss-20b (rápido, gratis) ▾ ]
  Clave          (si es la misma plataforma, se reutiliza)
```

- Cada modelo del desplegable con una etiqueta corta: «rápido», «más
  preciso», «gratis», «pago».
- Una clave por plataforma, guardada en `flutter_secure_storage` (regla del
  proyecto). El teclado nativo lee proveedor, modelo y clave por el puente.
- Al cambiar de proveedor, «Probar conexión» con un pedido mínimo.

## 6. Plan sugerido por etapas

1. **Rápido y sin riesgo:** desplegable de Groq (`turbo` / `large-v3`),
   sacando la migración automática; notas con `gemini-3.5-flash-lite` y
   pedidos en paralelo. Medir tiempos en el teléfono.
2. **Notas con Groq** (`gpt-oss-20b`): una sola clave gratis para todo.
3. **Proveedor OpenAI-compatible genérico** (OpenAI y OpenRouter comparten
   formato): un solo cliente con dirección + modelo + clave.
4. **Google `gemini-3.5-transcribe`** (cliente propio) y **Anthropic** para
   notas.
5. Textos de privacidad por proveedor (quién recibe el audio) antes del
   Play Store.

## Fuentes
- Groq, voz a texto: <https://console.groq.com/docs/speech-to-text> · límites: <https://console.groq.com/docs/rate-limits>
- Google, precios: <https://aistudio.google.com/docs/pricing> · modelos: <https://aistudio.google.com/docs/models>
- OpenAI, voz a texto: <https://developers.openai.com/api/docs/guides/speech-to-text>
- OpenRouter, modelos de voz: <https://openrouter.ai/collections/speech-to-text-models> · anuncio: <https://openrouter.ai/blog/announcing-audio-apis>
- Anthropic, precios: <https://platform.claude.com/docs/en/about-claude/pricing>
- Suscripción de Claude en apps de terceros (prensa): <https://winbuzzer.com/2026/02/19/anthropic-bans-claude-subscription-oauth-in-third-party-apps-xcxwbn/>
- Planes gratis de voz (comparativa, secundaria): <https://dev.to/unicodefawn/free-speech-to-text-and-text-to-speech-api-quotas-oct-2026-with-the-catches-17hg>
- Mistral Voxtral 3 (secundaria): <https://fourweekmba.com/ai-mistrals-voxtral-3-transcribes-speech-from-0-0035-a-minute/>
