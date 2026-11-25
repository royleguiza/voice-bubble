# Límites de contrato (contract-limits)

> Fuente única de verdad de los límites máximos y capacidades entre la app Flutter y el IME nativo Kotlin (Contrato C-19).
> Cualquier cambio en estos topes debe reflejarse en este documento y en los tests espejo de Dart y Kotlin.

| Dominio | Constante Dart | Constante Kotlin | Límite | Política ante desborde |
|---|---|---|---|---|
| **Historial de transcripciones** | `StorageService.maxItems` / `HistoryRepository.maxItems` | `TranscriptionHistoryLogic.MAX_ITEMS` / `TranscriptionHistoryRepository.MAX_ITEMS` | **100** | FIFO estricto (descarta los registros más antiguos). |
| **Credenciales** | `StorageService.maxCredentials` | `CredentialStore.MAX_CREDENTIALS` | **50** | Rechazo de nuevas inserciones (`addCredential` retorna `false`) y truncamiento de índice. |
| **Cola de audios pendientes** | `PendingNoteQueue.maxPending` / `StorageService.maxPendingNotes` | `NoteStore.MAX_PENDING` / `WidgetDictationService.MAX_PENDING_WAVS` | **15** | FIFO (desahucio del audio pendiente más antiguo con borrado seguro de su archivo WAV). |
| **Notas** | `NotesService.maxNotes` | `NoteStore.MAX_NOTES` | **200** | Rechazo de notas nuevas al llegar al tope (la copia de seguridad nunca desplaza notas locales). |
| **Orison Pro (T15)** | `ProGate.trialDays` / `ProGate.freeDailyDictations` | `ProGate.TRIAL_DAYS` / `ProGate.FREE_DAILY_DICTATIONS` | **30 días / 10 por día** | Pasada la prueba y sin Pro, el dictado 11 del día no arranca (aviso con enlace a Pro). Ante un error de lectura siempre deja dictar. |
| **Portapapeles** | `StorageService.maxClips` | `ClipboardStore.MAX_UNPINNED_ITEMS` | **50** | FIFO-50 sobre elementos no anclados (descarta el clip no anclado más antiguo). |

## Reglas de Coherencia
1. **Historial (100, T12 del plan de lanzamiento; antes 20)**:
   - Dart: `StorageService.maxItems == 100` y `HistoryRepository.maxItems == 100`.
   - Kotlin: `TranscriptionHistoryLogic.MAX_ITEMS == 100` y `TranscriptionHistoryRepository.MAX_ITEMS == 100`.
2. **Credenciales (50)**:
   - Dart: `StorageService.maxCredentials == 50`.
   - Kotlin: `CredentialStore.MAX_CREDENTIALS == 50`.
3. **Cola de notas pendientes (15)**:
   - Dart: `PendingNoteQueue.maxPending == 15` y `StorageService.maxPendingNotes == 15`.
   - Kotlin: `NoteStore.MAX_PENDING == 15`.
4. **Portapapeles (50, T12; antes 25)**:
   - Dart: `StorageService.maxClips == 50`.
   - Kotlin: `ClipboardStore.MAX_UNPINNED_ITEMS == 50`.
5. **Notas (200, T12; antes 50)**:
   - Dart: `NotesService.maxNotes == 200`.
   - Kotlin: `NoteStore.MAX_NOTES == 200`.
