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

    test('onBubbleClose callback is triggered when platform calls onBubbleClose',
        () async {
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
  });
}
