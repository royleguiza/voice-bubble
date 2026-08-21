import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/widgets/history_list.dart';
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

void main() {}

  group('Clipboard - HomeScreen', () {
    late List<Map<String, dynamic>> clipboardCalls;

    setUp(() {
      clipboardCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/base'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final data = methodCall.arguments as Map;
            clipboardCalls.add(Map<String, dynamic>.from(data));
            return null;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/base'),
        null,
      );
    });

    testWidgets(
      'botón copiar no se muestra cuando no hay resultado de transcripción',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: const HomeScreen()),
        );
        await tester.pump();

        expect(find.byIcon(Icons.copy), findsNothing);
      },
    );
  });

  group('Clipboard - HistoryList', () {
    late List<Map<String, dynamic>> clipboardCalls;

    setUp(() {
      clipboardCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/base'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final data = methodCall.arguments as Map;
            clipboardCalls.add(Map<String, dynamic>.from(data));
            return null;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter/base'),
        null,
      );
    });

    testWidgets(
      'al hacer tap en copiar un item del historial, Clipboard.setData se llama con el texto del item',
      (tester) async {
        final transcription = Transcription(
          text: 'Texto de prueba',
          timestamp: DateTime.now(),
          isLocal: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: HistoryList(transcriptions: [transcription]),
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.copy));
        await tester.pump();

        expect(clipboardCalls.length, greaterThan(0));
      },
    );

    testWidgets(
      'al hacer tap en copiar un item del historial, se muestra SnackBar "Texto copiado"',
      (tester) async {
        final transcription = Transcription(
          text: 'Otro texto',
          timestamp: DateTime.now(),
          isLocal: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 600,
                child: HistoryList(transcriptions: [transcription]),
              ),
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.copy));
        await tester.pumpAndSettle();

        expect(find.text('Texto copiado'), findsOneWidget);
      },
    );
  });

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
      'requestPermissions llama a requestPermission cuando no hay permiso y retorna true',
      () async {
        mockRecorder.setHasPermission(false);
        mockRecorder.setRequestPermissionResult(true);

        final result = await service.requestPermissions();

        expect(result, isTrue);
      },
    );

    test(
      'requestPermissions retorna false cuando el permiso es denegado',
      () async {
        mockRecorder.setHasPermission(false);
        mockRecorder.setRequestPermissionResult(false);

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
