# Plan — Cola diferida cloud en Notas (C1–C7)

> **Estado**: ✅ APROBADO EN PRINCIPIO POR EL DUEÑO (pedido 2026-09-22: “prepárate para incluir esta nueva funcionalidad”). Falta **ok de implementación + push** al arrancar.
> **Origen**: idea del dueño tras la investigación de transcripción local (opción 3): si no hay red al dictar, **guardar el audio** en la nota; más tarde, **solo si el usuario lo pide** (tocar dentro de la nota), pedir la transcripción cloud y quedar **texto + audio** juntos. **Sin auto-transcripción al detectar red.**
> **No confundir con ASR local**: la opción 3 (sherpa-onnx + Moonshine) es otro track independiente. Esta cola **complementa** el cloud actual y **no** requiere modelo local.
> **Reglas madre**: `AGENTS.md` (privacidad §5, anti-patrones §8, sin push sin ok), `docs/congelamiento-features.md` (freeze + flag OFF), `design.md`, `docs/contrato-claves.md`.

## 0. Fuera de alcance de este plan (explícito)

| Item | Por qué |
|---|---|
| Motor local / sherpa-onnx / Moonshine | Track separado (investigación `laboratorio_ui/investigacion-notas-local.html`) |
| Auto-upload al recuperar red / WorkManager / `connectivity_plus` | Choque directo con “el audio solo sale si el usuario inicia la transcripción” (`AGENTS.md` §5) |
| Historial FIFO-20 | Contrato `{text,timestamp}` + regla de 20; el audio+texto va **solo en Notas** |
| Widget Kotlin `WidgetDictationService` (hoy descarta audio en error) | Fase 2; no bloquea el valor en la app |
| Home / burbuja / teclado | Scope Notas |

## 1. Decisiones cerradas

| # | Decisión | Valor |
|---|---|---|
| D-C1 | Cuándo encolar | Solo si `TranscriptionException.isRetryable` (red/servidor) **o** red caída al fallar el dictado en Notas. `auth`/`badRequest` **no** encolan (UX de error actual + hint a Settings) |
| D-C2 | Disparar envío | **Solo** botón **“Transcribir con nube”** (o “Reintentar”) en la UI de pendientes / nota. Jamás al detectar conectividad |
| D-C3 | Tras éxito | `NotesService.addFromTranscription(text)` + **borrar WAV** + dequeue + `WidgetService().updateWidgets()` + SnackBar. Queda la nota (texto); el audio se conserva **mientras esté pendiente** y se elimina al transcribirse con éxito *o* al descartar (evita ocupar disco indefinidamente). **Retry de calidad**: si en fase 2 querés “re-transcribir”, se hará con flag aparte; v1 no re-sube texto ya guardado |
| D-C4 | Persistencia cola | **Clave Dart-only** `voice_notes_pending_v1` (JSON array). **No** entra a `docs/contract-keys.txt` (Kotlin no la lee en v1). WAVs en `getApplicationSupportDirectory()/pending_notes/<id>.wav` (**no** temp dir: el SO purga cache) |
| D-C5 | Capacidad | **Max 15 pendientes** (FIFO: al superar, descarta el más viejo **y** su WAV). Aviso si se descarta por límite |
| D-C6 | Flag | `notes_deferred_queue_enabled` Dart-only, **default OFF** hasta verificación en dispositivo (política `congelamiento-features.md`). Switch en Ajustes → General → grupo **“Notas”** (`ValueKey('notes-deferred-queue-switch')`) |
| D-C7 | Freeze / alcance docs | Al arrancar: dueño confirma “entra tarjeta” (swap o excepción). Actualizar en el mismo lote docs `README.md:7` y `AGENTS.md:20` (Notas **ya existe** en el código; el texto está desactualizado) con commit **`[skip ci]`** si solo toca `*.md` |

## 2. Flujo de usuario (v1)

```
[Notas · FAB Dictar] → stop → WAV en temp
        │
        ├─ OK online → transcribe → nota creada → borrar WAV     [hoy, sin cambios]
        │
        └─ falla kind=network (o servidor retryable)
                → mover WAV → appSupport/pending_notes/<id>.wav
                → append en voice_notes_pending_v1
                → SnackBar “Sin conexión · audio guardado en Notas”
                → chip/sección “Pendientes” visible en la lista

… el usuario vuelve (con o sin red; no importa hasta que toque) …

[Lista Notas · chip pendiente] → “Transcribir con nube”
        → load groq_api_key (patrón notes_screen.dart:114-117)
        → TranscriptionService.transcribe(pendingPath)   // 1 HTTP, sin auto-retry
        ├─ OK  → addFromTranscription + borrar WAV + dequeue + updateWidgets
        ├─ network → seguir pendiente (SnackBar “Sigue sin red”)
        └─ auth   → seguir pendiente + “Configurá la API key en Ajustes”
```

**Text + audio**: mientras está pendiente, el chip muestra duración/aprox. de fecha y **acción de reproducir** (simple `AudioPlayer` o, v1 mínima, solo info de archivo + botón **“Descartar audio”**). Si el dueño exige **conservar el WAV tras transcribir**, D-C3 se cambia a “mover a `appSupport/notes_audio/`” — coste disco y backup; **default del plan: borrar al éxito** (privacidad + espacio), decisión explícita al firmar el plan.

## 3. Arquitectura (solo donde importa)

### 3.1 Nuevo servicio (lógica fuera de widgets — `AGENTS.md` §5)

**`app_source/lib/services/pending_note_queue.dart`** (~150–200 líneas, mantiene `notes_screen.dart` <500):

```dart
class PendingNoteQueue {
  static const pendingKey = 'voice_notes_pending_v1'; // Dart-only
  static const maxPending = 15;
  // pendingDir = appSupport/pending_notes/

  Future<void> load();
  List<PendingNote> get items;          // {id, audioPath, createdAt, bytes?}
  Future<PendingNote?> enqueueFromTemp(String tempPath); // copy+delete temp o move
  Future<void> remove(String id, {bool deleteAudio = true});
  Future<void> pruneOldest();           // cap FIFO
  Future<void> discardAll();            // limpieza / settings
}
```

Modelo mínimo `PendingNote { String id; String audioPath; int createdAtMs; }` — **no** meter campos en `VoiceNote` (evita tocar contrato exacto de `notes_storage_test.dart` y claves compartidas con `NoteStore.kt`).

### 3.2 Hook en el dictado (mínimo diff)

`app_source/lib/screens/notes_screen.dart` `_stopAndSave` catch (≈99–105):

```dart
} catch (e) {
  // si e is TranscriptionException && e.isRetryable && flag ON
  //   → pendingQueue.enqueueFromTemp(path)
  //   → SnackBar audio guardado
  // si flag OFF → comportamiento actual
}
```

`stopRecording()` ya devuelve `path`; **capturarlo antes del `transcribe`** para no perderlo (hoy es local y se pierde).

### 3.3 UI pendientes (mismo patrón visual Notas)

En `NotesScreen` (lista, encima de `NoteCard`s o sección “Pendientes”):

- `ListView` con `ValueKey('pendingNotesList')`
- Cada fila: fecha/hora + “Audio sin transcribir” + botones con Keys:
  - `ValueKey('transcribeCloudButton-<id>')` → “Transcribir con nube”
  - `ValueKey('discardPendingButton-<id>')` → “Descartar” (confirm AlertDialog)
- Estado `_isTranscribingPending` para deshabilitar doble tap
- **Sin** badge de “sin red” proactiva (sin `connectivity_plus`); el resultado del tap informa el estado

Extraer widgets a `app_source/lib/widgets/pending_note_tile.dart` si `notes_screen.dart` pasaría de ~500 líneas.

### 3.4 Ajustes

`general_tab.dart`: grupo **Notas** + `SwitchListTile` `ValueKey('notes-deferred-queue-switch')` → `StorageService.load/saveNotesDeferredQueueEnabled` (clave Dart-only, patrón `bubble_history_enabled` **sin** bridge 3 lados).

Al apagar el flag: **no** borrar cola automáticamente (mostrar pendientes si ya hay; solo dejar de **encolar** nuevos). Opción de “vaciar pendientes” en el mismo grupo.

### 3.5 Qué no se toca

- `StorageService` historial / `Transcription` / `contract-keys.txt` / Kotlin widget / Home / `CloudSttService` (sigue 1 llamada, sin retry interno).

## 4. Orden de ejecución (lo antes posible)

| Fase | Tarea | Salida | Est. |
|---|---|---|---|
| **P0** | Ok del dueño: D-C3 (borrar WAV al éxito vs conservar), D-C6 flag default, D-C7 freeze/docs | 1 reply | — |
| **P1** | Docs alcance: `README.md` + `AGENTS.md` Notas + fila en `congelamiento-features.md` (o swap) `[skip ci]` si solo md | scope limpio | 15 min |
| **P2** | `PendingNoteQueue` + `PendingNote` + load/save atómico (tmp+rename como `NotesService`) | servicio verde unit test | 1–2 h |
| **P3** | Hook `_stopAndSave` + flag gate + move WAV a `pending_notes/` | offline → chip visible | 45 min |
| **P4** | UI lista pendientes + “Transcribir con nube” + descartar + keys | flujo e2e manual | 1.5–2 h |
| **P5** | Switch General + `load/save` flag | flag OFF por defecto | 30 min |
| **P6** | Tests (§5) + `test_master_suite.py` registro | suites locales verdes | 1.5 h |
| **P7** | Suite completa local → **pedir ok push** → CI → APK → prueba en **moto-g05** (offline real: avión → dictar → reactivar red → tocar) | entrega | 1 h + CI |

**Camino crítico**: P2 → P3 → P4 → P6 → P7. Estimado de coding concentrado: **~6–8 h** + CI.

## 5. Tests (obligatorio antes de push — regla del dueño)

### Dart (`app_source/test/`)

| Archivo | Qué cubre |
|---|---|
| `services/pending_note_queue_test.dart` (nuevo) | enqueue mueve WAV fuera de temp; cap 15; remove borra archivo; JSON corrupto tolerado; flag off no encola (si va en el servicio) |
| `integration/pending_queue_flow_test.dart` (nuevo, estilo `h5_matrix_test.dart`) | network fail → pending 1 archivo → tap éxito → nota única → WAV borrado → cola vacía; segundo network fail → sigue pending; auth no encola |
| `screens/settings…` | switch presente con key; default OFF |
| `notes_storage_test.dart` | **sin cambios** (no tocamos `VoiceNote`) |

Patrones: `mock_channels.dart`, `existsSync` bajo fakeAsync, **buscar por `ValueKey`**, superficie `tester.view.physicalSize` alta, import explícito `material.dart`.

### Python (rápido, sin SDK Flutter)

| Suite | Checks |
|---|---|
| `test_pending_notes_suite.py` (nueva) | clave **no** en `contract-keys.txt`; sin `connectivity_plus`/`WorkManager` en pubspec; sin auto-transmit (grep de listeners de red); `maxPending==15`; WAV path bajo `getApplicationSupportDirectory` no temp; registro en `SUITES` de `test_master_suite.py` |
| master | verde 100% + contrato intacto |

### Dispositivo (checklist `CHECKLIST-TESTING.md`)

1. Aeroplane ON → dictar en Notas → chip pendiente + SnackBar.  
2. Aeroplane OFF → **no** se transcribe solo.  
3. Tocar “Transcribir con nube” → nota creada, chip desaparece, widgets OK.  
4. Sin API key → sigue pendiente + hint Settings.  
5. Flag OFF → fallo offline = error actual, sin chip.  
6. 16 dictados offline → solo 15 pendientes (el más viejo sale).

## 6. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Freeze de features (`congelamiento`) | D-C7: ok explícito del dueño al arrancar P0; card nueva con flag OFF |
| README/AGENTS dicen “no notas” | Actualizar docs en P1 (código ya tiene Notas desde `69eb1e4`) |
| Temp WAV purgado por el SO | Mover a appSupport en el momento de encolar (P3) |
| Disco / backups (`allowBackup=true`) | Cap 15 + borrar al éxito; evaluar `data_extraction_rules` para `pending_notes/` si el dueño quiere |
| `notes_screen.dart` >500 líneas | Lógica en servicio + `pending_note_tile.dart` |
| Enviar sin gesto del usuario | Prohibido por diseño + test estático Python que caza auto-flush |
| Doble tap / envíos paralelos | `_isTranscribingPending` + botón disabled |

## 7. Criterios de aceptación (Definition of Done)

- [ ] Dictado offline con flag ON → audio **persistido** fuera de temp + entrada en cola.  
- [ ] Cero HTTP sin toque en “Transcribir con nube”.  
- [ ] Tras éxito: nota con texto, cola limpia, WAV borrado (o conservado si D-C3 cambia), widget de Notas actualizado.  
- [ ] Flag default OFF documentado en `congelamiento-features.md`.  
- [ ] `flutter analyze` estricto + `flutter test` + suites Python **100% verdes**.  
- [ ] Ninguna clave de cola en `contract-keys.txt`.  
- [ ] README/AGENTS alineados con Notas existente.  
- [ ] Push **solo** con autorización explícita del dueño + CI verde + APK en dispositivo.

## 8. Fase 2 (backlog, no bloquea)

1. Conservar WAV tras éxito (`notes_audio/`) + reproducir desde la nota (texto **y** audio juntos).  
2. Re-transcribir nota existente (mejor motor / corrección) — usuario explícito.  
3. Widget Kotlin: encolar en `onError` (clave bridge 3 lados si lee la cola).  
4. Opción 3 local: al abrir nota pendiente sin red → “Transcribir ahora en el dispositivo” (solo cuando exista el motor local).  
5. Badge Home “n pendientes” (sin connectivity_plus).

## 9. Registro

| Fecha | Evento |
|---|---|
| 2026-09-22 | Idea del dueño (cola cloud bajo demanda junto a investigación opción 3). Plan C1–C7 redactado. Servidor de lab de investigación **cerrado** (8088 libre). |
| 2026-09-22 | **Loop ejecutado** (autorización del dueño: “arranca y continúa hasta terminar… push… avísame cuando esté el APK”). D-C3 = borrar WAV al éxito; D-C6 = flag OFF; D-C7 = docs + freeze actualizados. Código en `app_source/` (`PendingNoteQueue`, hook `NotesScreen`, switch General, tests Dart + suite Python `test_pending_notes_suite.py` registrada en master). |

### Registro del loop

| Tarjeta | Ronda | Auditoría | Estado |
|---|---|---|---|
| C2 servicio + C3 hook + C4 UI + C5 flag | 1 | self-check + suite Python + master local | en curso |
| C6 tests | 1 | Dart unit + integration escritos (CI los ejecuta) | en curso |
| C7 push + CI | — | pendiente batería final | — |

> **Siguiente paso**: dueño responde P0 (D-C3, D-C6, D-C7) y autoriza arranque de implementación en local (push aparte).
