import 'package:shared_preferences/shared_preferences.dart';

/// PrefsBridge - Servicio modular para acceso tipado a SharedPreferences (C-25).
/// Centraliza las primitivas de lectura/escritura, validaciones de dominio y
/// la tabla de claves de contrato para el puente con Kotlin.
class PrefsBridge {
  Future<SharedPreferences> prefs() async =>
      await SharedPreferences.getInstance();

  // Primitivas seguras tipadas
  Future<bool> getBool(String key, bool def) async {
    try {
      final p = await prefs();
      final val = p.get(key);
      if (val is bool) return val;
      if (val is String) {
        final lower = val.trim().toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
      return def;
    } catch (_) {
      return def;
    }
  }

  Future<void> setBool(String key, bool value) async {
    await (await prefs()).setBool(key, value);
  }

  Future<String> getString(String key, String def) async {
    try {
      final p = await prefs();
      final val = p.get(key);
      if (val is String) return val;
      if (val != null) return val.toString();
      return def;
    } catch (_) {
      return def;
    }
  }

  Future<void> setString(String key, String value) async {
    await (await prefs()).setString(key, value);
  }

  Future<int> getInt(String key, int def) async {
    try {
      final p = await prefs();
      final val = p.get(key);
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? def;
      return def;
    } catch (_) {
      return def;
    }
  }

  Future<void> setInt(String key, int value) async {
    await (await prefs()).setInt(key, value);
  }

  Future<double> getDouble(String key, double def) async {
    try {
      final p = await prefs();
      final val = p.get(key);
      if (val is double) return val;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? def;
      return def;
    } catch (_) {
      return def;
    }
  }

  Future<void> setDouble(String key, double value) async {
    await (await prefs()).setDouble(key, value);
  }

  Future<String> getValidatedString(
      String key, List<String> valid, String def) async {
    try {
      final p = await prefs();
      final raw = p.get(key);
      final val = raw is String ? raw : raw?.toString();
      return (val != null && valid.contains(val)) ? val : def;
    } catch (_) {
      return def;
    }
  }

  Future<void> setValidatedString(
      String key, List<String> valid, String value) async {
    if (!valid.contains(value)) return;
    await (await prefs()).setString(key, value);
  }

  Future<int> getValidatedInt(String key, List<int> valid, int def) async {
    try {
      final val = await getInt(key, def);
      return valid.contains(val) ? val : def;
    } catch (_) {
      return def;
    }
  }

  Future<void> setValidatedInt(
      String key, List<int> valid, int value) async {
    if (!valid.contains(value)) return;
    await (await prefs()).setInt(key, value);
  }
}
