# Contrato de Merge Unificado — VoiceBubble STT

> **Contrato C-25**: Especificación formal de reglas de combinación (merge) de datos entre fuentes distribuidas (disco, SharedPreferences, memoria y procesos nativos).
> **Propósito**: Garantizar unicidad, determinismo, conmutatividad y límites estrictos sin duplicación de lógica ni divergencias entre Kotlin y Dart.

---

## 1. Principios Matemáticos del Merge

Toda función de merge $M(A, B)$ en VoiceBubble STT satisface las siguientes propiedades formales:

1. **Conmutatividad (Orden de entrada irrelevante)**:
   $$M(A, B) = M(B, A)$$
   El resultado final (conjunto de elementos resultantes con sus propiedades canónicas) no depende del orden en que se presenten las fuentes al algoritmo. Si dos fuentes contienen versiones concurrentes o idénticas, el resultado es estrictamente idéntico.

2. **Idempotencia (Estabilidad ante re-lecturas)**:
   $$M(A, A) = A$$
   Combinar una fuente consigo misma no altera ni multiplica sus elementos.

3. **Determinismo (Desempate estricto sin azar)**:
   Ante colisiones de timestamp exacto en microsegundos, el algoritmo aplica una regla de desempate canónica y determinista basada en el origen canónico (`FILE` antes de `PREFERENCES`) o en el orden léxico del identificador UUID v4 (`id`), nunca en punteros de memoria ni en orden de iteración no garantizado.

4. **Acotamiento FIFO Estricto ($|M| \le C$)**:
   El resultado final nunca excede la capacidad máxima $C$ configurada para el dominio, descartando los elementos más antiguos tras el ordenamiento descendente.

---

## 2. Dominios de Merge y Políticas Canónicas

| Dominio | Capacidad ($C$) | Identidad Canónica | Regla de Conflicto | Desempate |
|---|---|---|---|---|
| **Historial de Transcripciones** | 20 | Timestamp UTC ISO-8601 + Capa/Texto | Timestamp descendente (más reciente gana) | `FILE (0)` > `PREFERENCES (1)` > Índice original |
| **Notas de Voz** | 50 | UUID v4 (`id`) | Last-Writer-Wins (LWW) por `updatedAt` / `createdAt` | UUID léxico descendente |
| **Credenciales (Bóveda + Índice)** | 50 | UUID v4 (`id`) | Unión de índices por `id` + LWW metadatos; Bóveda `putIfAbsent` | Conserva secreto si ya existe en bóveda |
| **Snippets (Plantillas)** | 50 | UUID v4 (`id`) / Título unificado | Unión de semillas predefinidas (5) + snippets de usuario | Título y fecha de modificación |
| **Dictados Pendientes Widget** | 10 | UUID v4 (`id`) | FIFO cronológico | Inserción en cabeza, truncado al tope |

---

## 3. Especificación Detallada por Dominio

### 3.1 Historial de Transcripciones (`TranscriptionHistoryLogic` / `HistoryRepository`)

- **Fuentes**: Archivo JSON en disco (`voice_notes.json`) y lista StringList en SharedPreferences (`flutter.transcriptions`).
- **Formato**: JSON con campos `transcription` (String), `timestamp` (ISO-8601 UTC estricto con hasta 6 decimales de microsegundos), `layer` (opcional).
- **Regla de Validación**:
  - Fechas inválidas o con timestamps corruptos son descartadas sin contaminar el dataset.
  - Textos vacíos o blank Unicode son filtrados.
- **Deduplicación**:
  - Dos entradas con idéntico timestamp truncado a microsegundos y mismo texto canónico se consideran la misma entrada.
- **Tope FIFO**:
  - Máximo exacto de 20 entradas.

### 3.2 Notas de Voz (`NoteStore` / `NotesService`)

- **Fuentes**: Archivo JSON en disco (`notes.json`) y SharedPreferences (`flutter.notes`).
- **Formato**: Array de objetos con `id` (UUID v4 canónico RFC 4122), `text`, `createdAt`, `updatedAt`, `audioPath`.
- **Regla LWW (Last-Writer-Wins)**:
  - Para un mismo `id`, la versión con mayor `updatedAt` (o `createdAt` si falta) prevalece íntegramente.
- **Tope FIFO**:
  - Máximo de 50 notas activas.

### 3.3 Credenciales (`CredentialRepository` / `CredentialStore`)

- **Fuentes**: Índice en SharedPreferences (`flutter.vb_credentials_v1`) y Bóveda cifrada en EncryptedSharedPreferences (`flutter.vb_cred_pass_v1`).
- **Regla**:
  - Índice combina todas las credenciales presentes por `id`.
  - La bóveda combina passwords de ambas fuentes: si una clave ya está cifrada en la bóveda, se conserva; si una nueva viene en el merge, se añade de forma atómica (`putIfAbsent`).
- **Tope**:
  - Máximo 50 credenciales.

### 3.4 Snippets (`SnippetRepository` / `SnippetStore`)

- **Fuentes**: SharedPreferences (`flutter.kb_snippets_v1`).
- **Regla**:
  - Si la lista está vacía, se inyectan las 5 semillas predefinidas (editable y borrable por el usuario).
  - Si ya existen snippets, se preservan respetando el orden y límite de 50 elementos.

---

## 4. Garantías de Exclusión Mutua en Escritura

Ningún merge persiste datos sin antes adquirir el cerrojo adecuado:
- **Dart**: Colas asíncronas seriales (`_serialHistoryQueue`, `_serialQueue`) para serializar en el proceso + lock de archivo (`voice_notes.lock`) cross-process con detección de stale y timeout cooperativo.
- **Kotlin**: Cerrojos sincronizados en JVM (`STORE_MUTEX`, `REPO_MUTEX`, `WIDGET_SAVE_MUTEX`) con relectura inmediata bajo lock previo a la escritura atómica mediante reemplazo atómico (`StandardCopyOption.ATOMIC_MOVE`).
