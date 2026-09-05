import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/snippet.dart';
import '../models/transcription.dart';
import 'cloud_stt_service.dart';

class StorageService {
  static const String _key = 'transcriptions';
  static const String _recordModeKey = 'recording_mode';
  static const String defaultRecordMode = 'tap';

  /// Limites y valores de contrato compartidos con screens/tests (F6/F10
  /// importan estos nombres EXACTOS). Fuente unica, sin literales magicos.
  static const int maxItems = 20;
  static const int maxSnippets = 50;
  static const int maxSnippetLength = 2000;
  static const String recordModeHold = 'hold';

  // --- Rangos centralizados (única fuente; la UI no re-clampea) ---
  // Trackpad: sensibilidad 0.5..2.5.
  static const double minTrackpadSensitivity = 0.5;
  static const double maxTrackpadSensitivity = 2.5;
  // Isla: X [-160,160], Y [-100,120], ancho [130,320], alto [28,48].
  static const int minIslandPosX = -160;
  static const int maxIslandPosX = 160;
  static const int minIslandPosY = -100;
  static const int maxIslandPosY = 120;
  static const int minIslandWidth = 130;
  static const int maxIslandWidth = 320;
  static const int minIslandHeight = 28;
  static const int maxIslandHeight = 48;
  // Onda del mic de la isla (por si se usa aquí en el futuro).
  static const double minWaveformLevel = 0.0;
  static const double maxWaveformLevel = 1.0;

  static int clampIslandPosX(int v) => v.clamp(minIslandPosX, maxIslandPosX);
  static int clampIslandPosY(int v) => v.clamp(minIslandPosY, maxIslandPosY);
  static int clampIslandWidth(int v) =>
      v.clamp(minIslandWidth, maxIslandWidth);
  static int clampIslandHeight(int v) =>
      v.clamp(minIslandHeight, maxIslandHeight);
  static double clampTrackpadSensitivity(double v) =>
      v.clamp(minTrackpadSensitivity, maxTrackpadSensitivity);

  final FlutterSecureStorage _secureStorage;

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // --- Caché en memoria de SharedPreferences: UNA sola getInstance() ---
  // Instancia única de proceso (estática, no por StorageService): todas las
  // instancias comparten el mismo objeto, así que los setters son
  // write-through visibles para todos. Ante escrituras EXTERNAS al proceso
  // Dart (teclado nativo Kotlin sobre el mismo archivo
  // FlutterSharedPreferences) la caché queda obsoleta: por eso [_prefs()]
  // hace `reload()` en cada acceso y las lecturas que fusionan con disco
  // (`_readPrefsEntries`, `ensureSeeds`, historial) releen tras recargar.
  // Solo se invalida en tests que resiembran los mocks con
  // setMockInitialValues (ver [debugInvalidatePrefsCache]).
  static SharedPreferences? _prefsCache;

  Future<SharedPreferences> _prefs() async {
    final cached = _prefsCache;
    if (cached != null) {
      try {
        await cached.reload();
      } catch (_) {}
      return cached;
    }
    final fresh = await SharedPreferences.getInstance();
    _prefsCache = fresh;
    return fresh;
  }

  @visibleForTesting
  void debugInvalidatePrefsCache() {
    _prefsCache = null;
  }

  List<Transcription> _transcriptions = [];

  List<Transcription> get transcriptions =>
      List.unmodifiable(_transcriptions);

  /// Modo de interaccion del boton: [defaultRecordMode] (toque inicia/detiene)
  /// o [recordModeHold] (mantener presionado graba, soltar transcribe).
  Future<String> loadRecordMode() async {
    final prefs = await _prefs();
    return prefs.getString(_recordModeKey) ?? defaultRecordMode;
  }

  Future<void> saveRecordMode(String mode) async {
    final prefs = await _prefs();
    await prefs.setString(_recordModeKey, mode);
  }

  static const String _floatingBubbleKey = 'floating_bubble_enabled';

  Future<bool> loadFloatingBubbleEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_floatingBubbleKey) ?? false;
  }

  Future<void> saveFloatingBubbleEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_floatingBubbleKey, enabled);
  }

  static const String _bubbleHistoryKey = 'bubble_history_enabled';

  /// Modal de historial de la burbuja clásica (hito B1–B7, default ON).
  /// El servicio nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadBubbleHistoryEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_bubbleHistoryKey) ?? true;
  }

  Future<void> saveBubbleHistoryEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_bubbleHistoryKey, enabled);
  }

  static const String _keyboardTerminalRowKey = 'kb_terminal_row_visible';

  /// Fila terminal del teclado (TAB, ESC, CTRL, ALT, flechas).
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardTerminalRowVisible() async {
    final prefs = await _prefs();
    return prefs.getBool(_keyboardTerminalRowKey) ?? true;
  }

  Future<void> saveKeyboardTerminalRowVisible(bool visible) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyboardTerminalRowKey, visible);
  }

  static const String _keyboardCodeKeyVisibleKey = 'kb_code_key_visible';

  /// Tecla </> que abre la capa de simbolos de programacion.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardCodeKeyVisible() async {
    final prefs = await _prefs();
    return prefs.getBool(_keyboardCodeKeyVisibleKey) ?? true;
  }

  Future<void> saveKeyboardCodeKeyVisible(bool visible) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyboardCodeKeyVisibleKey, visible);
  }

  static const String _keyboardLanguageKeyVisibleKey =
      'kb_language_key_visible';

  /// Tecla ES/EN junto a la barra espaciadora para cambiar el idioma.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardLanguageKeyVisible() async {
    final prefs = await _prefs();
    return prefs.getBool(_keyboardLanguageKeyVisibleKey) ?? true;
  }

  Future<void> saveKeyboardLanguageKeyVisible(bool visible) async {
    final prefs = await _prefs();
    await prefs.setBool(_keyboardLanguageKeyVisibleKey, visible);
  }

  static const String kbHeightProfileKey = 'kb_height_profile';
  static const String kbHapticsEnabledKey = 'kb_haptics_enabled';
  static const String kbBottomElevationDpKey = 'kb_bottom_elevation_dp';
  static const String kbInvertToolbarKey = 'kb_invert_toolbar';

  static const int defaultBottomElevationDp = 24;

  Future<int> getBottomElevationDp() async {
    final prefs = await _prefs();
    return prefs.getInt(kbBottomElevationDpKey) ?? defaultBottomElevationDp;
  }

  Future<void> setBottomElevationDp(int dp) async {
    final prefs = await _prefs();
    await prefs.setInt(kbBottomElevationDpKey, dp);
  }

  Future<bool> getInvertToolbar() async {
    final prefs = await _prefs();
    return prefs.getBool(kbInvertToolbarKey) ?? false;
  }

  Future<void> setInvertToolbar(bool invert) async {
    final prefs = await _prefs();
    await prefs.setBool(kbInvertToolbarKey, invert);
  }

  static const String kbSpacebarAlignmentKey = 'kb_spacebar_alignment';
  static const String defaultSpacebarAlignment = 'center'; // left, center, right

  Future<String> getSpacebarAlignment() async {
    final prefs = await _prefs();
    return prefs.getString(kbSpacebarAlignmentKey) ?? defaultSpacebarAlignment;
  }

  Future<void> setSpacebarAlignment(String alignment) async {
    final prefs = await _prefs();
    await prefs.setString(kbSpacebarAlignmentKey, alignment);
  }

  static const String kbSpacebarTrackpadModeKey = 'kb_spacebar_trackpad_mode';
  static const String defaultSpacebarTrackpadMode = 'ios_2d'; // ios_2d, gboard_horizontal
  static const List<String> kbSpacebarTrackpadModes = ['ios_2d', 'gboard_horizontal'];

  Future<String> getSpacebarTrackpadMode() async {
    final prefs = await _prefs();
    final val = prefs.getString(kbSpacebarTrackpadModeKey);
    return kbSpacebarTrackpadModes.contains(val) ? val! : defaultSpacebarTrackpadMode;
  }

  Future<void> setSpacebarTrackpadMode(String mode) async {
    if (!kbSpacebarTrackpadModes.contains(mode)) return;
    final prefs = await _prefs();
    await prefs.setString(kbSpacebarTrackpadModeKey, mode);
  }

  /// Perfiles de altura del teclado validos, de menor a mayor.
  static const List<String> kbHeightProfiles = [
    'baja',
    'media',
    'alta',
    'muy_alta',
  ];
  static const String defaultHeightProfile = 'media';

  /// Altura global del teclado: 'baja', 'media', 'alta' o 'muy_alta'.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  /// Un valor ausente o invalido cae al perfil por defecto.
  Future<String> getHeightProfile() async {
    final prefs = await _prefs();
    final profile = prefs.getString(kbHeightProfileKey);
    return kbHeightProfiles.contains(profile)
        ? profile!
        : defaultHeightProfile;
  }

  Future<void> setHeightProfile(String profile) async {
    if (!kbHeightProfiles.contains(profile)) return;
    final prefs = await _prefs();
    await prefs.setString(kbHeightProfileKey, profile);
  }

  /// Vibracion hapatica al pulsar teclas. El teclado nativo Kotlin lee esta
  /// misma clave con prefijo "flutter.".
  Future<bool> getHapticsEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(kbHapticsEnabledKey) ?? true;
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(kbHapticsEnabledKey, enabled);
  }

  // --- Modo Trackpad y Puntero Virtual (MEJ-09) ---
  static const String kbTrackpadEnabledKey = 'kb_trackpad_enabled';
  static const String kbTrackpadToolbarVisibleKey = 'kb_trackpad_toolbar_visible';
  static const String kbTrackpadButtonLayoutKey = 'kb_trackpad_button_layout';
  static const String kbTrackpadScrollPositionKey = 'kb_trackpad_scroll_position';
  static const String kbTrackpadSensitivityKey = 'kb_trackpad_sensitivity';
  static const String kbTrackpadAccelCurveKey = 'kb_trackpad_accel_curve';
  static const String kbTrackpadTapToClickKey = 'kb_trackpad_tap_to_click';
  static const String kbTrackpadSecondaryClickKey = 'kb_trackpad_secondary_click';
  static const String kbTrackpadScrollDirectionKey = 'kb_trackpad_scroll_direction';
  static const String kbTrackpadHapticKey = 'kb_trackpad_haptic';
  static const String kbTrackpadPointerStyleKey = 'kb_trackpad_pointer_style';
  static const String kbTrackpadAutoReturnKey = 'kb_trackpad_auto_return';

  static const bool defaultTrackpadEnabled = true;
  static const bool defaultTrackpadToolbarVisible = true;
  static const String defaultTrackpadButtonLayout = 'top'; // top, wings
  static const String defaultTrackpadScrollPosition = 'right'; // right, left, disabled
  static const double defaultTrackpadSensitivity = 1.2; // 0.5 to 2.5
  static const String defaultTrackpadAccelCurve = 'dynamic'; // dynamic, linear, precision
  static const bool defaultTrackpadTapToClick = true;
  static const String defaultTrackpadSecondaryClick = '2fingers'; // 2fingers, button, hold
  static const String defaultTrackpadScrollDirection = 'natural'; // natural, standard
  static const String defaultTrackpadHaptic = 'subtle'; // subtle, none, firm
  static const String defaultTrackpadPointerStyle = 'arrow'; // arrow, dot, cross
  static const int defaultTrackpadAutoReturn = 0; // 0, 5, 15, 30

  static const List<String> kbTrackpadButtonLayouts = ['top', 'wings'];
  static const List<String> kbTrackpadScrollPositions = ['right', 'left', 'disabled'];
  static const List<String> kbTrackpadAccelCurves = ['dynamic', 'linear', 'precision'];
  static const List<String> kbTrackpadSecondaryClicks = ['2fingers', 'button', 'hold'];
  static const List<String> kbTrackpadScrollDirections = ['natural', 'standard'];
  static const List<String> kbTrackpadHaptics = ['subtle', 'none', 'firm'];
  static const List<String> kbTrackpadPointerStyles = ['arrow', 'dot', 'cross'];
  static const List<int> kbTrackpadAutoReturns = [0, 5, 15, 30];

  Future<bool> getTrackpadEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(kbTrackpadEnabledKey) ?? defaultTrackpadEnabled;
  }

  Future<void> setTrackpadEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(kbTrackpadEnabledKey, enabled);
  }

  Future<bool> getTrackpadToolbarVisible() async {
    final prefs = await _prefs();
    return prefs.getBool(kbTrackpadToolbarVisibleKey) ?? defaultTrackpadToolbarVisible;
  }

  Future<void> setTrackpadToolbarVisible(bool visible) async {
    final prefs = await _prefs();
    await prefs.setBool(kbTrackpadToolbarVisibleKey, visible);
  }

  Future<String> getTrackpadButtonLayout() async {
    final prefs = await _prefs();
    final val = prefs.getString(kbTrackpadButtonLayoutKey);
    return kbTrackpadButtonLayouts.contains(val) ? val! : defaultTrackpadButtonLayout;
  }

  Future<void> setTrackpadButtonLayout(String layout) async {
    if (!kbTrackpadButtonLayouts.contains(layout)) return;
    final prefs = await _prefs();
    await prefs.setString(kbTrackpadButtonLayoutKey, layout);
  }

  Future<String> getTrackpadScrollPosition() async {
    final prefs = await _prefs();
    final val = prefs.getString(kbTrackpadScrollPositionKey);
    return kbTrackpadScrollPositions.contains(val) ? val! : defaultTrackpadScrollPosition;
  }

  Future<void> setTrackpadScrollPosition(String position) async {
    if (!kbTrackpadScrollPositions.contains(position)) return;
    final prefs = await _prefs();
    await prefs.setString(kbTrackpadScrollPositionKey, position);
  }

  Future<double> getTrackpadSensitivity() async {
    final prefs = await _prefs();
    final raw =
        prefs.getDouble(kbTrackpadSensitivityKey) ?? defaultTrackpadSensitivity;
    return clampTrackpadSensitivity(raw);
  }

  Future<void> setTrackpadSensitivity(double sensitivity) async {
    final clamped = clampTrackpadSensitivity(sensitivity);
    final prefs = await _prefs();
    await prefs.setDouble(kbTrackpadSensitivityKey, clamped);
  }

  Future<String> getTrackpadAccelCurve() async {
    final prefs = await _prefs();
    final val = prefs.getString(kbTrackpadAccelCurveKey);
    return kbTrackpadAccelCurves.contains(val) ? val! : defaultTrackpadAccelCurve;
  }

  Future<void> setTrackpadAccelCurve(String curve) async {
    if (!kbTrackpadAccelCurves.contains(curve)) return;
    final prefs = await _prefs();
    await prefs.setString(kbTrackpadAccelCurveKey, curve);
  }

  Future<bool> getTrackpadTapToClick() async {
    final prefs = await _prefs();
    return prefs.getBool(kbTrackpadTapToClickKey) ?? defaultTrackpadTapToClick;
  }

  Future<void> setTrackpadTapToClick(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(kbTrackpadTapToClickKey, enabled);
  }

  Future<String> getTrackpadSecondaryClick() async {
    final prefs = await _prefs();
    final val = prefs.getString(kbTrackpadSecondaryClickKey);
    return kbTrackpadSecondaryClicks.contains(val) ? val! : defaultTrackpadSecondaryClick;
  }

  Future<void> setTrackpadSecondaryClick(String mode) async {
    if (!kbTrackpadSecondaryClicks.contains(mode)) return;
    final prefs = await _prefs();
    await prefs.setString(kbTrackpadSecondaryClickKey, mode);
  }

  Future<String> getTrackpadScrollDirection() async {
    final prefs = await _prefs();
    final val = prefs.getString(kbTrackpadScrollDirectionKey);
    return kbTrackpadScrollDirections.contains(val) ? val! : defaultTrackpadScrollDirection;
  }

  Future<void> setTrackpadScrollDirection(String direction) async {
    if (!kbTrackpadScrollDirections.contains(direction)) return;
    final prefs = await _prefs();
    await prefs.setString(kbTrackpadScrollDirectionKey, direction);
  }

  Future<String> getTrackpadHaptic() async {
    final prefs = await _prefs();
    final val = prefs.getString(kbTrackpadHapticKey);
    return kbTrackpadHaptics.contains(val) ? val! : defaultTrackpadHaptic;
  }

  Future<void> setTrackpadHaptic(String haptic) async {
    if (!kbTrackpadHaptics.contains(haptic)) return;
    final prefs = await _prefs();
    await prefs.setString(kbTrackpadHapticKey, haptic);
  }

  Future<String> getTrackpadPointerStyle() async {
    final prefs = await _prefs();
    final val = prefs.getString(kbTrackpadPointerStyleKey);
    return kbTrackpadPointerStyles.contains(val) ? val! : defaultTrackpadPointerStyle;
  }

  Future<void> setTrackpadPointerStyle(String style) async {
    if (!kbTrackpadPointerStyles.contains(style)) return;
    final prefs = await _prefs();
    await prefs.setString(kbTrackpadPointerStyleKey, style);
  }

  Future<int> getTrackpadAutoReturn() async {
    final prefs = await _prefs();
    final val = prefs.getInt(kbTrackpadAutoReturnKey);
    return kbTrackpadAutoReturns.contains(val) ? val! : defaultTrackpadAutoReturn;
  }

  Future<void> setTrackpadAutoReturn(int seconds) async {
    if (!kbTrackpadAutoReturns.contains(seconds)) return;
    final prefs = await _prefs();
    await prefs.setInt(kbTrackpadAutoReturnKey, seconds);
  }

  // --- MEJ-18: Píldora Flotante e Isla Dinámica (Laboratorio UI) ---
  static const String bubbleDockingModeKey = 'bubble_docking_mode';
  static const String defaultBubbleDockingMode = 'dynamic_island'; // 'dynamic_island', 'classic_bubble'
  static const List<String> bubbleDockingModes = ['dynamic_island', 'classic_bubble'];

  static const String islandPosXKey = 'island_pos_x';
  static const int defaultIslandPosX = 0; // px [-160, 160]

  static const String islandPosYKey = 'island_pos_y';
  static const int defaultIslandPosY = 12; // px [-100, 120]

  static const String islandWidthKey = 'island_width';
  static const int defaultIslandWidth = 184; // px [130, 320]

  static const String islandHeightKey = 'island_height';
  static const int defaultIslandHeight = 36; // px [28, 48]

  static const String islandSlotOrderKey = 'island_slot_order';
  static const String defaultIslandSlotOrder = 'trackpad_camera_mic'; // 'trackpad_camera_mic', 'mic_camera_trackpad'
  static const List<String> islandSlotOrders = ['trackpad_camera_mic', 'mic_camera_trackpad'];

  static const String islandThemeKey = 'island_theme';
  static const String defaultIslandTheme = 'dark'; // 'dark', 'glass', 'light'
  static const List<String> islandThemes = ['glass', 'dark', 'light'];

  static const String islandWaveformEnabledKey = 'island_waveform_enabled';
  static const bool defaultIslandWaveformEnabled = true;

  Future<String> getBubbleDockingMode() async {
    final prefs = await _prefs();
    final val = prefs.getString(bubbleDockingModeKey);
    return bubbleDockingModes.contains(val) ? val! : defaultBubbleDockingMode;
  }

  Future<void> setBubbleDockingMode(String mode) async {
    if (!bubbleDockingModes.contains(mode)) return;
    final prefs = await _prefs();
    await prefs.setString(bubbleDockingModeKey, mode);
  }

  Future<int> getIslandPosX() async {
    final prefs = await _prefs();
    final val = prefs.getInt(islandPosXKey) ?? defaultIslandPosX;
    return clampIslandPosX(val);
  }

  Future<void> setIslandPosX(int x) async {
    final clamped = clampIslandPosX(x);
    final prefs = await _prefs();
    await prefs.setInt(islandPosXKey, clamped);
  }

  Future<int> getIslandPosY() async {
    final prefs = await _prefs();
    final val = prefs.getInt(islandPosYKey) ?? defaultIslandPosY;
    return clampIslandPosY(val);
  }

  Future<void> setIslandPosY(int y) async {
    final clamped = clampIslandPosY(y);
    final prefs = await _prefs();
    await prefs.setInt(islandPosYKey, clamped);
  }

  Future<int> getIslandWidth() async {
    final prefs = await _prefs();
    final val = prefs.getInt(islandWidthKey) ?? defaultIslandWidth;
    return clampIslandWidth(val);
  }

  Future<void> setIslandWidth(int width) async {
    final clamped = clampIslandWidth(width);
    final prefs = await _prefs();
    await prefs.setInt(islandWidthKey, clamped);
  }

  Future<int> getIslandHeight() async {
    final prefs = await _prefs();
    final val = prefs.getInt(islandHeightKey) ?? defaultIslandHeight;
    return clampIslandHeight(val);
  }

  Future<void> setIslandHeight(int height) async {
    final clamped = clampIslandHeight(height);
    final prefs = await _prefs();
    await prefs.setInt(islandHeightKey, clamped);
  }

  Future<String> getIslandSlotOrder() async {
    final prefs = await _prefs();
    final val = prefs.getString(islandSlotOrderKey);
    return islandSlotOrders.contains(val) ? val! : defaultIslandSlotOrder;
  }

  Future<void> setIslandSlotOrder(String order) async {
    if (!islandSlotOrders.contains(order)) return;
    final prefs = await _prefs();
    await prefs.setString(islandSlotOrderKey, order);
  }

  Future<String> getIslandTheme() async {
    final prefs = await _prefs();
    final val = prefs.getString(islandThemeKey);
    return islandThemes.contains(val) ? val! : defaultIslandTheme;
  }

  Future<void> setIslandTheme(String theme) async {
    if (!islandThemes.contains(theme)) return;
    final prefs = await _prefs();
    await prefs.setString(islandThemeKey, theme);
  }

  Future<bool> getIslandWaveformEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(islandWaveformEnabledKey) ?? defaultIslandWaveformEnabled;
  }

  Future<void> setIslandWaveformEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(islandWaveformEnabledKey, enabled);
  }

  // --- Espejo D7: config STT no sensible para el teclado nativo (K3) ---
  // El teclado Kotlin lee url/model/language con prefijo "flutter." en
  // FlutterSharedPreferences. La API key JAMÁS vive aquí en texto plano:
  // solo en secure_storage bajo [secureSttApiKey]. Si existe un espejo
  // viejo en prefs (versiones previas), [migrateLegacySttMirror] lo mueve
  // a secure y lo borra una vez (lee→secure→borra).
  //
  // CONTRATO K3 (plan B verificado): flutter_secure_storage v9 (default,
  // `const FlutterSecureStorage()` sin aOptions) NO usa
  // EncryptedSharedPreferences: guarda en el archivo "FlutterSecureStorage"
  // bajo la clave "<prefijo-base64>_groq_api_key" con valor AES-GCM cuya
  // clave va envuelta en RSA dentro del Android Keystore (ver
  // FlutterSecureStorageConfig/FlutterSecureStorage del plugin). El IME
  // nativo no puede leerla sin duplicar esa construcción cripto (frágil
  // ante migraciones de algoritmo), así que Dart publica ADEMÁS el
  // indicador de presencia [sttKeyConfiguredKey] (bool, NO la key): el
  // teclado distingue "sin key" (aviso a Ajustes) de "key inválida" (401).
  // El lado Kotlin documenta el contrato en SpeechToTextClient.loadConfig.
  static const String secureSttApiKey = 'groq_api_key';

  /// Indicador de presencia de API key (bool en prefs, jamás la key).
  /// true = hay key legible en secure_storage; false/ausente = no hay.
  /// El teclado nativo lo leerá como "flutter.kb_stt_key_configured"
  /// (pendiente de alta en docs/contract-keys.txt: ITEM-INTERFAZ).
  static const String sttKeyConfiguredKey = 'kb_stt_key_configured';
  static const String _sttUrlKey = 'kb_stt_url';
  static const String _sttModelKey = 'kb_stt_model';
  static const String _sttLanguageKey = 'kb_stt_language';
  static const String _legacySttApiKeyPrefsKey = 'kb_stt_api_key';

  /// Migra el espejo viejo en texto plano (si existe) a secure_storage.
  /// Idempotente: la segunda llamada es no-op porque borra la clave vieja.
  /// Devuelve true si migró un valor no vacío.
  Future<bool> migrateLegacySttMirror() async {
    try {
      final prefs = await _prefs();
      final legacy = prefs.getString(_legacySttApiKeyPrefsKey);
      if (legacy == null) return false;
      final trimmed = legacy.trim();
      if (trimmed.isNotEmpty) {
        try {
          final current = await _secureStorage.read(key: secureSttApiKey);
          if (current == null || current.isEmpty) {
            await _secureStorage.write(key: secureSttApiKey, value: trimmed);
          }
        } catch (_) {
          // Sin keystore legible no se puede migrar ahora; no borrar para
          // reintentar en el próximo arranque.
          return false;
        }
      }
      await prefs.remove(_legacySttApiKeyPrefsKey);
      return trimmed.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Guarda solo la config NO sensible (url/model/language) en prefs y la
  /// key en secure_storage. Limpia cualquier resto en texto plano y publica
  /// el indicador de presencia [sttKeyConfiguredKey] (nunca la key).
  Future<void> saveSttMirror({required String apiKey}) async {
    await migrateLegacySttMirror();
    final trimmed = apiKey.trim();
    if (trimmed.isNotEmpty) {
      try {
        await _secureStorage.write(key: secureSttApiKey, value: trimmed);
      } catch (_) {
        // Frontera de canal del keystore: no crashear Ajustes; la config
        // no sensible igual queda sincronizada abajo.
        debugPrint('StorageService.saveSttMirror: secure write fallido');
      }
    }
    final prefs = await _prefs();
    await prefs.setBool(sttKeyConfiguredKey, await _hasSecureSttKey());
    await prefs.setString(_sttUrlKey, CloudSttService.endpoint);
    await prefs.setString(_sttModelKey, CloudSttService.model);
    await prefs.setString(_sttLanguageKey, CloudSttService.language);
    await prefs.remove(_legacySttApiKeyPrefsKey);
  }

  /// true si hay una key no vacía legible en secure_storage. Nunca lanza:
  /// ante keystore bloqueado se informa ausencia (el teclado avisará a
  /// Ajustes en vez de intentar un 401).
  Future<bool> _hasSecureSttKey() async {
    try {
      final current = await _secureStorage.read(key: secureSttApiKey);
      return current != null && current.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearSttMirror() async {
    try {
      await _secureStorage.delete(key: secureSttApiKey);
    } catch (_) {}
    final prefs = await _prefs();
    await prefs.setBool(sttKeyConfiguredKey, false);
    await prefs.remove(_sttUrlKey);
    await prefs.remove(_sttModelKey);
    await prefs.remove(_sttLanguageKey);
    await prefs.remove(_legacySttApiKeyPrefsKey);
  }

  // --- Snippets del teclado (K4) ---
  // Contrato compartido con el teclado nativo Kotlin: el valor de
  // [snippetsKey] es un STRING con un JSON array de objetos con claves
  // "id" (String), "nombre" (String), "contenido" (String) e "orden"
  // (int). El lado Kotlin lee estas mismas claves con prefijo "flutter.".
  static const String snippetsKey = 'voice_snippets_v1';
  static const String snippetsSeededKey = 'kb_snippets_seeded';

  int _snippetIdCounter = 0;

  /// ID unico sin dependencias externas: timestamp + contador monotono,
  /// para que llamadas rapidas seguidas nunca colisionen.
  String _nextSnippetId() {
    _snippetIdCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_snippetIdCounter';
  }

  /// Carga los snippets guardados para lecturas de UI. Ante JSON corrupto
  /// devuelve lista vacia para lecturas; las mutaciones usan _readSnippets
  /// y nunca pisan datos ilegibles.
  Future<List<Snippet>> loadSnippets() async =>
      await _readSnippets() ?? const [];

  /// Lectura interna distinguendo "vacio real" de "ilegible": devuelve
  /// null cuando el JSON esta corrupto, el tipo raiz no es lista o el canal
  /// falla (los llamadores de mutacion bloquean la escritura en ese caso).
  /// Devuelve lista (posiblemente vacia) solo cuando la lectura fue valida.
  Future<List<Snippet>?> _readSnippets() async {
    try {
      final prefs = await _prefs();
      await prefs.reload();
      final raw = prefs.getString(snippetsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return null;
      final loaded = <Snippet>[];
      final seenIds = <String>{};
      for (final item in decoded) {
        if (item is Map<dynamic, dynamic>) {
          var snippet =
              Snippet.fromJson(Map<String, dynamic>.from(item));
          // Boundary: id vacio o duplicado colapsaria reorder/delete;
          // se regenera para mantener ids unicos en esta carga.
          if (snippet.id.isEmpty || seenIds.contains(snippet.id)) {
            snippet = snippet.copyWith(id: _nextSnippetId());
          }
          seenIds.add(snippet.id);
          loaded.add(snippet);
        }
      }
      return loaded;
    } catch (_) {
      debugPrint('StorageService: lectura de snippets fallida, escritura bloqueada');
      return null;
    }
  }

  /// Serializa el JSON array ordenado por [Snippet.orden]; el orden es
  /// estable: empates conservan la posicion relativa de entrada.
  Future<void> saveSnippets(List<Snippet> snippets) async {
    final indexed = <(int, Snippet)>[
      for (var i = 0; i < snippets.length; i++) (i, snippets[i]),
    ];
    indexed.sort((a, b) {
      final byOrden = a.$2.orden.compareTo(b.$2.orden);
      return byOrden != 0 ? byOrden : a.$1.compareTo(b.$1);
    });
    final prefs = await _prefs();
    await prefs.setString(
      snippetsKey,
      jsonEncode(indexed.map((e) => e.$2.toJson()).toList()),
    );
  }

  /// Agrega un snippet al final de la lista. Devuelve false si viola los
  /// limites del contrato: nombre vacio, contenido mayor a
  /// [maxSnippetLength] caracteres o ya existen [maxSnippets] snippets.
  Future<bool> addSnippet({
    required String nombre,
    required String contenido,
  }) async {
    if (nombre.trim().isEmpty) return false;
    if (contenido.length > maxSnippetLength) return false;
    final current = await _readSnippets();
    // Lectura ilegible: bloqueada la escritura para no pisar datos.
    if (current == null) return false;
    if (current.length >= maxSnippets) return false;
    await saveSnippets([
      ...current,
      Snippet(
        id: _nextSnippetId(),
        nombre: nombre,
        contenido: contenido,
        orden: current.length,
      ),
    ]);
    return true;
  }

  /// Actualiza nombre y/o contenido del snippet con ese id. Devuelve false
  /// si el id no existe o los valores nuevos violan los limites de
  /// [addSnippet] (el snippet queda intacto en ese caso).
  Future<bool> updateSnippet(
    String id, {
    String? nombre,
    String? contenido,
  }) async {
    if (nombre != null && nombre.trim().isEmpty) return false;
    if (contenido != null && contenido.length > maxSnippetLength) {
      return false;
    }
    final current = await _readSnippets();
    if (current == null) return false;
    final index = current.indexWhere((s) => s.id == id);
    if (index == -1) return false;
    current[index] =
        current[index].copyWith(nombre: nombre, contenido: contenido);
    await saveSnippets(current);
    return true;
  }

  /// Elimina el snippet con ese id y renumera [Snippet.orden] para que
  /// quede contiguo. Devuelve false si el id no existia o la lectura fue
  /// ilegible (escritura bloqueada para no pisar datos).
  Future<bool> deleteSnippet(String id) async {
    final current = await _readSnippets();
    if (current == null) return false;
    final remaining =
        current.where((s) => s.id != id).toList(growable: false);
    if (remaining.length == current.length) return false;
    await saveSnippets([
      for (var i = 0; i < remaining.length; i++)
        remaining[i].copyWith(orden: i),
    ]);
    return true;
  }

  /// Recibe los ids en el nuevo orden deseado y reescribe [Snippet.orden]
  /// segun esa posicion. Los ids desconocidos se ignoran y los snippets no
  /// mencionados conservan su orden relativo al final de la lista. Si la
  /// lectura fue ilegible no escribe nada (no pisa datos).
  Future<void> reorderSnippets(List<String> idsInNewOrder) async {
    final current = await _readSnippets();
    if (current == null) return;
    final pending = {for (final s in current) s.id: s};
    final reordered = <Snippet>[];
    for (final id in idsInNewOrder) {
      final snippet = pending.remove(id);
      if (snippet != null) reordered.add(snippet);
    }
    reordered.addAll(pending.values);
    await saveSnippets([
      for (var i = 0; i < reordered.length; i++)
        reordered[i].copyWith(orden: i),
    ]);
  }

  /// Precarga los 5 seeds solo si nunca se sembro y ademas no hay snippets
  /// guardados. Idempotente: si el flag ya esta marcado no toca nada, asi
  /// que borrar todos los seeds manualmente no los resucita. El reload
  /// evita leer una cache Dart obsoleta por escrituras nativas de Kotlin;
  /// si la lectura es ilegible retorna sin marcar el flag ni escribir.
  Future<void> ensureSeeds() async {
    final prefs = await _prefs();
    await prefs.reload();
    if (prefs.getBool(snippetsSeededKey) ?? false) return;
    final current = await _readSnippets();
    if (current == null) return;
    if (current.isEmpty) {
      await saveSnippets(_seedSnippets);
    }
    await prefs.setBool(snippetsSeededKey, true);
  }

  /// Seeds exactos definidos por el contrato K4 (orden/nombre/contenido).
  /// IDs estables con prefijo "seed-" para que ambos lados puedan
  /// referenciarlos.
  static const List<Snippet> _seedSnippets = [
    Snippet(id: 'seed-codex', nombre: 'Codex', contenido: 'codex "', orden: 0),
    Snippet(
      id: 'seed-gemini',
      nombre: 'Gemini',
      contenido: 'gemini -p "',
      orden: 1,
    ),
    Snippet(
      id: 'seed-git-commit',
      nombre: 'Git commit',
      contenido: 'git add . && git commit -m "',
      orden: 2,
    ),
    Snippet(
      id: 'seed-git-push',
      nombre: 'Git push',
      contenido: 'git push origin main',
      orden: 3,
    ),
    Snippet(
      id: 'seed-supabase-push',
      nombre: 'Supabase push',
      contenido: 'supabase db push',
      orden: 4,
    ),
  ];

  static const String historyFileName = 'transcription_history.json';
  static const String _historyTmpSuffix = '.tmp';

  Future<File?> _getHistoryFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/$historyFileName');
    } catch (_) {
      return null;
    }
  }

  /// MÉTODOS DORMIDOS — NO LLAMAR AL ARRANCAR.
  /// Historial persistente FIFO-20 con retención (hasFragileUserData):
  /// sin purga al arrancar (ver main.dart). Se conservan solo por
  /// compatibilidad con copias viejas; otro agente decide su retirada.
  @Deprecated('No purgar: historial persistente FIFO-20 con retención.')
  Future<void> clearPreviousHistoryOnStartup() async {
    _transcriptions.clear();
    debugInvalidatePrefsCache();
    try {
      final prefs = await _prefs();
      await prefs.remove(_key);
    } catch (_) {}
    try {
      final file = await _getHistoryFile();
      if (file != null) {
        final tmp = File('${file.path}$_historyTmpSuffix');
        // Async obligado fuera del main (ANR en eMMC lentas).
        // ignore: avoid_slow_async_io
        if (await tmp.exists()) {
          await tmp.delete();
        }
        await file.writeAsString('[]', flush: true);
      }
    } catch (_) {}
  }

  /// Alias dormido (ver [clearPreviousHistoryOnStartup]): no usar.
  @Deprecated('No purgar: historial persistente FIFO-20 con retención.')
  Future<void> purgePreviousSessionHistory() =>
      clearPreviousHistoryOnStartup();

  /// Lee el archivo compartido sin lanzar. Entradas con `timestamp`
  /// presente-pero-ilegible se omiten para no contaminar con `now`
  /// (ver contrato tolerante de `Transcription.fromJson`).
  Future<List<Transcription>> _readHistoryFileEntries() async {
    try {
      final file = await _getHistoryFile();
      if (file == null) return const [];
      // Async obligado fuera del main (ver arriba).
      // ignore: avoid_slow_async_io
      if (!await file.exists()) return const [];
      final content = (await file.readAsString()).trim();
      if (content.isEmpty) return const [];
      final decoded = jsonDecode(content);
      if (decoded is! List<dynamic>) return const [];
      final out = <Transcription>[];
      for (final item in decoded) {
        if (item is! Map<dynamic, dynamic>) continue;
        final map = <String, dynamic>{};
        for (final e in item.entries) {
          final k = e.key;
          if (k is String) map[k] = e.value;
        }
        if (_isPresentButUnparseableTimestamp(map['timestamp'])) continue;
        out.add(Transcription.fromJson(map));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Transcription>> _readPrefsEntries() async {
    try {
      final prefs = await _prefs();
      await prefs.reload();
      final jsonList = prefs.getStringList(_key) ?? const <String>[];
      final out = <Transcription>[];
      for (final raw in jsonList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<dynamic, dynamic>) continue;
          final map = <String, dynamic>{};
          for (final e in decoded.entries) {
            final k = e.key;
            if (k is String) map[k] = e.value;
          }
          if (_isPresentButUnparseableTimestamp(map['timestamp'])) continue;
          out.add(Transcription.fromJson(map));
        } catch (_) {
          // Ignorar entrada corrupta
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// true solo cuando hay `timestamp` String no vacío que no parsea:
  /// es basura de disco y debe omitirse (no caer a `now`).
  /// `null`/ausente/`int`/`DateTime`/ISO válido → false (se acepta).
  static bool _isPresentButUnparseableTimestamp(Object? raw) {
    if (raw is! String) return false;
    if (raw.isEmpty) return false;
    return DateTime.tryParse(raw) == null;
  }

  static String _historyIdentity(Transcription t) =>
      '${t.timestamp.microsecondsSinceEpoch}|${t.text}';

  static bool _sameHistory(
      List<Transcription> a, List<Transcription> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (_historyIdentity(a[i]) != _historyIdentity(b[i])) return false;
    }
    return true;
  }

  /// Carga y fusiona sin escribir (para [load]/[add] sin triple escritura).
  Future<List<Transcription>> _loadMergedWithoutPersist() async {
    // Origen definitivo: archivo atómico + prefs (tests/migración).
    // Lecturas secuenciales (sin paralelismo real): el orden no importa
    // porque se reordena por timestamp descendente tras fusionar.
    final fileEntries = await _readHistoryFileEntries();
    final prefsEntries = await _readPrefsEntries();
    final loaded = [...fileEntries, ...prefsEntries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Merge conservador: la entrada en memoria que falta en disco
    // sobrevive (no pisar dictado recién añadido en un resume).
    // Dedup por identidad; ante colisión gana lo recién leído del disco.
    final byIdentity = <String, Transcription>{};
    for (final t in loaded) {
      byIdentity.putIfAbsent(_historyIdentity(t), () => t);
    }
    for (final t in _transcriptions) {
      byIdentity.putIfAbsent(_historyIdentity(t), () => t);
    }
    final merged = byIdentity.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return merged.length > maxItems ? merged.sublist(0, maxItems) : merged;
  }

  Future<void> load() async {
    final merged = await _loadMergedWithoutPersist();
    if (_sameHistory(_transcriptions, merged)) return;
    _transcriptions = merged;
    // Solo se reescribe cuando algo cambió.
    await _persist();
  }

  Future<void> add(Transcription transcription) async {
    final merged = await _loadMergedWithoutPersist();
    _transcriptions = merged;
    _transcriptions.insert(0, transcription);
    if (_transcriptions.length > maxItems) {
      _transcriptions = _transcriptions.sublist(0, maxItems);
    }
    // Una sola persistencia atómica (prefs + archivo tmp+rename).
    await _persist();
  }

  /// Una sola escritura lógica: prefs + archivo atómico.
  Future<void> _persist() async {
    await _save();
    await _saveHistoryFile();
  }

  Future<void> _save() async {
    try {
      final prefs = await _prefs();
      final jsonList =
          _transcriptions.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_key, jsonList);
    } catch (_) {}
  }

  Future<void> _saveHistoryFile() async {
    try {
      final file = await _getHistoryFile();
      if (file == null) return;
      final tmpFile = File('${file.path}$_historyTmpSuffix');
      final list = _transcriptions.map((t) => t.toJson()).toList();
      await tmpFile.writeAsString(jsonEncode(list), flush: true);
      // Async obligado fuera del main (ver arriba).
      // ignore: avoid_slow_async_io
      if (!await tmpFile.exists()) return;
      try {
        await tmpFile.rename(file.path);
      } catch (_) {
        await tmpFile.copy(file.path);
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}
