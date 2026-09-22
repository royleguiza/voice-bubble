import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/voice_note.dart';
import '../services/notes_service.dart';
import '../services/widget_service.dart';
import '../ui/design_tokens.dart';
import '../ui/transcription_feedback.dart';

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
                icon: const Icon(Icons.content_paste_rounded, size: 18),
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
                icon: const Icon(Icons.copy_rounded, size: 18),
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
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
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
