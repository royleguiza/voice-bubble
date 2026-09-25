import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/voice_note.dart';
import '../services/notes_service.dart';
import '../services/pending_note_queue.dart';
import '../services/transcription_service.dart';
import '../services/cloud_stt_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';
import '../ui/transcription_feedback.dart';
import '../widgets/note_card.dart';
import '../widgets/pending_note_tile.dart';
import 'note_editor_screen.dart';
import 'package:path_provider/path_provider.dart';

class NotesScreen extends StatefulWidget {
  final NotesService? notesService;
  final TranscriptionService? transcriptionService;
  final PendingNoteQueue? pendingQueue;

  const NotesScreen({
    super.key,
    this.notesService,
    this.transcriptionService,
    this.pendingQueue,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with WidgetsBindingObserver {
  late final NotesService _notesService;
  late final TranscriptionService _transcriptionService;
  late final PendingNoteQueue _pendingQueue;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _deferredQueueEnabled = false;
  bool _isTranscribingPending = false;
  bool _queueLoaded = false;
  bool _queueAvailable = false;
  bool _notesAvailable = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notesService = widget.notesService ?? NotesService();
    _transcriptionService = widget.transcriptionService ??
        TranscriptionService(
          cloudService: const CloudSttService(apiKey: ''),
          storageService: StorageService(),
        );
    _pendingQueue = widget.pendingQueue ?? PendingNoteQueue();
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El widget puede encolar offline mientras la app está en fondo:
    // al volver se re-lee la cola (con reload de prefs) y las notas.
    if (state == AppLifecycleState.resumed) {
      _refreshFromWidget();
    }
  }

  Future<void> _refreshFromWidget() async {
    final notesLoaded = await _notesService.load();
    try {
      _deferredQueueEnabled =
          await StorageService().loadNotesDeferredQueueEnabled();
    } catch (_) {}
    final queueLoaded = await _pendingQueue.load();
    _notesAvailable = notesLoaded;
    _queueAvailable = queueLoaded;
    _queueLoaded = true;
    _loading = false;
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final notesLoaded = await _notesService.load();
    try {
      _deferredQueueEnabled =
          await StorageService().loadNotesDeferredQueueEnabled();
    } catch (_) {
      _deferredQueueEnabled = false;
    }
    final queueLoaded = await _pendingQueue.load();
    _notesAvailable = notesLoaded;
    _queueAvailable = queueLoaded;
    _queueLoaded = true;
    _loading = false;
    if (mounted) setState(() {});
  }

  List<VoiceNote> get _filtered => _notesService.search(_query);

  Future<void> _dictateNew() async {
    if (_isRecording || _isTranscribing) return;
    setState(() => _isRecording = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _transcriptionService.startRecording(path);
      // Espera a que el usuario suelte: simulamos grabación corta controlada
      // por el botón de la pantalla. Aquí el flujo es tap→grabar→tap detener.
      // Para widget: tap único. Aquí usamos toggle.
    } catch (_) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopAndSave() async {
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });
    unawaited(HapticFeedback.lightImpact());
    String? path;
    String? keptPath;
    try {
      path = await _transcriptionService.stopRecording();
      if (path == null) {
        setState(() => _isTranscribing = false);
        return;
      }
      keptPath = await _pendingQueue.keepCopyForNote(path);
      if (keptPath == null) {
        if (mounted) {
          setState(() => _isTranscribing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo conservar el audio')),
          );
        }
        return;
      }
      final file = await _transcriptionService.transcribe(
        path,
        deleteAudioOnSuccess: false,
      );
      final ok = await _notesService.addFromTranscription(
        file.text,
        audioPath: keptPath,
      );
      if (ok) {
        await _transcriptionService.cleanupTempFile(path);
      }
      if (!mounted) return;
      setState(() => _isTranscribing = false);
      if (ok) {
        await WidgetService().updateWidgets();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota guardada')),
        );
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota no guardada; el audio se conserva')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isTranscribing = false);
      // Cola diferida: solo fallos reintentables (red/servidor) y con flag ON.
      // Nunca auto-upload: el envío posterior es un toque del usuario.
      final retryable =
          e is TranscriptionException && e.isRetryable && path != null;
      if (retryable && _deferredQueueEnabled) {
        final item = await _pendingQueue.enqueueFromTemp(path);
        if (!mounted) return;
        setState(() {});
        if (item != null) {
          _pendingQueue.deleteKeptAudio(keptPath);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión · audio guardado en Notas'),
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _transcribePending(PendingNote item) async {
    if (_isTranscribingPending) return;
    setState(() => _isTranscribingPending = true);
    final keptPath = await _pendingQueue.promoteToKept(item);
    if (keptPath == null) {
      if (mounted) {
        setState(() => _isTranscribingPending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo conservar el audio')),
        );
      }
      return;
    }
    var noteCommitted = false;
    try {
      final key = await StorageService.espSecureStorage
              .read(key: 'groq_api_key') ??
          '';
      _transcriptionService.updateApiKey(key);
      final file = await _transcriptionService.transcribe(
        item.audioPath,
        deleteAudioOnSuccess: false,
      );
      final ok = await _notesService.addFromTranscription(
        file.text,
        audioPath: keptPath,
      );
      if (!ok) {
        if (mounted) {
          setState(() => _isTranscribingPending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nota no guardada; el audio se conserva')),
          );
        }
        return;
      }
      noteCommitted = true;
      final removed = await _pendingQueue.remove(item.id, deleteAudio: true);
      await WidgetService().updateWidgets();
      if (!mounted) return;
      setState(() => _isTranscribingPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed ? 'Nota guardada' : 'Nota guardada; el audio queda pendiente',
          ),
        ),
      );
      setState(() {});
    } on TranscriptionException catch (e) {
      if (!noteCommitted) _pendingQueue.deleteKeptAudio(keptPath);
      if (!mounted) return;
      setState(() => _isTranscribingPending = false);
      final msg = e.kind == TranscriptionErrorKind.auth
          ? 'Falta la API key. Configurala en Ajustes.'
          : e.isRetryable
              ? 'Sigue sin red. El audio queda pendiente.'
              : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!noteCommitted) _pendingQueue.deleteKeptAudio(keptPath);
      if (!mounted) return;
      setState(() => _isTranscribingPending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _discardPending(PendingNote item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar audio'),
        content: const Text(
            'Se borrará el audio sin transcribir. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _pendingQueue.remove(item.id, deleteAudio: true);
    if (mounted) setState(() {});
  }

  /// Borra solo el audio conservado de una nota (el texto permanece).
  Future<void> _deleteNoteAudio(VoiceNote note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar audio'),
        content: const Text(
            'Se borrará el audio original. La transcripción queda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar audio'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _notesService.updateNote(note.id, clearAudioPath: true);
    await WidgetService().updateWidgets();
    if (mounted) setState(() {});
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      await _stopAndSave();
    } else {
      // Cargar API key antes de grabar
      try {
        final key =
            await StorageService.espSecureStorage.read(key: 'groq_api_key') ??
                '';
        _transcriptionService.updateApiKey(key);
      } catch (_) {}
      await _dictateNew();
    }
  }

  void _openEditor(VoiceNote? note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          note: note,
          notesService: _notesService,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
        centerTitle: true,
        actions: [
          Semantics(
            label: 'Nueva nota',
            button: true,
            child: IconButton(
              tooltip: 'Nueva nota',
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _openEditor(null),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar en 50 notas',
                hintStyle: kTextFootnote.copyWith(
                  color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
                ),
                filled: true,
                fillColor: isDark ? kBgSecondaryDark : kBgSecondaryLight,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kBorderRadiusCard),
                  borderSide: BorderSide(
                    color: isDark ? kSeparatorDark : kSeparatorLight,
                    width: 0.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kBorderRadiusCard),
                  borderSide: BorderSide(
                    color: isDark ? kSeparatorDark : kSeparatorLight,
                    width: 0.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(kBorderRadiusCard),
                  borderSide: const BorderSide(color: kAccentLight, width: 1),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  !_notesAvailable
                      ? (_loading ? 'Cargando…' : 'Notas no disponibles')
                      : '${_filtered.length} / ${NotesService.maxNotes}',
                  key: const ValueKey('notesStatus'),
                  style: kTextCaption.copyWith(
                    color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
                  ),
                ),
                const Spacer(),
                if (_isRecording || _isTranscribing)
                  Row(
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _isRecording ? kRecording : kAccentLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isRecording ? 'Grabando' : 'Procesando',
                        style: kTextCaption.copyWith(
                          color: _isRecording ? kRecording : kAccentLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
           if (_deferredQueueEnabled &&
               _queueLoaded &&
               _queueAvailable &&
               _pendingQueue.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Pendientes · ${_pendingQueue.items.length}',
                key: const ValueKey('pendingNotesList'),
                style: kTextCaption.copyWith(
                  color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                'Sin transcripción local todavía: el audio se guarda en el teléfono y solo sale a la nube cuando tocas Transcribir.',
                key: const ValueKey('pendingLocalInfo'),
                style: kTextCaption.copyWith(
                  color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (final p in _pendingQueue.items) ...[
                    PendingNoteTile(
                      item: p,
                      busy: _isTranscribingPending,
                      onTranscribe: () => _transcribePending(p),
                      onDiscard: () => _discardPending(p),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
           if (_queueLoaded && !_queueAvailable)
             Padding(
               padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
               child: Text(
                 'Cola no disponible',
                 key: const ValueKey('pendingQueueUnavailable'),
                 style: kTextCaption.copyWith(
                   color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
                 ),
               ),
             ),
           Expanded(
             child: !_notesAvailable
                 ? Center(
                     child: Text(
                       _loading
                           ? 'Cargando notas…'
                           : 'No se pudo leer el estado de las notas',
                       key: const ValueKey('notesUnavailable'),
                       style: kTextFootnote.copyWith(
                         color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
                       ),
                     ),
                   )
                 : _filtered.isEmpty
                     ? Center(
                         child: Text(
                           _query.isEmpty ? 'Sin notas' : 'Sin resultados',
                           style: kTextFootnote.copyWith(
                             color: isDark
                                 ? kLabelSecondaryDark
                                 : kLabelSecondaryLight,
                           ),
                         ),
                       )
                     : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = _filtered[i];
                      return NoteCard(
                        note: n,
                        onTap: () => _openEditor(n),
                        onDeleteAudio: n.hasAudio
                            ? () => _deleteNoteAudio(n)
                            : null,
                        onCopy: () async {
                          // Solo el contenido (cuerpo), nunca el título.
                          final copy = await copyTranscriptionText(n.cuerpo);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(copy == ClipboardCopyResult.ok
                                  ? copiedToClipboardMessage
                                  : clipboardFailureMessage),
                            ),
                          );
                        },
                        onDelete: () async {
                          await _notesService.deleteNote(n.id);
                          await WidgetService().updateWidgets();
                          if (mounted) setState(() {});
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: GlassContainer(
        borderRadius: kBorderRadiusCapsule,
        small: true,
        child: FloatingActionButton.extended(
          key: const ValueKey('notesMicFab'),
          heroTag: 'notesMic',
          elevation: 0,
          backgroundColor: _isRecording ? kRecording : kAccentLight,
          foregroundColor: Colors.white,
          onPressed: _isTranscribing ? null : _toggleRecord,
          icon: Icon(
            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
            size: 22,
          ),
          label: Text(_isRecording ? 'Detener' : 'Dictar'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
