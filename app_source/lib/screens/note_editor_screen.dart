import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async' show unawaited;

import '../helpers/note_groups.dart';
import '../models/voice_note.dart';
import '../services/notes_service.dart';
import '../services/gemini_key_store.dart';
import '../services/gemini_note_service.dart';
import '../services/widget_service.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';
import '../ui/transcription_feedback.dart';
import '../widgets/app_icons.dart';
import '../widgets/note_audio_row.dart';

/// Editor de una nota: hoja limpia (sin cajas ni etiquetas) con el mismo
/// lenguaje que Inicio — fondo base, botones de vidrio circulares arriba y
/// una barra de vidrio flotante abajo con acciones solo de icono.
///
/// Volver atrás guarda los cambios (como Notas de iOS); el ✓ guarda y cierra.
class NoteEditorScreen extends StatefulWidget {
  final VoiceNote? note;
  final NotesService notesService;
  final String? initialGeminiAction;

  const NoteEditorScreen({
    super.key,
    this.note,
    required this.notesService,
    this.initialGeminiAction,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  final _bodyFocus = FocusNode();
  final _geminiKeyStore = GeminiKeyStore();
  bool _geminiReady = false;
  bool _geminiBusy = false;
  bool _saving = false;

  /// El contador del título solo aparece cerca del límite.
  static const int _titleCounterFrom = 60;

  /// Alto de la barra de herramientas flotante (sin el margen inferior).
  static const double _toolbarHeight = 56;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note?.titulo ?? '');
    _bodyCtrl = TextEditingController(text: widget.note?.cuerpo ?? '');
    _loadGeminiState();
    _titleCtrl.addListener(_onChanged);
    _bodyCtrl.addListener(_onChanged);
    if (widget.initialGeminiAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _geminiReady) {
          _runGemini(widget.initialGeminiAction!);
        }
      });
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _dirty =>
      _titleCtrl.text.trim() != (widget.note?.titulo ?? '').trim() ||
      _bodyCtrl.text.trim() != (widget.note?.cuerpo ?? '').trim();

  Future<void> _loadGeminiState() async {
    final has = await _geminiKeyStore.hasKey();
    final enabled = await _geminiKeyStore.actionsEnabled();
    if (mounted) setState(() => _geminiReady = has && enabled);
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _runGemini(String accion) async {
    final texto = _bodyCtrl.text.trim();
    if (texto.isEmpty) {
      _showSnack('Escribe o dicta una nota primero');
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
      } else if (accion == 'resumir') {
        resultado = await service.resumir(texto);
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
      unawaited(showDialog<void>(
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
      ));
      return;
    }
    if (resultado == null) return;
    if (accion == 'titulo') {
      _titleCtrl.text = resultado;
      if (widget.note != null) {
        await widget.notesService.updateNote(widget.note!.id,
            titulo: resultado, cuerpo: _bodyCtrl.text);
        await WidgetService().updateWidgets();
      }
      return;
    }
    _showGeminiResult(accion, resultado);
  }

  void _showGeminiResult(String accion, String resultado) {
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(accion == 'titulo' ? 'Título sugerido' : 'Resumen de la nota'),
        content: SingleChildScrollView(child: Text(resultado)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Descartar'),
          ),
          FilledButton(
            key: ValueKey('geminiApply_$accion'),
            onPressed: () async {
              _bodyCtrl.text = resultado;
              Navigator.of(ctx).pop();
              if (widget.note != null) {
                await widget.notesService
                    .updateNote(widget.note!.id, cuerpo: _bodyCtrl.text);
                await WidgetService().updateWidgets();
              }
            },
            child: const Text('Reemplazar'),
          ),
        ],
      ),
    ));
  }

  Future<void> _save() async {
    if (_saving) return;
    final titulo = _titleCtrl.text.trim();
    final cuerpo = _bodyCtrl.text.trim();
    if (cuerpo.isEmpty) {
      _showSnack('Cuerpo requerido');
      return;
    }
    _saving = true;
    bool ok;
    try {
      if (widget.note == null) {
        ok = await widget.notesService.addNote(titulo: titulo, cuerpo: cuerpo);
      } else {
        ok = await widget.notesService.updateNote(
          widget.note!.id,
          titulo: titulo,
          cuerpo: cuerpo,
        );
      }
    } finally {
      _saving = false;
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

  /// Volver: con cambios y texto se guarda; con el cuerpo vacío se descarta
  /// (no hay nota que conservar) y se sale sin preguntar.
  void _onPopBlocked() {
    if (_bodyCtrl.text.trim().isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    unawaited(_save());
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final txt = data?.text ?? '';
    if (txt.isEmpty) {
      if (mounted) _showSnack('El portapapeles está vacío');
      return;
    }
    // Pega donde está el cursor (o al final si el cuerpo no tiene foco).
    final value = _bodyCtrl.value;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    final text = value.text.replaceRange(start, end, txt);
    _bodyCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + txt.length),
    );
    unawaited(HapticFeedback.selectionClick());
  }

  Future<void> _copy() async {
    // Copia el contenido (cuerpo) en edición, no el título.
    final txt = _bodyCtrl.text;
    if (txt.isEmpty) {
      _showSnack('Sin contenido para copiar');
      return;
    }
    final copy = await copyTranscriptionText(txt);
    if (!mounted) return;
    unawaited(HapticFeedback.selectionClick());
    _showSnack(copy == ClipboardCopyResult.ok
        ? copiedToClipboardMessage
        : clipboardFailureMessage);
  }

  Future<void> _delete() async {
    final note = widget.note;
    if (note == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(ctx).pop(false),
        },
        child: AlertDialog(
          title: const Text('Eliminar nota'),
          content: Text(note.hasAudio
              ? 'Se borrarán el texto y el audio. No se puede deshacer.'
              : 'Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              key: const ValueKey('noteEditorDeleteConfirm'),
              style: TextButton.styleFrom(foregroundColor: kRecording),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    await widget.notesService.deleteNote(note.id);
    await WidgetService().updateWidgets();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  String _metaLabel() {
    final note = widget.note;
    if (note == null) return 'Nueva nota';
    final group = noteGroupLabel(note.updatedAt);
    final time = noteTimeLabel(note.updatedAt);
    // Hoy/Ayer muestran la hora; lo más viejo, la fecha corta.
    return (group == 'Hoy' || group == 'Ayer') ? '$group, $time' : time;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? kBgBaseDark : kBgBaseLight;
    final primary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final secondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final tertiary = isDark ? kLabelTertiaryDark : kLabelTertiaryLight;
    final accent = isDark ? kAccentDark : kAccentLight;
    final insets = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final toolbarGap = keyboard > 0 ? 8.0 : insets.bottom + 12;
    final titleLen = _titleCtrl.text.characters.length;
    final note = widget.note;

    final noBorder = InputDecoration(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      isCollapsed: true,
      filled: false,
      counterText: '',
    );
    final titleStyle = kTextTitle.copyWith(
      fontSize: 28,
      height: 34 / 28,
      letterSpacing: 0.2,
      color: primary,
    );
    final bodyStyle = kTextBody.copyWith(
      fontSize: 18,
      height: 1.5,
      letterSpacing: -0.3,
      color: primary,
    );

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              Positioned.fill(
                child: ListView(
                  key: const ValueKey('noteEditorScroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    insets.top + 64,
                    20,
                    _toolbarHeight + toolbarGap + 24,
                  ),
                  children: [
                    Row(
                      children: [
                        Text(
                          _metaLabel(),
                          key: const ValueKey('noteEditorMeta'),
                          style: kTextFootnote.copyWith(
                            color: secondary,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                        if (note != null && note.hasAudio) ...[
                          const SizedBox(width: 10),
                          NoteAudioRow(
                            key: ValueKey('editorAudio_${note.id}'),
                            audioPath: note.audioPath!,
                            noteId: note.id,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('noteEditorTitle'),
                            controller: _titleCtrl,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _bodyFocus.requestFocus(),
                            minLines: 1,
                            maxLines: 3,
                            maxLength: NotesService.maxTituloLength,
                            textCapitalization: TextCapitalization.sentences,
                            cursorColor: accent,
                            style: titleStyle,
                            decoration: noBorder.copyWith(
                              hintText: 'Título',
                              hintStyle: titleStyle.copyWith(color: tertiary),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 6),
                            ),
                          ),
                        ),
                        if (_geminiReady && _titleCtrl.text.trim().isEmpty)
                          IconButton(
                            key: const ValueKey('geminiTituloIcon'),
                            icon: Icon(Icons.auto_awesome_rounded,
                                size: AppIcons.medium, color: accent),
                            tooltip: 'Generar título con IA',
                            onPressed: _geminiBusy
                                ? null
                                : () => _runGemini('titulo'),
                          ),
                      ],
                    ),
                    if (titleLen >= _titleCounterFrom)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$titleLen/${NotesService.maxTituloLength}',
                          key: const ValueKey('noteEditorTitleCounter'),
                          style: kTextCaption.copyWith(
                            color: titleLen >= NotesService.maxTituloLength
                                ? kRecording
                                : secondary,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('noteEditorBody'),
                      controller: _bodyCtrl,
                      focusNode: _bodyFocus,
                      autofocus: note == null,
                      minLines: 12,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: accent,
                      style: bodyStyle,
                      decoration: noBorder.copyWith(
                        hintText: 'Escribí o pegá el texto de la nota',
                        hintStyle: bodyStyle.copyWith(color: tertiary),
                      ),
                    ),
                  ],
                ),
              ),
              // Barra superior: volver y guardar, de vidrio como Inicio.
              Positioned(
                top: insets.top + 6,
                left: 12,
                child: _GlassCircleButton(
                  key: const ValueKey('noteEditorBack'),
                  icon: Icons.chevron_left_rounded,
                  iconSize: AppIcons.large,
                  tooltip: 'Volver',
                  color: primary,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Positioned(
                top: insets.top + 6,
                right: 12,
                child: _SaveButton(
                  enabled: _dirty && _bodyCtrl.text.trim().isNotEmpty,
                  onPressed: _save,
                ),
              ),
              // Barra de acciones flotante (sigue al teclado).
              Positioned(
                left: 0,
                right: 0,
                bottom: toolbarGap,
                child: Center(
                  child: GlassContainer(
                    key: const ValueKey('noteEditorToolbar'),
                    borderRadius: kBorderRadiusCapsule,
                    crystal: true,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: SizedBox(
                      height: _toolbarHeight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToolButton(
                            key: const ValueKey('noteEditorPasteButton'),
                            icon: Icons.content_paste_rounded,
                            tooltip: 'Pegar',
                            color: primary,
                            onPressed: _paste,
                          ),
                          _ToolButton(
                            key: const ValueKey('noteEditorCopyButton'),
                            icon: Icons.copy_rounded,
                            tooltip: 'Copiar texto',
                            color: primary,
                            onPressed: _copy,
                          ),
                          if (_geminiReady)
                            _ToolButton(
                              key: const ValueKey('geminiResumirButton'),
                              icon: Icons.summarize_outlined,
                              tooltip: 'Resumir con IA',
                              color: accent,
                              busy: _geminiBusy,
                              onPressed: _geminiBusy
                                  ? null
                                  : () => _runGemini('resumir'),
                            ),
                          if (note != null) ...[
                            _ToolbarDivider(color: tertiary),
                            _ToolButton(
                              key: const ValueKey('noteEditorDeleteButton'),
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Eliminar nota',
                              color: isDark ? kRecordingDark : kRecording,
                              onPressed: _delete,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón circular de vidrio de 44 dp (mismo que Configuración en Inicio).
class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  const _GlassCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.iconSize = AppIcons.medium,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: kBorderRadiusCapsule,
      crystal: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: iconSize, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// ✓ de guardar: círculo de acento cuando hay cambios; apagado si no.
class _SaveButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _SaveButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? kAccentDark : kAccentLight;
    final motionSafe = !MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Guardar',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Guardar',
        child: AnimatedContainer(
          key: const ValueKey('noteEditorSave'),
          duration:
              motionSafe ? const Duration(milliseconds: 200) : Duration.zero,
          curve: kCurveFade,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? accent : (isDark ? kFillDark : kFillLight),
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Icon(
                Icons.check_rounded,
                size: AppIcons.medium,
                color: enabled
                    ? Colors.white
                    : (isDark ? kLabelTertiaryDark : kLabelTertiaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Acción de la barra flotante: solo icono, 48 dp, nombre en tooltip y
/// para lectores de pantalla.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;
  final bool busy;

  const _ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 52, minHeight: 48),
      icon: busy
          ? SizedBox(
              width: AppIcons.small,
              height: AppIcons.small,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: AppIcons.medium, color: color),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  final Color color;

  const _ToolbarDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: color,
    );
  }
}
