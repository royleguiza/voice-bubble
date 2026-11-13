import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import '../services/transcription_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_stt_service.dart';
import '../services/floating_bubble_service.dart';
import '../services/keyboard_service.dart';
import '../services/pending_note_queue.dart';
import '../models/transcription.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';
import '../ui/transcription_feedback.dart';
import '../helpers/note_groups.dart';
import 'settings_screen.dart';
import 'note_editor_screen.dart';
import '../models/voice_note.dart';
import '../services/notes_service.dart';
import '../services/widget_service.dart';
import '../controllers/recording_controller.dart';
import '../widgets/record_button.dart';
import '../widgets/history_list.dart';
import '../widgets/home_chrome.dart';
import '../widgets/note_card.dart';
import '../widgets/pending_note_tile.dart';
import 'package:path_provider/path_provider.dart';

/// Pantalla principal: las notas son la app y la burbuja de dictado flota
/// abajo (laboratorio_ui/inicio-notas.html).
///
/// Dictar desde acá crea una nota con su audio original, la suma al
/// Historial (FIFO-20) y la copia. La burbuja flotante del sistema, en
/// cambio, sigue el flujo de siempre: Historial + pegar/copiar, sin nota.
class HomeScreen extends StatefulWidget {
  final TranscriptionService? transcriptionService;
  final StorageService? storageService;
  final FloatingBubbleService? floatingBubbleService;
  final RecordingController? recordingController;
  final NotesService? notesService;
  final PendingNoteQueue? pendingQueue;

  /// Clave del lienzo del botón de dictar: la animación de arranque
  /// (`HorizonIntroHost`) lee de ahí el centro y el radio reales del
  /// agujero para aterrizar exactamente sobre él. Solo presentación.
  final GlobalKey? holeKey;

  const HomeScreen({
    super.key,
    this.transcriptionService,
    this.storageService,
    this.floatingBubbleService,
    this.recordingController,
    this.notesService,
    this.pendingQueue,
    this.holeKey,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TranscriptionService _transcriptionService;
  late final StorageService _storageService;
  late final FloatingBubbleService _floatingBubbleService;
  late final RecordingController _recordingController;
  late final NotesService _notesService;
  late final PendingNoteQueue _pendingQueue;
  final _secureStorage = StorageService.espSecureStorage;
  final _keyboardService = KeyboardService();

  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isStartingRecording = false;
  bool _isStoppingRecording = false;
  bool _shouldStopAfterStart = false;

  /// ✕ en la pastilla: al cortar, se tira el audio sin transcribir.
  bool _discardOnStop = false;

  /// La grabación en curso nació en la burbuja de esta pantalla y termina
  /// en una nota. Falso cuando la inicia la burbuja flotante del sistema.
  bool _recordingAsNote = false;
  String? _pendingAudioPath;
  bool _pendingAsNote = false;
  String _recordMode = StorageService.defaultRecordMode;
  DateTime? _holdStartedAt;

  // Notas y cola sin conexión (antes en la pantalla Notas).
  bool _notesAvailable = false;
  bool _notesLoading = true;
  bool _deferredQueueEnabled = false;
  bool _queueLoaded = false;
  bool _queueAvailable = false;
  bool _isTranscribingPending = false;

  /// 0 = Notas, 1 = Historial.
  int _tab = 0;
  final _searchCtrl = TextEditingController();
  String _query = '';
  final _notesScroll = ScrollController();
  final _historyScroll = ScrollController();

  /// Título grande fuera de pantalla → barra compacta visible. Va en un
  /// notifier y no en setState: cruzar el umbral al desplazar reconstruye
  /// solo la barra, nunca la lista ni la pantalla.
  final ValueNotifier<bool> _scrolled = ValueNotifier<bool>(false);

  /// Filas planas (encabezados + ítems) memoizadas: se recalculan solo si
  /// cambian los datos, la búsqueda o el día, no en cada build.
  final _noteRows = GroupedRowsMemo<VoiceNote>(idOf: (n) => n.id);
  final _historyRows = GroupedRowsMemo<Transcription>(idOf: (t) => t.id);

  /// Nota recién dictada: se resalta con un anillo que se desvanece.
  String? _freshNoteId;
  late final AnimationController _newNoteCtrl = AnimationController(
    vsync: this,
    duration: kAnimNewNote,
  );
  late final Animation<double> _newNoteHighlight = ReverseAnimation(
    CurvedAnimation(parent: _newNoteCtrl, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _floatingBubbleService =
        widget.floatingBubbleService ?? FloatingBubbleService();
    _floatingBubbleService.onBubbleTap = _handleBubbleTap;
    _floatingBubbleService.onBubbleClose = _handleBubbleClose;

    if (widget.transcriptionService != null) {
      _transcriptionService = widget.transcriptionService!;
      _storageService =
          widget.storageService ?? _transcriptionService.storageService;
    } else {
      _storageService = widget.storageService ?? StorageService();
      _transcriptionService = TranscriptionService(
        cloudService: const CloudSttService(apiKey: ''),
        storageService: _storageService,
      );
    }
    _notesService = widget.notesService ?? NotesService();
    _pendingQueue = widget.pendingQueue ?? PendingNoteQueue();
    _recordingController = widget.recordingController ??
        RecordingController(
          transcriptionService: _transcriptionService,
          floatingBubbleService: _floatingBubbleService,
          onHapticStart: _hapticStart,
          onHapticStop: _hapticStop,
        );
    _notesScroll.addListener(_onScroll);
    _historyScroll.addListener(_onScroll);
    _init();
  }

  void _onScroll() {
    final c = _tab == 0 ? _notesScroll : _historyScroll;
    _scrolled.value = c.hasClients && c.offset > kLargeTitleCollapseOffset;
  }

  Future<void> _handleBubbleTap() async {
    if (_isTranscribing || _isStartingRecording || _isStoppingRecording) return;
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  void _handleBubbleClose() {
    // El callback nativo es sync-void pero el guardado es async: observar
    // el futuro (unawaited + catch) en vez de disparar y olvidar. Sin esto,
    // un canal roto dejaba un Future sin observar y el toggle mentía.
    unawaited(() async {
      try {
        await _storageService.saveFloatingBubbleEnabled(false);
      } catch (_) {}
    }());
  }

  Future<void> _loadApiKey() async {
    try {
      final key = await _secureStorage.read(key: 'groq_api_key') ?? '';
      _transcriptionService.updateApiKey(key);
      // Auto-cura de la config nativa (teclado/burbuja híbrida): si la
      // bóveda tiene key pero presencia/config se perdieron, republicarlos
      // sin pedir reingreso. Best-effort: un fallo aquí nunca rompe la
      // grabación de la app.
      if (key.trim().isNotEmpty) {
        try {
          await _storageService.repairSttMirror();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _loadRecordMode() async {
    try {
      final mode = await _storageService.loadRecordMode();
      if (mounted) setState(() => _recordMode = mode);
    } catch (_) {}
  }

  /// Notas + cola diferida. El widget puede escribir en ambas con la app en
  /// segundo plano, por eso se relee también al volver al primer plano.
  Future<void> _loadNotes() async {
    bool notesLoaded = false;
    try {
      notesLoaded = await _notesService.load();
    } catch (_) {}
    try {
      _deferredQueueEnabled =
          await _storageService.loadNotesDeferredQueueEnabled();
    } catch (_) {
      _deferredQueueEnabled = false;
    }
    bool queueLoaded = false;
    try {
      queueLoaded = await _pendingQueue.load();
    } catch (_) {}
    _notesAvailable = notesLoaded;
    _queueAvailable = queueLoaded;
    _queueLoaded = true;
    _notesLoading = false;
    if (mounted) setState(() {});
  }

  Future<void> _init() async {
    // En paralelo: leer notas toca disco con lock y no debe frenar la key,
    // el modo de grabación ni la burbuja.
    unawaited(_loadNotes());
    try {
      await _storageService.load();
    } catch (_) {}
    await _loadApiKey();
    await _loadRecordMode();
    try {
      final bubbleEnabled = await _storageService.loadFloatingBubbleEnabled();
      if (bubbleEnabled) {
        final hasPermission = await _floatingBubbleService.canDrawOverlays();
        if (hasPermission) {
          await _floatingBubbleService.startBubble();
        } else {
          await _storageService.saveFloatingBubbleEnabled(false);
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _transcriptionService.requestPermissions();
        _handleWidgetAction();
      });
    }
  }

  Future<void> _handleWidgetAction() async {
    try {
      final action = await WidgetService().getInitialAction();
      final act = action['action'];
      final noteId = action['noteId'] ?? action['note_id'];
      if (!mounted) return;
      if (act == 'open_notes') {
        // Las notas ya son la pantalla principal.
        _selectTab(0);
      } else if ((act == 'open_note' ||
              act == 'gemini_resumir' ||
              act == 'gemini_titulo') &&
          noteId != null &&
          noteId.isNotEmpty) {
        String? geminiAction;
        if (act == 'gemini_resumir') geminiAction = 'resumir';
        if (act == 'gemini_titulo') geminiAction = 'titulo';
        await _notesService.load();
        VoiceNote? note;
        try {
          note = _notesService.notes.firstWhere((n) => n.id == noteId);
        } catch (_) {
          note = null;
        }
        if (!mounted) return;
        if (note != null) {
          await _openEditor(note, geminiAction: geminiAction);
        } else {
          _selectTab(0);
        }
      }
    } catch (_) {}
  }

  bool get motionSafe => !MediaQuery.disableAnimationsOf(context);

  RecordButtonState get _buttonState {
    if (_isTranscribing || _isStoppingRecording) {
      return RecordButtonState.transcribing;
    }
    if (_isRecording || _isStartingRecording) {
      return RecordButtonState.recording;
    }
    return RecordButtonState.idle;
  }

  /// Línea corta sobre la burbuja. En reposo no dice nada: la burbuja se
  /// explica sola y la lista queda limpia.
  String get _statusText {
    if (_isRecording || _isStartingRecording) {
      return _recordMode == StorageService.recordModeHold
          ? 'Soltá para terminar'
          : '';
    }
    if (_isTranscribing || _isStoppingRecording) return 'Transcribiendo…';
    if (_pendingAudioPath != null) return 'Error, toca para reintentar';
    return '';
  }

  void _hapticStart() => HapticFeedback.mediumImpact();
  void _hapticStop() => HapticFeedback.lightImpact();

  Future<void> _toggleRecording() async {
    if (_isRecording || _isStartingRecording) {
      await _stopRecording();
    } else {
      await _startRecording(asNote: true);
    }
  }

  Future<void> _startRecording({bool asNote = false}) async {
    if (_isStartingRecording ||
        _isStoppingRecording ||
        _isRecording ||
        _isTranscribing) {
      return;
    }
    _isStartingRecording = true;
    _shouldStopAfterStart = false;
    _discardOnStop = false;
    _recordingAsNote = asNote;
    final previousPending = _pendingAudioPath;
    _pendingAudioPath = null;
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() {});
    }

    try {
      if (previousPending != null) {
        await _transcriptionService.cleanupTempFile(previousPending);
      }
      final dir = await getTemporaryDirectory();
      // Encoder wav (PCM 16 bits + cabecera RIFF): Groq rechaza PCM crudo.
      final path =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _floatingBubbleService
          .updateBubbleState(BubbleVisualState.recording);
      if (!mounted) {
        await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        return;
      }
      await _transcriptionService.startRecording(path);
      if (mounted) {
        setState(() {
          _isStartingRecording = false;
          _isRecording = true;
        });
        _hapticStart();
      } else {
        _isStartingRecording = false;
        _isRecording = true;
      }
      if (_shouldStopAfterStart) {
        _shouldStopAfterStart = false;
        await _stopRecording();
      }
    } catch (e) {
      _isStartingRecording = false;
      _shouldStopAfterStart = false;
      await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar grabación: $e')),
        );
      }
    }
  }

  /// Hold demasiado corto (<300 ms): descartar como toque accidental.
  Future<void> _cancelHoldIfTooShort() async {
    final started = _holdStartedAt;
    _holdStartedAt = null;
    if (started == null) return;
    if (DateTime.now().difference(started) <
        const Duration(milliseconds: 300)) {
      if (_isStartingRecording) {
        _shouldStopAfterStart = true;
      } else if (_isRecording) {
        final path = await _transcriptionService.stopRecording();
        if (path != null) {
          await _transcriptionService.cleanupTempFile(path);
        }
        await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        if (mounted) setState(() => _isRecording = false);
      }
    }
  }

  /// ✕ de la pastilla: corta y tira el audio, sin red ni nota.
  Future<void> _discardRecording() async {
    if (!(_isRecording || _isStartingRecording)) return;
    _discardOnStop = true;
    await _stopRecording();
  }

  /// Intenta pegar en el cursor con el teclado propio; con otro teclado
  /// Android lo prohíbe y queda el portapapeles: avisar pegado manual.
  /// [showCopyFallback]: en falso no muestra SnackBar (el llamador ya
  /// notificó un fallo de clipboard y no debe pisarse con un "copiado").
  Future<void> _pasteOrCopyFeedback(String text,
      {bool showCopyFallback = true}) async {
    bool pasted = false;
    try {
      pasted = await _keyboardService.commitText(text);
    } catch (_) {}
    if (!pasted && showCopyFallback && mounted) {
      try {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(copiedToClipboardMessage),
              duration: Duration(seconds: 2),
            ),
          );
      } catch (_) {}
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {}
  }

  void _showClipboardFailure() => _showSnack(clipboardFailureMessage);

  /// Audio mínimo útil para llamar a Groq (≥8000 bytes). Se exige tanto en
  /// [_stopRecording] como en [_retryPending]: por debajo se limpia el
  /// temporal sin transcribir y sin mostrar error.
  static const int minAudioBytes = 8000;
  static const int _minAudioBytes = minAudioBytes;

  /// SPK-17 (Dart): se mantiene I/O SYNC a propósito. `await File.exists()`
  /// se cuelga bajo FakeAsync de testWidgets (regla AGENTS §9.2-10,
  /// commit 6a0e9c5) y estos chequeos corren en _stopRecording/_retryPending,
  /// rutas que los widget tests SÍ ejercitan con paths falsos. Es un único
  /// stat() de microsegundos; el ANR real (JSON bajo lock) se corrigió en
  /// TranscriptionHistoryRepository.kt.
  bool _hasUsableAudio(String path) {
    try {
      final file = File(path);
      return file.existsSync() && file.lengthSync() >= _minAudioBytes;
    } catch (_) {
      return false;
    }
  }

  bool _audioFileExists(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Flujo compartido transcribe→clipboard→push→feedback (antes duplicado
  /// ~30 líneas entre [_stopRecording] y [_retryPending]).
  ///
  /// El clipboard va clasificado: si falla NO es error de red, NO marca
  /// [_pendingAudioPath] (transcribe() ya borró el audio en éxito) y la
  /// transcripción igualmente se muestra y guarda en historial.
  Future<void> _publishTranscriptionResult(Transcription result) async {
    final copy = await copyTranscriptionText(result.text);
    // Write-through al historial unificado nativo para la modal de la isla.
    // SPK-04: con el timestamp ya persistido por Dart para identidad exacta
    // (sin eco por doble timestamp, sin dictados tragados por ventanas).
    await _floatingBubbleService.pushHistoryEntry(result.text,
        timestamp: result.timestamp);
    if (copy == ClipboardCopyResult.failed) {
      _showClipboardFailure();
      // Pegado silencioso: no pisa el aviso de clipboard con un "copiado".
      await _pasteOrCopyFeedback(result.text, showCopyFallback: false);
    } else {
      await _pasteOrCopyFeedback(result.text);
    }
    await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
    if (mounted) {
      setState(() {
        _pendingAudioPath = null;
        _isTranscribing = false;
      });
    } else {
      _pendingAudioPath = null;
      _isTranscribing = false;
    }
  }

  /// Dictado de la app → nota con audio + Historial + portapapeles.
  ///
  /// C-45: transcribir PRIMERO (repara el hueco sin tapa en disco) y
  /// conservar DESPUÉS, para que notes_audio quede sano y reproducible.
  /// La transcripción ya quedó en Historial dentro de transcribe(): si la
  /// nota no se puede guardar, el texto no se pierde y se avisa.
  Future<void> _transcribeIntoNote(String path) async {
    final result = await _transcriptionService.transcribe(
      path,
      deleteAudioOnSuccess: false,
    );
    final keptPath = await _pendingQueue.keepCopyForNote(path);
    var ok = false;
    if (keptPath != null) {
      ok = await _notesService.addFromTranscription(
        result.text,
        audioPath: keptPath,
      );
      if (!ok) _pendingQueue.deleteKeptAudio(keptPath);
    }
    if (ok) {
      await _transcriptionService.cleanupTempFile(path);
      _freshNoteId =
          _notesService.notes.isEmpty ? null : _notesService.notes.first.id;
      unawaited(WidgetService().updateWidgets());
    }
    await _publishTranscriptionResult(result);
    if (!mounted) return;
    if (ok) {
      _revealFreshNote();
      // La tarjeta nueva es el aviso visual; TalkBack necesita oírlo.
      unawaited(SemanticsService.sendAnnouncement(
        View.of(context),
        'Nota guardada',
        TextDirection.ltr,
      ));
    } else {
      final full = _notesService.notes.length >= NotesService.maxNotes;
      _showSnack(full
          ? 'Nota no guardada: llegaste a ${NotesService.maxNotes} notas. '
              'El texto quedó copiado y en Historial.'
          : keptPath == null
              ? 'No se pudo conservar el audio. El texto quedó en Historial.'
              : 'Nota no guardada; el texto quedó en Historial');
    }
  }

  void _revealFreshNote() {
    setState(() {
      _tab = 0;
      _query = '';
      _searchCtrl.clear();
    });
    if (motionSafe) {
      _newNoteCtrl.forward(from: 0);
    } else {
      _newNoteCtrl.value = 1.0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_notesScroll.hasClients) return;
      if (motionSafe) {
        _notesScroll.animateTo(0,
            duration: const Duration(milliseconds: 400), curve: kCurveFade);
      } else {
        _notesScroll.jumpTo(0);
      }
    });
  }

  void _showTranscribeError(Object e, {required bool canRetry}) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            action: canRetry
                ? SnackBarAction(
                    label: 'Reintentar',
                    onPressed: _retryPending,
                  )
                : null,
          ),
        );
    } catch (_) {}
  }

  /// Fallo al transcribir un dictado de la app. Sin red y con la cola
  /// diferida activa, el audio pasa a Pendientes (se envía cuando el
  /// usuario toque Transcribir: nunca auto-upload). Si no, queda para
  /// Reintentar sin regrabar.
  Future<void> _handleTranscribeFailure(
      Object e, String path, bool asNote) async {
    await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
    final retryable = e is TranscriptionException && e.isRetryable;
    if (asNote &&
        retryable &&
        _deferredQueueEnabled &&
        _audioFileExists(path)) {
      final item = await _pendingQueue.enqueueFromTemp(path);
      if (item != null) {
        if (mounted) {
          setState(() {
            _pendingAudioPath = null;
            _isTranscribing = false;
          });
          _showSnack('Sin conexión · audio guardado en Notas');
        } else {
          _pendingAudioPath = null;
          _isTranscribing = false;
        }
        return;
      }
    }
    // Conservar el audio para reintento sin regrabar, SALVO si ya se
    // borró: transcribe() borra el temporal en éxito, así que un fallo
    // tardío (p.ej. clipboard, ya clasificado aparte) con archivo
    // ausente no debe dejar un pendiente que reintentaría con
    // "archivo no encontrado".
    final stillExists = _audioFileExists(path);
    if (mounted) {
      setState(() {
        _pendingAudioPath = stillExists ? path : null;
        _pendingAsNote = asNote;
        _isTranscribing = false;
      });
      _showTranscribeError(e, canRetry: stillExists);
    } else {
      _pendingAudioPath = stillExists ? path : null;
      _pendingAsNote = asNote;
      _isTranscribing = false;
    }
  }

  Future<void> _stopRecording() async {
    if (_isStartingRecording) {
      _shouldStopAfterStart = true;
      return;
    }
    if (_isStoppingRecording || !_isRecording) {
      return;
    }
    _isStoppingRecording = true;
    final discard = _discardOnStop;
    _discardOnStop = false;
    final asNote = _recordingAsNote;
    _hapticStop();
    try {
      await _floatingBubbleService.updateBubbleState(
          discard ? BubbleVisualState.idle : BubbleVisualState.transcribing);

      // Pasar a "Procesando" de inmediato: no dejar un frame de botón rojo
      // con overflow mientras se cierra el recorder.
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isTranscribing = !discard;
        });
      } else {
        _isRecording = false;
        _isTranscribing = !discard;
      }
      final path = await _transcriptionService.stopRecording();
      _isStoppingRecording = false;

      if (path == null) {
        await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        if (mounted) {
          setState(() => _isTranscribing = false);
        } else {
          _isTranscribing = false;
        }
        return;
      }

      // Verificar si el archivo tiene audio suficiente (>1000 bytes).
      // Si la grabación fue instantánea o vacía, se limpia sin llamar a Groq ni arrojar error.
      if (discard || !_hasUsableAudio(path)) {
        await _transcriptionService.cleanupTempFile(path);
        await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
        if (mounted) {
          setState(() => _isTranscribing = false);
        } else {
          _isTranscribing = false;
        }
        return;
      }

      try {
        // Anti-stale: la key puede haberse configurado/rotado en Ajustes
        // o el servicio venir con key vacía tras muerte del proceso y tap
        // de burbuja en segundo plano. Releer siempre antes de transcribir:
        // elimina el "API key no configurada" fantasma en burbuja cuando
        // la app sí transcribe bien.
        await _loadApiKey();
        if (asNote) {
          await _transcribeIntoNote(path);
        } else {
          final result = await _transcriptionService.transcribe(path);
          await _publishTranscriptionResult(result);
        }
      } catch (e) {
        await _handleTranscribeFailure(e, path, asNote);
      }
    } catch (e) {
      // stopRecording() o el canal de la burbuja lanzaron: jamás dejar la
      // UI en "Procesando…" eterno con botón muerto.
      try {
        await _floatingBubbleService.updateBubbleState(BubbleVisualState.idle);
      } catch (_) {}
      if (mounted) {
        setState(() => _isTranscribing = false);
        _showTranscribeError(e, canRetry: false);
      } else {
        _isTranscribing = false;
      }
    } finally {
      // Ambos flags SIEMPRE se resetean aunque stop/transcribe/canal lancen.
      _isStoppingRecording = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _retryPending() async {
    final path = _pendingAudioPath;
    if (path == null || _isTranscribing || _isRecording) return;
    final asNote = _pendingAsNote;
    if (!_hasUsableAudio(path)) {
      // El temporal se perdió o quedó vacío entre el fallo y el reintento:
      // limpiar el pendiente en vez de fallar con "archivo no encontrado".
      await _transcriptionService.cleanupTempFile(path);
      if (mounted) {
        setState(() {
          _pendingAudioPath = null;
          _isTranscribing = false;
        });
        _showSnack('El audio pendiente ya no está disponible');
      } else {
        _pendingAudioPath = null;
        _isTranscribing = false;
      }
      return;
    }
    if (mounted) {
      setState(() => _isTranscribing = true);
    } else {
      _isTranscribing = true;
    }
    await _floatingBubbleService
        .updateBubbleState(BubbleVisualState.transcribing);
    try {
      // Anti-stale también en reintento (misma causa que en _stopRecording).
      await _loadApiKey();
      if (asNote) {
        await _transcribeIntoNote(path);
      } else {
        final result = await _transcriptionService.transcribe(path);
        await _publishTranscriptionResult(result);
      }
    } catch (e) {
      await _handleTranscribeFailure(e, path, asNote);
    }
  }

  // ---------------------------------------------------------------------------
  // Notas pendientes (cola diferida sin conexión)
  // ---------------------------------------------------------------------------

  Future<void> _transcribePending(PendingNote item) async {
    if (_isTranscribingPending) return;
    setState(() => _isTranscribingPending = true);
    // C-45: transcribir PRIMERO (repara en disco) y promover DESPUÉS, para
    // que notes_audio quede sano. Antes se promovía el dañado.
    var noteCommitted = false;
    String? keptPath;
    try {
      await _loadApiKey();
      final file = await _transcriptionService.transcribe(
        item.audioPath,
        deleteAudioOnSuccess: false,
      );
      keptPath = await _pendingQueue.promoteToKept(item);
      if (keptPath == null) {
        if (mounted) {
          setState(() => _isTranscribingPending = false);
          _showSnack('No se pudo conservar el audio');
        }
        return;
      }
      final ok = await _notesService.addFromTranscription(
        file.text,
        audioPath: keptPath,
      );
      if (!ok) {
        _pendingQueue.deleteKeptAudio(keptPath);
        if (mounted) {
          setState(() => _isTranscribingPending = false);
          _showSnack('Nota no guardada; el audio se conserva');
        }
        return;
      }
      noteCommitted = true;
      final removed = await _pendingQueue.remove(item.id, deleteAudio: true);
      await WidgetService().updateWidgets();
      if (!mounted) return;
      _freshNoteId =
          _notesService.notes.isEmpty ? null : _notesService.notes.first.id;
      setState(() => _isTranscribingPending = false);
      _revealFreshNote();
      _showSnack(
        removed ? 'Nota guardada' : 'Nota guardada; el audio queda pendiente',
      );
    } on TranscriptionException catch (e) {
      if (!noteCommitted) _pendingQueue.deleteKeptAudio(keptPath);
      if (!mounted) return;
      setState(() => _isTranscribingPending = false);
      _showSnack(e.kind == TranscriptionErrorKind.auth
          ? 'Falta la API key. Configurala en Ajustes.'
          : e.isRetryable
              ? 'Sigue sin red. El audio queda pendiente.'
              : e.message);
    } catch (e) {
      if (!noteCommitted) _pendingQueue.deleteKeptAudio(keptPath);
      if (!mounted) return;
      setState(() => _isTranscribingPending = false);
      _showSnack('Error: $e');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(ctx).pop(false),
        },
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    return confirm == true;
  }

  Future<void> _discardPending(PendingNote item) async {
    final ok = await _confirm(
      title: 'Descartar audio',
      message:
          'Se borrará el audio sin transcribir. Esta acción no se puede deshacer.',
      confirmLabel: 'Descartar',
    );
    if (!ok) return;
    await _pendingQueue.remove(item.id, deleteAudio: true);
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Acciones de una nota
  // ---------------------------------------------------------------------------

  Future<void> _copyNote(VoiceNote n) async {
    // Solo el contenido (cuerpo), nunca el título.
    final copy = await copyTranscriptionText(n.cuerpo);
    if (!mounted) return;
    unawaited(HapticFeedback.selectionClick());
    _showSnack(copy == ClipboardCopyResult.ok
        ? copiedToClipboardMessage
        : clipboardFailureMessage);
  }

  /// Borra solo el audio conservado de una nota (el texto permanece).
  Future<void> _deleteNoteAudio(VoiceNote note) async {
    final ok = await _confirm(
      title: 'Borrar audio',
      message: 'Se borrará el audio original. La transcripción queda.',
      confirmLabel: 'Borrar audio',
    );
    if (!ok) return;
    await _notesService.updateNote(note.id, clearAudioPath: true);
    await WidgetService().updateWidgets();
    if (mounted) setState(() {});
  }

  Future<void> _deleteNote(VoiceNote note) async {
    final ok = await _notesService.deleteNote(note.id);
    await WidgetService().updateWidgets();
    if (!mounted) return;
    setState(() {});
    _showSnack(ok ? 'Nota eliminada' : 'No se pudo eliminar la nota');
  }

  Future<void> _openNoteActions(VoiceNote note) async {
    unawaited(HapticFeedback.selectionClick());
    final action = await showNoteActions(
      context,
      heading: note.titulo.trim().isEmpty ? note.cuerpo : note.titulo,
      hasAudio: note.hasAudio,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case NoteAction.open:
        await _openEditor(note);
      case NoteAction.copy:
        await _copyNote(note);
      case NoteAction.deleteAudio:
        await _deleteNoteAudio(note);
      case NoteAction.delete:
        await _deleteNote(note);
    }
  }

  Future<void> _openEditor(VoiceNote? note, {String? geminiAction}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          notesService: _notesService,
          initialGeminiAction: geminiAction,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// El teclado nativo escribe dictados en disco mientras la app está en
  /// segundo plano; al volver al primer plano se relee el historial desde
  /// SharedPreferences para mostrarlos sin reiniciar la app. Lo mismo con
  /// las notas y la cola, que el widget también escribe.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshHistoryFromDisk();
      _loadNotes();
    }
  }

  Future<void> _refreshHistoryFromDisk() async {
    try {
      await _storageService.load();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    if (widget.recordingController == null) {
      _recordingController.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    _floatingBubbleService.onBubbleTap = null;
    _floatingBubbleService.onBubbleClose = null;
    unawaited(_releaseMicrophoneOnTeardown());
    _newNoteCtrl.dispose();
    _searchCtrl.dispose();
    _notesScroll.dispose();
    _historyScroll.dispose();
    _scrolled.dispose();
    super.dispose();
  }

  Future<void> _releaseMicrophoneOnTeardown() async {
    try {
      if (!_transcriptionService.hasMicrophoneClaim) return;
      if (_isRecording || _isStartingRecording) {
        await _transcriptionService.stopRecording();
      }
      await _transcriptionService.releaseMicrophoneClaim();
    } catch (_) {}
  }

  /// Abre Configuración y, al volver, recarga clave, modo y cola (la app
  /// los cachea para grabar/transcribir sin releer el keystore en cada uso).
  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          storageService: _storageService,
          floatingBubbleService: _floatingBubbleService,
        ),
      ),
    );
    await _loadApiKey();
    await _loadRecordMode();
    await _loadNotes();
  }

  void _selectTab(int tab) {
    if (tab == _tab) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _tab = tab;
      _query = '';
      _searchCtrl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  List<Transcription> _filterHistory(List<Transcription> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((t) => t.text.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelSecondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final bg = isDark ? kBgBaseDark : kBgBaseLight;
    final title = _tab == 0 ? 'Notas' : 'Historial';
    final topBarHeight = insets.top + 56;
    final isHold = _recordMode == StorageService.recordModeHold;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _tab == 0
                ? _buildNotesTab(context, title, topBarHeight)
                : _buildHistoryTab(context, title, topBarHeight),
          ),
          // Barra compacta: aparece al desplazar, cuando el título grande
          // ya salió de pantalla.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: topBarHeight,
            child: RepaintBoundary(
              child: ValueListenableBuilder<bool>(
                valueListenable: _scrolled,
                builder: (context, scrolled, bar) => IgnorePointer(
                  ignoring: !scrolled,
                  child: AnimatedOpacity(
                    opacity: scrolled ? 1 : 0,
                    duration: motionSafe
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                    child: bar,
                  ),
                ),
                // Horizonte: barra sólida (sin desenfoque), fondo opaco.
                child: Container(
                  padding: EdgeInsets.only(top: insets.top),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? kSeparatorDark : kSeparatorLight,
                        width: kSurfaceBorderWidth,
                      ),
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      title,
                      style: kSettingsNavTitle.copyWith(
                        color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Ajustes: botón de ícono circular sólido (surf + line, sin halo).
          Positioned(
            top: insets.top + 6,
            right: 12,
            child: GlassContainer(
              borderRadius: kBorderRadiusCapsule,
              crystal: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('homeSettingsButton'),
                  customBorder: const CircleBorder(),
                  onTap: _openSettings,
                  child: const Tooltip(
                    message: 'Configuración',
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.tune_rounded, size: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // El contenido se esfuma bajo la burbuja (capa de contenido).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: insets.bottom + kRecordDockClearance,
            // Capa propia: el degradado no se vuelve a grabar con la lista.
            child: IgnorePointer(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bg.withValues(alpha: 0), bg],
                      stops: const [0, 0.72],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              child: Text(
                _statusText,
                key: const ValueKey('homeStatusText'),
                style: kTextFootnote.copyWith(
                  fontWeight: FontWeight.w500,
                  color: _pendingAudioPath != null && !_isRecording
                      ? (isDark ? kEmberTextDark : kEmberTextLight)
                      : labelSecondary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Capa propia: los cuadros de la pastilla no repintan el resto.
            RepaintBoundary(
              key: widget.holeKey,
              child: RecordButton(
                key: const ValueKey('recordButton'),
                state: _buttonState,
                levelSource: _transcriptionService.currentLevel,
                onCancel: isHold ? null : _discardRecording,
                onPressed: _recordMode == StorageService.defaultRecordMode
                    ? _toggleRecording
                    : () async {
                        if (_isRecording || _isStartingRecording) {
                          await _stopRecording();
                        } else {
                          unawaited(
                            SemanticsService.sendAnnouncement(
                              View.of(context),
                              'Mantené para grabar',
                              TextDirection.ltr,
                            ),
                          );
                        }
                      },
                onHoldStart: _recordMode == StorageService.recordModeHold
                    ? () {
                        _holdStartedAt = DateTime.now();
                        _startRecording(asNote: true);
                      }
                    : null,
                onHoldEnd: _recordMode == StorageService.recordModeHold
                    ? () async {
                        await _cancelHoldIfTooShort();
                        if (_isRecording || _isStartingRecording) {
                          await _stopRecording();
                        }
                      }
                    : null,
              ),
            ),
            const SizedBox(height: kRecordDockBottomGap - 16),
          ],
        ),
      ),
    );
  }

  /// Título grande + selector + buscador: se desplazan con la lista.
  Widget _buildHeader(BuildContext context, String title, double top) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notesCount = _notesAvailable ? _notesService.notes.length : 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top - 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
            child: Semantics(
              header: true,
              child: Text(
                title,
                key: const ValueKey('homeTitleText'),
                style: kTextLargeTitle.copyWith(
                  color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
                ),
              ),
            ),
          ),
          HomeSegmented(
            index: _tab,
            notesCount: notesCount,
            historyCount: _transcriptionService.history.length,
            onChanged: _selectTab,
          ),
          const SizedBox(height: 14),
          HomeSearchField(
            controller: _searchCtrl,
            hint: _tab == 0
                ? (notesCount == 0 ? 'Buscar' : 'Buscar en $notesCount notas')
                : 'Buscar en el historial',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _bottomClearance(BuildContext context) => SizedBox(
        height: kRecordDockClearance + MediaQuery.paddingOf(context).bottom,
      );

  Widget _buildNotesTab(BuildContext context, String title, double top) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    // Lista plana de encabezados de sección, espacios y tarjetas, en orden.
    final rows = _notesAvailable
        ? _noteRows.resolve(
            _notesService.notes,
            _query,
            build: () => groupRows(
              _notesService.search(_query),
              groupOf: (n) => noteGroupLabel(n.updatedAt),
              timeOf: (n) => noteTimeLabel(n.updatedAt),
            ),
          )
        : const <GroupedRow<VoiceNote>>[];
    final pending = _pendingQueue.items;
    final showPending = _deferredQueueEnabled &&
        _queueLoaded &&
        _queueAvailable &&
        pending.isNotEmpty;

    Widget? placeholder;
    if (!_notesAvailable) {
      placeholder = HomeEmptyState(
        key: const ValueKey('notesUnavailable'),
        showGlyph: false,
        title: _notesLoading ? 'Cargando notas…' : 'Notas no disponibles',
        message: _notesLoading ? '' : 'No se pudo leer el estado de las notas',
      );
    } else if (rows.isEmpty && !showPending) {
      placeholder = _query.isEmpty
          ? HomeEmptyState(
              key: const ValueKey('notesEmpty'),
              title: 'Tu primera nota',
              message: _recordMode == StorageService.recordModeHold
                  ? 'Mantené la burbuja y hablá.\nLo que digas queda escrito acá.'
                  : 'Tocá la burbuja y hablá.\nLo que digas queda escrito acá.',
            )
          : HomeEmptyState(
              key: const ValueKey('notesNoResults'),
              showGlyph: false,
              title: 'Sin resultados',
              message: 'Nada coincide con “$_query”.',
            );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('home_notes_scroll'),
      controller: _notesScroll,
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context, title, top)),
        if (showPending)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Encabezado, aviso y luego tarjeta + espacio por pendiente.
            sliver: SliverList.builder(
              itemCount: 2 + pending.length * 2,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return HomeSectionHeader(
                    'Pendientes · ${pending.length}',
                    key: const ValueKey('pendingNotesList'),
                  );
                }
                if (i == 1) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      'Sin transcripción local todavía: el audio se guarda en el teléfono y solo sale a la nube cuando tocas Transcribir.',
                      key: const ValueKey('pendingLocalInfo'),
                      style: kTextCaption.copyWith(color: secondary),
                    ),
                  );
                }
                if (i.isOdd) return const SizedBox(height: 8);
                final p = pending[(i - 2) ~/ 2];
                return PendingNoteTile(
                  item: p,
                  busy: _isTranscribingPending,
                  onTranscribe: () => _transcribePending(p),
                  onDiscard: () => _discardPending(p),
                );
              },
            ),
          ),
        if (_queueLoaded && !_queueAvailable)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Cola no disponible',
                key: const ValueKey('pendingQueueUnavailable'),
                style: kTextCaption.copyWith(color: secondary),
              ),
            ),
          ),
        if (placeholder != null)
          SliverToBoxAdapter(child: placeholder)
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Perezosa: solo se construyen las tarjetas visibles (y la
            // franja de caché); la key por id conserva cada tarjeta aunque
            // cambie su índice.
            sliver: SliverList.builder(
              itemCount: rows.length,
              findChildIndexCallback: (key) =>
                  key is ValueKey<String> ? _noteRows.indexOf(key.value) : null,
              itemBuilder: (context, i) => switch (rows[i]) {
                GroupHeaderRow(:final label) =>
                  HomeSectionHeader(label, key: ValueKey('notesGroup-$label')),
                GroupGapRow() => const SizedBox(height: 10),
                GroupItemRow(item: final n, :final timeLabel) => NoteCard(
                    key: ValueKey(n.id),
                    note: n,
                    timeLabel: timeLabel,
                    highlight: n.id == _freshNoteId ? _newNoteHighlight : null,
                    onTap: () => _openEditor(n),
                    onLongPress: () => _openNoteActions(n),
                    onCopy: () => _copyNote(n),
                  ),
              },
            ),
          ),
        SliverToBoxAdapter(child: _bottomClearance(context)),
      ],
    );
  }

  Widget _buildHistoryTab(BuildContext context, String title, double top) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? kSeparatorDark : kSeparatorLight;
    final searching = _query.trim().isNotEmpty;

    // Agrupado por día solo en la presentación: el orden es el del
    // repositorio (más nuevo primero) y cada corrida de un mismo día abre
    // un encabezado. La fila lleva solo la hora.
    final rows = _historyRows.resolve(
      _transcriptionService.history,
      _query,
      build: () => groupRows(
        _filterHistory(_transcriptionService.history),
        groupOf: (t) => historyDayLabel(t.timestamp),
        timeOf: (t) => historyTimeLabel(t.timestamp),
      ),
    );

    final Widget list;
    if (rows.isEmpty) {
      list = SliverToBoxAdapter(
        child: searching
            ? HomeEmptyState(
                showGlyph: false,
                title: 'Sin resultados',
                message: 'Nada coincide con “$_query”.',
              )
            : const HistoryList(transcriptions: [], embedded: true),
      );
    } else {
      // Un solo sliver perezoso con índices planos (encabezado de día,
      // fila, separador line): sin una lista con shrinkWrap por día.
      list = SliverList.builder(
        itemCount: rows.length,
        findChildIndexCallback: (key) => key is ValueKey<String> &&
                key.value.startsWith('historyRow-')
            ? _historyRows.indexOf(key.value.substring('historyRow-'.length))
            : null,
        itemBuilder: (context, i) => switch (rows[i]) {
          GroupHeaderRow(:final label) =>
            HomeSectionHeader(label, key: ValueKey('historyGroup-$label')),
          GroupGapRow() => Divider(
              height: kSurfaceBorderWidth,
              thickness: kSurfaceBorderWidth,
              color: line,
            ),
          GroupItemRow(item: final t, :final timeLabel) => HistoryTile(
              key: ValueKey('historyRow-${t.id}'),
              transcription: t,
              timeLabel: timeLabel,
            ),
        },
      );
    }

    return CustomScrollView(
      key: const PageStorageKey<String>('home_history_scroll'),
      controller: _historyScroll,
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context, title, top)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: list,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
            child: Text(
              'Las últimas ${StorageService.maxItems} transcripciones de la app, '
              'la burbuja y el teclado. Las más viejas se borran solas.',
              textAlign: TextAlign.center,
              style: kTextFootnote.copyWith(
                color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _bottomClearance(context)),
      ],
    );
  }
}
