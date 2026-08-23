import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/snippet.dart';
import '../services/storage_service.dart';
import '../services/floating_bubble_service.dart';
import '../services/keyboard_service.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService? storageService;
  final FlutterSecureStorage? secureStorage;
  final FloatingBubbleService? floatingBubbleService;
  final KeyboardService? keyboardService;

  const SettingsScreen({
    super.key,
    this.storageService,
    this.secureStorage,
    this.floatingBubbleService,
    this.keyboardService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Limites del contrato de snippets (StorageService K4). Se duplican aqui
  // solo para mostrar el contador y validar en cliente antes de persistir;
  // la fuente de verdad sigue siendo StorageService.
  static const int _maxSnippets = 50;
  static const int _maxSnippetContentLength = 2000;

  final _apiKeyController = TextEditingController();
  late final FlutterSecureStorage _secureStorage;
  late final StorageService _storageService;
  late final FloatingBubbleService _floatingBubbleService;
  late final KeyboardService _keyboardService;

  bool _hasApiKey = false;
  String _recordMode = StorageService.defaultRecordMode;
  bool _isBubbleEnabled = false;
  bool _isKeyboardEnabled = false;
  bool _isKeyboardSelected = false;
  bool _showTerminalRow = true;
  bool _showCodeKey = true;
  bool _showLanguageKey = true;
  List<Snippet> _snippets = [];

  @override
  void initState() {
    super.initState();
    _secureStorage = widget.secureStorage ?? const FlutterSecureStorage();
    _storageService = widget.storageService ?? StorageService();
    _floatingBubbleService =
        widget.floatingBubbleService ?? FloatingBubbleService();
    _keyboardService = widget.keyboardService ?? KeyboardService();
    _loadApiKey();
    _loadRecordMode();
    _loadBubbleState();
    _loadKeyboardStatus();
    _loadTerminalRowVisible();
    _loadCodeKeyVisible();
    _loadLanguageKeyVisible();
    _initSnippets();
  }

  Future<void> _initSnippets() async {
    try {
      await _storageService.ensureSeeds();
      await _reloadSnippets();
    } catch (_) {}
  }

  Future<void> _reloadSnippets() async {
    try {
      final snippets = await _storageService.loadSnippets();
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
    await _storageService
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
    await _storageService.deleteSnippet(snippet.id);
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
        maxContentLength: _maxSnippetContentLength,
        maxSnippets: _maxSnippets,
        onSubmit: ({required String nombre, required String contenido}) {
          if (existing == null) {
            return _storageService.addSnippet(
              nombre: nombre,
              contenido: contenido,
            );
          }
          return _storageService.updateSnippet(
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

  Future<void> _loadTerminalRowVisible() async {
    try {
      final visible = await _storageService.loadKeyboardTerminalRowVisible();
      if (mounted) {
        setState(() => _showTerminalRow = visible);
      }
    } catch (_) {}
  }

  Future<void> _toggleTerminalRow(bool visible) async {
    await _storageService.saveKeyboardTerminalRowVisible(visible);
    if (mounted) setState(() => _showTerminalRow = visible);
  }

  Future<void> _loadCodeKeyVisible() async {
    try {
      final visible = await _storageService.loadKeyboardCodeKeyVisible();
      if (mounted) {
        setState(() => _showCodeKey = visible);
      }
    } catch (_) {}
  }

  Future<void> _toggleKeyboardCodeKey(bool visible) async {
    await _storageService.saveKeyboardCodeKeyVisible(visible);
    if (mounted) setState(() => _showCodeKey = visible);
  }

  Future<void> _loadLanguageKeyVisible() async {
    try {
      final visible = await _storageService.loadKeyboardLanguageKeyVisible();
      if (mounted) {
        setState(() => _showLanguageKey = visible);
      }
    } catch (_) {}
  }

  Future<void> _toggleKeyboardLanguageKey(bool visible) async {
    await _storageService.saveKeyboardLanguageKeyVisible(visible);
    if (mounted) setState(() => _showLanguageKey = visible);
  }

  Future<void> _loadKeyboardStatus() async {
    try {
      final enabled = await _keyboardService.isKeyboardEnabled();
      final selected = await _keyboardService.isKeyboardSelected();
      if (mounted) {
        setState(() {
          _isKeyboardEnabled = enabled;
          _isKeyboardSelected = selected;
        });
      }
    } catch (_) {}
  }

  String get _keyboardStatusText {
    if (_isKeyboardEnabled && _isKeyboardSelected) return 'Activo';
    if (_isKeyboardEnabled) return 'Habilitado, falta seleccionarlo';
    return 'No habilitado';
  }

  Future<void> _openKeyboardSettings() async {
    await _keyboardService.openKeyboardSettings();
  }

  Future<void> _loadBubbleState() async {
    try {
      final enabled = await _storageService.loadFloatingBubbleEnabled();
      final isRunning = await _floatingBubbleService.isBubbleRunning();
      if (mounted) {
        setState(() => _isBubbleEnabled = enabled && isRunning);
      }
    } catch (_) {}
  }

  Future<void> _toggleBubble(bool enable) async {
    if (enable) {
      final hasPermission = await _floatingBubbleService.canDrawOverlays();
      if (!hasPermission) {
        if (!mounted) return;
        final grant = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permiso de superposición'),
            content: const Text(
              'Para mostrar la burbuja sobre otras apps, VoiceBubble necesita el permiso de mostrar sobre otras aplicaciones.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Configurar'),
              ),
            ],
          ),
        );
        if (grant == true) {
          await _floatingBubbleService.requestOverlayPermission();
        }
        return;
      }
      final started = await _floatingBubbleService.startBubble();
      if (started) {
        await _storageService.saveFloatingBubbleEnabled(true);
        if (mounted) setState(() => _isBubbleEnabled = true);
      }
    } else {
      await _floatingBubbleService.stopBubble();
      await _storageService.saveFloatingBubbleEnabled(false);
      if (mounted) setState(() => _isBubbleEnabled = false);
    }
  }

  Future<void> _loadRecordMode() async {
    try {
      final mode = await _storageService.loadRecordMode();
      if (mounted) setState(() => _recordMode = mode);
    } catch (_) {}
  }

  Future<void> _saveRecordMode(String mode) async {
    await _storageService.saveRecordMode(mode);
    if (mounted) setState(() => _recordMode = mode);
  }

  Future<void> _loadApiKey() async {
    final key = await _secureStorage.read(key: 'groq_api_key') ?? '';
    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _hasApiKey = key.isNotEmpty;
      });
    }
    // Espejo D7: mantiene sincronizadas las credenciales del teclado nativo.
    if (key.isNotEmpty) {
      try {
        await _storageService.saveSttMirror(apiKey: key);
      } catch (_) {}
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await _secureStorage.write(key: 'groq_api_key', value: key);
    if (key.isNotEmpty) {
      await _storageService.saveSttMirror(apiKey: key);
    } else {
      await _storageService.clearSttMirror();
    }
    if (mounted) {
      setState(() => _hasApiKey = key.isNotEmpty);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key guardada')),
      );
    }
  }

  Future<void> _clearApiKey() async {
    await _secureStorage.delete(key: 'groq_api_key');
    await _storageService.clearSttMirror();
    if (mounted) {
      _apiKeyController.clear();
      setState(() => _hasApiKey = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key eliminada')),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Floating Bubble section
          Text(
            'Burbuja flotante',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activar burbuja flotante'),
            subtitle: const Text(
              'Flota sobre otras aplicaciones para transcribir y copiar texto al instante.',
            ),
            value: _isBubbleEnabled,
            onChanged: _toggleBubble,
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Keyboard section
          Text(
            'Teclado VoiceBubble',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.keyboard,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _keyboardStatusText,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadKeyboardStatus,
                        tooltip: 'Actualizar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usa VoiceBubble como teclado del sistema en cualquier app.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fila terminal'),
                    subtitle: Text(
                      'TAB, ESC, CTRL, ALT y flechas sobre las letras. '
                      'Desactívala si usás Termux, que ya trae teclas propias.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    value: _showTerminalRow,
                    onChanged: _toggleTerminalRow,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tecla de capa código'),
                    subtitle: Text(
                      'La tecla </> abre los símbolos de programación. '
                      'Desactívala para liberar espacio en la barra inferior.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    value: _showCodeKey,
                    onChanged: _toggleKeyboardCodeKey,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tecla de idioma'),
                    subtitle: Text(
                      'El botón ES/EN junto a la barra espaciadora. '
                      'Desactívala si dictás en un solo idioma.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    value: _showLanguageKey,
                    onChanged: _toggleKeyboardLanguageKey,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Abrir ajustes del sistema'),
                    onPressed: _openKeyboardSettings,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guía: activa "VoiceBubble Keyboard" en Administrar teclados y luego selecciónalo al escribir.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),

          // Snippets del teclado (K4): CRUD + reorden desde Ajustes.
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Snippets del teclado',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${_snippets.length} / $_maxSnippets',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              IconButton(
                key: const ValueKey('snippets-add-button'),
                icon: const Icon(Icons.add),
                tooltip: 'Agregar snippet',
                onPressed: () => _openSnippetSheet(),
              ),
            ],
          ),
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

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // API Key section
          Text(
            'API Key de Groq',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Necesaria para el modo Cloud. Obtén tu clave en console.groq.com',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'gsk_...',
                    border: const OutlineInputBorder(),
                    suffixIcon: _hasApiKey
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveApiKey,
                tooltip: 'Guardar',
              ),
              if (_hasApiKey)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clearApiKey,
                  tooltip: 'Borrar',
                ),
            ],
          ),

          const SizedBox(height: 32),

          // Transcription model section
          Text(
            'Modelo de transcripcion',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Modo Cloud',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          'Groq Whisper Large V3 (whisper-large-v3)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Recording interaction mode
          Text(
            'Modo de grabación',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'tap', label: Text('Toque')),
              ButtonSegment(value: 'hold', label: Text('Mantener')),
            ],
            selected: {_recordMode},
            onSelectionChanged: (modes) => _saveRecordMode(modes.first),
          ),
          const SizedBox(height: 8),
          Text(
            _recordMode == 'hold'
                ? 'Mantén presionado para grabar y suelta para transcribir.'
                : 'Toca para iniciar y vuelve a tocar para transcribir.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),

          const SizedBox(height: 32),

          // About section
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Acerca de',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'VoiceBubble STT v0.1.0',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Transcripción de voz a texto con Groq Whisper.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
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
  String? _nombreError;
  String? _contenidoError;
  String? _generalError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.existing?.nombre ?? '');
    _contenidoController =
        TextEditingController(text: widget.existing?.contenido ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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

    // La validación local ya pasó: un false aqui solo puede venir del
    // límite de 50 snippets (creación) o de un id inexistente (edición).
    final saved = await widget.onSubmit(nombre: nombre, contenido: contenido);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _generalError = _isEditing
          ? 'No se pudo guardar el snippet.'
          : 'Límite de ${widget.maxSnippets} snippets alcanzado. '
              'Elimina alguno para crear otro.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelSecondary = isDark ? kLabelSecondaryDark : kLabelSecondaryLight;
    final length = _contenidoController.text.length;
    final overLimit = length > widget.maxContentLength;

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
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$length / ${widget.maxContentLength}',
                style: kTextCaption.copyWith(
                  color: overLimit
                      ? Theme.of(context).colorScheme.error
                      : labelSecondary,
                ),
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
                  onPressed: _submit,
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
