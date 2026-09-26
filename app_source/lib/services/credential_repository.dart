import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/uuid_helper.dart';

/// CredentialRepository - Repositorio modular de credenciales (C-25).
/// Separa el almacenamiento seguro (bóveda cifrada) y el índice público de StorageService.
class CredentialRepository {
  static const String credentialsKey = 'vb_credentials_v1';
  static const String credPassKey = 'vb_cred_pass_v1';
  static const String credShowUserKey = 'vb_cred_show_user';

  static const int maxCredentials = 50;
  static const int maxCredentialNameLength = 80;
  static const int maxCredentialUserLength = 120;
  static const int maxCredentialPassLength = 256;

  static const espOptions = AndroidOptions(encryptedSharedPreferences: true);
  static const espSecureStorage = FlutterSecureStorage(aOptions: espOptions);

  CredentialRepository();

  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  String nextCredentialId() => generateUuidV4();

  Future<bool> getShowUserInKeyboard() async {
    try {
      final p = await _prefs();
      return p.getBool(credShowUserKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setShowUserInKeyboard(bool show) async {
    try {
      final p = await _prefs();
      await p.setBool(credShowUserKey, show);
    } catch (_) {}
  }
}
