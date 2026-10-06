import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/voice_note.dart';
import '../services/notes_service.dart';
import '../services/gemini_key_store.dart';
import '../services/gemini_note_service.dart';
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
  final _geminiKeyStore = GeminiKeyStore();
  bool _geminiReady = false;
  bool _geminiBusy = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.titulo ?? '');
    _bodyCtrl = TextEditingController(text: widget.note?.cuerpo ?? '');
    _loadGeminiState();
  }

  Future<void> _loadGeminiState() async {
    final has = await _geminiKeyStore.hasKey();
    final enabled = await _geminiKeyStore.actionsEnabled();
    if (mounted) setState(() => _geminiReady = has && enabled);
  }

  Future<void> _runGemini(String accion) async {
    final texto = _bodyCtrl.text.trim();
    if (texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe o dicta una nota primero')),
      );
      return;
    }
    final key = await _geminiKeyStore.getKey();
    if (key == null) {
      if (!mounted) return;
      setState(() => _geminiReady = false);
      return;
    }
    if (mounted) setState(() => _geminiBusy = true);
    String? resultado;
    Object? error;
    try {
      final service = GeminiNoteService(apiKey: key);
      if (accion == 'titulo') {
        resultado = await service.sugerirTitulo(texto);
      } else if (accion == 'reestructurar') {
        resultado = await service.reestructurar(texto);
      } else {
        resultado = await service.investigar(texto);
      }
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    setState(() => _geminiBusy = false);
    if (error != null) {
      final msg = error is GeminiException
          ? error.message
          : 'Error inesperado: $error';
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error de IA'),
          content: SelectableText(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }
    if (resultado == null) return;
    _showGeminiResult(accion, resultado);
  }

  void _showGeminiResult(String accion, String resultado) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accion == 'titulo'
            ? 'Título sugerido'
            : accion == 'reestructurar'
                ? 'Nota reestructurada'
                : 'Investigación preliminar'),
        content: SingleChildScrollView(child: Text(resultado)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Descartar'),
          ),
          FilledButton(
            key: ValueKey('geminiApply_$accion'),
            onPressed: () {
              if (accion == 'titulo') {
                _titleCtrl.text = resultado;
              } else if (accion == 'reestructurar') {
                _bodyCtrl.text = resultado;
              } else {
                _bodyCtrl.text = '${_bodyCtrl.text}\n\n$resultado';
              }
              Navigator.of(ctx).pop();
            },
            child: Text(accion == 'investigar' ? 'Anexar' : 'Aplicar'),
          ),
        ],
      ),
    );
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Scaffold(
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
          if (_geminiReady)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('geminiTituloButton'),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_geminiBusy ? 'Procesando…' : 'IA · Título'),
                    onPressed: _geminiBusy ? null : () => _runGemini('titulo'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('geminiReestructurarButton'),
                    icon: const Icon(Icons.reorder_rounded, size: 18),
                    label: const Text('IA · Reestructurar'),
                    onPressed:
                        _geminiBusy ? null : () => _runGemini('reestructurar'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('geminiInvestigarButton'),
                    icon: const Icon(Icons.travel_explore_rounded, size: 18),
                    label: const Text('IA · Investigar'),
                    onPressed:
                        _geminiBusy ? null : () => _runGemini('investigar'),
                  ),
                ],
              ),
            ),
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
    ),
  );
}
}
