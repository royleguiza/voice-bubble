import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_stt_service.dart';

/// SttConfigStore - Almacén y sincronización modular de configuración STT (C-25).
/// Extraído de StorageService para aislar claves de API, endpoints y boveda segura.
class SttConfigStore {
  static const String sttApiKeyKey = 'stt_api_key';
  static const String sttProviderKey = 'stt_provider';
  static const String defaultSttProvider = 'groq';

  static const String secureSttApiKey = 'kb_stt_api_key_v1';
  static const String sttApiKeyMirrorKey = 'kb_stt_api_key_mirror';
  static const String sttKeyConfiguredKey = 'kb_stt_key_configured';

  static const String sttUrlKey = 'kb_stt_url';
  static const String sttModelKey = 'kb_stt_model';
  static const String sttLanguageKey = 'kb_stt_language';

  static const espOptions = AndroidOptions(encryptedSharedPreferences: true);
  static const espSecureStorage = FlutterSecureStorage(aOptions: espOptions);

  final FlutterSecureStorage _secureStorage;

  SttConfigStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? espSecureStorage;

  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  Future<String?> getSttApiKey() async {
    try {
      final key = await _secureStorage.read(key: secureSttApiKey);
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    try {
      final p = await _prefs();
      return p.getString(sttApiKeyKey);
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveSttApiKey(String apiKey) async {
    return await saveSttMirror(apiKey: apiKey);
  }

  Future<void> deleteSttApiKey() async {
    await clearSttMirror();
    try {
      final p = await _prefs();
      await p.remove(sttApiKeyKey);
    } catch (_) {}
  }

  Future<String> getSttProvider() async {
    try {
      final p = await _prefs();
      return p.getString(sttProviderKey) ?? defaultSttProvider;
    } catch (_) {
      return defaultSttProvider;
    }
  }

  Future<void> saveSttProvider(String provider) async {
    try {
      final p = await _prefs();
      await p.setString(sttProviderKey, provider);
    } catch (_) {}
  }

  Future<String> getSttUrl() async {
    try {
      final p = await _prefs();
      return p.getString(sttUrlKey) ?? CloudSttService.endpoint;
    } catch (_) {
      return CloudSttService.endpoint;
    }
  }

  Future<void> setSttUrl(String url) async {
    try {
      final p = await _prefs();
      await p.setString(sttUrlKey, url);
    } catch (_) {}
  }

  Future<bool> hasSecureSttKey() async {
    try {
      final current = await _secureStorage.read(key: secureSttApiKey);
      return current != null && current.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveSttMirror({required String apiKey}) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await clearSttMirror();
      return false;
    }

    var hasKey = false;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _secureStorage.write(key: secureSttApiKey, value: trimmed);
        final readBack = await _secureStorage.read(key: secureSttApiKey);
        if (readBack != null && readBack.trim().isNotEmpty) {
          hasKey = true;
          break;
        }
      } catch (_) {
        if (attempt == 1) {
          debugPrint('SttConfigStore.saveSttMirror: secure write fallido tras reintento');
        }
      }
    }

    var published = false;
    try {
      final prefs = await _prefs();
      final okPresence = await prefs.setBool(sttKeyConfiguredKey, hasKey);

      final currentUrl = prefs.getString(sttUrlKey);
      final okUrl = (currentUrl != null && currentUrl.trim().isNotEmpty)
          ? true
          : await prefs.setString(sttUrlKey, CloudSttService.endpoint);

      final okModel = await prefs.setString(sttModelKey, CloudSttService.model);
      final okLang = await prefs.setString(sttLanguageKey, CloudSttService.language);

      try {
        await prefs.remove(sttApiKeyMirrorKey);
      } catch (_) {}

      published = okPresence && okUrl && okModel && okLang;
    } catch (_) {
      published = false;
    }

    return hasKey && published;
  }

  Future<bool> repairSttMirror() async {
    try {
      var hasKey = await hasSecureSttKey();
      if (!hasKey) {
        final prefs = await _prefs();
        final legacyKey = prefs.getString(sttApiKeyKey);
        if (legacyKey != null && legacyKey.trim().isNotEmpty) {
          return await saveSttMirror(apiKey: legacyKey);
        }
      }

      var published = false;
      try {
        final prefs = await _prefs();
        final okPresence = await prefs.setBool(sttKeyConfiguredKey, hasKey);

        final currentUrl = prefs.getString(sttUrlKey);
        final okUrl = (currentUrl != null && currentUrl.trim().isNotEmpty)
            ? true
            : await prefs.setString(sttUrlKey, CloudSttService.endpoint);

        final okModel = await prefs.setString(sttModelKey, CloudSttService.model);
        final okLang = await prefs.setString(sttLanguageKey, CloudSttService.language);

        try {
          await prefs.remove(sttApiKeyMirrorKey);
        } catch (_) {}

        published = okPresence && okUrl && okModel && okLang;
      } catch (_) {
        published = false;
      }

      return hasKey && published;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearSttMirror() async {
    try {
      await _secureStorage.delete(key: secureSttApiKey);
    } catch (_) {}
    try {
      final prefs = await _prefs();
      await prefs.setBool(sttKeyConfiguredKey, false);
      await prefs.remove(sttApiKeyMirrorKey);
    } catch (_) {}
  }
}
