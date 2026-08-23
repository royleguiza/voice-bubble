import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/storage_service.dart';
import '../services/floating_bubble_service.dart';
import '../services/keyboard_service.dart';

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
