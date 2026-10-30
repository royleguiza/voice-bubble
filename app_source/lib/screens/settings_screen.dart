import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:record/record.dart';
import 'credentials_screen.dart';
import 'settings/snippets_tab.dart';
import '../services/channel_guard.dart';
import '../services/storage_service.dart';
import '../services/gemini_key_store.dart';
import '../services/gemini_note_service.dart';
import '../services/widget_service.dart';
import '../ui/debouncer.dart';
import '../ui/design_tokens.dart';
import '../ui/theme_mode.dart';
import '../services/floating_bubble_service.dart';
import '../services/floating_trackpad_service.dart';
import '../services/keyboard_service.dart';
import '../widgets/settings_v2.dart';

part 'settings/general_tab.dart';
part 'settings/teclado_tab.dart';
part 'settings/trackpad_tab.dart';

/// Páginas de Ajustes. La raíz es una lista estilo Ajustes de iOS y cada
/// tema abre su propia página (antes: 5 pestañas con listas largas).
enum SettingsPage {
  root,
  transcripcion,
  ia,
  teclado,
  sonido,
  burbuja,
  trackpad,
  snippets,
  claves,
  notas,
  acerca,
}

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
  final _apiKeyController = TextEditingController();
  late final FlutterSecureStorage _secureStorage;
  late final StorageService _storageService;
  late final FloatingBubbleService _floatingBubbleService;
  late final FloatingTrackpadService _floatingTrackpadService;
  late final KeyboardService _keyboardService;

  /// Pila de navegación interna: solo se construye la página visible.
  final List<SettingsPage> _stack = [SettingsPage.root];
  bool _navForward = true;
  final _snippetsKey = GlobalKey<SnippetsTabState>();
  final _credentialsKey = GlobalKey<CredentialsScreenState>();

  /// Clave guardada (fuente de la cola "••••1234" y del Cancelar del sheet).
  String _storedApiKey = '';
  bool _hasApiKey = false;
  bool _isEditingApiKey = false;
  String? _apiKeyError;
  final _geminiKeyStore = GeminiKeyStore();
  final _geminiApiKeyController = TextEditingController();
  String _storedGeminiKey = '';
  bool _geminiHasApiKey = false;
  bool _geminiIsEditingApiKey = false;
  String? _geminiApiKeyError;
  bool _geminiActionsEnabled = true;
  String _recordMode = StorageService.defaultRecordMode;
  bool _isBubbleEnabled = false;
  bool _showBubbleHistory = true;
  bool _notesDeferredQueue = false;
  bool _isKeyboardEnabled = false;
  bool _isKeyboardSelected = false;
  bool _showTerminalRow = true;
  bool _showCodeKey = true;
  bool _showLanguageKey = true;
  bool _showCredentialsKey = true;
  bool _clipboardImagesEnabled = false;
  String _heightProfile = StorageService.defaultHeightProfile;
  String _keySpacing = StorageService.defaultKeySpacing;
  bool _hapticsEnabled = true;
  String _hapticStyle = StorageService.defaultHapticStyle;
  bool _micHapticsEnabled = true;
  bool _micHapticStart = true;
  bool _micHapticRecording = true;
  bool _micHapticPaste = true;
  bool _micHapticCancel = true;
  bool _micSoundsEnabled = false;
  String _micStartStyle = StorageService.defaultMicSoundStyle;
  String _micStopStyle = StorageService.defaultMicSoundStyle;
  int _bottomElevationDp = StorageService.defaultBottomElevationDp;
  bool _invertToolbar = false;
  String _spacebarAlignment = StorageService.defaultSpacebarAlignment;
  String _spacebarTrackpadMode = StorageService.defaultSpacebarTrackpadMode;
  bool _longPressSymbolsEnabled = StorageService.defaultLongPressSymbols;
  String _longPressDelay = StorageService.defaultLongPressDelay;
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
  String _widgetMicPosition = StorageService.defaultWidgetMicPosition;

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

  /// Carga inicial en dos fases para que Ajustes abra al instante:
  /// 1. Preferencias planas (ya en memoria, sin I/O): un único setState.
  /// 2. Lo lento (bóveda cifrada + canales nativos) en paralelo, con su
  ///    propio setState. Antes las ~40 lecturas iban en serie DETRÁS de dos
  ///    lecturas del keystore y de una reescritura del espejo STT (escritura
  ///    cifrada + relectura + 4 commits a disco) en CADA apertura.
  /// Cada lectura captura su propio fallo de frontera de canal y conserva el
  /// valor por defecto del campo.
  Future<void> _loadInitialState() async {
    final slow = _loadSlowState();
    await _loadPrefsState();
    await slow;
  }

  Future<void> _loadPrefsState() async {
    final s = _storageService;
    final results = await (
      s.loadRecordMode(),
      s.loadKeyboardTerminalRowVisible(),
      s.loadKeyboardCodeKeyVisible(),
      s.loadKeyboardLanguageKeyVisible(),
      s.getHeightProfile(),
      s.getKeySpacing(),
      s.getHapticsEnabled(),
      _geminiKeyStore.actionsEnabled(),
    ).wait;
    // Fuera del record .wait (límite de aridad del SDK). Son lecturas de
    // memoria: los await en serie cuestan un microtask cada uno.
    final hapticStyle = await s.getHapticStyle();
    final micHapticsEnabled = await s.getMicHapticsEnabled();
    final micHapticStart = await s.getMicHapticStart();
    final micHapticRecording = await s.getMicHapticRecording();
    final micHapticPaste = await s.getMicHapticPaste();
    final micHapticCancel = await s.getMicHapticCancel();
    final micSoundsEnabled = await s.getMicSoundsEnabled();
    final micStartStyle = await s.getMicStartStyle();
    final micStopStyle = await s.getMicStopStyle();
    final bottomElevation = await s.getBottomElevationDp();
    final invertToolbar = await s.getInvertToolbar();
    final spacebarAlign = await s.getSpacebarAlignment();
    final spacebarTrackpadMode = await s.getSpacebarTrackpadMode();
    final trackpadEnabled = await s.getTrackpadEnabled();
    final trackpadToolbarVisible = await s.getTrackpadToolbarVisible();
    final trackpadButtonLayout = await s.getTrackpadButtonLayout();
    final trackpadScrollPosition = await s.getTrackpadScrollPosition();
    final trackpadSensitivity = await s.getTrackpadSensitivity();
    final trackpadAccelCurve = await s.getTrackpadAccelCurve();
    final trackpadTapToClick = await s.getTrackpadTapToClick();
    final trackpadSecondaryClick = await s.getTrackpadSecondaryClick();
    final trackpadScrollDirection = await s.getTrackpadScrollDirection();
    final trackpadHaptic = await s.getTrackpadHaptic();
    final trackpadPointerStyle = await s.getTrackpadPointerStyle();
    final trackpadAutoReturn = await s.getTrackpadAutoReturn();
    final bubbleHistory = await s.loadBubbleHistoryEnabled();
    final notesDeferred = await s.loadNotesDeferredQueueEnabled();
    final credentialsKeyVisible = await s.loadKeyboardCredentialsKeyVisible();
    final clipboardImages = await s.getClipboardImagesEnabled();
    final longPressSymbols = await s.getLongPressSymbolsEnabled();
    final longPressDelay = await s.getLongPressDelay();
    final themeMode = await s.loadThemeMode();
    final widgetMicPos = await s.getWidgetMicPosition();
    if (!mounted) return;
    setState(() {
      _recordMode = results.$1;
      _showTerminalRow = results.$2;
      _showCodeKey = results.$3;
      _showLanguageKey = results.$4;
      _heightProfile = results.$5;
      _keySpacing = results.$6;
      _hapticsEnabled = results.$7;
      _geminiActionsEnabled = results.$8;
      _showCredentialsKey = credentialsKeyVisible;
      _hapticStyle = hapticStyle;
      _micHapticsEnabled = micHapticsEnabled;
      _micHapticStart = micHapticStart;
      _micHapticRecording = micHapticRecording;
      _micHapticPaste = micHapticPaste;
      _micHapticCancel = micHapticCancel;
      _micSoundsEnabled = micSoundsEnabled;
      _micStartStyle = micStartStyle;
      _micStopStyle = micStopStyle;
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
      _notesDeferredQueue = notesDeferred;
      _clipboardImagesEnabled = clipboardImages;
      _longPressSymbolsEnabled = longPressSymbols;
      _longPressDelay = longPressDelay;
      _themeMode = themeMode;
      _widgetMicPosition = widgetMicPos;
    });
  }

  /// Bóveda cifrada y canales nativos, todo en paralelo.
  Future<void> _loadSlowState() async {
    final results = await (
      _readStoredApiKey(),
      _geminiKeyStore.getKey(),
      _readBubbleEnabled(),
      _readKeyboardStatus(),
    ).wait;
    final apiKey = results.$1;
    final geminiKey = results.$2 ?? '';
    if (mounted) {
      setState(() {
        _storedApiKey = apiKey;
        _apiKeyController.text = apiKey;
        _hasApiKey = apiKey.isNotEmpty;
        _isEditingApiKey = false;
        _apiKeyError = null;
        _storedGeminiKey = geminiKey;
        _geminiApiKeyController.text = geminiKey;
        _geminiHasApiKey = geminiKey.isNotEmpty;
        _geminiIsEditingApiKey = false;
        _geminiApiKeyError = null;
        _isBubbleEnabled = results.$3;
        _isKeyboardEnabled = results.$4.$1;
        _isKeyboardSelected = results.$4.$2;
      });
    }
    // Espejo D7 (credenciales del teclado nativo): solo se repara si falta.
    // Antes se reescribía entero en cada apertura de Ajustes.
    if (apiKey.isNotEmpty) {
      try {
        if (!await _storageService.isSttMirrorConfigured()) {
          await _storageService.saveSttMirror(apiKey: apiKey);
        }
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------
  // Navegación interna
  // ---------------------------------------------------------------------

  void _go(SettingsPage page) {
    setState(() {
      _navForward = true;
      _stack.add(page);
    });
  }

  /// Atrás (botón de la barra o gesto del sistema): primero cierra el sheet
  /// de clave, después sube un nivel.
  void _handleBack() {
    if (_isEditingApiKey) {
      _cancelApiEdit();
      return;
    }
    if (_geminiIsEditingApiKey) {
      _cancelGeminiApiEdit();
      return;
    }
    if (_stack.length > 1) {
      setState(() {
        _navForward = false;
        _stack.removeLast();
      });
    }
  }

  // ---------------------------------------------------------------------
  // Acciones
  // ---------------------------------------------------------------------

  /// Modal de historial de la burbuja clásica (hito B1–B7): el toque largo
  /// la abre solo con el switch ON (aplica al abrir la próxima vez, la
  /// modal lee la preferencia en vivo desde el nativo).
  Future<void> _toggleBubbleHistory(bool enabled) async {
    try {
      await _storageService.saveBubbleHistoryEnabled(enabled);
    } catch (_) {}
    if (mounted) setState(() => _showBubbleHistory = enabled);
  }

  /// Cola diferida cloud en Notas (C1–C7): solo gate de encolar nuevos.
  /// No borra pendientes existentes al apagar.
  Future<void> _toggleNotesDeferredQueue(bool enabled) async {
    try {
      await _storageService.saveNotesDeferredQueueEnabled(enabled);
    } catch (_) {}
    if (mounted) setState(() => _notesDeferredQueue = enabled);
  }

  Future<void> _setWidgetMicPosition(String pos) async {
    try {
      await _storageService.setWidgetMicPosition(pos);
    } catch (_) {}
    if (mounted) setState(() => _widgetMicPosition = pos);
    try {
      await WidgetService().updateWidgets();
    } catch (_) {}
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

  Future<void> _toggleKeyboardCredentialsKey(bool visible) async {
    await _storageService.saveKeyboardCredentialsKeyVisible(visible);
    if (mounted) setState(() => _showCredentialsKey = visible);
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

  Future<void> _toggleLongPressSymbols(bool enabled) async {
    await _storageService.setLongPressSymbolsEnabled(enabled);
    if (mounted) setState(() => _longPressSymbolsEnabled = enabled);
  }

  Future<void> _saveLongPressDelay(String delay) async {
    await _storageService.setLongPressDelay(delay);
    if (mounted) setState(() => _longPressDelay = delay);
  }

  Future<void> _toggleHaptics(bool enabled) async {
    await _storageService.setHapticsEnabled(enabled);
    if (mounted) setState(() => _hapticsEnabled = enabled);
  }

  Future<void> _saveHapticStyle(String style) async {
    await _storageService.setHapticStyle(style);
    if (mounted) setState(() => _hapticStyle = style);
  }

  Future<void> _toggleMicHaptics(bool v) async {
    await _storageService.setMicHapticsEnabled(v);
    if (mounted) setState(() => _micHapticsEnabled = v);
  }

  Future<void> _toggleMicHapticStart(bool v) async {
    await _storageService.setMicHapticStart(v);
    if (mounted) setState(() => _micHapticStart = v);
  }

  Future<void> _toggleMicHapticRecording(bool v) async {
    await _storageService.setMicHapticRecording(v);
    if (mounted) setState(() => _micHapticRecording = v);
  }

  Future<void> _toggleMicHapticPaste(bool v) async {
    await _storageService.setMicHapticPaste(v);
    if (mounted) setState(() => _micHapticPaste = v);
  }

  Future<void> _toggleMicHapticCancel(bool v) async {
    await _storageService.setMicHapticCancel(v);
    if (mounted) setState(() => _micHapticCancel = v);
  }

  Future<void> _toggleMicSounds(bool v) async {
    await _storageService.setMicSoundsEnabled(v);
    if (mounted) setState(() => _micSoundsEnabled = v);
  }

  Future<void> _saveMicStartStyle(String v) async {
    await _storageService.setMicStartStyle(v);
    if (mounted) setState(() => _micStartStyle = v);
  }

  Future<void> _saveMicStopStyle(String v) async {
    await _storageService.setMicStopStyle(v);
    if (mounted) setState(() => _micStopStyle = v);
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

  /// Entrada del slider de sensibilidad (C-33): el estado visual y el
  /// debouncer viven en [TrackpadSensitivitySection] para evitar el rebuild
  /// de toda la pantalla de Ajustes en cada tick. Aquí solo persistimos.
  void _onTrackpadSensitivitySlider(double value) {
    _trackpadSensitivity = value;
    _storageService.setTrackpadSensitivity(value);
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

  /// Relectura del estado del teclado (al volver de los ajustes de Android).
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

  bool get _isKeyboardActive => _isKeyboardEnabled && _isKeyboardSelected;

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

  /// Revisión manual del permiso de overlay desde Burbuja flotante.
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

  /// Guarda la clave de Groq desde el sheet. Éxito = cierra el sheet
  /// (`_isEditingApiKey = false`); error de validación o de guardado = el
  /// sheet sigue abierto con el mensaje.
  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    // Validación visible: vacía, incompleta (<10) o sin prefijo gsk_.
    String? error;
    if (key.isEmpty) {
      error = 'Pegá tu clave para continuar.';
    } else if (key.length < 10) {
      error = 'Parece incompleta: revisá que la copiaste entera.';
    } else if (!key.startsWith('gsk_')) {
      error = 'Las claves de Groq empiezan con gsk_.';
    }
    if (error != null) {
      if (mounted) setState(() => _apiKeyError = error);
      return;
    }
    try {
      await _secureStorage.write(key: 'groq_api_key', value: key);
      final bool ok;
      if (key.isNotEmpty) {
        ok = await _storageService.saveSttMirror(apiKey: key);
      } else {
        await _storageService.clearSttMirror();
        ok = true;
      }
      if (!ok) {
        throw StateError('Fallo al guardar espejo STT');
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
      _storedApiKey = key;
      _hasApiKey = key.isNotEmpty;
      _isEditingApiKey = false;
      _apiKeyError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clave guardada')),
    );
  }

  /// Abre el sheet. Con clave guardada el campo arranca vacío (se pega la
  /// nueva); Cancelar restaura la guardada.
  void _startApiEdit() {
    if (mounted) {
      setState(() {
        _apiKeyController.clear();
        _isEditingApiKey = true;
        _apiKeyError = null;
      });
    }
  }

  void _cancelApiEdit() {
    if (mounted) {
      setState(() {
        _apiKeyController.text = _storedApiKey;
        _isEditingApiKey = false;
        _apiKeyError = null;
      });
    }
  }

  String _tailOf(String key) {
    final text = key.trim();
    if (text.length < 4) return '••••';
    return '••••${text.substring(text.length - 4)}';
  }

  /// Cola visible de la clave (últimos 4, resto oculto). Nunca expone la
  /// clave completa en UI.
  String get _apiKeyTail => _tailOf(_storedApiKey);

  String get _geminiApiKeyTail => _tailOf(_storedGeminiKey);

  Future<void> _saveGeminiApiKey() async {
    final key = _geminiApiKeyController.text.trim();
    String? error;
    if (key.isEmpty) {
      error = 'Pegá tu clave de Google AI Studio para continuar.';
    } else if (key.length < 10) {
      error = 'Parece incompleta: revisá que la copiaste entera.';
    }
    if (error != null) {
      if (mounted) setState(() => _geminiApiKeyError = error);
      return;
    }
    final ok = await _geminiKeyStore.saveKey(key);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la API key')),
      );
      return;
    }
    await _geminiKeyStore.setActionsEnabled(_geminiActionsEnabled);
    if (!mounted) return;
    setState(() {
      _storedGeminiKey = key;
      _geminiHasApiKey = true;
      _geminiIsEditingApiKey = false;
      _geminiApiKeyError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clave de Google AI guardada')),
    );
  }

  void _startGeminiApiEdit() {
    if (mounted) {
      setState(() {
        _geminiApiKeyController.clear();
        _geminiIsEditingApiKey = true;
        _geminiApiKeyError = null;
      });
    }
  }

  void _cancelGeminiApiEdit() {
    if (mounted) {
      setState(() {
        _geminiApiKeyController.text = _storedGeminiKey;
        _geminiIsEditingApiKey = false;
        _geminiApiKeyError = null;
      });
    }
  }

  Future<void> _clearGeminiApiKey() async {
    await _geminiKeyStore.clearKey();
    if (!mounted) return;
    _geminiApiKeyController.clear();
    setState(() {
      _storedGeminiKey = '';
      _geminiHasApiKey = false;
      _geminiIsEditingApiKey = false;
      _geminiApiKeyError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clave de Google AI eliminada')),
    );
  }

  Future<void> _testGeminiConnection() async {
    final key = _storedGeminiKey.trim();
    if (key.isEmpty) return;
    final ok = await GeminiNoteService(apiKey: key).testConnection();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            ok ? 'Conectado con Gemini' : 'No se pudo conectar: revisá la clave'),
      ),
    );
  }

  Future<void> _toggleGeminiActions(bool enabled) async {
    await _geminiKeyStore.setActionsEnabled(enabled);
    if (mounted) setState(() => _geminiActionsEnabled = enabled);
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
      _storedApiKey = '';
      _hasApiKey = false;
      _isEditingApiKey = false;
      _apiKeyError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clave eliminada')),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _apiKeyController.dispose();
    _geminiApiKeyController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Construcción
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = SettingsPalette.of(context);
    final page = _stack.last;
    final sheetOpen = _isEditingApiKey || _geminiIsEditingApiKey;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final slideFrom = _navForward ? 0.12 : -0.12;
    return PopScope(
      canPop: _stack.length == 1 && !sheetOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(slideFrom, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(page),
                    child: _buildPage(context, page),
                  ),
                ),
              ),
              if (sheetOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _handleBack,
                    child: const ColoredBox(color: kScrimColor),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      8,
                      0,
                      8,
                      8 +
                          MediaQuery.viewInsetsOf(context).bottom +
                          MediaQuery.paddingOf(context).bottom,
                    ),
                    child: _isEditingApiKey
                        ? _buildGroqKeySheet(context)
                        : _buildGeminiKeySheet(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, SettingsPage page) {
    switch (page) {
      case SettingsPage.root:
        return _buildRootPage(context);
      case SettingsPage.transcripcion:
        return _buildTranscripcionPage(context);
      case SettingsPage.ia:
        return _buildIaPage(context);
      case SettingsPage.teclado:
        return _buildTecladoPage(context);
      case SettingsPage.sonido:
        return _buildSonidoPage(context);
      case SettingsPage.burbuja:
        return _buildBurbujaPage(context);
      case SettingsPage.trackpad:
        return _buildTrackpadPage(context);
      case SettingsPage.notas:
        return _buildNotasPage(context);
      case SettingsPage.acerca:
        return _buildAcercaPage(context);
      case SettingsPage.snippets:
        return _subpage(
          context,
          title: 'Snippets',
          trailing: SettingsGlassButton(
            key: const ValueKey('snippets-add-button'),
            icon: Icons.add_rounded,
            tooltip: 'Nuevo snippet',
            onPressed: () => _snippetsKey.currentState?.openNewSnippet(),
          ),
          body: SnippetsTab(
            key: _snippetsKey,
            storageService: _storageService,
          ),
        );
      case SettingsPage.claves:
        return _subpage(
          context,
          title: 'Claves',
          trailing: SettingsGlassButton(
            key: const ValueKey('credenciales-open-add'),
            icon: Icons.add_rounded,
            tooltip: 'Nueva clave',
            onPressed: () =>
                _credentialsKey.currentState?.openAddCredential(),
          ),
          body: CredentialsScreen(
            key: _credentialsKey,
            storageService: _storageService,
          ),
        );
    }
  }

  /// Lista de grupos con el espaciado estándar entre ellos.
  Widget _sectionList(
    BuildContext context, {
    required String storageKey,
    required List<Widget> sections,
    Widget? header,
  }) {
    final children = <Widget>[if (header != null) header];
    for (var i = 0; i < sections.length; i++) {
      if (i > 0 || header != null) {
        children.add(const SizedBox(height: kSettingsGroupGap));
      }
      children.add(sections[i]);
    }
    return ListView(
      key: PageStorageKey<String>(storageKey),
      padding: EdgeInsets.fromLTRB(
        16,
        header == null ? 8 : 0,
        16,
        kSettingsGroupGap + MediaQuery.paddingOf(context).bottom,
      ),
      children: children,
    );
  }

  /// Subpágina: barra con botón de volver de vidrio, título centrado y
  /// acción opcional a la derecha.
  Widget _subpage(
    BuildContext context, {
    required String title,
    List<Widget>? sections,
    Widget? body,
    Widget? trailing,
  }) {
    final p = SettingsPalette.of(context);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: kSettingsNavBarHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                child: SettingsGlassButton(
                  key: const ValueKey('settings-back-button'),
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Volver',
                  onPressed: _handleBack,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: kSettingsNavTitle.copyWith(color: p.label),
                  ),
                ),
              ),
              if (trailing != null) Positioned(right: 12, child: trailing),
            ],
          ),
        ),
        Expanded(
          child: body ??
              _sectionList(
                context,
                storageKey: 'settings_${title.toLowerCase()}',
                sections: sections!,
              ),
        ),
      ],
    );
  }

  Widget _buildRootPage(BuildContext context) {
    final p = SettingsPalette.of(context);
    final needsSetup = !_hasApiKey || !_isKeyboardActive;
    return _sectionList(
      context,
      storageKey: 'settings_root',
      header: const SettingsLargeTitle('Ajustes'),
      sections: [
        if (needsSetup)
          SettingsSection(
            key: const ValueKey('setup-section'),
            header: 'Terminá de configurar',
            footer: 'Con esto ya podés dictar en cualquier app.',
            iconInset: true,
            children: [
              if (!_hasApiKey)
                SettingsNavRow(
                  key: const ValueKey('setup-groq-row'),
                  icon: Icons.graphic_eq_rounded,
                  tile: kTileRed,
                  title: 'Agregar clave de Groq',
                  value: 'Falta',
                  valueColor: p.alert,
                  onTap: () => _go(SettingsPage.transcripcion),
                ),
              if (!_isKeyboardActive)
                SettingsNavRow(
                  key: const ValueKey('setup-keyboard-row'),
                  icon: Icons.keyboard_rounded,
                  tile: kTileGray,
                  title: 'Activar el teclado',
                  value: 'Falta',
                  valueColor: p.alert,
                  onTap: () => _go(SettingsPage.teclado),
                ),
            ],
          ),
        SettingsAppCard(
          key: const ValueKey('about-open-button'),
          title: 'VoiceBubble',
          subtitle: 'Dictado con Groq Whisper',
          onTap: () => _go(SettingsPage.acerca),
        ),
        SettingsSection(
          iconInset: true,
          children: [
            SettingsNavRow(
              key: const ValueKey('nav-transcripcion'),
              icon: Icons.graphic_eq_rounded,
              tile: kTileRed,
              title: 'Transcripción',
              value: _hasApiKey ? 'Groq' : 'Sin clave',
              onTap: () => _go(SettingsPage.transcripcion),
            ),
            SettingsNavRow(
              key: const ValueKey('nav-ia'),
              icon: Icons.auto_awesome_rounded,
              tile: kTilePurple,
              title: 'Inteligencia artificial',
              value: _geminiHasApiKey
                  ? (_geminiActionsEnabled ? 'Activa' : 'Oculta')
                  : 'Opcional',
              onTap: () => _go(SettingsPage.ia),
            ),
          ],
        ),
        SettingsSection(
          header: 'Dónde dictar',
          iconInset: true,
          children: [
            SettingsNavRow(
              key: const ValueKey('nav-teclado'),
              icon: Icons.keyboard_rounded,
              tile: kTileGray,
              title: 'Teclado',
              value: _isKeyboardActive ? 'Activo' : 'Inactivo',
              onTap: () => _go(SettingsPage.teclado),
            ),
            SettingsNavRow(
              key: const ValueKey('nav-burbuja'),
              icon: Icons.bubble_chart_rounded,
              tile: kTileBlue,
              title: 'Burbuja flotante',
              value: _isBubbleEnabled ? 'Activada' : 'Apagada',
              onTap: () => _go(SettingsPage.burbuja),
            ),
            SettingsNavRow(
              key: const ValueKey('nav-trackpad'),
              icon: Icons.touch_app_rounded,
              tile: kTileIndigo,
              title: 'Trackpad',
              value: _trackpadEnabled ? 'Activado' : 'Apagado',
              onTap: () => _go(SettingsPage.trackpad),
            ),
          ],
        ),
        SettingsSection(
          header: 'Tu contenido',
          iconInset: true,
          children: [
            SettingsNavRow(
              key: const ValueKey('nav-snippets'),
              icon: Icons.short_text_rounded,
              tile: kTileOrange,
              title: 'Snippets',
              onTap: () => _go(SettingsPage.snippets),
            ),
            SettingsNavRow(
              key: const ValueKey('nav-claves'),
              icon: Icons.key_rounded,
              tile: kTileGreen,
              title: 'Claves',
              onTap: () => _go(SettingsPage.claves),
            ),
            SettingsNavRow(
              key: const ValueKey('nav-notas'),
              icon: Icons.sticky_note_2_rounded,
              tile: kTileYellow,
              title: 'Notas y widgets',
              onTap: () => _go(SettingsPage.notas),
            ),
          ],
        ),
        SettingsSection(
          iconInset: true,
          children: [
            SettingsMenuRow<String>(
              id: 'theme-selector',
              icon: Icons.contrast_rounded,
              tile: kTileGray,
              title: 'Apariencia',
              value: _themeMode,
              options: const [
                SettingsOption('sistema', 'Automática'),
                SettingsOption('claro', 'Clara'),
                SettingsOption('oscuro', 'Oscura'),
              ],
              onSelected: _saveThemeMode,
            ),
          ],
        ),
      ],
    );
  }

  /// Acerca de: identidad, versión, diagnóstico y privacidad.
  Widget _buildAcercaPage(BuildContext context) {
    final p = SettingsPalette.of(context);
    return _subpage(
      context,
      title: 'Acerca de',
      sections: [
        Column(
          children: [
            const SizedBox(height: 8),
            const SettingsAppIcon(dimension: 88),
            const SizedBox(height: 14),
            Text(
              'VoiceBubble',
              style: kTextTitle.copyWith(fontSize: 24, color: p.label),
            ),
            const SizedBox(height: 4),
            Text(
              'Transcripción de voz a texto con Groq Whisper.',
              textAlign: TextAlign.center,
              style: kTextSubhead.copyWith(color: p.secondary),
            ),
          ],
        ),
        SettingsSection(
          footer: 'Sin analytics ni telemetría. El audio sale del teléfono '
              'solo cuando dictás, y el teclado nunca guarda lo que escribís.',
          children: [
            const SettingsValueRow(
              key: ValueKey('about-version'),
              title: 'Versión',
              value: '1.0.0',
            ),
            const SettingsValueRow(title: 'Motor', value: 'Groq Whisper'),
            SettingsValueRow(
              key: const ValueKey('about-channel-errors'),
              title: 'Errores de canal',
              value: '$channelErrorCount',
            ),
          ],
        ),
      ],
    );
  }
}
