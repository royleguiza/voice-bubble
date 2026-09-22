import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/voice_note.dart';
import '../services/notes_service.dart';
import '../services/transcription_service.dart';
import '../services/cloud_stt_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';
import '../ui/transcription_feedback.dart';
import '../widgets/note_card.dart';
import 'package:path_provider/path_provider.dart';

class NotesScreen extends StatefulWidget {
  final NotesService? notesService;
  final TranscriptionService? transcriptionService;

  const NotesScreen({
    super.key,
    this.notesService,
    this.transcriptionService,
  });

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final NotesService _notesService;
  late final TranscriptionService _transcriptionService;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _isRecording = false;
  bool _isTranscribing = false;

  @override
  void initState() {
    super.initState();
    _notesService = widget.notesService ?? NotesService();
    _transcriptionService = widget.transcriptionService ??
        TranscriptionService(
          cloudService: const CloudSttService(apiKey: ''),
          storageService: StorageService(),
        );
    _load();
  }

  Future<void> _load() async {
    await _notesService.load();
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
    try {
      final path = await _transcriptionService.stopRecording();
      if (path == null) {
        setState(() => _isTranscribing = false);
        return;
      }
      final file = await _transcriptionService.transcribe(path);
      final ok = await _notesService.addFromTranscription(file.text);
      if (!mounted) return;
      setState(() => _isTranscribing = false);
      if (ok) {
        await WidgetService().updateWidgets();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota guardada')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranscribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      await _stopAndSave();
    } else {
      // Cargar API key antes de grabar
      try {
        final key = await StorageService.espSecureStorage.read(key: 'groq_api_key') ?? '';
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  '${_filtered.length} / ${NotesService.maxNotes}',
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
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty ? 'Sin notas' : 'Sin resultados',
                      style: kTextFootnote.copyWith(
                        color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
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
            size: 20,
          ),
          label: Text(_isRecording ? 'Detener' : 'Dictar'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class NoteEditorScreen extends StatefulWidget {
  final VoiceNote? note;
  final NotesService notesService;

  const NoteEditorScreen({
    super.key,
    this.note,
    required this.notesService,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.titulo ?? '');
    _bodyCtrl = TextEditingController(text: widget.note?.cuerpo ?? '');
  }

  Future<void> _save() async {
    final titulo = _titleCtrl.text.trim();
    final cuerpo = _bodyCtrl.text.trim();
    if (cuerpo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuerpo requerido')),
      );
      return;
    }
    bool ok;
    if (widget.note == null) {
      ok = await widget.notesService.addNote(titulo: titulo, cuerpo: cuerpo);
    } else {
      ok = await widget.notesService.updateNote(
        widget.note!.id,
        titulo: titulo,
        cuerpo: cuerpo,
      );
    }
    if (!mounted) return;
    if (ok) {
      await WidgetService().updateWidgets();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite alcanzado o error')),
      );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Nueva nota' : 'Editar nota'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          TextField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            maxLength: NotesService.maxTituloLength,
            style: kTextSubhead.copyWith(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Titulo',
              labelStyle: kTextFootnote.copyWith(
                color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
              ),
              filled: true,
              fillColor: isDark ? kBgSecondaryDark : kBgSecondaryLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kBorderRadiusCard),
                borderSide: BorderSide(
                  color: isDark ? kSeparatorDark : kSeparatorLight,
                ),
              ),
              counterStyle: kTextCaption.copyWith(
                color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            minLines: 8,
            maxLines: 14,
            maxLength: NotesService.maxCuerpoLength,
            style: kTextBody,
            decoration: InputDecoration(
              labelText: 'Cuerpo',
              alignLabelWithHint: true,
              labelStyle: kTextFootnote.copyWith(
                color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
              ),
              filled: true,
              fillColor: isDark ? kBgSecondaryDark : kBgSecondaryLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(kBorderRadiusCard),
                borderSide: BorderSide(
                  color: isDark ? kSeparatorDark : kSeparatorLight,
                ),
              ),
              counterStyle: kTextCaption.copyWith(
                color: isDark ? kLabelSecondaryDark : kLabelSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: const Text('Pegar'),
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  final txt = data?.text ?? '';
                  if (txt.isNotEmpty) {
                    _bodyCtrl.text = '${_bodyCtrl.text}$txt';
                  }
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('noteEditorCopyButton'),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copiar'),
                onPressed: () async {
                  // Copia el contenido (cuerpo) en edición, no el título.
                  final txt = _bodyCtrl.text;
                  if (txt.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Sin contenido para copiar')),
                    );
                    return;
                  }
                  final copy = await copyTranscriptionText(txt);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(copy == ClipboardCopyResult.ok
                          ? copiedToClipboardMessage
                          : clipboardFailureMessage),
                    ),
                  );
                },
              ),
              if (widget.note != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Borrar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kRecording,
                  ),
                  onPressed: () async {
                    await widget.notesService.deleteNote(widget.note!.id);
                    await WidgetService().updateWidgets();
                    if (!mounted) return;
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
