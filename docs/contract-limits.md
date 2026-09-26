# Límites de contrato (contract-limits)

> Fuente única de verdad de los límites máximos y capacidades entre la app Flutter y el IME nativo Kotlin (Contrato C-19).
> Cualquier cambio en estos topes debe reflejarse en este documento y en los tests espejo de Dart y Kotlin.

| Dominio | Constante Dart | Constante Kotlin | Límite | Política ante desborde |
|---|---|---|---|---|
| **Historial de transcripciones** | `StorageService.maxItems` | `TranscriptionHistoryLogic.MAX_ITEMS` / `TranscriptionHistoryRepository.MAX_ITEMS` | **20** | FIFO estricto (descarta los registros más antiguos). |
| **Credenciales** | `StorageService.maxCredentials` | `CredentialStore.MAX_CREDENTIALS` | **50** | Rechazo de nuevas inserciones (`addCredential` retorna `false`) y truncamiento de índice. |
| **Cola de audios pendientes** | `PendingNoteQueue.maxPending` / `StorageService.maxPendingNotes` | `NoteStore.MAX_PENDING` / `WidgetDictationService.MAX_PENDING_WAVS` | **15** | FIFO (desahucio del audio pendiente más antiguo con borrado seguro de su archivo WAV). |
| **Portapapeles** | `StorageService.maxClips` | `ClipboardStore.MAX_UNPINNED_ITEMS` | **25** | FIFO-25 sobre elementos no anclados (descarta el clip no anclado más antiguo). |

## Reglas de Coherencia
1. **Historial (20)**:
   - Dart: `StorageService.maxItems == 20`.
   - Kotlin: `TranscriptionHistoryLogic.MAX_ITEMS == 20` y `TranscriptionHistoryRepository.MAX_ITEMS == 20`.
2. **Credenciales (50)**:
   - Dart: `StorageService.maxCredentials == 50`.
   - Kotlin: `CredentialStore.MAX_CREDENTIALS == 50`.
3. **Cola de notas pendientes (15)**:
   - Dart: `PendingNoteQueue.maxPending == 15` y `StorageService.maxPendingNotes == 15`.
   - Kotlin: `NoteStore.MAX_PENDING == 15`.
4. **Portapapeles (25)**:
   - Dart: `StorageService.maxClips == 25`.
   - Kotlin: `ClipboardStore.MAX_UNPINNED_ITEMS == 25`.
