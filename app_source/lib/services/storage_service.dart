import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transcription.dart';
import 'cloud_stt_service.dart';

class StorageService {
  static const String _key = 'transcriptions';
  static const int _maxItems = 20;
  static const String _recordModeKey = 'recording_mode';
  static const String defaultRecordMode = 'tap';

  List<Transcription> _transcriptions = [];

  List<Transcription> get transcriptions =>
      List.unmodifiable(_transcriptions);

  /// Modo de interacción del botón: 'tap' (toque inicia/detiene)
  /// o 'hold' (mantener presionado graba, soltar transcribe).
  Future<String> loadRecordMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_recordModeKey) ?? defaultRecordMode;
  }

  Future<void> saveRecordMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordModeKey, mode);
  }

  static const String _floatingBubbleKey = 'floating_bubble_enabled';

  Future<bool> loadFloatingBubbleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingBubbleKey) ?? false;
  }

  Future<void> saveFloatingBubbleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingBubbleKey, enabled);
  }

  static const String _keyboardTerminalRowKey = 'kb_terminal_row_visible';

  /// Fila terminal del teclado (TAB, ESC, CTRL, ALT, flechas).
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardTerminalRowVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyboardTerminalRowKey) ?? true;
  }

  Future<void> saveKeyboardTerminalRowVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyboardTerminalRowKey, visible);
  }

  // --- Espejo D7: credenciales STT para el teclado nativo (K3) ---
  // El teclado Kotlin lee estas claves con prefijo "flutter." en
  // FlutterSharedPreferences. La API key vive aqui en texto plano dentro de
  // las preferencias PRIVADAS del paquete (inaccesibles para otras apps),
  // nunca en el repo ni en storage externo.
  static const String _sttProviderKey = 'kb_stt_provider';
  static const String _sttUrlKey = 'kb_stt_url';
  static const String _sttModelKey = 'kb_stt_model';
  static const String _sttApiKeyKey = 'kb_stt_api_key';

  Future<void> saveSttMirror({required String apiKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sttApiKeyKey, apiKey);
    await prefs.setString(_sttProviderKey, CloudSttService.provider);
    await prefs.setString(_sttUrlKey, CloudSttService.endpoint);
    await prefs.setString(_sttModelKey, CloudSttService.model);
    await prefs.setString('kb_stt_language', CloudSttService.language);
  }

  Future<void> clearSttMirror() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sttApiKeyKey);
    await prefs.remove(_sttProviderKey);
    await prefs.remove(_sttUrlKey);
    await prefs.remove(_sttModelKey);
    await prefs.remove('kb_stt_language');
  }

  Future<String?> loadSttMirroredApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sttApiKeyKey);
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final jsonList = prefs.getStringList(_key) ?? [];
    final loaded = <Transcription>[];
    for (final json in jsonList) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map) {
          loaded.add(
            Transcription.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } catch (_) {
        // Ignore corrupt entry gracefully
      }
    }
    _transcriptions = loaded;
  }

  Future<void> add(Transcription transcription) async {
    _transcriptions.insert(0, transcription);
    if (_transcriptions.length > _maxItems) {
      _transcriptions = _transcriptions.sublist(0, _maxItems);
    }
    await _save();
  }

  Future<void> clear() async {
    _transcriptions.clear();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList =
        _transcriptions.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }
}
