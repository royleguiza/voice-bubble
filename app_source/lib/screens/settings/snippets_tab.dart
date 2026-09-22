import 'package:flutter/material.dart';

import '../../models/snippet.dart';
import '../../services/storage_service.dart';
import '../../ui/design_tokens.dart';
import '../../ui/glass_container.dart';
import '../../widgets/settings_v2.dart';

/// Tab Snippets de Ajustes (SPK-06, módulo 1 de N): CRUD de fragmentos
/// con su propio State, extraído de SettingsScreen sin cambiar conducta.
/// El árbol visible (Keys, textos) es idéntico: los tests de widgets
/// existentes lo verifican sin cambios.
class SnippetsTab extends StatefulWidget {
  final StorageService storageService;

  const SnippetsTab({
    super.key,
    required this.storageService,
  });

  @override
  State<SnippetsTab> createState() => _SnippetsTabState();
}

class _SnippetsTabState extends State<SnippetsTab> {
  List<Snippet> _snippets = [];
  String _query = '';
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
      });
    } catch (_) {}
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

  Future<void> _confirmDeleteSnippet(Snippet snippet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar snippet'),
        content: Text(
          '¿Eliminar "${snippet.nombre}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _reordering = true);
    try {
      await widget.storageService.deleteSnippet(snippet.id);
      await _reloadSnippets();
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? _snippets
        : _snippets
            .where((s) =>
                s.nombre.toLowerCase().contains(q) ||
                s.contenido.toLowerCase().contains(q))
            .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        const SettingsPageTitle('Snippets'),
        Row(
          children: [
            StatusPill(
              dotColor: isDark ? kAccentDark : kAccentLight,
              label: '${_snippets.length} / ${StorageService.maxSnippets}',
            ),
            const Spacer(),
            IconButton.filled(
              key: const ValueKey('snippets-add-button'),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Nuevo snippet',
              onPressed: () => _openSnippetSheet(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('snippets-search-field'),
          decoration: InputDecoration(
            hintText: 'Buscar snippets...',
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
          ),
          onChanged: (value) {
            if (mounted) setState(() => _query = value);
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Fragmentos que se insertan con un toque desde el teclado.',
          style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              q.isEmpty
                  ? 'Todavía no hay snippets. Toca + para crear el primero.'
                  : 'Sin resultados para "$_query".',
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++)
            _buildSnippetTile(visible[i], _snippets.indexOf(visible[i])),
      ],
    );
  }

  /// Tarjeta Variante C (lab snippets): título + swatch arriba, contenido
  /// al centro, acciones compactas al pie junto al meta. Fill teñido ~20% +
  /// stroke ~45% (token snippetPaletteStroke), radio kBorderRadiusCard.
  /// Sin muesca. Claves y tipo IconButton intactos (contrato K4).
  Widget _buildSnippetTile(Snippet snippet, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = snippetPaletteBase(snippet.color, isDark: isDark);
    final fill = snippetPaletteFill(snippet.color, isDark: isDark);
    final stroke = snippetPaletteStroke(snippet.color, isDark: isDark);
    final labelPrimary = isDark ? kLabelPrimaryDark : kLabelPrimaryLight;
    final labelSecondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final cardBase = theme.cardTheme.color ?? theme.cardColor;
    final canReorder = !_reordering;
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      color: fill != null ? Color.alphaBlend(fill, cardBase) : cardBase,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kBorderRadiusCard),
        side: stroke != null
            ? BorderSide(color: stroke, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (base != null) ...[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: base, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    snippet.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kSettingRowTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: labelPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              snippet.contenido,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: kTextCallout.copyWith(
                color: labelPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 0.5,
              color: theme.dividerColor,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '#${index + 1} · ${snippet.contenido.length} / '
                      '${StorageService.maxSnippetLength}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kTextMeta.copyWith(color: labelSecondary),
                    ),
                  ),
                  const Spacer(),
                  _snippetActionButton(
                    actionKey: 'snippet-up-${snippet.id}',
                    icon: Icons.arrow_upward_rounded,
                    tooltip: 'Subir ${snippet.nombre}',
                    enabled: canReorder && index > 0,
                    onPressed: () => _moveSnippet(snippet, -1),
                    labelSecondary: labelSecondary,
                  ),
                  _snippetActionButton(
                    actionKey: 'snippet-down-${snippet.id}',
                    icon: Icons.arrow_downward_rounded,
                    tooltip: 'Bajar ${snippet.nombre}',
                    enabled: canReorder && index < _snippets.length - 1,
                    onPressed: () => _moveSnippet(snippet, 1),
                    labelSecondary: labelSecondary,
                  ),
                  const SizedBox(width: 8),
                  _snippetActionButton(
                    actionKey: 'snippet-edit-${snippet.id}',
                    icon: Icons.edit_rounded,
                    tooltip: 'Editar ${snippet.nombre}',
                    enabled: true,
                    onPressed: () => _openSnippetSheet(existing: snippet),
                    labelSecondary: labelSecondary,
                  ),
                  const SizedBox(width: 4),
                  _snippetActionButton(
                    actionKey: 'snippet-delete-${snippet.id}',
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Eliminar ${snippet.nombre}',
                    enabled: canReorder,
                    onPressed: () => _confirmDeleteSnippet(snippet),
                    labelSecondary: labelSecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Botón de acción compacto de la tarjeta (glifo 18, caja 44 dp).
  /// Sin rojo: design.md §4 reserva el rojo para el estado grabando;
  /// el borrado se confirma en diálogo.
  Widget _snippetActionButton({
    required String actionKey,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
    required Color labelSecondary,
  }) {
    return IconButton(
      key: ValueKey(actionKey),
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      color: labelSecondary,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      onPressed: enabled ? onPressed : null,
    );
  }
}

class _SnippetFormSheet extends StatefulWidget {
  final Snippet? existing;
  final int maxContentLength;
  final int maxSnippets;
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
  });

  @override
  State<_SnippetFormSheet> createState() => _SnippetFormSheetState();
}

class _SnippetFormSheetState extends State<_SnippetFormSheet> {
  late final TextEditingController _nombreController;
  late final TextEditingController _contenidoController;
  // Contador de caracteres reactivo: antes onChanged hacía setState() y
  // reconstruía TODO el sheet (incluido el BackdropFilter blur del
  // GlassContainer) por cada carácter. Ahora solo se redibuja el contador.
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelSecondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassContainer(
        borderRadius: kBorderRadiusSheet,
        crystal: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isEditing ? 'Editar snippet' : 'Nuevo snippet',
              style: kTextTitle.copyWith(
                color: isDark ? kLabelPrimaryDark : kLabelPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('snippet-name-field'),
              controller: _nombreController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nombre',
                border: const OutlineInputBorder(),
                errorText: _nombreError,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('snippet-content-field'),
              controller: _contenidoController,
              keyboardType: TextInputType.multiline,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: 'Contenido',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                errorText: _contenidoError,
              ),
              onChanged: (value) {
                _contentLength.value = value.length;
              },
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: ValueListenableBuilder<int>(
                valueListenable: _contentLength,
                builder: (_, length, __) {
                  final overLimit = length > widget.maxContentLength;
                  return Text(
                    '$length / ${widget.maxContentLength}',
                    style: kTextCaption.copyWith(
                      color: overLimit
                          ? Theme.of(context).colorScheme.error
                          : labelSecondary,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Color',
              style: kSettingsGroupTitle.copyWith(color: labelSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
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
            if (_generalError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _generalError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  // Deshabilitado mientras se guarda para evitar
                  // dobles submits con read-modify-write concurrentes.
                  onPressed: _submitting ? null : _submit,
                  child: Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
                ),
              ],
            ),
          ],
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
    final fill = base == null
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : base!.withValues(alpha: selected ? 0.90 : 0.35);
    final stroke = base == null
        ? Theme.of(context).dividerColor
        : base!.withValues(alpha: selected ? 1.0 : 0.55);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: stroke,
                width: selected ? 2.5 : 1.25,
              ),
            ),
            child: selected && base != null
                ? Icon(Icons.check_rounded, size: 18, color: base)
                : null,
          ),
        ),
      ),
    );
  }
}
