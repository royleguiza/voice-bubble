import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FloatingBubbleService service;
  late List<MethodCall> log;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(FloatingBubbleService.channelName);

  setUp(() {
    log = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'canDrawOverlays':
          return true;
        case 'requestOverlayPermission':
          return true;
        case 'startBubble':
          return true;
        case 'stopBubble':
          return true;
        case 'isBubbleRunning':
          return true;
        case 'updateBubbleState':
          return true;
        case 'pushHistoryEntry':
          return true;
        case 'updateWaveformLevel':
          return null;
        default:
          return null;
      }
    });
    service = FloatingBubbleService();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('FloatingBubbleService - Method Calls', () {
    test('canDrawOverlays returns true when permitted', () async {
      final res = await service.canDrawOverlays();
      expect(res, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'canDrawOverlays');
    });

    test('canDrawOverlays handles platform errors gracefully', () async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        throw PlatformException(code: 'ERROR', message: 'Failed');
      });
      final res = await service.canDrawOverlays();
      expect(res, isFalse);
    });

    test('canDrawOverlays returns false when overlay permission denied', () async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'canDrawOverlays') return false;
        return true;
      });
      final res = await service.canDrawOverlays();
      expect(res, isFalse);
    });

    test('requestOverlayPermission returns false when user denies it', () async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'requestOverlayPermission') return false;
        return true;
      });
      final res = await service.requestOverlayPermission();
      expect(res, isFalse);
    });

    test('startBubble returns false when native start throws', () async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'startBubble') {
          throw PlatformException(code: 'START_FAILED', message: 'denied');
        }
        return true;
      });
      final res = await service.startBubble();
      expect(res, isFalse);
    });

    test('stopBubble returns false when native stop throws', () async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'stopBubble') {
          throw PlatformException(code: 'STOP_FAILED', message: 'dead');
        }
        return true;
      });
      final res = await service.stopBubble();
      expect(res, isFalse);
    });

    test('pushHistoryEntry returns false when clipboard write fails', () async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'pushHistoryEntry') {
          throw PlatformException(code: 'CLIPBOARD_FAILED', message: 'locked');
        }
        return true;
      });
      final res = await service.pushHistoryEntry('texto que no se pudo copiar');
      expect(res, isFalse);
    });

    test('pushHistoryEntry returns false when native returns null', () async {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) async => null);
      final res = await service.pushHistoryEntry('hola');
      expect(res, isFalse);
    });

    test('requestOverlayPermission invokes native method', () async {
      final res = await service.requestOverlayPermission();
      expect(res, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'requestOverlayPermission');
    });

    test('startBubble invokes native method', () async {
      final res = await service.startBubble();
      expect(res, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'startBubble');
    });

    test('stopBubble invokes native method', () async {
      final res = await service.stopBubble();
      expect(res, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'stopBubble');
    });

    test('isBubbleRunning returns correct status', () async {
      final res = await service.isBubbleRunning();
      expect(res, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'isBubbleRunning');
    });

    test('updateBubbleState sends correct enum name strings', () async {
      await service.updateBubbleState(BubbleVisualState.recording);
      expect(log.last.method, 'updateBubbleState');
      expect(log.last.arguments, {'state': 'recording'});

      await service.updateBubbleState(BubbleVisualState.transcribing);
      expect(log.last.method, 'updateBubbleState');
      expect(log.last.arguments, {'state': 'transcribing'});

      await service.updateBubbleState(BubbleVisualState.idle);
      expect(log.last.method, 'updateBubbleState');
      expect(log.last.arguments, {'state': 'idle'});
    });
  });

  group('FloatingBubbleService - Callbacks from Platform', () {
    test('onBubbleTap callback is triggered when platform calls onBubbleTap',
        () async {
      bool tapped = false;
      service.onBubbleTap = () {
        tapped = true;
      };

      await messenger.handlePlatformMessage(
        FloatingBubbleService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onBubbleTap'),
        ),
        (ByteData? data) {},
      );

      expect(tapped, isTrue);
    });

    test('onBubbleClose callback is triggered when platform calls onBubbleClose',        () async {
      bool closed = false;
      service.onBubbleClose = () {
        closed = true;
      };

      await messenger.handlePlatformMessage(
        FloatingBubbleService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onBubbleClose'),
        ),
        (ByteData? data) {},
      );

      expect(closed, isTrue);
    });

    test('onBubbleCancel callback is triggered when platform calls onBubbleCancel',
        () async {
      bool cancelled = false;
      service.onBubbleCancel = () {
        cancelled = true;
      };

      await messenger.handlePlatformMessage(
        FloatingBubbleService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onBubbleCancel'),
        ),
        (ByteData? data) {},
      );

      expect(cancelled, isTrue);
    });

    test('pushHistoryEntry sends text to native history', () async {
      final res = await service.pushHistoryEntry('hola mundo');
      expect(res, isTrue);
      expect(log.last.method, 'pushHistoryEntry');
      expect(log.last.arguments, {'text': 'hola mundo'});
    });

    test('updateWaveformLevel sends clamped level without throwing', () async {
      await service.updateWaveformLevel(0.5);
      expect(log.last.method, 'updateWaveformLevel');
      expect(log.last.arguments, {'level': 0.5});
      await service.updateWaveformLevel(9.9);
      expect(log.last.arguments, {'level': 1.0});
    });
  });
}
