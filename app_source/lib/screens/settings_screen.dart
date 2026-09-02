import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:record/record.dart';
import '../models/snippet.dart';
import '../services/storage_service.dart';
import '../services/floating_bubble_service.dart';
import '../services/keyboard_service.dart';
import '../ui/design_tokens.dart';
import '../ui/glass_container.dart';
import '../widgets/settings_tab_bar.dart';

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

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  int _currentTab = 0;
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
  String _heightProfile = StorageService.defaultHeightProfile;
  bool _hapticsEnabled = true;
  int _bottomElevationDp = StorageService.defaultBottomElevationDp;
  bool _invertToolbar = false;
  String _spacebarAlignment = StorageService.defaultSpacebarAlignment;
  List<Snippet> _snippets = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secureStorage = widget.secureStorage ?? const FlutterSecureStorage();
    _storageService = widget.storageService ?? StorageService();
    _floatingBubbleService =
        widget.floatingBubbleService ?? FloatingBubbleService();
    _keyboardService = widget.keyboardService ?? KeyboardService();
    _loadInitialState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureMicrophonePermission();
    });
  }

  /// Carga inicial de toda la pantalla: las lecturas corren en paralelo y
  /// aplican UN único setState al terminar (antes: ~10 encadenados al abrir
  /// Ajustes). Cada lectura captura su propio fallo de frontera de canal y
  /// conserva el valor por defecto del campo, para que un canal ausente o un
  /// keystore bloqueado no dejen la pantalla sin estado.
  Future<void> _loadInitialState() async {
    final apiKey = await _readStoredApiKey();
    final results = await (
      _storageService.loadRecordMode(),
      _readBubbleEnabled(),
      _readKeyboardStatus(),
      _loadInitialSnippets(),
      _storageService.loadKeyboardTerminalRowVisible(),
      _storageService.loadKeyboardCodeKeyVisible(),
      _storageService.loadKeyboardLanguageKeyVisible(),
      _storageService.getHeightProfile(),
      _storageService.getHapticsEnabled(),
    ).wait;
    final bottomElevation = await _storageService.getBottomElevationDp();
    final invertToolbar = await _storageService.getInvertToolbar();
    final spacebarAlign = await _storageService.getSpacebarAlignment();
    // Espejo D7: mantiene sincronizadas las credenciales del teclado nativo.
    if (apiKey.isNotEmpty) {
      try {
        await _storageService.saveSttMirror(apiKey: apiKey);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _apiKeyController.text = apiKey;
      _hasApiKey = apiKey.isNotEmpty;
      _recordMode = results.$1;
      _isBubbleEnabled = results.$2;
      _isKeyboardEnabled = results.$3.$1;
      _isKeyboardSelected = results.$3.$2;
      _snippets = results.$4..sort((a, b) => a.orden.compareTo(b.orden));
      _showTerminalRow = results.$5;
      _showCodeKey = results.$6;
      _showLanguageKey = results.$7;
      _heightProfile = results.$8;
      _hapticsEnabled = results.$9;
      _bottomElevationDp = bottomElevation;
      _invertToolbar = invertToolbar;
      _spacebarAlignment = spacebarAlign;
    });
  }

  /// Lee la API key del secure storage. Frontera de canal: el keystore de
  /// Android puede lanzar PlatformException (dispositivo recién restaurado o
  /// bloqueado); sin clave legible se muestra el campo vacío en vez de crashear.
  Future<String> _readStoredApiKey() async {
    try {
      return await _secureStorage.read(key: 'groq_api_key') ?? '';
    } catch (_) {
      return '';
    }
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
        maxContentLength: StorageService.maxSnippetLength,
        maxSnippets: StorageService.maxSnippets,
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

  Future<void> _toggleTerminalRow(bool visible) async {
    await _storageService.saveKeyboardTerminalRowVisible(visible);
    if (mounted) setState(() => _showTerminalRow = visible);
  }

  Future<void> _toggleKeyboardCodeKey(bool visible) async {
    await _storageService.saveKeyboardCodeKeyVisible(visible);
    if (mounted) setState(() => _showCodeKey = visible);
  }

  Future<void> _toggleKeyboardLanguageKey(bool visible) async {
    await _storageService.saveKeyboardLanguageKeyVisible(visible);
    if (mounted) setState(() => _showLanguageKey = visible);
  }

  Future<void> _saveHeightProfile(String profile) async {
    await _storageService.setHeightProfile(profile);
    if (mounted) setState(() => _heightProfile = profile);
  }

  Future<void> _saveBottomElevation(int dp) async {
    await _storageService.setBottomElevationDp(dp);
    if (mounted) setState(() => _bottomElevationDp = dp);
  }

  Future<void> _toggleInvertToolbar(bool invert) async {
    await _storageService.setInvertToolbar(invert);
    if (mounted) setState(() => _invertToolbar = invert);
  }

  Future<void> _saveSpacebarAlignment(String alignment) async {
    await _storageService.setSpacebarAlignment(alignment);
    if (mounted) setState(() => _spacebarAlignment = alignment);
  }

  String get _heightProfileHint {
    switch (_heightProfile) {
      case 'baja':
        return 'Teclas compactas para dejar más pantalla libre.';
      case 'alta':
        return 'Teclas más altas para dictar con menos errores.';
      case 'muy_alta':
        return 'Teclas extra altas para máxima comodidad y precisión.';
      default:
        return 'Altura equilibrada entre espacio y precisión.';
    }
  }

  Future<void> _toggleHaptics(bool enabled) async {
    await _storageService.setHapticsEnabled(enabled);
    if (mounted) setState(() => _hapticsEnabled = enabled);
  }

  /// Relectura manual (botón Actualizar) del estado del teclado.
  Future<void> _loadKeyboardStatus() async {
    final status = await _readKeyboardStatus();
    if (mounted) {
      setState(() {
        _isKeyboardEnabled = status.$1;
        _isKeyboardSelected = status.$2;
      });
    }
  }

  /// Preferencia + proceso vivo: la burbuja solo cuenta como activa si ambas.
  Future<bool> _readBubbleEnabled() async {
    try {
      final enabled = await _storageService.loadFloatingBubbleEnabled();
      final isRunning = await _floatingBubbleService.isBubbleRunning();
      return enabled && isRunning;
    } catch (_) {
      return false;
    }
  }

  /// Estado habilitado/seleccionado vía MethodChannel; defaults si el canal
  /// no está disponible (tests o servicio ausente).
  Future<(bool, bool)> _readKeyboardStatus() async {
    try {
      final enabled = await _keyboardService.isKeyboardEnabled();
      final selected = await _keyboardService.isKeyboardSelected();
      return (enabled, selected);
    } catch (_) {
      return (false, false);
    }
  }

  /// Seeds idempotentes + lectura inicial de snippets.
  Future<List<Snippet>> _loadInitialSnippets() async {
    try {
      await _storageService.ensureSeeds();
      return await _storageService.loadSnippets();
    } catch (_) {
      return const <Snippet>[];
    }
  }

  String get _keyboardStatusText {
    if (_isKeyboardEnabled && _isKeyboardSelected) return 'Activo';
    if (_isKeyboardEnabled) return 'Habilitado, falta seleccionarlo';
    return 'No habilitado';
  }

  Future<void> _openKeyboardSettings() async {
    await _keyboardService.openKeyboardSettings();
  }

  Future<void> _showInputMethodPicker() async {
    await _keyboardService.showInputMethodPicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  Future<void> _handleAppResumed() async {
    final wasEnabled = _isKeyboardEnabled;
    await _loadKeyboardStatus();
    // Si acaba de habilitar el teclado en ajustes del sistema, mostramos
    // el modal de inmediato para que lo active sin salir de la app.
    if (!wasEnabled && _isKeyboardEnabled && !_isKeyboardSelected) {
      await _showInputMethodPicker();
    }
  }

  Future<void> _ensureMicrophonePermission() async {
    try {
      final recorder = AudioRecorder();
      await recorder.hasPermission();
      recorder.dispose();
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

  Future<void> _saveRecordMode(String mode) async {
    await _storageService.saveRecordMode(mode);
    if (mounted) setState(() => _recordMode = mode);
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
    WidgetsBinding.instance.removeObserver(this);
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
      body: Stack(
        children: [
          IndexedStack(
            index: _currentTab,
            children: [
              _buildGeneralTab(context),
              _buildKeyboardTab(context),
              _buildSnippetsTab(context),
              _buildAboutTab(context),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SettingsTabBar(
              selectedIndex: _currentTab,
              onTabSelected: (index) {
                setState(() {
                  _currentTab = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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

        // Recording interaction mode
        Text(
          'Modo de grabación',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: StorageService.defaultRecordMode,
              label: Text('Toque'),
            ),
            ButtonSegment(
              value: StorageService.recordModeHold,
              label: Text('Mantener'),
            ),
          ],
          selected: {_recordMode},
          onSelectionChanged: (modes) => _saveRecordMode(modes.first),
        ),
        const SizedBox(height: 8),
        Text(
          _recordMode == StorageService.recordModeHold
              ? 'Mantén presionado para grabar y suelta para transcribir.'
              : 'Toca para iniciar y vuelve a tocar para transcribir.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),

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

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

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
      ],
    );
  }

  Widget _buildSpacebarAlignmentCards() {
    return Row(
      children: [
        Expanded(child: _buildMiniKbCard('left', 'Zurdo')),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniKbCard('center', 'Centro')),
        const SizedBox(width: 8),
        Expanded(child: _buildMiniKbCard('right', 'Diestro')),
      ],
    );
  }

  Widget _buildMiniKbCard(String id, String label) {
    final isSelected = _spacebarAlignment == id;
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => _saveSpacebarAlignment(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? colorScheme.primary.withValues(alpha: 0.1) 
              : colorScheme.surface,
          border: Border.all(
            color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildMiniKbRow(id, colorScheme),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniKbRow(String layout, ColorScheme colorScheme) {
    Widget miniKey(int flex, {bool isSpace = false}) {
      return Expanded(
        flex: flex,
        child: Container(
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSpace ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }

    List<Widget> keys;
    if (layout == 'left') {
      keys = [miniKey(1), miniKey(3, isSpace: true), miniKey(1), miniKey(1), miniKey(1)];
    } else if (layout == 'right') {
      keys = [miniKey(1), miniKey(1), miniKey(1), miniKey(3, isSpace: true), miniKey(1)];
    } else {
      // center
      keys = [miniKey(1), miniKey(1), miniKey(3, isSpace: true), miniKey(1), miniKey(1)];
    }

    return Row(children: keys);
  }

  Widget _buildKeyboardTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
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
                const SizedBox(height: 4),
                Text(
                  'Altura del teclado',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  key: const ValueKey('kb-height-profile-selector'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'baja', label: Text('Baja')),
                    ButtonSegment(value: 'media', label: Text('Media')),
                    ButtonSegment(value: 'alta', label: Text('Alta')),
                    ButtonSegment(value: 'muy_alta', label: Text('Muy alta')),
                  ],
                  selected: {_heightProfile},
                  onSelectionChanged: (profiles) =>
                      _saveHeightProfile(profiles.first),
                ),
                const SizedBox(height: 8),
                Text(
                  _heightProfileHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Barra Interactiva Superior',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Invertir disposición (Zurdo/Diestro)'),
                  subtitle: Text(
                    'El micrófono pasa a la izquierda y el portapapeles a la derecha.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: _invertToolbar,
                  onChanged: _toggleInvertToolbar,
                ),
                const SizedBox(height: 16),
                Text(
                  'Posición de la Barra Espaciadora',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                _buildSpacebarAlignmentCards(),
                const SizedBox(height: 16),
                Text(
                  'Elevación Inferior (Bottom Lift)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  key: const ValueKey('kb-bottom-elevation-selector'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 0, label: Text('0dp')),
                    ButtonSegment(value: 12, label: Text('12dp')),
                    ButtonSegment(value: 24, label: Text('24dp')),
                    ButtonSegment(value: 36, label: Text('36dp')),
                    ButtonSegment(value: 48, label: Text('48dp')),
                  ],
                  selected: {_bottomElevationDp},
                  onSelectionChanged: (dps) => _saveBottomElevation(dps.first),
                ),
                const SizedBox(height: 8),
                Text(
                  'Despega el teclado del borde inferior de la pantalla. Ideal para dispositivos con barra de gestos o biseles delgados.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vibración'),
                  subtitle: Text(
                    'Feedback háptico al tocar cada tecla.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  value: _hapticsEnabled,
                  onChanged: _toggleHaptics,
                ),
                const SizedBox(height: 12),
                if (!_isKeyboardEnabled) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Abrir ajustes del sistema'),
                    onPressed: _openKeyboardSettings,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paso 1: Activa "VoiceBubble STT" en Administrar teclados de Android. Al volver, la app te permitirá seleccionarlo inmediatamente sin salir.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ] else if (!_isKeyboardSelected) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.touch_app),
                    label: const Text('Seleccionar VoiceBubble como teclado'),
                    onPressed: _showInputMethodPicker,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paso 2: Toca para abrir el selector modal y activar VoiceBubble STT directamente sin salir de la app.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Abrir ajustes del sistema'),
                    onPressed: _openKeyboardSettings,
                  ),
                ] else ...[
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text('Teclado activo (toca para cambiar)'),
                    onPressed: _showInputMethodPicker,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'VoiceBubble está activo. Toca el botón para alternar rápidamente entre teclados sin salir de la app.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: const Text('Abrir ajustes del sistema'),
                    onPressed: _openKeyboardSettings,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnippetsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Snippets del teclado',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '${_snippets.length} / ${StorageService.maxSnippets}',
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
      ],
    );
  }

  Widget _buildAboutTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(
          'Acerca de',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VoiceBubble STT v0.1.0',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Transcripción de voz a texto con Groq Whisper.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
  bool _submitting = false;

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
