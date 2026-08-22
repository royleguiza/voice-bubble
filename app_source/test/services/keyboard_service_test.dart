import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(KeyboardService.channelName);

  late List<MethodCall> log;

  setUp(() {
    log = <MethodCall>[];
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mockKeyboardChannel({
    bool? enabled,
    bool? selected,
    bool openResult = true,
    bool failAll = false,
  }) {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      log.add(call);
      if (failAll) {
        throw PlatformException(code: 'MOCK_ERROR');
      }
      switch (call.method) {
        case 'isKeyboardEnabled':
          return enabled;
        case 'isKeyboardSelected':
          return selected;
        case 'openKeyboardSettings':
          return openResult;
        default:
          return null;
      }
    });
  }

  group('KeyboardService', () {
    test('channel name es el esperado', () {
      expect(
        KeyboardService.channelName,
        'com.royleguiza.voicebubblestt/keyboard',
      );
    });

    test('isKeyboardEnabled devuelve true cuando el nativo responde true',
        () async {
      mockKeyboardChannel(enabled: true, selected: false);
      final service = KeyboardService();
      expect(await service.isKeyboardEnabled(), isTrue);
      expect(log.single.method, 'isKeyboardEnabled');
    });

    test('isKeyboardEnabled devuelve false cuando el nativo responde false',
        () async {
      mockKeyboardChannel(enabled: false, selected: false);
      final service = KeyboardService();
      expect(await service.isKeyboardEnabled(), isFalse);
    });

    test('isKeyboardSelected refleja el estado del sistema', () async {
      mockKeyboardChannel(enabled: true, selected: true);
      final service = KeyboardService();
      expect(await service.isKeyboardSelected(), isTrue);
      expect(log.single.method, 'isKeyboardSelected');
    });

    test('openKeyboardSettings invoca el metodo correcto', () async {
      mockKeyboardChannel();
      final service = KeyboardService();
      expect(await service.openKeyboardSettings(), isTrue);
      expect(log.single.method, 'openKeyboardSettings');
    });

    test('devuelve false si el nativo lanza error (defensivo)', () async {
      mockKeyboardChannel(failAll: true);
      final service = KeyboardService();
      expect(await service.isKeyboardEnabled(), isFalse);
      expect(await service.isKeyboardSelected(), isFalse);
      expect(await service.openKeyboardSettings(), isFalse);
    });

    test('devuelve false sin handler registrado (MissingPluginException)',
        () async {
      final service = KeyboardService();
      expect(await service.isKeyboardEnabled(), isFalse);
      expect(await service.isKeyboardSelected(), isFalse);
      expect(await service.openKeyboardSettings(), isFalse);
    });
  });
}
