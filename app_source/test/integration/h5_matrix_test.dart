import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/services/transcription_service.dart';
import 'package:voice_bubble_stt/widgets/record_button.dart';

/// Matriz H5-T5 (Lane A): integracion widget-level de los flujos de
/// grabacion de HomeScreen contra servicios instrumentados.
///
/// Lecciones aplicadas:
/// - 7: Clipboard/HapticFeedback viajan por SystemChannels.platform -> mock.
/// - 10: IO sincrona en los fakes (writeAsBytesSync); los futures de dart:io
///   no corren bajo fakeAsync. El cloud scripted evita todo IO real.
/// - 11: canales llfbandit mockeados en setUp aunque el recorder sea
///   inyectado (defensa ante constructores implicitos).
/// - 14: pump fijo alrededor del anillo pulsante infinito; pumpAndSettle solo
///   en reposo.
/// - 17: superficie alta en todo test que renderice HomeScreen.
class _FakeRecorder implements AudioRecorder {
  final Completer<void> postFrameApplied = Completer<void>();
  int startCount = 0;
  int stopCount = 0;
  int permissionRequestCount = 0;
  RecordConfig? lastConfig;
  String? lastPath;

  @override
  Future<bool> hasPermission({bool request = true}) async {
    permissionRequestCount += 1;
    if (!postFrameApplied.isCompleted) postFrameApplied.complete();
    return true;
  }

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startCount++;
    lastConfig = config;
    lastPath = path;
    // IO sincrona: simula que el plugin escribe el WAV PCM16 en disco.
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

/// Cloud scripted: sin HTTP ni IO real. Cada transcribe consume el siguiente
/// outcome (excepcion o transcripcion) y registra el path pedido.
class _ScriptedCloudSttService extends CloudSttService {
  final List<Object> outcomes;
  final List<String> requestedPaths = <String>[];

  _ScriptedCloudSttService(this.outcomes) : super(apiKey: 'gsk_test_key');

  @override
  Future<Transcription> transcribe(String audioPath) async {
    requestedPaths.add(audioPath);
    if (outcomes.isEmpty) {
      throw const TranscriptionException(
        'script de outcomes agotado',
        kind: TranscriptionErrorKind.unknown,
      );
    }
    final next = outcomes.removeAt(0);
    if (next is TranscriptionException) throw next;
    return next as Transcription;
  }
}

/// HomeScreen._init llama updateApiKey tras leer la key (vacia en tests) y
/// reemplazaria el cloud inyectado por un CloudSttService REAL cuyo flujo
/// hace IO asincrona (se cuelga bajo fakeAsync, leccion 10). Este stub congela
/// el cloud scripted durante toda la vida de la pantalla.
class _FrozenCloudTranscriptionService extends TranscriptionService {
  _FrozenCloudTranscriptionService({
    required super.cloudService,
    required super.storageService,
    required super.recorder,
  });

  @override
  void updateApiKey(String apiKey) {}
}

class _TrackedFloatingBubbleService extends FloatingBubbleService {
  final List<Completer<void>> _expectedIdleUpdates = <Completer<void>>[];

  Future<void> expectNextIdleUpdate() {
    final completion = Completer<void>();
    _expectedIdleUpdates.add(completion);
    return completion.future;
  }

  @override
  Future<bool> updateBubbleState(BubbleVisualState state) async {
    final result = await super.updateBubbleState(state);
    if (state == BubbleVisualState.idle && _expectedIdleUpdates.isNotEmpty) {
      _expectedIdleUpdates.removeAt(0).complete();
    }
    return result;
  }
}

class _ReadyStorageService extends StorageService {
  final Completer<void> loadCompleted = Completer<void>();
  final Completer<void> recordModeRead = Completer<void>();
  final Completer<void> floatingBubbleRead = Completer<void>();
  String? loadedMode;
  bool? loadedFloatingBubble;

  @override
  Future<bool> load() async {
    final result = await super.load();
    if (!loadCompleted.isCompleted) loadCompleted.complete();
    return result;
  }

  @override
  Future<String> loadRecordMode() async {
    final mode = await super.loadRecordMode();
    loadedMode = mode;
    if (!recordModeRead.isCompleted) recordModeRead.complete();
    return mode;
  }

  @override
  Future<bool> loadFloatingBubbleEnabled() async {
    final enabled = await super.loadFloatingBubbleEnabled();
    loadedFloatingBubble = enabled;
    if (!floatingBubbleRead.isCompleted) floatingBubbleRead.complete();
    return enabled;
  }
}

class _Bundle {
  final _FakeRecorder recorder;
  final _ScriptedCloudSttService cloud;
  final _TrackedFloatingBubbleService bubble;
  final _ReadyStorageService storage;
  final TranscriptionService service;

  _Bundle(
    this.recorder,
    this.cloud,
    this.bubble,
    this.storage,
    this.service,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  String? clipboardText;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    clipboardText = null;

    // Sync a propósito: setup/teardown con directorio real (la regla
    // avoid_slow_async_io solo observa métodos async, no estos).
    tempDir = Directory.systemTemp.createTempSync('h5_matrix_');

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // record 7.x: el constructor AudioRecorder() invoca 'create' al canal
    // (leccion 11): se mockean ambos canales llfbandit en todo caso.
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

    // Exclusion mutua K3: teclado libre.
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.royleguiza.voicebubblestt/keyboard'),
      (MethodCall call) async => false,
    );

    // getTemporaryDirectory() apunta al tmp UNICO del test.
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
      const MethodChannel('com.royleguiza.voicebubblestt/floating_bubble'),
      (MethodCall call) async => true,
    );

    // Leccion 7: store en memoria del portapapeles para poder verificarlo.
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channels = [
      'com.llfbandit.record',
      'com.llfbandit.record/messages',
      'com.royleguiza.voicebubblestt/keyboard',
      'com.royleguiza.voicebubblestt/floating_bubble',
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

    // Sync a propósito en teardown (ver arriba).
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  void pumpUntilRecordMode(
    WidgetTester tester,
    _ReadyStorageService storage,
    String mode,
  ) {
    final finder = find.byKey(const ValueKey('recordButton'));
    final button = tester.widget<RecordButton>(finder);
    final expectsHold = mode == StorageService.recordModeHold;
    expect(storage.recordModeRead.isCompleted, isTrue);
    expect(storage.loadedMode, mode);
    expect((button.onPressed == null), expectsHold);
    expect((button.onHoldStart != null), expectsHold);
    expect((button.onHoldEnd != null), expectsHold);
  }

  _Bundle makeBundle(List<Object> outcomes) {
    final recorder = _FakeRecorder();
    final cloud = _ScriptedCloudSttService(outcomes);
    final bubble = _TrackedFloatingBubbleService();
    final storage = _ReadyStorageService();
    final service = _FrozenCloudTranscriptionService(
      cloudService: cloud,
      storageService: storage,
      recorder: recorder,
    );
    return _Bundle(recorder, cloud, bubble, storage, service);
  }

  Future<void> drainAfterIdleUpdate(
    WidgetTester tester,
    Future<void> idleUpdate,
  ) async {
    await tester.runAsync(() => idleUpdate);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> pumpHome(
    WidgetTester tester,
    TranscriptionService service,
    _ReadyStorageService storage,
    _TrackedFloatingBubbleService bubble,
    _FakeRecorder recorder,
  ) async {
    // Superficie alta: contenido completo siempre construido (9.1-17/21).
    tester.view.physicalSize = const Size(1600, 4800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      // Clave unica por fase: sin ella, pumpWidget con estructura identica
      // REUTILIZA el State del HomeScreen anterior y la fase nueva hereda
      // servicios/modo de la vieja (falla de aislamiento entre fases).
      home: KeyedSubtree(
        key: UniqueKey(),
        child: HomeScreen(
          transcriptionService: service,
          storageService: storage,
          floatingBubbleService: bubble,
        ),
      ),
    ));
    await tester.pump();
    await tester.runAsync(
      () => Future.wait<void>([
        storage.loadCompleted.future,
        storage.recordModeRead.future,
        storage.floatingBubbleRead.future,
      ]),
    );
    await tester.pump();
    await tester.runAsync(() => recorder.postFrameApplied.future);
    await tester.pump();
    expect(storage.loadCompleted.isCompleted, isTrue);
    expect(storage.recordModeRead.isCompleted, isTrue);
    expect(storage.floatingBubbleRead.isCompleted, isTrue);
    expect(storage.loadedFloatingBubble, isFalse);
    expect(recorder.permissionRequestCount, 1);
  }

  group('Punto 1 - grabacion larga simulada', () {
    testWidgets(
        '~10 minutos en ticks: estados estables, sin overflow, stop exitoso guarda una sola vez',
        (tester) async {
      final bundle = makeBundle([
        Transcription(
          text: 'dictado largo exitoso',
          timestamp: DateTime.now(),
        ),
      ]);
      await pumpHome(
        tester,
        bundle.service,
        bundle.storage,
        bundle.bubble,
        bundle.recorder,
      );
      expect(find.text('Listo para transcribir'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      // Anillo pulsante infinito: pump fijo, nunca pumpAndSettle (leccion 14).
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.text('Grabando...'), findsOneWidget);

      // 20 ticks x 30 s = ~10 minutos de grabacion sostenida.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(seconds: 30));
      }
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.text('Grabando...'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(bundle.recorder.startCount, 1);
      // La config PCM16/WAV sigue intacta tras la sesion larga (leccion 13).
      expect(bundle.recorder.lastConfig?.encoder, AudioEncoder.wav);
      expect(bundle.recorder.lastConfig?.sampleRate, 16000);
      expect(bundle.recorder.lastConfig?.numChannels, 1);

      final transcriptionCompleted = bundle.bubble.expectNextIdleUpdate();
      await tester.tap(find.byKey(const ValueKey('recordButton')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await drainAfterIdleUpdate(tester, transcriptionCompleted);

      // Un solo ciclo start/stop y una sola llamada de transcripcion.
      expect(bundle.recorder.startCount, 1);
      expect(bundle.recorder.stopCount, 1);
      expect(bundle.cloud.requestedPaths.length, 1);
      expect(bundle.storage.transcriptions.length, 1);
      expect(bundle.storage.transcriptions.first.text, 'dictado largo exitoso');
      expect(find.textContaining('dictado largo exitoso'), findsOneWidget);
      expect(find.text('Grabando...'), findsNothing);
      expect(find.text('Procesando...'), findsNothing);
      // Exito borra el temporal (IO async en produccion; expect sync
      // sobre FS real aquí, a propósito).
      expect(File(bundle.cloud.requestedPaths.single).existsSync(), isFalse);
      // Sin animaciones transitorias pendientes -> sin timers colgados.
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('Punto 2 - reintento sin regrabar', () {
    testWidgets(
        'fallo de red conserva el archivo; Reintentar reusa EL MISMO path sin start/stop extra y guarda una sola transcripcion',
        (tester) async {
      final bundle = makeBundle([
        const TranscriptionException(
          'Sin conexión a internet.',
          kind: TranscriptionErrorKind.network,
        ),
        Transcription(
          text: 'segundo intento ok',
          timestamp: DateTime.now(),
        ),
      ]);
      await pumpHome(
        tester,
        bundle.service,
        bundle.storage,
        bundle.bubble,
        bundle.recorder,
      );

      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));
      final firstAttemptCompleted = bundle.bubble.expectNextIdleUpdate();
      await tester.tap(find.byKey(const ValueKey('recordButton')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await drainAfterIdleUpdate(tester, firstAttemptCompleted);

      // Primer intento: fallo de red reintentable.
      expect(find.textContaining('Sin conexión a internet'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Error, toca para reintentar'), findsOneWidget);
      final audioPath = bundle.cloud.requestedPaths.single;
      // Archivo CONSERVADO pese al fallo (premisa del reintento).
      expect(File(audioPath).existsSync(), isTrue);
      expect(bundle.recorder.startCount, 1);
      expect(bundle.recorder.stopCount, 1);

      // Reintento desde la accion del SnackBar.
      final retryCompleted = bundle.bubble.expectNextIdleUpdate();
      await tester.tap(find.text('Reintentar'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await drainAfterIdleUpdate(tester, retryCompleted);

      // NINGUN start/stop adicional: se transcribe el mismo archivo.
      expect(bundle.recorder.startCount, 1);
      expect(bundle.recorder.stopCount, 1);
      expect(bundle.cloud.requestedPaths.length, 2);
      expect(bundle.cloud.requestedPaths[1], audioPath);
      // Exito: EXACTAMENTE una transcripcion nueva en el historial.
      expect(bundle.storage.transcriptions.length, 1);
      expect(bundle.storage.transcriptions.first.text, 'segundo intento ok');
      expect(find.textContaining('segundo intento ok'), findsOneWidget);
      expect(find.text('Error, toca para reintentar'), findsNothing);
      // Exito borra el temporal y copia el texto al portapapeles.
      expect(File(audioPath).existsSync(), isFalse);
      expect(clipboardText, 'segundo intento ok');

      // El SnackBar anterior caduca con su timer: sin colgados al terminar.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('Punto 3 - modos toque/mantener persisten (UI)', () {
    testWidgets(
        "'hold' sembrado en prefs gobierna pantallas recreadas con servicios nuevos",
        (tester) async {
      // Semilla directa de la clave compartida que lee loadRecordMode.
      SharedPreferences.setMockInitialValues({'recording_mode': 'hold'});

      // --- Fase A: primera pantalla (StorageService nuevo lee 'hold').
      final bundleA = makeBundle(<Object>[]);
      await pumpHome(
        tester,
        bundleA.service,
        bundleA.storage,
        bundleA.bubble,
        bundleA.recorder,
      );
      pumpUntilRecordMode(
        tester,
        bundleA.storage,
        StorageService.recordModeHold,
      );
      expect(
        await tester.runAsync(() => bundleA.storage.loadRecordMode()),
        'hold',
      );

      // En hold, onTap esta deshabilitado: tocar NO inicia grabacion.
      final button = find.byKey(const ValueKey('recordButton'));
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(bundleA.recorder.startCount, 0);

      // Mantener presionado SI inicia (wiring onLongPressStart vivo).
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(bundleA.recorder.startCount, 1);

      // Soltar casi de inmediato: guard <300 ms descarta y limpia sin
      // transcribir (DateTime.now real: determinista en el runner).
      await gesture.up();
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(bundleA.cloud.requestedPaths, isEmpty);
      expect(bundleA.storage.transcriptions, isEmpty);
      if (bundleA.recorder.lastPath != null) {
        expect(File(bundleA.recorder.lastPath!).existsSync(), isFalse);
      }

      // --- Fase B: pantalla recreada con INSTANCIA nueva de almacenamiento.
      final bundleB = makeBundle(<Object>[]);
      await pumpHome(
        tester,
        bundleB.service,
        bundleB.storage,
        bundleB.bubble,
        bundleB.recorder,
      );
      pumpUntilRecordMode(
        tester,
        bundleB.storage,
        StorageService.recordModeHold,
      );
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);
      expect(bundleB.recorder.startCount, 0);

      // --- Fase C: volver a 'tap' persiste igual de bien.
      await tester.runAsync(
        () => bundleB.storage.saveRecordMode('tap'),
      );
      final bundleC = makeBundle([
        Transcription(
          text: 'dictado modo toque',
          timestamp: DateTime.now(),
        ),
      ]);
      await pumpHome(
        tester,
        bundleC.service,
        bundleC.storage,
        bundleC.bubble,
        bundleC.recorder,
      );
      pumpUntilRecordMode(
        tester,
        bundleC.storage,
        StorageService.defaultRecordMode,
      );

      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      await tester.tap(button);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pumpAndSettle();

      expect(bundleC.storage.transcriptions.length, 1);
      expect(bundleC.storage.transcriptions.first.text, 'dictado modo toque');
      expect(find.textContaining('dictado modo toque'), findsOneWidget);
      expect(clipboardText, 'dictado modo toque');
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
