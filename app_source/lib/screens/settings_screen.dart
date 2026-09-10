import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:record/record.dart';
import 'credentials_screen.dart';
import 'settings/general_tab.dart';
import 'settings/snippets_tab.dart';
import 'settings/teclado_tab.dart';
import 'settings/trackpad_tab.dart';
import '../services/storage_service.dart';
import '../ui/theme_mode.dart';
import '../services/floating_bubble_service.dart';
import '../services/floating_trackpad_service.dart';
import '../services/keyboard_service.dart';
import '../ui/debouncer.dart';
import '../widgets/settings_tab_bar.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService? storageService;
  final FlutterSecureStorage? secureStorage;
  final FloatingBubbleService? floatingBubbleService;
  final FloatingTrackpadService? floatingTrackpadService;
  final KeyboardService? keyboardService;

  const SettingsScreen({
    super.key,
    this.storageService,
    this.secureStorage,
    this.floatingBubbleService,
    this.floatingTrackpadService,
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
  late final FloatingTrackpadService _floatingTrackpadService;
  late final KeyboardService _keyboardService;

  bool _hasApiKey = false;
  bool _isEditingApiKey = false;
  String? _apiKeyError;
  bool _showApiDetail = false;
  String _recordMode = StorageService.defaultRecordMode;
  bool _isBubbleEnabled = false;
  bool _showBubbleHistory = true;
  bool _isKeyboardEnabled = false;
  bool _isKeyboardSelected = false;
  bool _showTerminalRow = true;
  bool _showCodeKey = true;
  bool _showLanguageKey = true;
  bool _clipboardImagesEnabled = false;
  String _heightProfile = StorageService.defaultHeightProfile;
  String _keySpacing = StorageService.defaultKeySpacing;
  bool _hapticsEnabled = true;
  String _hapticStyle = StorageService.defaultHapticStyle;
  int _bottomElevationDp = StorageService.defaultBottomElevationDp;
  bool _invertToolbar = false;
  String _spacebarAlignment = StorageService.defaultSpacebarAlignment;
  String _spacebarTrackpadMode = StorageService.defaultSpacebarTrackpadMode;
  bool _trackpadEnabled = StorageService.defaultTrackpadEnabled;
  bool _trackpadToolbarVisible = StorageService.defaultTrackpadToolbarVisible;
  String _trackpadButtonLayout = StorageService.defaultTrackpadButtonLayout;
  String _trackpadScrollPosition = StorageService.defaultTrackpadScrollPosition;
  double _trackpadSensitivity = StorageService.defaultTrackpadSensitivity;
  String _trackpadAccelCurve = StorageService.defaultTrackpadAccelCurve;
  bool _trackpadTapToClick = StorageService.defaultTrackpadTapToClick;
  String _trackpadSecondaryClick = StorageService.defaultTrackpadSecondaryClick;
  String _trackpadScrollDirection = StorageService.defaultTrackpadScrollDirection;
  String _trackpadHaptic = StorageService.defaultTrackpadHaptic;
  String _trackpadPointerStyle = StorageService.defaultTrackpadPointerStyle;
  int _trackpadAutoReturn = StorageService.defaultTrackpadAutoReturn;
  String _themeMode = StorageService.defaultThemeMode;

  /// Tabs ya visitados: la pila es perezosa (solo construye lo visitado)
  /// pero conserva el estado (lo visitado nunca se desmonta).
  final Set<int> _builtTabs = {0};

  /// Debouncers por slider para persistencia (prefs + canal nativo).
  /// El thumb hace setState inmediato; solo el guardado se difiere 150 ms.
  final Map<String, Debouncer> _sliderDebouncers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _secureStorage = widget.secureStorage ?? StorageService.espSecureStorage;
    _storageService = widget.storageService ?? StorageService();
    _floatingBubbleService =
        widget.floatingBubbleService ?? FloatingBubbleService();
    _floatingTrackpadService =
        widget.floatingTrackpadService ?? FloatingTrackpadService();
    _keyboardService = widget.keyboardService ?? KeyboardService();
    _loadInitialState();
    // Sin petición de mic al abrir Ajustes: hasPermission() dispara el
    // prompt del sistema y molesta sin motivo. Se pide solo en intención
    // explícita de usar el mic (activar la burbuja, ver _toggleBubble).
  }

  /// Persistencia diferida de sliders: crea o reutiliza un Debouncer por
  /// clave para no cancelar guardados de sliders distintos entre sí.
  void _persistSliderDebounced(
      String key, Future<void> Function() persist) {
    final debouncer =
        _sliderDebouncers.putIfAbsent(key, () => Debouncer());
    debouncer.run(persist);
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
      _storageService.loadKeyboardTerminalRowVisible(),
      _storageService.loadKeyboardCodeKeyVisible(),
      _storageService.loadKeyboardLanguageKeyVisible(),
      _storageService.getHeightProfile(),
      _storageService.getKeySpacing(),
      _storageService.getHapticsEnabled(),
    ).wait;
    // Fuera del record .wait (límite de aridad del SDK): carga aparte.
    final hapticStyle = await _storageService.getHapticStyle();
    final bottomElevation = await _storageService.getBottomElevationDp();
    final invertToolbar = await _storageService.getInvertToolbar();
    final spacebarAlign = await _storageService.getSpacebarAlignment();
    final spacebarTrackpadMode = await _storageService.getSpacebarTrackpadMode();
    final trackpadEnabled = await _storageService.getTrackpadEnabled();
    final trackpadToolbarVisible = await _storageService.getTrackpadToolbarVisible();
    final trackpadButtonLayout = await _storageService.getTrackpadButtonLayout();
    final trackpadScrollPosition = await _storageService.getTrackpadScrollPosition();
    final trackpadSensitivity = await _storageService.getTrackpadSensitivity();
    final trackpadAccelCurve = await _storageService.getTrackpadAccelCurve();
    final trackpadTapToClick = await _storageService.getTrackpadTapToClick();
    final trackpadSecondaryClick = await _storageService.getTrackpadSecondaryClick();
    final trackpadScrollDirection = await _storageService.getTrackpadScrollDirection();
    final trackpadHaptic = await _storageService.getTrackpadHaptic();
    final trackpadPointerStyle = await _storageService.getTrackpadPointerStyle();
    final trackpadAutoReturn = await _storageService.getTrackpadAutoReturn();
    final bubbleHistory = await _storageService.loadBubbleHistoryEnabled();
    final clipboardImages = await _storageService.getClipboardImagesEnabled();
    final themeMode = await _storageService.loadThemeMode();
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
      _isEditingApiKey = false;
      _apiKeyError = null;
      _showApiDetail = false;
      _recordMode = results.$1;
      _isBubbleEnabled = results.$2;
      _isKeyboardEnabled = results.$3.$1;
      _isKeyboardSelected = results.$3.$2;
      _showTerminalRow = results.$4;
      _showCodeKey = results.$5;
      _showLanguageKey = results.$6;
      _heightProfile = results.$7;
      _keySpacing = results.$8;
      _hapticsEnabled = results.$9;
      _hapticStyle = hapticStyle;
      _bottomElevationDp = bottomElevation;
      _invertToolbar = invertToolbar;
      _spacebarAlignment = spacebarAlign;
      _spacebarTrackpadMode = spacebarTrackpadMode;
      _trackpadEnabled = trackpadEnabled;
      _trackpadToolbarVisible = trackpadToolbarVisible;
      _trackpadButtonLayout = trackpadButtonLayout;
      _trackpadScrollPosition = trackpadScrollPosition;
      _trackpadSensitivity = trackpadSensitivity;
      _trackpadAccelCurve = trackpadAccelCurve;
      _trackpadTapToClick = trackpadTapToClick;
      _trackpadSecondaryClick = trackpadSecondaryClick;
      _trackpadScrollDirection = trackpadScrollDirection;
      _trackpadHaptic = trackpadHaptic;
      _trackpadPointerStyle = trackpadPointerStyle;
      _trackpadAutoReturn = trackpadAutoReturn;
      _showBubbleHistory = bubbleHistory;
      _clipboardImagesEnabled = clipboardImages;
      _themeMode = themeMode;
    });
  }

  /// Modal de historial de la burbuja clásica (hito B1–B7): el toque largo
  /// la abre solo con el switch ON (aplica al abrir la próxima vez, la
  /// modal lee la preferencia en vivo desde el nativo).
  Future<void> _toggleBubbleHistory(bool enabled) async {
    try {
      await _storageService.saveBubbleHistoryEnabled(enabled);
    } catch (_) {}
    if (mounted) setState(() => _showBubbleHistory = enabled);
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

  Future<void> _toggleClipboardImages(bool enabled) async {
    await _storageService.setClipboardImagesEnabled(enabled);
    if (mounted) setState(() => _clipboardImagesEnabled = enabled);
  }

  Future<void> _saveHeightProfile(String profile) async {
    await _storageService.setHeightProfile(profile);
    if (mounted) setState(() => _heightProfile = profile);
  }

  Future<void> _saveKeySpacing(String spacing) async {
    await _storageService.setKeySpacing(spacing);
    if (mounted) setState(() => _keySpacing = spacing);
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

  Future<void> _saveSpacebarTrackpadMode(String mode) async {
    await _storageService.setSpacebarTrackpadMode(mode);
    if (mounted) setState(() => _spacebarTrackpadMode = mode);
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

  String get _keySpacingHint {
    switch (_keySpacing) {
      case 'compacto':
        return 'Teclas más juntas para pantallas chicas.';
      case 'amplio':
        return 'Más aire entre teclas para evitar pulsaciones vecinas.';
      case 'extra':
        return 'Separación máxima: teclas bien aisladas contra toques falsos.';
      default:
        return 'Separación equilibrada entre teclas.';
    }
  }

  Future<void> _toggleHaptics(bool enabled) async {
    await _storageService.setHapticsEnabled(enabled);
    if (mounted) setState(() => _hapticsEnabled = enabled);
  }

  Future<void> _saveHapticStyle(String style) async {
    await _storageService.setHapticStyle(style);
    if (mounted) setState(() => _hapticStyle = style);
  }

  String get _hapticStyleHint {
    switch (_hapticStyle) {
      case 'nitido':
        return 'Clic seco y corto, como botón físico.';
      case 'suave':
        return 'Toque leve y discreto.';
      default:
        return 'Vibración marcada al pulsar.';
    }
  }

  Future<void> _toggleTrackpadEnabled(bool value) async {
    setState(() => _trackpadEnabled = value);
    await _storageService.setTrackpadEnabled(value);
    // La burbuja overlay del trackpad se gobierna desde este toggle (antes
    // el servicio Dart no tenía ningún llamador). Best-effort sin diálogos:
    // sin permiso de overlay el nativo devuelve false y la pref sigue
    // siendo la fuente de verdad que lee el teclado.
    try {
      if (value) {
        await _floatingTrackpadService.startTrackpadBubble();
      } else {
        await _floatingTrackpadService.stopTrackpadBubble();
      }
    } catch (_) {}
  }

  Future<void> _toggleTrackpadToolbarVisible(bool value) async {
    setState(() => _trackpadToolbarVisible = value);
    await _storageService.setTrackpadToolbarVisible(value);
  }

  Future<void> _saveTrackpadButtonLayout(String value) async {
    setState(() => _trackpadButtonLayout = value);
    await _storageService.setTrackpadButtonLayout(value);
  }

  Future<void> _saveTrackpadScrollPosition(String value) async {
    setState(() => _trackpadScrollPosition = value);
    await _storageService.setTrackpadScrollPosition(value);
  }

  /// Entrada del slider de sensibilidad: estado local inmediato (thumb
  /// sin lag) + persistencia diferida 150 ms (helper reutilizable).
  void _onTrackpadSensitivitySlider(double value) {
    setState(() => _trackpadSensitivity = value);
    _persistSliderDebounced(
        'trackpadSensitivity',
        () => _storageService.setTrackpadSensitivity(value));
  }

  Future<void> _saveTrackpadAccelCurve(String value) async {
    setState(() => _trackpadAccelCurve = value);
    await _storageService.setTrackpadAccelCurve(value);
  }

  Future<void> _toggleTrackpadTapToClick(bool value) async {
    setState(() => _trackpadTapToClick = value);
    await _storageService.setTrackpadTapToClick(value);
  }

  Future<void> _saveTrackpadSecondaryClick(String value) async {
    setState(() => _trackpadSecondaryClick = value);
    await _storageService.setTrackpadSecondaryClick(value);
  }

  Future<void> _saveTrackpadScrollDirection(String value) async {
    setState(() => _trackpadScrollDirection = value);
    await _storageService.setTrackpadScrollDirection(value);
  }

  Future<void> _saveTrackpadHaptic(String value) async {
    setState(() => _trackpadHaptic = value);
    await _storageService.setTrackpadHaptic(value);
  }

  Future<void> _saveTrackpadPointerStyle(String value) async {
    setState(() => _trackpadPointerStyle = value);
    await _storageService.setTrackpadPointerStyle(value);
  }

  Future<void> _saveTrackpadAutoReturn(int value) async {
    setState(() => _trackpadAutoReturn = value);
    await _storageService.setTrackpadAutoReturn(value);
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

  Future<void> _saveThemeMode(String mode) async {
    await _storageService.saveThemeMode(mode);
    appThemeMode.value = themeModeFromStorage(mode);
    if (mounted) setState(() => _themeMode = mode);
  }

  /// Acerca de fuera del dock (prototipo v1): sheet informativo invocado
  /// desde General. Preserva textos de contrato (versión + descripción).
  Future<void> _showAboutSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var sheetThemeMode = _themeMode;
        return StatefulBuilder(
          builder: (modalContext, setModalState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mic_rounded,
                        color: Theme.of(modalContext).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'VoiceBubble STT v1.0.0',
                          style:
                              Theme.of(modalContext).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Cerrar',
                        onPressed: () =>
                            Navigator.of(modalContext).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Transcripción de voz a texto con Groq Whisper.',
                    style: Theme.of(modalContext)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(modalContext)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Burbuja flotante + teclado del sistema con dictado. '
                    'Historial de 20 transcripciones. Sin analytics, sin telemetría. '
                    'El audio solo viaja a internet cuando tú inicias una transcripción.',
                    style: Theme.of(modalContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'El teclado jamás registra ni guarda lo que escribes. '
                    'Sin dictado ni snippets en campos de contraseña.',
                    style: Theme.of(modalContext)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(modalContext)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Apariencia',
                    style:
                        Theme.of(modalContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    key: const ValueKey('about-theme-selector'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: 'sistema', label: Text('Sistema')),
                      ButtonSegment(
                          value: 'claro', label: Text('Claro')),
                      ButtonSegment(
                          value: 'oscuro', label: Text('Oscuro')),
                    ],
                    selected: {sheetThemeMode},
                    onSelectionChanged: (modes) {
                      setModalState(
                          () => sheetThemeMode = modes.first);
                      _saveThemeMode(modes.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(modalContext).pop(),
                      child: const Text('Entendido'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Revisión manual del permiso de overlay desde la sección Burbuja.
  /// Reutiliza el flujo de _toggleBubble: abre el ajuste del sistema y,
  /// al volver con permiso concedido, arranca la burbuja en un solo gesto.
  Future<void> _reviewOverlayPermission() async {
    bool hasPermission = false;
    try {
      hasPermission = await _floatingBubbleService.canDrawOverlays();
    } catch (_) {
      hasPermission = false;
    }
    if (hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de superposición concedido')),
        );
      }
      return;
    }
    try {
      await _floatingBubbleService.requestOverlayPermission();
    } catch (_) {}
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
      await recorder.dispose();
    } catch (_) {}
  }

  Future<void> _toggleBubble(bool enable) async {
    if (enable) {
      // Intención explícita de usar el mic (la burbuja graba): aquí SÍ se
      // puede pedir el permiso, nunca al abrir Ajustes (ver initState).
      unawaited(_ensureMicrophonePermission());
      bool hasPermission = false;
      try {
        hasPermission = await _floatingBubbleService.canDrawOverlays();
      } catch (_) {
        hasPermission = false;
      }
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
        if (grant != true) return;
        try {
          await _floatingBubbleService.requestOverlayPermission();
        } catch (_) {}
        // Un solo gesto: al volver del ajuste del sistema se relee el
        // permiso y, si ya está concedido, se arranca + guarda + setState
        // sin exigir un segundo toque. Antes se retornaba aquí.
        try {
          hasPermission = await _floatingBubbleService.canDrawOverlays();
        } catch (_) {
          hasPermission = false;
        }
        if (!hasPermission) return;
      }
      bool started = false;
      try {
        started = await _floatingBubbleService.startBubble();
      } catch (_) {
        started = false;
      }
      if (started) {
        try {
          await _storageService.saveFloatingBubbleEnabled(true);
        } catch (_) {}
        if (mounted) setState(() => _isBubbleEnabled = true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudo activar la burbuja flotante')),
        );
      }
    } else {
      try {
        await _floatingBubbleService.stopBubble();
      } catch (_) {}
      try {
        await _storageService.saveFloatingBubbleEnabled(false);
      } catch (_) {}
      if (mounted) setState(() => _isBubbleEnabled = false);
    }
  }

  Future<void> _saveRecordMode(String mode) async {
    await _storageService.saveRecordMode(mode);
    if (mounted) setState(() => _recordMode = mode);
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    // Validación visible (paridad con prototipo laboratorio-ui v1):
    // vacía, incompleta (<10) o sin prefijo gsk_.
    String? error;
    if (key.isEmpty) {
      error = 'Pega tu API Key para continuar.';
    } else if (key.length < 10) {
      error = 'Parece incompleta: revisa que la copiaste entera.';
    } else if (!key.startsWith('gsk_')) {
      error = 'Formato inesperado: las claves de Groq empiezan con gsk_.';
    }
    if (error != null) {
      if (mounted) setState(() => _apiKeyError = error);
      return;
    }
    try {
      await _secureStorage.write(key: 'groq_api_key', value: key);
      if (key.isNotEmpty) {
        await _storageService.saveSttMirror(apiKey: key);
      } else {
        await _storageService.clearSttMirror();
      }
    } catch (_) {
      // Keystore bloqueado / prefs caído: SnackBar, nunca pantalla roja.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la API key')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _hasApiKey = key.isNotEmpty;
      _isEditingApiKey = false;
      _apiKeyError = null;
      _showApiDetail = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key guardada')),
    );
  }

  void _startApiEdit() {
    if (mounted) {
      setState(() {
        _isEditingApiKey = true;
        _apiKeyError = null;
        _showApiDetail = false;
      });
    }
  }

  void _cancelApiEdit() {
    if (mounted) {
      setState(() {
        _isEditingApiKey = false;
        _apiKeyError = null;
      });
    }
  }

  /// Cola visible de la key para el botón verde (últimos 4, resto oculto).
  /// Nunca expone la key completa en UI.
  String get _apiKeyTail {
    final text = _apiKeyController.text.trim();
    if (text.length < 4) return '••••';
    return '••••${text.substring(text.length - 4)}';
  }

  Future<void> _clearApiKey() async {
    try {
      await _secureStorage.delete(key: 'groq_api_key');
      await _storageService.clearSttMirror();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la API key')),
      );
      return;
    }
    if (!mounted) return;
    _apiKeyController.clear();
    setState(() {
      _hasApiKey = false;
      _isEditingApiKey = false;
      _apiKeyError = null;
      _showApiDetail = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API key eliminada')),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiKeyController.dispose();
    for (final debouncer in _sliderDebouncers.values) {
      debouncer.dispose();
    }
    _sliderDebouncers.clear();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _currentTab = index;
      _builtTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // Construcción perezosa por tab con estado preservado: solo los
            // tabs visitados se construyen (antes IndexedStack montaba todo
            // con sus ~10 lecturas iniciales), y lo visitado nunca se
            // desmonta, así que inputs y scrolls sobreviven al cambio de tab.
            // Estructura v2 (laboratorio_ui/settings-redesign-v2.html):
            // General (Inicio+Burbuja) / Teclado / Trackpad / Snippets /
            // Claves. Acerca vive como sheet desde General.
            IndexedStack(
              index: _currentTab,
              children: [
                _builtTabs.contains(0)
                    ? _buildGeneralTab(context)
                    : const SizedBox.shrink(),
                _builtTabs.contains(1)
                    ? _buildKeyboardTab(context)
                    : const SizedBox.shrink(),
                _builtTabs.contains(2)
                    ? _buildTrackpadTab(context)
                    : const SizedBox.shrink(),
                _builtTabs.contains(3)
                    ? _buildSnippetsTab(context)
                    : const SizedBox.shrink(),
                _builtTabs.contains(4)
                    ? CredentialsScreen(
                        storageService: _storageService,
                        onSelectTab: _selectTab,
                      )
                    : const SizedBox.shrink(),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SettingsTabBar(
                selectedIndex: _currentTab,
                onTabSelected: _selectTab,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// General v2 (rediseño): API Key + grabación + modelo + burbuja +
  /// acerca. Fusiona Inicio y Burbuja en una superficie agrupada.
  Widget _buildGeneralTab(BuildContext context) {
    return GeneralTab(
      hasApiKey: _hasApiKey,
      isEditingApiKey: _isEditingApiKey,
      apiKeyController: _apiKeyController,
      apiKeyError: _apiKeyError,
      showApiDetail: _showApiDetail,
      apiKeyTail: _apiKeyTail,
      onStartApiEdit: _startApiEdit,
      onCancelApiEdit: _cancelApiEdit,
      onSaveApiKey: _saveApiKey,
      onClearApiKey: _clearApiKey,
      onToggleApiDetail: () {
        if (mounted) {
          setState(() => _showApiDetail = !_showApiDetail);
        }
      },
      recordMode: _recordMode,
      onSaveRecordMode: _saveRecordMode,
      isBubbleEnabled: _isBubbleEnabled,
      onToggleBubble: _toggleBubble,
      showBubbleHistory: _showBubbleHistory,
      onToggleBubbleHistory: _toggleBubbleHistory,
      onReviewOverlayPermission: _reviewOverlayPermission,
      onShowAboutSheet: _showAboutSheet,
    );
  }


  Widget _buildKeyboardTab(BuildContext context) {
    return TecladoTab(
      keyboardStatusText: _keyboardStatusText,
      onLoadKeyboardStatus: _loadKeyboardStatus,
      showTerminalRow: _showTerminalRow,
      onToggleTerminalRow: _toggleTerminalRow,
      showCodeKey: _showCodeKey,
      onToggleCodeKey: _toggleKeyboardCodeKey,
      showLanguageKey: _showLanguageKey,
      onToggleLanguageKey: _toggleKeyboardLanguageKey,
      clipboardImagesEnabled: _clipboardImagesEnabled,
      onToggleClipboardImages: _toggleClipboardImages,
      heightProfile: _heightProfile,
      onSaveHeightProfile: _saveHeightProfile,
      heightProfileHint: _heightProfileHint,
      keySpacing: _keySpacing,
      onSaveKeySpacing: _saveKeySpacing,
      keySpacingHint: _keySpacingHint,
      invertToolbar: _invertToolbar,
      onToggleInvertToolbar: _toggleInvertToolbar,
      spacebarAlignment: _spacebarAlignment,
      onSaveSpacebarAlignment: _saveSpacebarAlignment,
      spacebarTrackpadMode: _spacebarTrackpadMode,
      onSaveSpacebarTrackpadMode: _saveSpacebarTrackpadMode,
      bottomElevationDp: _bottomElevationDp,
      onSaveBottomElevation: _saveBottomElevation,
      hapticsEnabled: _hapticsEnabled,
      onToggleHaptics: _toggleHaptics,
      hapticStyle: _hapticStyle,
      onSaveHapticStyle: _saveHapticStyle,
      hapticStyleHint: _hapticStyleHint,
      isKeyboardEnabled: _isKeyboardEnabled,
      isKeyboardSelected: _isKeyboardSelected,
      onOpenKeyboardSettings: _openKeyboardSettings,
      onShowInputMethodPicker: _showInputMethodPicker,
      onSelectTab: _selectTab,
    );
  }

  Widget _buildTrackpadTab(BuildContext context) {
    return TrackpadTab(
      trackpadEnabled: _trackpadEnabled,
      onToggleTrackpadEnabled: _toggleTrackpadEnabled,
      trackpadToolbarVisible: _trackpadToolbarVisible,
      onToggleTrackpadToolbarVisible: _toggleTrackpadToolbarVisible,
      trackpadButtonLayout: _trackpadButtonLayout,
      onSaveTrackpadButtonLayout: _saveTrackpadButtonLayout,
      trackpadScrollPosition: _trackpadScrollPosition,
      onSaveTrackpadScrollPosition: _saveTrackpadScrollPosition,
      trackpadSensitivity: _trackpadSensitivity,
      onTrackpadSensitivitySlider: _onTrackpadSensitivitySlider,
      trackpadAccelCurve: _trackpadAccelCurve,
      onSaveTrackpadAccelCurve: _saveTrackpadAccelCurve,
      trackpadTapToClick: _trackpadTapToClick,
      onToggleTrackpadTapToClick: _toggleTrackpadTapToClick,
      trackpadSecondaryClick: _trackpadSecondaryClick,
      onSaveTrackpadSecondaryClick: _saveTrackpadSecondaryClick,
      trackpadScrollDirection: _trackpadScrollDirection,
      onSaveTrackpadScrollDirection: _saveTrackpadScrollDirection,
      trackpadPointerStyle: _trackpadPointerStyle,
      onSaveTrackpadPointerStyle: _saveTrackpadPointerStyle,
      trackpadHaptic: _trackpadHaptic,
      onSaveTrackpadHaptic: _saveTrackpadHaptic,
      trackpadAutoReturn: _trackpadAutoReturn,
      onSaveTrackpadAutoReturn: _saveTrackpadAutoReturn,
    );
  }

  Widget _buildSnippetsTab(BuildContext context) {
    return SnippetsTab(storageService: _storageService);
  }

  // Acerca v2: ya no es tab. Vive como sheet desde General vía
  // _showAboutSheet (incluye el selector de tema Sistema/Claro/Oscuro).
  // Se conserva el contrato de textos (versión + descripción).
}

