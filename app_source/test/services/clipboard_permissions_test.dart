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
  Future<bool> hasPermission() async => _hasPermissionValue;

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
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
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
}
