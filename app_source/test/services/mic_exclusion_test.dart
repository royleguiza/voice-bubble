import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

import '../helpers/mock_channels.dart';

/// Gate compartido por todos los entrypoints (imita `BackgroundWork`: CAS con
/// token; 0 = microfono ocupado; un token obsoleto no libera el actual).
class _FakeMicGate {
  _FakeMicGate([this.order = <String>[]]);
  final List<String> order;
  int _owner = 0;
  int _sequence = 0;
  int claims = 0;
  int releases = 0;

  bool get isClaimed => _owner != 0;

  int claim() {
    claims++;
    order.add('claim');
    if (_owner != 0) return 0;
    _sequence++;
    _owner = _sequence;
    return _sequence;
  }

  void release(int claim) {
    releases++;
    order.add('release');
    if (claim != 0 && claim == _owner) _owner = 0;
  }
}

class _ScriptedRecorder implements AudioRecorder {
  _ScriptedRecorder([this.order]);
  final List<String>? order;
  int startCount = 0;
  bool permission = true;
  bool throwOnStart = false;
  void Function()? onStart;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    order?.add('permission');
    return permission;
  }

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    if (throwOnStart) throw StateError('start fallo');
    startCount++;
    order?.add('start');
    onStart?.call();
  }

  @override
  Future<String?> stop() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Exclusion mutua de microfono (C-05): claim atomico compartido por
/// teclado, widget, burbuja y Notas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    registerRecordChannelMocks();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record'), null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'), null);
    messenger.setMockMethodCallHandler(
      const MethodChannel(KeyboardService.channelName), null);
  });

  TranscriptionService buildService({
    _FakeMicGate? gate,
    AudioRecorder? recorder,
  }) {
    return TranscriptionService(
      cloudService: const CloudSttService(apiKey: 'k'),
      storageService: StorageService(),
      recorder: recorder ?? AudioRecorder(),
      claimMicrophone: gate == null ? null : () async => gate.claim(),
      releaseMicrophone:
          gate == null ? null : (int claim) async => gate.release(claim),
    );
  }

  group('Exclusion mutua de microfono', () {
    test('bloquea el inicio cuando el claim esta tomado', () async {
      final gate = _FakeMicGate();
      final recorder = _ScriptedRecorder();
      gate.claim();
      final service = buildService(gate: gate, recorder: recorder);

      await expectLater(
        service.startRecording('/tmp/no-debe-llegar.wav'),
        throwsA(isA<TranscriptionException>()),
      );
      expect(recorder.startCount, 0);
    });

    test('el error de ocupacion es descriptivo', () async {
      final gate = _FakeMicGate();
      gate.claim();
      final service = buildService(gate: gate);

      await expectLater(
        service.startRecording('/tmp/x.wav'),
        throwsA(
          isA<TranscriptionException>().having(
            (e) => e.message,
            'message',
            contains('teclado'),
          ),
        ),
      );
    });

    test('permite grabar cuando el microfono esta libre', () async {
      final gate = _FakeMicGate();
      final service = buildService(gate: gate);

      await service.startRecording('/tmp/libre.wav');
      expect(gate.isClaimed, isTrue);
      await service.stopRecording();
      expect(gate.isClaimed, isFalse);
    });

    test('el claim se toma inmediatamente antes de recorder.start', () async {
      final order = <String>[];
      final gate = _FakeMicGate(order);
      final recorder = _ScriptedRecorder(order);
      final service = buildService(gate: gate, recorder: recorder);

      await service.startRecording('/tmp/orden.wav');

      expect(order, ['permission', 'claim', 'start']);
      await service.stopRecording();
    });

    test('el claim propio ya excluye al rival en el instante del start',
        () async {
      final gate = _FakeMicGate();
      final recorder = _ScriptedRecorder();
      var roboEnElStart = -1;
      recorder.onStart = () {
        roboEnElStart = gate.claim();
      };
      final service = buildService(gate: gate, recorder: recorder);

      await service.startRecording('/tmp/arranque.wav');

      expect(roboEnElStart, 0);
      expect(recorder.startCount, 1);
      await service.stopRecording();
    });

    test('carrera burbuja vs Notas: un solo ganador llega a recorder.start',
        () async {
      final gate = _FakeMicGate();
      final recorder = _ScriptedRecorder();
      final burbuja = buildService(gate: gate, recorder: recorder);
      final notas = buildService(gate: gate, recorder: recorder);
      final resultado = <String>[];

      await Future.wait([
        () async {
          try {
            await burbuja.startRecording('/tmp/burbuja.wav');
            resultado.add('burbuja');
          } on TranscriptionException {
            resultado.add('bloqueada');
          }
        }(),
        () async {
          try {
            await notas.startRecording('/tmp/notas.wav');
            resultado.add('notas');
          } on TranscriptionException {
            resultado.add('bloqueada');
          }
        }(),
      ]);

      expect(resultado.where((r) => r == 'bloqueada').length, 1);
      expect(recorder.startCount, 1);
      await burbuja.stopRecording();
      await notas.stopRecording();
      expect(gate.isClaimed, isFalse);
    });

    test('sin permiso no toca el claim ni deja el microfono tomado', () async {
      final gate = _FakeMicGate();
      final recorder = _ScriptedRecorder()..permission = false;
      final service = buildService(gate: gate, recorder: recorder);

      await expectLater(
        service.startRecording('/tmp/sin-permiso.wav'),
        throwsA(isA<TranscriptionException>()),
      );
      expect(gate.claims, 0);
      expect(gate.isClaimed, isFalse);
      expect(gate.claim(), isNot(0));
    });

    test('libera el claim si recorder.start lanza', () async {
      final gate = _FakeMicGate();
      final recorder = _ScriptedRecorder()..throwOnStart = true;
      final service = buildService(gate: gate, recorder: recorder);

      await expectLater(
        service.startRecording('/tmp/start-roto.wav'),
        throwsA(isA<StateError>()),
      );
      expect(gate.isClaimed, isFalse);
      expect(gate.releases, 1);
      expect(gate.claim(), isNot(0));
    });

    test('libera el claim al cancelar sin cerrar el recorder', () async {
      final gate = _FakeMicGate();
      final service = buildService(gate: gate, recorder: _ScriptedRecorder());

      await service.startRecording('/tmp/cancelable.wav');
      expect(service.hasMicrophoneClaim, isTrue);
      await service.releaseMicrophoneClaim();
      expect(gate.isClaimed, isFalse);
      expect(service.hasMicrophoneClaim, isFalse);
    });

    test('un token obsoleto no libera el claim de otro', () async {
      final gate = _FakeMicGate();
      final service = buildService(gate: gate, recorder: _ScriptedRecorder());

      await service.startRecording('/tmp/primero.wav');
      await service.stopRecording();
      final segundo = gate.claim();
      expect(segundo, isNot(0));

      gate.release(1);
      expect(gate.isClaimed, isTrue);
      gate.release(segundo);
      expect(gate.isClaimed, isFalse);
    });

    test('claim por canal nativo y release con el mismo token', () async {
      final liberaciones = <int>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel(KeyboardService.channelName),
        (MethodCall call) async {
          if (call.method == 'claimMicrophone') return 7;
          if (call.method == 'releaseMicrophone') {
            final args = call.arguments as Map<Object?, Object?>;
            liberaciones.add(args['claim']! as int);
            return true;
          }
          return null;
        },
      );
      final service = buildService(recorder: _ScriptedRecorder());

      await service.startRecording('/tmp/canal.wav');
      await service.stopRecording();
      expect(liberaciones, [7]);
    });

    test('sin canal nativo falla cerrado: la burbuja no puede grabar sola',
        () async {
      final primero = buildService(recorder: _ScriptedRecorder());
      final segundo = buildService(recorder: _ScriptedRecorder());

      await expectLater(
        primero.startRecording('/tmp/local-1.wav'),
        throwsA(isA<TranscriptionException>()),
      );
      await expectLater(
        segundo.startRecording('/tmp/local-2.wav'),
        throwsA(isA<TranscriptionException>()),
      );
    });

    test('un canal que lanza no deja un microfono irrecuperable', () async {
      var canalVivo = false;
      final liberaciones = <int>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel(KeyboardService.channelName),
        (MethodCall call) async {
          if (!canalVivo) throw MissingPluginException('sin implementacion');
          if (call.method == 'claimMicrophone') return 4;
          if (call.method == 'releaseMicrophone') {
            final args = call.arguments as Map<Object?, Object?>;
            liberaciones.add(args['claim']! as int);
            return true;
          }
          return null;
        },
      );
      final service = buildService(recorder: _ScriptedRecorder());

      await expectLater(
        service.startRecording('/tmp/caido-1.wav'),
        throwsA(isA<TranscriptionException>()),
      );
      expect(service.hasMicrophoneClaim, isFalse);

      canalVivo = true;
      await service.startRecording('/tmp/caido-2.wav');
      expect(service.hasMicrophoneClaim, isTrue);
      await service.stopRecording();
      expect(liberaciones, [4]);
      expect(service.hasMicrophoneClaim, isFalse);
    });
  });
}
