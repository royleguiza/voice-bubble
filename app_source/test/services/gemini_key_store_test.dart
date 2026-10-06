import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/gemini_key_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('GeminiKeyStore', () {
    test('sin key: hasKey false y getKey null', () async {
      final store = GeminiKeyStore();
      expect(await store.hasKey(), isFalse);
      expect(await store.getKey(), isNull);
    });

    test('saveKey guarda y hasKey true', () async {
      final store = GeminiKeyStore();
      expect(await store.saveKey('  AQ.test123456789  '), isTrue);
      expect(await store.hasKey(), isTrue);
      expect(await store.getKey(), 'AQ.test123456789');
    });

    test('saveKey vacío limpia', () async {
      final store = GeminiKeyStore();
      await store.saveKey('AQ.x12345678901');
      await store.saveKey('');
      expect(await store.hasKey(), isFalse);
    });

    test('clearKey elimina y marca configured false', () async {
      final store = GeminiKeyStore();
      await store.saveKey('AQ.x12345678901');
      await store.clearKey();
      expect(await store.hasKey(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(GeminiKeyStore.configuredKey), isFalse);
    });

    test('actionsEnabled default sigue configured', () async {
      final store = GeminiKeyStore();
      await store.saveKey('AQ.x12345678901');
      expect(await store.actionsEnabled(), isTrue);
      await store.setActionsEnabled(false);
      expect(await store.actionsEnabled(), isFalse);
    });
  });
}
