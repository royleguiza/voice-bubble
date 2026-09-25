import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/screens/notes_screen.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/pending_note_queue.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';

/// Integración del flujo C1–C7: offline → cola → tap → éxito → nota.
/// Lecciones: 7 (platform mock), 10 (IO sync en fakes), 11 (canales record),
/// 14 (pump fijo con anillo), 17 (superficie alta), keys no copy.

class _FakeRecorder implements AudioRecorder {
  int startCount = 0;
  int stopCount = 0;
  RecordConfig? lastConfig;
  String? lastPath;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startCount++;
    lastConfig = config;
    lastPath = path;
    File(path).writeAsBytesSync(List<int>.filled(2048, 0x61));
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    return lastPath;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ScriptedCloudSttService extends CloudSttService {
  final List<Object> outcomes;
  final List<String> requestedPaths = <String>[];

  _ScriptedCloudSttService(this.outcomes) : super(apiKey: 'gsk_test_key');

  @override
  Future<Transcription> transcribe(String audioPath) async {
    requestedPaths.add(audioPath);
    if (outcomes.isEmpty) {
      throw const TranscriptionException(
        'script agotado',
        kind: TranscriptionErrorKind.unknown,
      );
    }
    final next = outcomes.removeAt(0);
    if (next is TranscriptionException) throw next;
    return next as Transcription;
  }
}

class _FrozenCloudTranscriptionService extends TranscriptionService {
  _FrozenCloudTranscriptionService({
    required super.cloudService,
    required super.storageService,
    required super.recorder,
  });

  @override
  void updateApiKey(String apiKey) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'notes_deferred_queue_enabled': true,
      'voice_notes_v1': '[]',
      'voice_notes_pending_v1': '[]',
    });
    FlutterSecureStorage.setMockInitialValues({});

    tempDir = Directory.systemTemp.createTempSync('pending_flow_');
    File('${tempDir.path}/voice_notes.json').writeAsStringSync('[]');

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    for (final channel in [
      'com.llfbandit.record',
      'com.llfbandit.record/messages',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall call) async {
          if (call.method.toLowerCase().contains('permission')) return true;
          return null;
        },
      );
    }

    messenger.setMockMethodCallHandler(
      const MethodChannel('com.royleguiza.voicebubblestt/keyboard'),
      (MethodCall call) async {
        if (call.method == 'claimMicrophone') return 1;
        if (call.method == 'releaseMicrophone') return true;
        return false;
      },
    );

    for (final channel in [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall call) async => tempDir.path,
      );
    }

    messenger.setMockMethodCallHandler(
      const MethodChannel('com.royleguiza.voicebubblestt/widget'),
      (MethodCall call) async => null,
    );

    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async => null,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channels = [
      'com.llfbandit.record',
      'com.llfbandit.record/messages',
      'com.royleguiza.voicebubblestt/keyboard',
      'com.royleguiza.voicebubblestt/widget',
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
    ];
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpNotes(
    WidgetTester tester,
    TranscriptionService service,
    PendingNoteQueue queue,
  ) async {
    tester.view.physicalSize = const Size(1600, 4800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: KeyedSubtree(
        key: UniqueKey(),
        child: NotesScreen(
          transcriptionService: service,
          pendingQueue: queue,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'offline encola; tap Transcribir con nube crea nota y limpia cola',
      (tester) async {
    final recorder = _FakeRecorder();
    final cloud = _ScriptedCloudSttService([
      const TranscriptionException(
        'Sin conexión a internet.',
        kind: TranscriptionErrorKind.network,
      ),
      Transcription(
        text: 'dictado offline luego nube',
        timestamp: DateTime.now(),
      ),
    ]);
    final service = _FrozenCloudTranscriptionService(
      cloudService: cloud,
      storageService: StorageService(),
      recorder: recorder,
    );
    final queue = PendingNoteQueue();
    await pumpNotes(tester, service, queue);

    expect(find.byKey(const ValueKey('notesMicFab')), findsOneWidget);
    expect(find.byKey(const ValueKey('pendingNotesList')), findsNothing);

    // Grabar y detener → fallo de red → encolar.
    await tester.tap(find.byKey(const ValueKey('notesMicFab')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('notesMicFab')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(
      find.textContaining('audio guardado en Notas'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pendingNotesList')), findsOneWidget);
    expect(queue.items.length, 1);
    expect(queue.audioExists(queue.items.first), isTrue);
    // Temp del dictado no duplicado en cola.
    expect(
      File(cloud.requestedPaths.single).existsSync(),
      isFalse,
    );

    // Tocar "Transcribir con nube" → éxito → nota + cola vacía.
    final btn = find.byKey(
      ValueKey('transcribeCloudButton-${queue.items.first.id}'),
    );
    expect(btn, findsOneWidget);
    // Dejar caducar el SnackBar de encolado (4s) para no interferir con
    // el resto del flujo (el estado funcional es la aserción de éxito).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('audio guardado en Notas'), findsNothing);

    await tester.tap(btn);
    // Cadena async: secure-storage → transcribe → add → remove → widgets.
    // Suficientes pumps para que la nota y la cola queden en su estado final
    // sin depender del timing del SnackBar (frágil bajo fakeAsync).
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(cloud.requestedPaths.length, 2);
    expect(queue.items, isEmpty);
    expect(find.byKey(const ValueKey('pendingNotesList')), findsNothing);
    expect(
      find.textContaining('dictado offline luego nube'),
      findsOneWidget,
    );
    // Drenar timers del SnackBar de éxito para no dejar colgados.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('flag OFF: fallo de red no encola (comportamiento actual)',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'notes_deferred_queue_enabled': false,
    });
    final recorder = _FakeRecorder();
    final cloud = _ScriptedCloudSttService([
      const TranscriptionException(
        'Sin conexión a internet.',
        kind: TranscriptionErrorKind.network,
      ),
    ]);
    final service = _FrozenCloudTranscriptionService(
      cloudService: cloud,
      storageService: StorageService(),
      recorder: recorder,
    );
    final queue = PendingNoteQueue();
    await pumpNotes(tester, service, queue);

    await tester.tap(find.byKey(const ValueKey('notesMicFab')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('notesMicFab')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(find.byKey(const ValueKey('pendingNotesList')), findsNothing);
    expect(queue.items, isEmpty);
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('UI no presenta estado vacío cuando la lectura es corrupta',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'notes_deferred_queue_enabled': true,
      'voice_notes_v1': '{bad',
      'voice_notes_pending_v1': '{bad',
    });
    File('${tempDir.path}/voice_notes.json').writeAsStringSync('{bad');
    final recorder = _FakeRecorder();
    final cloud = _ScriptedCloudSttService([]);
    final service = _FrozenCloudTranscriptionService(
      cloudService: cloud,
      storageService: StorageService(),
      recorder: recorder,
    );
    final queue = PendingNoteQueue();
    await pumpNotes(tester, service, queue);

    expect(find.byKey(const ValueKey('notesStatus')), findsOneWidget);
    expect(find.text('Notas no disponibles'), findsOneWidget);
    expect(find.text('Sin notas'), findsNothing);
    expect(find.text('0 / 50'), findsNothing);
  });

  testWidgets('auth no encola aunque el flag esté ON', (tester) async {
    final recorder = _FakeRecorder();
    final cloud = _ScriptedCloudSttService([
      const TranscriptionException(
        'API key de Groq no configurada.',
        kind: TranscriptionErrorKind.auth,
      ),
    ]);
    final service = _FrozenCloudTranscriptionService(
      cloudService: cloud,
      storageService: StorageService(),
      recorder: recorder,
    );
    final queue = PendingNoteQueue();
    await pumpNotes(tester, service, queue);

    await tester.tap(find.byKey(const ValueKey('notesMicFab')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('notesMicFab')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(queue.items, isEmpty);
    expect(find.byKey(const ValueKey('pendingNotesList')), findsNothing);
  });
}
