import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/credential.dart';
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
  static const int maxCredentials = 50;
  static const int maxCredentialNameLength = 80;
  static const int maxCredentialUserLength = 120;
  static const int maxCredentialPassLength = 256;
  static const String recordModeHold = 'hold';

  // --- Rangos centralizados (única fuente; la UI no re-clampea) ---
  // Trackpad: sensibilidad 0.5..2.5.
  static const double minTrackpadSensitivity = 0.5;
  static const double maxTrackpadSensitivity = 2.5;
  static double clampTrackpadSensitivity(double v) =>
      v.clamp(minTrackpadSensitivity, maxTrackpadSensitivity);

  final FlutterSecureStorage _secureStorage;

  /// Bóveda única (SPK-02): flutter_secure_storage con ESP activado. El IME
  /// nativo lee el MISMO archivo vía SecureStore.kt (APIs públicas AndroidX);
  /// por eso TODOS los call sites usan esta instancia y jamás el default.
  /// La activación auto-migra el formato viejo al abrirla (lo hace upstream).
  static const espOptions = AndroidOptions(encryptedSharedPreferences: true);
  static const espSecureStorage = FlutterSecureStorage(aOptions: espOptions);

  StorageService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? espSecureStorage;

  Future<SharedPreferences> _prefs() async {
    return await SharedPreferences.getInstance();
  }

  // --- Puente tipado SPK-07: 4 primitivas + validadas (única vía de
  // acceso a prefs planas; cada clave nueva usa estas y entra en
  // [bridgeKeys], que el master verifica contra contract-keys.txt) ---
  Future<bool> _getBool(String key, bool def) async =>
      (await _prefs()).getBool(key) ?? def;
  Future<void> _setBool(String key, bool value) async {
    await (await _prefs()).setBool(key, value);
  }

  Future<String> _getString(String key, String def) async =>
      (await _prefs()).getString(key) ?? def;
  Future<void> _setString(String key, String value) async {
    await (await _prefs()).setString(key, value);
  }

  Future<int> _getInt(String key, int def) async =>
      (await _prefs()).getInt(key) ?? def;
  Future<void> _setInt(String key, int value) async {
    await (await _prefs()).setInt(key, value);
  }

  Future<double> _getDouble(String key, double def) async =>
      (await _prefs()).getDouble(key) ?? def;
  Future<void> _setDouble(String key, double value) async {
    await (await _prefs()).setDouble(key, value);
  }

  /// Lectura validada contra dominio: valor ausente o inválido cae al
  /// default (nunca null, nunca basura en el IME).
  Future<String> _getValidatedString(
          String key, List<String> valid, String def) async {
    final val = (await _prefs()).getString(key);
    return valid.contains(val) ? val! : def;
  }

  Future<void> _setValidatedString(
      String key, List<String> valid, String value) async {
    if (!valid.contains(value)) return;
    await (await _prefs()).setString(key, value);
  }

  Future<int> _getValidatedInt(String key, List<int> valid, int def) async {
    final val = (await _prefs()).getInt(key);
    return valid.contains(val) ? val! : def;
  }

  Future<void> _setValidatedInt(
      String key, List<int> valid, int value) async {
    if (!valid.contains(value)) return;
    await (await _prefs()).setInt(key, value);
  }

  List<Transcription> _transcriptions = [];

  List<Transcription> get transcriptions =>
      List.unmodifiable(_transcriptions);

  /// Modo de interaccion del boton: [defaultRecordMode] (toque inicia/detiene)
  /// o [recordModeHold] (mantener presionado graba, soltar transcribe).
  Future<String> loadRecordMode() =>
      _getString(_recordModeKey, defaultRecordMode);

  Future<void> saveRecordMode(String mode) =>
      _setString(_recordModeKey, mode);

  static const String _floatingBubbleKey = 'floating_bubble_enabled';

  Future<bool> loadFloatingBubbleEnabled() =>
      _getBool(_floatingBubbleKey, false);

  Future<void> saveFloatingBubbleEnabled(bool enabled) =>
      _setBool(_floatingBubbleKey, enabled);

  static const String _bubbleHistoryKey = 'bubble_history_enabled';

  /// Modal de historial de la burbuja clásica (hito B1–B7, default ON).
  /// El servicio nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadBubbleHistoryEnabled() =>
      _getBool(_bubbleHistoryKey, true);

  Future<void> saveBubbleHistoryEnabled(bool enabled) =>
      _setBool(_bubbleHistoryKey, enabled);

  /// Tema de la app (rediseño v2, pedido del dueño): 'sistema' (default,
  /// sigue al sistema), 'claro' u 'oscuro'. SOLO Dart: no entra en
  /// [bridgeKeys] ni en contract-keys.txt (el IME no la lee).
  static const String themeModeKey = 'theme_mode';
  static const List<String> themeModes = ['sistema', 'claro', 'oscuro'];
  static const String defaultThemeMode = 'sistema';

  Future<String> loadThemeMode() =>
      _getValidatedString(themeModeKey, themeModes, defaultThemeMode);

  Future<void> saveThemeMode(String mode) =>
      _setValidatedString(themeModeKey, themeModes, mode);

  static const String _keyboardTerminalRowKey = 'kb_terminal_row_visible';

  /// Fila terminal del teclado (TAB, ESC, CTRL, ALT, flechas).
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardTerminalRowVisible() =>
      _getBool(_keyboardTerminalRowKey, true);

  Future<void> saveKeyboardTerminalRowVisible(bool visible) =>
      _setBool(_keyboardTerminalRowKey, visible);

  static const String _keyboardCodeKeyVisibleKey = 'kb_code_key_visible';

  /// Tecla </> que abre la capa de simbolos de programacion.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardCodeKeyVisible() =>
      _getBool(_keyboardCodeKeyVisibleKey, true);

  Future<void> saveKeyboardCodeKeyVisible(bool visible) =>
      _setBool(_keyboardCodeKeyVisibleKey, visible);

  static const String _keyboardLanguageKeyVisibleKey =
      'kb_language_key_visible';

  /// Tecla ES/EN junto a la barra espaciadora para cambiar el idioma.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardLanguageKeyVisible() =>
      _getBool(_keyboardLanguageKeyVisibleKey, true);

  Future<void> saveKeyboardLanguageKeyVisible(bool visible) =>
      _setBool(_keyboardLanguageKeyVisibleKey, visible);

  static const String _keyboardCredentialsKeyVisibleKey =
      'kb_credentials_key_visible';

  /// Llavecita de credenciales en la barra superior del teclado.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  /// Default true (visible, conducta histórica).
  Future<bool> loadKeyboardCredentialsKeyVisible() =>
      _getBool(_keyboardCredentialsKeyVisibleKey, true);

  Future<void> saveKeyboardCredentialsKeyVisible(bool visible) =>
      _setBool(_keyboardCredentialsKeyVisibleKey, visible);

  static const String kbClipboardImagesEnabledKey =
      'kb_clipboard_images_enabled';

  /// SPK-10: imágenes del portapapeles opt-in (texto primero). Default OFF.
  /// El IME lo lee con prefijo "flutter." (ver KeyboardPrefs).
  Future<bool> getClipboardImagesEnabled() =>
      _getBool(kbClipboardImagesEnabledKey, false);

  Future<void> setClipboardImagesEnabled(bool enabled) =>
      _setBool(kbClipboardImagesEnabledKey, enabled);

  static const String notesDeferredQueueKey = 'notes_deferred_queue_enabled';

  /// Cola diferida cloud en Notas (C1–C7, plan-notas-cola-nube.md).
  /// Compartida con el widget nativo (WidgetDictationService encola en
  /// offline): entra al puente y al contrato. Default OFF hasta
  /// verificación en dispositivo.
  Future<bool> loadNotesDeferredQueueEnabled() =>
      _getBool(notesDeferredQueueKey, false);

  Future<void> saveNotesDeferredQueueEnabled(bool enabled) =>
      _setBool(notesDeferredQueueKey, enabled);

  /// Cola de audios pendientes (JSON array `{id,audioPath,createdAtMs}`).
  /// Fuente del valor: `PendingNoteQueue.pendingKey`; se duplica aquí
  /// como const para entrar a [bridgeKeys] (el master exige que cada
  /// ident del puente exista en este archivo). La escribe Dart
  /// (PendingNoteQueue) y el widget Kotlin; nadie la lee en el IME.
  static const String notesPendingKey = 'voice_notes_pending_v1';

  static const String kbHeightProfileKey = 'kb_height_profile';
  static const String kbHapticsEnabledKey = 'kb_haptics_enabled';
  static const String kbBottomElevationDpKey = 'kb_bottom_elevation_dp';
  static const String kbInvertToolbarKey = 'kb_invert_toolbar';

  static const int defaultBottomElevationDp = 24;

  Future<int> getBottomElevationDp() =>
      _getInt(kbBottomElevationDpKey, defaultBottomElevationDp);

  Future<void> setBottomElevationDp(int dp) =>
      _setInt(kbBottomElevationDpKey, dp);

  Future<bool> getInvertToolbar() => _getBool(kbInvertToolbarKey, false);

  Future<void> setInvertToolbar(bool invert) =>
      _setBool(kbInvertToolbarKey, invert);

  static const String kbSpacebarAlignmentKey = 'kb_spacebar_alignment';
  static const String defaultSpacebarAlignment = 'center'; // left, center, right

  Future<String> getSpacebarAlignment() =>
      _getString(kbSpacebarAlignmentKey, defaultSpacebarAlignment);

  Future<void> setSpacebarAlignment(String alignment) =>
      _setString(kbSpacebarAlignmentKey, alignment);

  static const String kbSpacebarTrackpadModeKey = 'kb_spacebar_trackpad_mode';
  static const String defaultSpacebarTrackpadMode = 'ios_2d'; // ios_2d, gboard_horizontal
  static const List<String> kbSpacebarTrackpadModes = ['ios_2d', 'gboard_horizontal'];

  Future<String> getSpacebarTrackpadMode() => _getValidatedString(
      kbSpacebarTrackpadModeKey,
      kbSpacebarTrackpadModes, defaultSpacebarTrackpadMode);

  Future<void> setSpacebarTrackpadMode(String mode) =>
      _setValidatedString(
          kbSpacebarTrackpadModeKey, kbSpacebarTrackpadModes, mode);

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
  Future<String> getHeightProfile() => _getValidatedString(
      kbHeightProfileKey, kbHeightProfiles, defaultHeightProfile);

  Future<void> setHeightProfile(String profile) => _setValidatedString(
      kbHeightProfileKey, kbHeightProfiles, profile);

  /// Vibracion hapatica al pulsar teclas. El teclado nativo Kotlin lee esta
  /// misma clave con prefijo "flutter.".
  Future<bool> getHapticsEnabled() => _getBool(kbHapticsEnabledKey, true);

  Future<void> setHapticsEnabled(bool enabled) =>
      _setBool(kbHapticsEnabledKey, enabled);

  static const String kbHapticStyleKey = 'kb_haptic_style';

  /// Estilo háptico de teclas, de más nítido a más suave.
  static const List<String> kbHapticStyles = [
    'nitido',
    'firme',
    'suave',
  ];
  static const String defaultHapticStyle = 'nitido';

  /// Estilo del feedback háptico al pulsar teclas: 'nitido' (clic seco),
  /// 'firme' o 'suave'. El teclado nativo Kotlin lee esta misma clave con
  /// prefijo "flutter.". Un valor ausente o invalido cae al por defecto.
  Future<String> getHapticStyle() => _getValidatedString(
      kbHapticStyleKey, kbHapticStyles, defaultHapticStyle);

  Future<void> setHapticStyle(String style) => _setValidatedString(
      kbHapticStyleKey, kbHapticStyles, style);

  /// Micrófono: feedback independiente de la vibración de teclas.
  /// El teclado nativo Kotlin lee estas claves con prefijo "flutter.".
  static const String kbMicHapticsEnabledKey = 'kb_mic_haptics_enabled';
  static const String kbMicHapticStartKey = 'kb_mic_haptic_start';
  static const String kbMicHapticRecordingKey = 'kb_mic_haptic_recording';
  static const String kbMicHapticPasteKey = 'kb_mic_haptic_paste';
  static const String kbMicHapticCancelKey = 'kb_mic_haptic_cancel';
  static const String kbMicSoundsEnabledKey = 'kb_mic_sounds_enabled';

  Future<bool> getMicHapticsEnabled() =>
      _getBool(kbMicHapticsEnabledKey, true);
  Future<void> setMicHapticsEnabled(bool v) =>
      _setBool(kbMicHapticsEnabledKey, v);
  Future<bool> getMicHapticStart() => _getBool(kbMicHapticStartKey, true);
  Future<void> setMicHapticStart(bool v) =>
      _setBool(kbMicHapticStartKey, v);
  Future<bool> getMicHapticRecording() =>
      _getBool(kbMicHapticRecordingKey, true);
  Future<void> setMicHapticRecording(bool v) =>
      _setBool(kbMicHapticRecordingKey, v);
  Future<bool> getMicHapticPaste() => _getBool(kbMicHapticPasteKey, true);
  Future<void> setMicHapticPaste(bool v) =>
      _setBool(kbMicHapticPasteKey, v);
  Future<bool> getMicHapticCancel() => _getBool(kbMicHapticCancelKey, true);
  Future<void> setMicHapticCancel(bool v) =>
      _setBool(kbMicHapticCancelKey, v);
  Future<bool> getMicSoundsEnabled() =>
      _getBool(kbMicSoundsEnabledKey, false);
  Future<void> setMicSoundsEnabled(bool v) =>
      _setBool(kbMicSoundsEnabledKey, v);

  /// Estilo de sonido de inicio/fin (opciones '1'..'4', default '3').
  /// El teclado nativo resuelve el recurso `mic_start_N` / `mic_stop_N` en res/raw.
  static const String kbMicStartStyleKey = 'kb_mic_start_style';
  static const String kbMicStopStyleKey = 'kb_mic_stop_style';
  static const List<String> kbMicSoundStyles = ['1', '2', '3', '4'];
  static const String defaultMicSoundStyle = '3';

  Future<String> getMicStartStyle() => _getValidatedString(
      kbMicStartStyleKey, kbMicSoundStyles, defaultMicSoundStyle);
  Future<void> setMicStartStyle(String v) =>
      _setValidatedString(kbMicStartStyleKey, kbMicSoundStyles, v);
  Future<String> getMicStopStyle() => _getValidatedString(
      kbMicStopStyleKey, kbMicSoundStyles, defaultMicSoundStyle);
  Future<void> setMicStopStyle(String v) =>
      _setValidatedString(kbMicStopStyleKey, kbMicSoundStyles, v);

  static const String kbKeySpacingKey = 'kb_key_spacing';

  /// Espaciado entre teclas anti-fantasma, de menor a mayor.
  static const List<String> kbKeySpacings = [
    'compacto',
    'normal',
    'amplio',
    'extra',
  ];
  static const String defaultKeySpacing = 'normal';

  /// Separación entre teclas: 'compacto', 'normal', 'amplio' o 'extra'.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter."
  /// y escala solo los gaps (las alturas las dueña el perfil de altura).
  /// Un valor ausente o invalido cae al perfil por defecto.
  Future<String> getKeySpacing() => _getValidatedString(
      kbKeySpacingKey, kbKeySpacings, defaultKeySpacing);

  Future<void> setKeySpacing(String spacing) => _setValidatedString(
      kbKeySpacingKey, kbKeySpacings, spacing);

  /// Menús de pulsación larga MEJ-05 (símbolos y tildes sin cambiar de capa).
  /// El teclado nativo Kotlin lee estas claves con prefijo "flutter.".
  static const String kbLongPressSymbolsKey = 'kb_long_press_symbols';
  static const String kbLongPressDelayKey = 'kb_long_press_delay';

  /// Retardos de long-press, de más rápido a más relajado.
  static const List<String> kbLongPressDelays = [
    'rapido',
    'normal',
    'relajado',
  ];
  static const String defaultLongPressDelay = 'normal';
  static const bool defaultLongPressSymbols = true;

  /// Switch de menús de pulsación larga (default ON, sin cambio de conducta
  /// al actualizar: antes siempre estaban activos los acentos).
  Future<bool> getLongPressSymbolsEnabled() =>
      _getBool(kbLongPressSymbolsKey, defaultLongPressSymbols);

  Future<void> setLongPressSymbolsEnabled(bool enabled) =>
      _setBool(kbLongPressSymbolsKey, enabled);

  /// Retardo del long-press: 'rapido' (250ms), 'normal' (350ms, default) o
  /// 'relajado' (450ms). Valor ausente o inválido cae al por defecto.
  Future<String> getLongPressDelay() => _getValidatedString(
      kbLongPressDelayKey, kbLongPressDelays, defaultLongPressDelay);

  Future<void> setLongPressDelay(String delay) => _setValidatedString(
      kbLongPressDelayKey, kbLongPressDelays, delay);

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

  static const bool defaultTrackpadEnabled = false;
  static const bool defaultTrackpadToolbarVisible = false;
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

  Future<bool> getTrackpadEnabled() =>
      _getBool(kbTrackpadEnabledKey, defaultTrackpadEnabled);

  Future<void> setTrackpadEnabled(bool enabled) =>
      _setBool(kbTrackpadEnabledKey, enabled);

  Future<bool> getTrackpadToolbarVisible() =>
      _getBool(kbTrackpadToolbarVisibleKey, defaultTrackpadToolbarVisible);

  Future<void> setTrackpadToolbarVisible(bool visible) =>
      _setBool(kbTrackpadToolbarVisibleKey, visible);

  Future<String> getTrackpadButtonLayout() => _getValidatedString(
      kbTrackpadButtonLayoutKey,
      kbTrackpadButtonLayouts, defaultTrackpadButtonLayout);

  Future<void> setTrackpadButtonLayout(String layout) =>
      _setValidatedString(
          kbTrackpadButtonLayoutKey, kbTrackpadButtonLayouts, layout);

  Future<String> getTrackpadScrollPosition() => _getValidatedString(
      kbTrackpadScrollPositionKey,
      kbTrackpadScrollPositions, defaultTrackpadScrollPosition);

  Future<void> setTrackpadScrollPosition(String position) =>
      _setValidatedString(
          kbTrackpadScrollPositionKey, kbTrackpadScrollPositions, position);

  Future<double> getTrackpadSensitivity() async {
    final raw = await _getDouble(
        kbTrackpadSensitivityKey, defaultTrackpadSensitivity);
    return clampTrackpadSensitivity(raw);
  }

  Future<void> setTrackpadSensitivity(double sensitivity) =>
      _setDouble(kbTrackpadSensitivityKey,
          clampTrackpadSensitivity(sensitivity));

  Future<String> getTrackpadAccelCurve() => _getValidatedString(
      kbTrackpadAccelCurveKey,
      kbTrackpadAccelCurves, defaultTrackpadAccelCurve);

  Future<void> setTrackpadAccelCurve(String curve) => _setValidatedString(
      kbTrackpadAccelCurveKey, kbTrackpadAccelCurves, curve);

  Future<bool> getTrackpadTapToClick() =>
      _getBool(kbTrackpadTapToClickKey, defaultTrackpadTapToClick);

  Future<void> setTrackpadTapToClick(bool enabled) =>
      _setBool(kbTrackpadTapToClickKey, enabled);

  Future<String> getTrackpadSecondaryClick() => _getValidatedString(
      kbTrackpadSecondaryClickKey,
      kbTrackpadSecondaryClicks, defaultTrackpadSecondaryClick);

  Future<void> setTrackpadSecondaryClick(String mode) =>
      _setValidatedString(
          kbTrackpadSecondaryClickKey, kbTrackpadSecondaryClicks, mode);

  Future<String> getTrackpadScrollDirection() => _getValidatedString(
      kbTrackpadScrollDirectionKey,
      kbTrackpadScrollDirections, defaultTrackpadScrollDirection);

  Future<void> setTrackpadScrollDirection(String direction) =>
      _setValidatedString(
          kbTrackpadScrollDirectionKey, kbTrackpadScrollDirections, direction);

  Future<String> getTrackpadHaptic() => _getValidatedString(
      kbTrackpadHapticKey, kbTrackpadHaptics, defaultTrackpadHaptic);

  Future<void> setTrackpadHaptic(String haptic) => _setValidatedString(
      kbTrackpadHapticKey, kbTrackpadHaptics, haptic);

  Future<String> getTrackpadPointerStyle() => _getValidatedString(
      kbTrackpadPointerStyleKey,
      kbTrackpadPointerStyles, defaultTrackpadPointerStyle);

  Future<void> setTrackpadPointerStyle(String style) => _setValidatedString(
      kbTrackpadPointerStyleKey, kbTrackpadPointerStyles, style);

  Future<int> getTrackpadAutoReturn() => _getValidatedInt(
      kbTrackpadAutoReturnKey,
      kbTrackpadAutoReturns, defaultTrackpadAutoReturn);

  Future<void> setTrackpadAutoReturn(int seconds) => _setValidatedInt(
      kbTrackpadAutoReturnKey, kbTrackpadAutoReturns, seconds);

  static const String widgetMicPositionKey = 'widget_mic_position';
  static const List<String> widgetMicPositions = ['left', 'right'];
  static const String defaultWidgetMicPosition = 'right';

  Future<String> getWidgetMicPosition() => _getValidatedString(
      widgetMicPositionKey, widgetMicPositions, defaultWidgetMicPosition);

  Future<void> setWidgetMicPosition(String pos) => _setValidatedString(
      widgetMicPositionKey, widgetMicPositions, pos);

  /// Tabla del contrato puente SPK-07: EXACTAMENTE las claves de
  /// docs/contract-keys.txt (lo que Kotlin lee con prefijo "flutter.").
  /// Fuente única del lado Dart (referencia los const de arriba, sin
  /// literales duplicados); el master la verifica contra el contrato y
  /// el CI contra Kotlin. Clave nueva = entrar aquí + contrato + Kotlin.
  static const String notesKey = 'voice_notes_v1';

  static const List<String> bridgeKeys = [
    _bubbleHistoryKey,
    kbBottomElevationDpKey,
    kbClipboardImagesEnabledKey,
    _keyboardCodeKeyVisibleKey,
    _keyboardCredentialsKeyVisibleKey,
    kbHapticsEnabledKey,
    kbHapticStyleKey,
    kbHeightProfileKey,
    kbInvertToolbarKey,
    _keyboardLanguageKeyVisibleKey,
    kbKeySpacingKey,
    kbLongPressDelayKey,
    kbLongPressSymbolsKey,
    kbMicHapticCancelKey,
    kbMicHapticPasteKey,
    kbMicHapticRecordingKey,
    kbMicHapticStartKey,
    kbMicHapticsEnabledKey,
    kbMicSoundsEnabledKey,
    kbMicStartStyleKey,
    kbMicStopStyleKey,
    notesDeferredQueueKey,
    notesPendingKey,
    snippetsSeededKey,
    kbSpacebarAlignmentKey,
    kbSpacebarTrackpadModeKey,
    sttApiKeyMirrorKey,
    _sttLanguageKey,
    _sttModelKey,
    _sttUrlKey,
    _keyboardTerminalRowKey,
    kbTrackpadAccelCurveKey,
    kbTrackpadAutoReturnKey,
    kbTrackpadButtonLayoutKey,
    kbTrackpadEnabledKey,
    kbTrackpadHapticKey,
    kbTrackpadPointerStyleKey,
    kbTrackpadScrollDirectionKey,
    kbTrackpadScrollPositionKey,
    kbTrackpadSecondaryClickKey,
    kbTrackpadSensitivityKey,
    kbTrackpadTapToClickKey,
    kbTrackpadToolbarVisibleKey,
    widgetMicPositionKey,
    _key,
    credPassKey,
    credShowUserKey,
    credentialsKey,
    notesKey,
    snippetsKey,
  ];

  // --- Config STT para el teclado nativo (K3) + bóveda (SPK-02) ---
  // Contrato único: docs/contrato-stt.md (bóveda groq_api_key + prefs
  // planas url/model/language/presencia; legado kb_stt_api_key prohibido).
  static const String secureSttApiKey = 'groq_api_key';

  /// Indicador de presencia de API key (bool en prefs, jamás la key).
  /// true = hay key legible en secure_storage; false/ausente = no hay.
  /// El teclado nativo lo puede leer como "flutter.kb_stt_key_configured".
  static const String sttKeyConfiguredKey = 'kb_stt_key_configured';
  static const String _sttUrlKey = 'kb_stt_url';
  static const String _sttModelKey = 'kb_stt_model';
  static const String _sttLanguageKey = 'kb_stt_language';

  /// Legado pre-SPK-02: espejo plano de la key en prefs. Solo se LEE para
  /// limpieza (el IME también lo migra por su cuenta); PROHIBIDO escribir.
  static const String sttApiKeyMirrorKey = 'kb_stt_api_key';

  /// Compat: repara presencia/config desde la bóveda y limpia el legado.
  /// Devuelve true si al salir hay key no vacía en la bóveda.
  Future<bool> migrateLegacySttMirror() => repairSttMirror();

  /// Publica presencia + url/model/language desde la bóveda (fuente de
  /// verdad) y borra el espejo plano legado si sobrevive. Idempotente.
  /// Nunca pisa la bóveda (solo la lee). Devuelve true si hay key.
  Future<bool> repairSttMirror() async {
    try {
      final secure = await _secureStorage.read(key: secureSttApiKey);
      final hasKey = secure != null && secure.trim().isNotEmpty;
      final prefs = await _prefs();
      try {
        await prefs.setBool(sttKeyConfiguredKey, hasKey);
        await prefs.setString(_sttUrlKey, CloudSttService.endpoint);
        await prefs.setString(_sttModelKey, CloudSttService.model);
        await prefs.setString(_sttLanguageKey, CloudSttService.language);
        await prefs.remove(sttApiKeyMirrorKey);
      } catch (_) {}
      return hasKey;
    } catch (_) {
      return false;
    }
  }

  /// Guarda la key en la bóveda (fuente única para app e IME), más la
  /// config no sensible y la presencia. Si viene vacía, solo limpia el
  /// legado plano (el borrado explícito va en [clearSttMirror]).
  Future<void> saveSttMirror({required String apiKey}) async {
    final trimmed = apiKey.trim();
    if (trimmed.isNotEmpty) {
      try {
        await _secureStorage.write(key: secureSttApiKey, value: trimmed);
      } catch (_) {
        // Frontera del keystore: no crashear Ajustes; presencia dirá la
        // verdad abajo (fail-fast honesto en el teclado).
        debugPrint('StorageService.saveSttMirror: secure write fallido');
      }
    }
    final prefs = await _prefs();
    await prefs.setBool(sttKeyConfiguredKey, await _hasSecureSttKey());
    await prefs.setString(_sttUrlKey, CloudSttService.endpoint);
    await prefs.setString(_sttModelKey, CloudSttService.model);
    await prefs.setString(_sttLanguageKey, CloudSttService.language);
    try {
      await prefs.remove(sttApiKeyMirrorKey);
    } catch (_) {}
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
    await prefs.remove(sttApiKeyMirrorKey);
  }

  // --- Snippets del teclado (K4) ---
  // Contrato compartido con el teclado nativo Kotlin: el valor de
  // [snippetsKey] es un STRING con un JSON array de objetos con claves
  // "id" (String), "nombre" (String), "contenido" (String) e "orden"
  // (int). Opcional aditivo: "color" (String, id de paleta de 6; solo se
  // escribe si tiene valor). El lado Kotlin lee estas mismas claves con
  // prefijo "flutter.".
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
  /// [color] es opcional: id de la paleta fija de 6 (null = default).
  Future<bool> addSnippet({
    required String nombre,
    required String contenido,
    String? color,
  }) async {
    if (nombre.trim().isEmpty) return false;
    if (contenido.length > maxSnippetLength) return false;
    if (color != null && !kSnippetColorIds.contains(color)) return false;
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
        color: color,
      ),
    ]);
    return true;
  }

  /// Actualiza nombre, contenido y/o color del snippet con ese id. Devuelve
  /// false si el id no existe o los valores nuevos violan los limites de
  /// [addSnippet] (el snippet queda intacto en ese caso). Para limpiar el
  /// color usar [clearColor] (o [color] no nulo para establecerlo).
  Future<bool> updateSnippet(
    String id, {
    String? nombre,
    String? contenido,
    String? color,
    bool clearColor = false,
  }) async {
    if (nombre != null && nombre.trim().isEmpty) return false;
    if (contenido != null && contenido.length > maxSnippetLength) {
      return false;
    }
    if (color != null && !kSnippetColorIds.contains(color)) return false;
    final current = await _readSnippets();
    if (current == null) return false;
    final index = current.indexWhere((s) => s.id == id);
    if (index == -1) return false;
    final nextColor = clearColor ? null : color ?? current[index].color;
    // copyWith usa sentinel: null explícito castearía nombre/contenido a
    // String. Forzar keep; color siempre se envía (set/clear/keep).
    final base = current[index];
    current[index] = base.copyWith(
      nombre: nombre ?? base.nombre,
      contenido: contenido ?? base.contenido,
      color: nextColor,
    );
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

  /// Lee el archivo compartido sin lanzar. Entradas con `timestamp`
  /// presente-pero-ilegible se omiten para no contaminar con `now`
  /// (ver contrato tolerante de `Transcription.fromJson`).
  Future<List<Transcription>> _readHistoryFileEntries() async {
    try {
      final file = await _getHistoryFile();
      if (file == null) return const [];
      if (!file.existsSync()) return const [];
      final content = file.readAsStringSync().trim();
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
      try {
        await prefs.reload();
      } catch (_) {}
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

  // --- Credenciales para relleno desde el teclado ---
  // Contrato compartido con el teclado nativo Kotlin:
  // - [credentialsKey]: STRING en prefs planas con JSON array
  //   [{id, nombre, usuario}] (solo identificadores: la contraseña JAMAS
  //   va en el índice; nombre/usuario ya se muestran en la UI).
  // - [credPassKey]: STRING con JSON objeto {id: password}, SOLO en la
  //   bóveda ([espSecureStorage], SPK-02). El IME la lee vía SecureStore.kt.
  // - [credShowUserKey]: BOOL en prefs planas (default false).
  // La UI nunca relee passwords: sin ojo, sin edición.
  static const String credentialsKey = 'vb_credentials_v1';
  static const String credPassKey = 'vb_cred_pass_v1';
  static const String credShowUserKey = 'vb_cred_show_user';

  int _credentialIdCounter = 0;

  String _nextCredentialId() {
    _credentialIdCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_credentialIdCounter';
  }

  Future<List<VbCredential>> loadCredentials() async =>
      await _readCredentials() ?? const [];

  Future<List<VbCredential>?> _readCredentials() async {
    try {
      final prefs = await _prefs();
      await prefs.reload();
      final raw = prefs.getString(credentialsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return null;
      final loaded = <VbCredential>[];
      final seenIds = <String>{};
      for (final item in decoded) {
        if (item is Map<dynamic, dynamic>) {
          var cred =
              VbCredential.fromJson(Map<String, dynamic>.from(item));
          if (cred.id.isEmpty || seenIds.contains(cred.id)) {
            cred = cred.copyWith(id: _nextCredentialId());
          }
          seenIds.add(cred.id);
          loaded.add(cred);
        }
      }
      return loaded;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _readPassMap() async {
    try {
      var raw = await _secureStorage.read(key: credPassKey);
      if (raw == null || raw.isEmpty) {
        raw = await _migratePlainPassMap();
      }
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map<dynamic, dynamic>) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  /// Migración única pre-SPK-02: mapa plano → bóveda. Idempotente: si no
  /// hay legado devuelve null y el llamador opera sobre la bóveda vacía.
  Future<String?> _migratePlainPassMap() async {
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(credPassKey);
      if (raw == null || raw.isEmpty) return null;
      await _secureStorage.write(key: credPassKey, value: raw);
      await prefs.remove(credPassKey);
      return raw;
    } catch (_) {
      return null;
    }
  }

  /// Guarda nombre+usuario+contraseña. La contraseña solo se escribe:
  /// no existe lectura de vuelta en la UI. Devuelve false si viola
  /// límites o la lectura está ilegible (no pisa datos).
  Future<bool> addCredential({
    required String nombre,
    required String usuario,
    required String password,
  }) async {
    if (nombre.trim().isEmpty || usuario.trim().isEmpty || password.isEmpty) {
      return false;
    }
    if (nombre.length > maxCredentialNameLength ||
        usuario.length > maxCredentialUserLength ||
        password.length > maxCredentialPassLength) {
      return false;
    }
    final current = await _readCredentials();
    if (current == null) return false;
    if (current.length >= maxCredentials) return false;
    final id = _nextCredentialId();
    final prefs = await _prefs();
    await prefs.setString(
      credentialsKey,
      jsonEncode([
        ...current.map((c) => c.toJson()),
        VbCredential(id: id, nombre: nombre, usuario: usuario).toJson(),
      ]),
    );
    final passes = await _readPassMap();
    passes[id] = password;
    await _secureStorage.write(key: credPassKey, value: jsonEncode(passes));
    return true;
  }

  /// Borra por id el índice Y su contraseña. Sin edición: ante un error
  /// se borra y se crea de nuevo.
  Future<bool> deleteCredential(String id) async {
    final current = await _readCredentials();
    if (current == null) return false;
    final remaining =
        current.where((c) => c.id != id).toList(growable: false);
    if (remaining.length == current.length) return false;
    final prefs = await _prefs();
    await prefs.setString(
      credentialsKey,
      jsonEncode(remaining.map((c) => c.toJson()).toList()),
    );
    final passes = await _readPassMap();
    passes.remove(id);
    await _secureStorage.write(key: credPassKey, value: jsonEncode(passes));
    return true;
  }

  Future<bool> loadCredShowUser() async {
    final prefs = await _prefs();
    return prefs.getBool(credShowUserKey) ?? false;
  }

  Future<void> saveCredShowUser(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(credShowUserKey, value);
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
      tmpFile.writeAsStringSync(jsonEncode(list), flush: true);
      if (tmpFile.existsSync()) {
        try {
          tmpFile.renameSync(file.path);
        } catch (_) {
          tmpFile.copySync(file.path);
          try {
            tmpFile.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
