import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la API key de Google AI Studio (Gemini) con el mismo criterio que la
/// key de Groq: secure storage para el valor, SharedPreferences solo para
/// presencia y bandera de visibilidad de acciones.
class GeminiKeyStore {
  static const String secureKey = 'kb_gemini_api_key_v1';
  static const String configuredKey = 'kb_gemini_key_configured';
  static const String actionsEnabledKey = 'kb_gemini_actions_enabled';

  static const espOptions = AndroidOptions(encryptedSharedPreferences: true);
  static const espSecureStorage = FlutterSecureStorage(aOptions: espOptions);

  final FlutterSecureStorage _secureStorage;

  GeminiKeyStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? espSecureStorage;

  Future<String?> getKey() async {
    try {
      final key = await _secureStorage.read(key: secureKey);
      if (key != null && key.trim().isNotEmpty) return key.trim();
    } catch (_) {}
    return null;
  }

  Future<bool> hasKey() async {
    final key = await getKey();
    return key != null;
  }

  Future<bool> saveKey(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await clearKey();
      return false;
    }
    try {
      await _secureStorage.write(key: secureKey, value: trimmed);
      final readBack = await _secureStorage.read(key: secureKey);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(configuredKey, readBack != null && readBack.isNotEmpty);
      return readBack != null && readBack.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearKey() async {
    try {
      await _secureStorage.delete(key: secureKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(configuredKey, false);
    } catch (_) {}
  }

  Future<bool> actionsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configured = prefs.getBool(configuredKey) ?? false;
      return prefs.getBool(actionsEnabledKey) ?? configured;
    } catch (_) {
      return false;
    }
  }

  Future<void> setActionsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(actionsEnabledKey, enabled);
    } catch (_) {}
  }
}
