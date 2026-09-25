import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/screens/notes_screen.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/pending_note_queue.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

import '../helpers/mock_channels.dart';

/// C-05 en las dos pantallas que abren el microfono: el estado visual se
/// publica antes del claim y ninguna de las dos llega al recorder con el
/// microfono tomado por el teclado.
class _SharedMicGate {
  _SharedMicGate(this.order);
  final List<String> order;
  int _owner = 0;
  int _sequence = 0;

  bool get isClaimed => _owner != 0;

  int claim() {
    order.add('claim');
    if (_owner != 0) return 0;
    _sequence++;
    _owner = _sequence;
    return _sequence;
  }

  void release(int claim) {
    order.add('release');
    if (claim != 0 && claim == _owner) _owner = 0;
  }
}

class _OrderBubbleService extends FloatingBubbleService {
  _OrderBubbleService(this.order);
  final List<String> order;

  @override
  Future<bool> updateBubbleState(BubbleVisualState state) async {
    order.add('bubble:${state.name}');
    return true;
  }
}

class _OrderRecorder implements AudioRecorder {
  _OrderRecorder(this.order, {this.throwOnStop = false});
  final List<String> order;
  final bool throwOnStop;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    order.add('start');
  }

  @override
  Future<String?> stop() async {
    order.add('stop');
    if (throwOnStop) throw StateError('stop fallo');
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _HangingBubbleService extends FloatingBubbleService {
  _HangingBubbleService(this.order);
  final List<String> order;
  final Completer<bool> recording = Completer<bool>();

  @override
  Future<bool> updateBubbleState(BubbleVisualState state) async {
    order.add('bubble:${state.name}');
    if (state == BubbleVisualState.recording) return recording.future;
    return true;
  }
}

class _HangingStartRecorder implements AudioRecorder {
  _HangingStartRecorder(this.order);
  final List<String> order;
  final Completer<void> startGate = Completer<void>();
  int starts = 0;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) {
    starts++;
    order.add('start');
    return startGate.future;
  }

  @override
  Future<String?> stop() async {
    order.add('stop');
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'voice_notes_v1': '[]',
      'voice_notes_pending_v1': '[]',
    });
    FlutterSecureStorage.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('mic_exclusion_ui_');
    File('${tempDir.path}/voice_notes.json').writeAsStringSync('[]');
    registerAppChannelMocks(temporaryDirectory: tempDir.path);
  });

  tearDown(() {
    unregisterAppChannelMocks();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  TranscriptionService buildService(_SharedMicGate gate, AudioRecorder rec) {
    return TranscriptionService(
      cloudService: const CloudSttService(apiKey: 'k'),
      storageService: StorageService(),
      recorder: rec,
      claimMicrophone: () async => gate.claim(),
      releaseMicrophone: (int claim) async => gate.release(claim),
    );
  }

  group('HomeScreen y NotesScreen compiten por el mismo claim', () {
    testWidgets('Home publica el estado visual antes de tomar el claim',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _OrderRecorder(order);
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          transcriptionService: buildService(gate, recorder),
          storageService: StorageService(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(order, ['bubble:recording', 'claim', 'start']);
      expect(gate.isClaimed, isTrue);
    });

    testWidgets('Home no arranca con el microfono tomado y vuelve a idle',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _OrderRecorder(order);
      gate.claim();
      order.clear();
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          transcriptionService: buildService(gate, recorder),
          storageService: StorageService(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(order, isNot(contains('start')));
      expect(order.last, 'bubble:idle');
      expect(gate.isClaimed, isTrue);
    });

    testWidgets('Notas toma el claim tras publicar el estado visual',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _OrderRecorder(order);
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: NotesScreen(
          transcriptionService: buildService(gate, recorder),
          pendingQueue: PendingNoteQueue(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('notesMicFab')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(order, ['bubble:recording', 'claim', 'start']);
      expect(gate.isClaimed, isTrue);
      expect(find.text('Detener'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('notesMicFab')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(gate.isClaimed, isFalse);
      expect(order.last, 'bubble:idle');
    });

    testWidgets('Notas no arranca con el microfono tomado', (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _OrderRecorder(order);
      gate.claim();
      order.clear();
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: NotesScreen(
          transcriptionService: buildService(gate, recorder),
          pendingQueue: PendingNoteQueue(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('notesMicFab')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(order, isNot(contains('start')));
      expect(order.last, 'bubble:idle');
      expect(find.text('Dictar'), findsOneWidget);
      expect(gate.isClaimed, isTrue);
    });
  });

  group('Teardown de UI: una pantalla muerta no deja el microfono tomado',
      () {
    testWidgets('Home libera el microfono si desaparece grabando',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _OrderRecorder(order);
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final service = buildService(gate, recorder);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          transcriptionService: service,
          storageService: StorageService(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(gate.isClaimed, isTrue);

      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );
      await tester.pump();
      await tester.pump();

      expect(order, contains('stop'));
      expect(gate.isClaimed, isFalse);
      expect(service.hasMicrophoneClaim, isFalse);
    });

    testWidgets('Home libera el claim aunque el recorder no pueda cerrar',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _OrderRecorder(order, throwOnStop: true);
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final service = buildService(gate, recorder);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          transcriptionService: service,
          storageService: StorageService(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(gate.isClaimed, isTrue);

      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );
      await tester.pump();
      await tester.pump();

      expect(gate.isClaimed, isFalse);
      expect(service.hasMicrophoneClaim, isFalse);
    });

    testWidgets('Notas libera el microfono si desaparece grabando',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _OrderRecorder(order);
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final service = buildService(gate, recorder);
      await tester.pumpWidget(MaterialApp(
        home: NotesScreen(
          transcriptionService: service,
          pendingQueue: PendingNoteQueue(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('notesMicFab')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(gate.isClaimed, isTrue);

      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );
      await tester.pump();
      await tester.pump();

      expect(order, contains('stop'));
      expect(gate.isClaimed, isFalse);
      expect(service.hasMicrophoneClaim, isFalse);
    });

    testWidgets('Home no toma el microfono si desaparece durante el arranque',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final bubble = _HangingBubbleService(order);
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          transcriptionService: buildService(gate, _OrderRecorder(order)),
          storageService: StorageService(),
          floatingBubbleService: bubble,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump();
      await tester.pump();
      expect(order, ['bubble:recording']);

      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );
      bubble.recording.complete(true);
      await tester.pump();
      await tester.pump();

      expect(order, ['bubble:recording', 'bubble:idle']);
      expect(gate.isClaimed, isFalse);
    });

    testWidgets(
        'Home no deja el microfono tomado si desaparece con recorder.start en vuelo',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _HangingStartRecorder(order);
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final service = buildService(gate, recorder);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          transcriptionService: service,
          storageService: StorageService(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(recorder.starts, 1);
      expect(service.hasMicrophoneClaim, isTrue);

      await tester.pumpWidget(
        const MaterialApp(home: SizedBox.shrink()),
      );
      await tester.pump();
      await tester.pump();
      expect(gate.isClaimed, isFalse);

      recorder.startGate.complete();
      await tester.pump();
      await tester.pump();

      expect(gate.isClaimed, isFalse);
      expect(service.hasMicrophoneClaim, isFalse);
      expect(gate.claim(), isNot(0));
    });

    testWidgets(
        'Notas libera el microfono si el segundo toque llega con recorder.start en vuelo',
        (tester) async {
      final order = <String>[];
      final gate = _SharedMicGate(order);
      final recorder = _HangingStartRecorder(order);
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      final service = buildService(gate, recorder);
      await tester.pumpWidget(MaterialApp(
        home: NotesScreen(
          transcriptionService: service,
          pendingQueue: PendingNoteQueue(),
          floatingBubbleService: _OrderBubbleService(order),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('notesMicFab')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(recorder.starts, 1);
      expect(service.hasMicrophoneClaim, isTrue);
      expect(find.text('Detener'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('notesMicFab')));
      await tester.pump();
      await tester.pump();
      expect(order, contains('stop'));
      expect(gate.isClaimed, isFalse);

      recorder.startGate.complete();
      await tester.pump();
      await tester.pump();

      expect(gate.isClaimed, isFalse);
      expect(service.hasMicrophoneClaim, isFalse);
      expect(gate.claim(), isNot(0));
    });
  });
}
