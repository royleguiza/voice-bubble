import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

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

  group('TranscriptionService - Permisos', () {
    late MockAudioRecorder mockRecorder;
    late TranscriptionService service;

    setUp(() {
      mockRecorder = MockAudioRecorder();
      service = TranscriptionService(
        cloudService: const CloudSttService(apiKey: ''),
        storageService: StorageService(),
        recorder: mockRecorder,
        claimMicrophone: () async => 1,
        releaseMicrophone: (int claim) async {},
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
          () => service.startRecording('/tmp/test.wav'),
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

        await service.startRecording('/tmp/test.wav');

        expect(mockRecorder.started, isTrue);
        expect(mockRecorder.lastStartedPath, '/tmp/test.wav');
      },
    );
  });
}
