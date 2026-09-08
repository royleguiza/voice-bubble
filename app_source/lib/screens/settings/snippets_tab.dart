import 'package:flutter/material.dart';

import '../../models/snippet.dart';
import '../../services/storage_service.dart';
import '../../ui/design_tokens.dart';
import '../../ui/glass_container.dart';

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
    final index = _snippets.indexWhere((s) => s.id == snippet.id);
    final target = index + delta;
    if (index == -1 || target < 0 || target >= _snippets.length) return;
    final reordered = [..._snippets];
    final item = reordered.removeAt(index);
    reordered.insert(target, item);
    await widget.storageService
        .reorderSnippets(reordered.map((s) => s.id).toList());
    await _reloadSnippets();
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
    await widget.storageService.deleteSnippet(snippet.id);
    await _reloadSnippets();
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
        onSubmit: ({required String nombre, required String contenido}) {
          if (existing == null) {
            return widget.storageService.addSnippet(
              nombre: nombre,
              contenido: contenido,
            );
          }
          return widget.storageService.updateSnippet(
            existing.id,
            nombre: nombre,
            contenido: contenido,
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Snippets',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${_snippets.length} / ${StorageService.maxSnippets}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Fragmentos que se insertan con un toque desde el teclado.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const ValueKey('snippets-add-button'),
            icon: const Icon(Icons.add),
            label: const Text('+ Nuevo snippet'),
            onPressed: () => _openSnippetSheet(),
          ),
        ),
        const SizedBox(height: 12),
        if (_snippets.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Todavía no hay snippets. Toca + para crear el primero.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          for (var i = 0; i < _snippets.length; i++)
            _buildSnippetTile(_snippets[i], i),
      ],
    );
  }

  Widget _buildSnippetTile(Snippet snippet, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snippet.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    snippet.contenido,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('snippet-up-${snippet.id}'),
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: 'Subir',
                  visualDensity: VisualDensity.compact,
                  onPressed:
                      index > 0 ? () => _moveSnippet(snippet, -1) : null,
                ),
                IconButton(
                  key: ValueKey('snippet-down-${snippet.id}'),
                  icon: const Icon(Icons.arrow_downward_rounded),
                  tooltip: 'Bajar',
                  visualDensity: VisualDensity.compact,
                  onPressed: index < _snippets.length - 1
                      ? () => _moveSnippet(snippet, 1)
                      : null,
                ),
              ],
            ),
            IconButton(
              key: ValueKey('snippet-edit-${snippet.id}'),
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Editar',
              onPressed: () => _openSnippetSheet(existing: snippet),
            ),
            IconButton(
              key: ValueKey('snippet-delete-${snippet.id}'),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Eliminar',
              onPressed: () => _confirmDeleteSnippet(snippet),
            ),
          ],
        ),
      ),
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
      saved = await widget.onSubmit(nombre: nombre, contenido: contenido);
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
        small: false,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
