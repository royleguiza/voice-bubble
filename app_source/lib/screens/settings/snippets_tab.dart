import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/snippet.dart';
import '../../services/storage_service.dart';
import '../../ui/design_tokens.dart';
import '../../widgets/settings_v2.dart';

/// Página Snippets de Ajustes: buscador, lista agrupada (tocar = editar) y
/// modo "Ordenar" con flechas. El "+" vive en la barra de la página y llama
/// a [SnippetsTabState.openNewSnippet].
class SnippetsTab extends StatefulWidget {
  final StorageService storageService;

  const SnippetsTab({
    super.key,
    required this.storageService,
  });

  @override
  State<SnippetsTab> createState() => SnippetsTabState();
}

class SnippetsTabState extends State<SnippetsTab> {
  List<Snippet> _snippets = [];
  String _query = '';
  bool _loaded = false;
  bool _reorderMode = false;

  /// Bloquea ↑↓/borrar mientras una reordenación o borrado está en vuelo
  /// (evita doble tap concurrente sobre el mismo índice).
  bool _reordering = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  /// Seeds idempotentes + lectura inicial de snippets.
  Future<void> _loadInitial() async {
    try {
      await widget.storageService.ensureSeeds();
      final snippets = await widget.storageService.loadSnippets();
      if (!mounted) return;
      setState(() {
        _snippets = snippets..sort((a, b) => a.orden.compareTo(b.orden));
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _reloadSnippets() async {
    try {
      final snippets = await widget.storageService.loadSnippets();
      if (!mounted) return;
      setState(() {
        _snippets = snippets..sort((a, b) => a.orden.compareTo(b.orden));
      });
    } catch (_) {}
  }

  Future<void> _moveSnippet(Snippet snippet, int delta) async {
    if (_reordering) return;
    final index = _snippets.indexWhere((s) => s.id == snippet.id);
    final target = index + delta;
    if (index == -1 || target < 0 || target >= _snippets.length) return;
    setState(() => _reordering = true);
    final reordered = [..._snippets];
    final item = reordered.removeAt(index);
    reordered.insert(target, item);
    try {
      await widget.storageService
          .reorderSnippets(reordered.map((s) => s.id).toList());
      await _reloadSnippets();
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  /// Confirma y borra. Devuelve true si se borró.
  Future<bool> _confirmDeleteSnippet(Snippet snippet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar snippet'),
        content: Text(
          '¿Eliminar "${snippet.nombre}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('snippet-dialog-cancel-delete'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('snippet-dialog-confirm-delete'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    setState(() => _reordering = true);
    try {
      await widget.storageService.deleteSnippet(snippet.id);
      await _reloadSnippets();
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
    return true;
  }

  /// Abre el sheet de alta (lo llama el "+" de la barra).
  void openNewSnippet() => _openSnippetSheet();

  Future<void> _openSnippetSheet({Snippet? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: kScrimColor,
      builder: (_) => _SnippetFormSheet(
        existing: existing,
        maxContentLength: StorageService.maxSnippetLength,
        maxSnippets: StorageService.maxSnippets,
        onDelete: existing == null
            ? null
            : () => _confirmDeleteSnippet(existing),
        onSubmit: ({
          required String nombre,
          required String contenido,
          String? color,
          bool clearColor = false,
        }) {
          if (existing == null) {
            return widget.storageService.addSnippet(
              nombre: nombre,
              contenido: contenido,
              color: color,
            );
          }
          return widget.storageService.updateSnippet(
            existing.id,
            nombre: nombre,
            contenido: contenido,
            color: color,
            clearColor: clearColor,
          );
        },
      ),
    );
    if (saved == true) {
      await _reloadSnippets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? _snippets
        : _snippets
            .where((s) =>
                s.nombre.toLowerCase().contains(q) ||
                s.contenido.toLowerCase().contains(q))
            .toList();
    return ListView(
      key: const PageStorageKey<String>('snippets_tab_scroll'),
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        kSettingsGroupGap + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (_snippets.isNotEmpty) ...[
          _SearchField(
            onChanged: (value) {
              if (mounted) setState(() => _query = value);
            },
          ),
          const SizedBox(height: 20),
        ],
        if (_loaded && _snippets.isEmpty)
          SettingsEmptyState(
            icon: Icons.short_text_rounded,
            title: 'Sin snippets',
            message: 'Guardá textos que usás seguido y pegalos con un toque '
                'desde el teclado.',
            actionLabel: 'Crear snippet',
            actionKey: const ValueKey('snippets-empty-add'),
            onAction: _openSnippetSheet,
          )
        else if (visible.isEmpty && q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Text(
              'Sin resultados para "$_query".',
              textAlign: TextAlign.center,
              style: kTextSubhead.copyWith(color: p.secondary),
            ),
          )
        else if (visible.isNotEmpty) ...[
          SettingsSection(
            footer: '${_snippets.length} de ${StorageService.maxSnippets} · '
                'Se insertan con un toque desde el teclado.',
            children: [
              for (final s in visible)
                _SnippetRow(
                  snippet: s,
                  reorderMode: _reorderMode && q.isEmpty,
                  canMoveUp: !_reordering && _snippets.indexOf(s) > 0,
                  canMoveDown: !_reordering &&
                      _snippets.indexOf(s) < _snippets.length - 1,
                  onTap: () => _openSnippetSheet(existing: s),
                  onMoveUp: () => _moveSnippet(s, -1),
                  onMoveDown: () => _moveSnippet(s, 1),
                ),
            ],
          ),
          if (_snippets.length > 1 && q.isEmpty) ...[
            const SizedBox(height: kSettingsGroupGap),
            SettingsSection(
              children: [
                SettingsActionRow(
                  key: const ValueKey('snippets-reorder-button'),
                  title: _reorderMode ? 'Listo' : 'Ordenar',
                  onTap: () => setState(() => _reorderMode = !_reorderMode),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// Buscador en cápsula gris (estilo iOS).
class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: p.switchOff,
        borderRadius: BorderRadius.circular(kBorderRadiusCapsule),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: p.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              key: const ValueKey('snippets-search-field'),
              onChanged: onChanged,
              style: kTextBody.copyWith(color: p.label),
              decoration: InputDecoration(
                hintText: 'Buscar',
                hintStyle: kTextBody.copyWith(color: p.secondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de snippet: punto de color, nombre y vista previa de una línea.
/// En modo Ordenar muestra ↑↓ en lugar del chevron.
class _SnippetRow extends StatelessWidget {
  final Snippet snippet;
  final bool reorderMode;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onTap;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _SnippetRow({
    required this.snippet,
    required this.reorderMode,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onTap,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final dot = snippetPaletteBase(snippet.color, isDark: p.isDark);
    final preview = snippet.contenido.replaceAll('\n', ' ');
    return InkWell(
      key: ValueKey('snippet-edit-${snippet.id}'),
      onTap: reorderMode ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, reorderMode ? 4 : 16, 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dot ?? p.chevron,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  button: !reorderMode,
                  label: '${snippet.nombre}. $preview',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snippet.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTextBody.copyWith(color: p.label),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kTextSubhead.copyWith(color: p.secondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (reorderMode) ...[
                IconButton(
                  key: ValueKey('snippet-up-${snippet.id}'),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 22),
                  tooltip: 'Subir ${snippet.nombre}',
                  color: p.tintText,
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  onPressed: canMoveUp ? onMoveUp : null,
                ),
                IconButton(
                  key: ValueKey('snippet-down-${snippet.id}'),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 22),
                  tooltip: 'Bajar ${snippet.nombre}',
                  color: p.tintText,
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  onPressed: canMoveDown ? onMoveDown : null,
                ),
              ] else
                Icon(Icons.chevron_right_rounded, size: 22, color: p.chevron),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnippetFormSheet extends StatefulWidget {
  final Snippet? existing;
  final int maxContentLength;
  final int maxSnippets;
  final Future<bool> Function()? onDelete;
  final Future<bool> Function({
    required String nombre,
    required String contenido,
    String? color,
    bool clearColor,
  }) onSubmit;

  const _SnippetFormSheet({
    required this.existing,
    required this.maxContentLength,
    required this.maxSnippets,
    required this.onSubmit,
    this.onDelete,
  });

  @override
  State<_SnippetFormSheet> createState() => _SnippetFormSheetState();
}

class _SnippetFormSheetState extends State<_SnippetFormSheet> {
  late final TextEditingController _nombreController;
  late final TextEditingController _contenidoController;
  // Contador de caracteres reactivo: solo se redibuja el contador, no todo
  // el sheet, en cada carácter.
  late final ValueNotifier<int> _contentLength;
  String? _nombreError;
  String? _contenidoError;
  String? _generalError;
  bool _submitting = false;
  String? _color;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.existing?.nombre ?? '');
    _contenidoController =
        TextEditingController(text: widget.existing?.contenido ?? '');
    _contentLength =
        ValueNotifier<int>(_contenidoController.text.length);
    _color = widget.existing?.color;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _contenidoController.dispose();
    _contentLength.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final nombre = _nombreController.text.trim();
    final contenido = _contenidoController.text;
    final nombreError = nombre.isEmpty ? 'El nombre es obligatorio' : null;
    final contenidoError = contenido.length > widget.maxContentLength
        ? 'Máximo ${widget.maxContentLength} caracteres'
        : null;
    setState(() {
      _nombreError = nombreError;
      _contenidoError = contenidoError;
      _generalError = null;
    });
    if (nombreError != null || contenidoError != null) return;

    setState(() => _submitting = true);
    bool saved = false;
    try {
      final clearColor =
          _color == null && widget.existing?.color != null;
      saved = await widget.onSubmit(
        nombre: nombre,
        contenido: contenido,
        color: _color,
        clearColor: clearColor,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generalError = 'No se pudo guardar el snippet.';
      });
    } finally {
      if (mounted && !saved) {
        setState(() => _submitting = false);
      }
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      // Un false ya NO implica solo límite: también puede venir de una
      // lectura corrupta del storage (protección anti-pérdida de datos).
      _generalError ??= _isEditing
          ? 'No se pudo guardar el snippet.'
          : 'No se pudo guardar el snippet: Límite de ${widget.maxSnippets} '
              'snippets alcanzado o datos temporales no legibles.';
    });
  }

  Future<void> _delete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null) return;
    final deleted = await onDelete();
    if (deleted && mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final isDark = p.isDark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            8, 0, 8, 8 + MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.90,
          ),
          child: SettingsSheetFrame(
            title: _isEditing ? 'Editar snippet' : 'Nuevo snippet',
            closeKey: const ValueKey('snippet-cancel-button'),
            onClose: () => Navigator.of(context).pop(),
            saveKey: const ValueKey('snippet-save-button'),
            // Deshabilitado mientras se guarda para evitar dobles submits
            // con read-modify-write concurrentes.
            onSave: _submitting ? null : _submit,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SettingsSheetCard(
                        children: [
                          SettingsSheetField(
                            key: const ValueKey('snippet-name-field'),
                            label: 'Nombre',
                            hint: 'Ej. Firma',
                            controller: _nombreController,
                            textInputAction: TextInputAction.next,
                            errorText: _nombreError,
                          ),
                          SettingsSheetField(
                            key: const ValueKey('snippet-content-field'),
                            label: 'Texto',
                            hint: 'Lo que se va a insertar',
                            controller: _contenidoController,
                            minLines: 3,
                            maxLines: 6,
                            errorText: _contenidoError,
                            onChanged: (value) {
                              _contentLength.value = value.length;
                            },
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _contentLength,
                            builder: (_, length, __) {
                              final overLimit =
                                  length > widget.maxContentLength;
                              return Text(
                                '$length / ${widget.maxContentLength}',
                                style: kTextCaption.copyWith(
                                  color: overLimit
                                      ? Theme.of(context).colorScheme.error
                                      : p.secondary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Color',
                            style:
                                kSettingsSectionHeader.copyWith(color: p.label),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ColorSwatch(
                              key: const ValueKey('snippet-color-none'),
                              selected: _color == null,
                              base: null,
                              label: 'Sin color',
                              onTap: () => setState(() => _color = null),
                            ),
                            for (final id in kSnippetColorIds)
                              _ColorSwatch(
                                key: ValueKey('snippet-color-$id'),
                                selected: _color == id,
                                base: snippetPaletteBase(id, isDark: isDark),
                                label: id,
                                onTap: () => setState(() => _color = id),
                              ),
                          ],
                        ),
                      ),
                      if (_generalError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Text(
                            _generalError!,
                            style: kTextFootnote.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_isEditing && widget.onDelete != null) ...[
                        const SizedBox(height: 16),
                        SettingsSheetCard(
                          children: [
                            SettingsActionRow(
                              key: const ValueKey('snippet-delete-button'),
                              title: 'Eliminar snippet',
                              destructive: true,
                              onTap: _delete,
                            ),
                          ],
                        ),
                      ],
                    ],
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

/// Swatch circular de la paleta de snippets (6 ids + sin color).
class _ColorSwatch extends StatelessWidget {
  final bool selected;
  final Color? base;
  final String label;
  final VoidCallback onTap;

  const _ColorSwatch({
    super.key,
    required this.selected,
    required this.base,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final fill = base ?? p.switchOff;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? (base ?? p.secondary) : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: base == null
                    ? Icon(Icons.block_rounded, size: 18, color: p.secondary)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
