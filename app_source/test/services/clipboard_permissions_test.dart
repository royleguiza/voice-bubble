import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/local_stt_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

class MockAudioRecorder implements AudioRecorder {
  bool _hasPermissionValue = false;
  String? _lastStartedPath;
  bool _started = false;

  void setHasPermission(bool value) => _hasPermissionValue = value;

  String? get lastStartedPath => _lastStartedPath;
  bool get started => _started;

  @override
  Future<bool> hasPermission({bool request = true}) async => _hasPermissionValue;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    _lastStartedPath = path;
    _started = true;
  }

  @override
  Future<String?> stop() async {
    _started = false;
    return _lastStartedPath;
  }

  @override
  Future<bool> isRecording() async => _started;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> cancel() async {
    _started = false;
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Backend en memoria para Clipboard: el canal flutter/platform no tiene
  // implementación nativa en tests y sin mock getData() devuelve null.
  String? clipboardStore;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          clipboardStore = (call.arguments as Map)['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, String?>{'text': clipboardStore};
        default:
          return null;
      }
    },
  );

  group('TranscriptionService - Permisos', () {
    late MockAudioRecorder mockRecorder;
    late TranscriptionService service;

    setUp(() {
      mockRecorder = MockAudioRecorder();
      service = TranscriptionService(
        cloudService: const CloudSttService(apiKey: ''),
        localService: LocalSttService(),
        storageService: StorageService(),
        recorder: mockRecorder,
      );
    });

    test(
      'requestPermissions retorna true cuando el permiso ya fue otorgado',
      () async {
        mockRecorder.setHasPermission(true);

        final result = await service.requestPermissions();

        expect(result, isTrue);
      },
    );

    test(
      'requestPermissions retorna false cuando no hay permiso',
      () async {
        mockRecorder.setHasPermission(false);

        final result = await service.requestPermissions();

        expect(result, isFalse);
      },
    );

    test(
      'startRecording lanza TranscriptionException cuando no hay permiso',
      () async {
        mockRecorder.setHasPermission(false);

        expect(
          () => service.startRecording('/tmp/test.m4a'),
          throwsA(
            isA<TranscriptionException>().having(
              (e) => e.message,
              'message',
              contains('Permiso de micrófono denegado'),
            ),
          ),
        );
      },
    );

    test(
      'startRecording llama a start del recorder cuando hay permiso',
      () async {
        mockRecorder.setHasPermission(true);

        await service.startRecording('/tmp/test.m4a');

        expect(mockRecorder.started, isTrue);
        expect(mockRecorder.lastStartedPath, '/tmp/test.m4a');
      },
    );
  });

  group('Clipboard Service & Channels', () {
    test('Clipboard.setData guarda texto y Clipboard.getData lo recupera', () async {
      const testText = 'Texto de transcripción para portapapeles';
      await Clipboard.setData(const ClipboardData(text: testText));

      final result = await Clipboard.getData(Clipboard.kTextPlain);
      expect(result?.text, testText);
    });

    test('Clipboard maneja texto con caracteres especiales y acentos', () async {
      const complexText = 'Acentos: áéíóú ñ, emojis: 🎤🚀, comillas: "test"';
      await Clipboard.setData(const ClipboardData(text: complexText));

      final result = await Clipboard.getData(Clipboard.kTextPlain);
      expect(result?.text, complexText);
    });

    test('Clipboard maneja texto vacío', () async {
      await Clipboard.setData(const ClipboardData(text: ''));

      final result = await Clipboard.getData(Clipboard.kTextPlain);
      expect(result?.text, '');
    });
  });
}
