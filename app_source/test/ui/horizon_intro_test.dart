// Animación Horizonte (design.md §15): Inicio se construye debajo desde el
// primer cuadro, la capa se desmonta al terminar, un toque la saltea, el
// arranque no se repite en el mismo proceso, no aparece con reducir
// movimiento, respeta el presupuesto (≤ 120 partículas, TextPainter
// acotados) y aterriza exactamente sobre el agujero del botón de dictar.
// Además: versión corta al volver de Ajustes y salida con «atrás».
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/main.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/models/voice_note.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/screens/note_editor_screen.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/notes_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/ui/design_tokens.dart';
import 'package:voice_bubble_stt/ui/horizon_intro.dart';

import '../helpers/mock_channels.dart';

/// Notas en memoria que cuentan cuándo se pidió la carga.
class _CountingNotes extends NotesService {
  int loads = 0;

  @override
  Future<bool> load() async {
    loads++;
    return true;
  }

  @override
  List<VoiceNote> get notes => const [];

  @override
  List<VoiceNote> search(String query) => const [];
}

/// Una nota: permite abrir el editor y el menú de acciones.
class _OneNote extends _CountingNotes {
  static final VoiceNote note = VoiceNote(
    id: 'n1',
    titulo: 'Nota de prueba',
    cuerpo: 'cuerpo',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  List<VoiceNote> get notes => [note];

  @override
  List<VoiceNote> search(String query) => [note];
}

class _MemoryHistory extends StorageService {
  @override
  Future<bool> load() async => true;

  @override
  List<Transcription> get transcriptions => const [];
}

const _introKey = ValueKey('horizonIntro');
const _exitKey = ValueKey('horizonExit');
const _recordKey = ValueKey('recordButton');

/// Duración nominal del arranque en frío.
final Duration _total = kIntroSwallow + kIntroLand;

/// Duración nominal de la versión corta (volver de Ajustes).
final Duration _totalReturn = kIntroSwallowReturn + kIntroLand;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    registerAppChannelMocks();
    HorizonIntroHost.debugResetColdStart();
  });

  tearDown(unregisterAppChannelMocks);

  void phone(WidgetTester tester, {double width = 411, double height = 891}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget host({
    _CountingNotes? notes,
    bool enabled = true,
    Brightness brightness = Brightness.light,
  }) {
    return MaterialApp(
      theme:
          brightness == Brightness.light ? buildLightTheme() : buildDarkTheme(),
      home: HorizonIntroHost(
        enabled: enabled,
        homeBuilder: (holeKey) => HomeScreen(
          holeKey: holeKey,
          notesService: notes ?? _CountingNotes(),
          storageService: _MemoryHistory(),
        ),
      ),
    );
  }

  /// Avanza cuadros de 16 ms hasta que la capa se va; devuelve cuántos.
  Future<int> pumpUntilGone(WidgetTester tester, {int maxFrames = 200}) async {
    var frames = 0;
    while (find.byKey(_introKey).evaluate().isNotEmpty && frames < maxFrames) {
      await tester.pump(const Duration(milliseconds: 16));
      frames++;
    }
    return frames;
  }

  group('Arranque: carga y ciclo de vida', () {
    testWidgets('por defecto VoiceBubbleApp no muestra el arranque',
        (tester) async {
      await tester.pumpWidget(const VoiceBubbleApp());
      expect(find.byKey(_introKey), findsNothing);
      expect(find.byType(HorizonIntroHost), findsNothing);
      // No reclamó el arranque del proceso.
      expect(HorizonIntroHost.coldStartPending, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Inicio se construye en el primer cuadro con el arranque encima '
        '(VoiceBubbleApp(showIntro: true))', (tester) async {
      phone(tester);
      await tester.pumpWidget(const VoiceBubbleApp(showIntro: true));
      // Un solo cuadro: Inicio ya está armado debajo de la capa.
      expect(find.byKey(_introKey), findsOneWidget);
      expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
      expect(find.byKey(_recordKey), findsOneWidget);
      expect(find.byKey(const ValueKey('horizonIntroCanvas')), findsOneWidget);
      await pumpUntilGone(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(_introKey), findsNothing);
      expect(find.byKey(const ValueKey('recordIdle')), findsOneWidget);
    });

    testWidgets(
        'la carga de notas arranca en el primer cuadro, sin esperar '
        'a la animación', (tester) async {
      phone(tester);
      final notes = _CountingNotes();
      await tester.pumpWidget(host(notes: notes));
      expect(find.byKey(_introKey), findsOneWidget);
      expect(notes.loads, 1);
      await pumpUntilGone(tester);
    });

    testWidgets('la capa se desmonta al terminar, en ≈ 1,75 s', (tester) async {
      phone(tester);
      await tester.pumpWidget(host());
      final frames = await pumpUntilGone(tester);
      expect(find.byKey(_introKey), findsNothing);
      // 16 ms por cuadro: duración nominal + el cuadro final ya aterrizado.
      expect(frames * 16, lessThanOrEqualTo(_total.inMilliseconds + 3 * 16));
      expect(frames * 16, greaterThanOrEqualTo(_total.inMilliseconds));
      // Fase 1 ≈ 1300 ms + fase 2 ≈ 450 ms.
      expect(kIntroSwallow, const Duration(milliseconds: 1300));
      expect(kIntroLand, const Duration(milliseconds: 450));
      expect(_total, const Duration(milliseconds: 1750));
      // Sin la capa, Inicio sigue en pie y estable.
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
    });

    testWidgets('un toque en la fase 1 la saltea sin activar Inicio',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 100));
      // Tocar justo sobre el botón de dictar: el toque es del arranque.
      await tester.tapAt(tester.getCenter(find.byKey(_recordKey)));
      await tester.pump(const Duration(milliseconds: 16));
      // Ya en la fase 2: la capa deja pasar los toques.
      final ignore = tester.widget<IgnorePointer>(find.descendant(
          of: find.byKey(_introKey), matching: find.byType(IgnorePointer)));
      expect(ignore.ignoring, isTrue);
      final frames = await pumpUntilGone(tester);
      expect(frames * 16,
          lessThanOrEqualTo(kIntroSkipLand.inMilliseconds + 4 * 16));
      expect(find.byKey(_introKey), findsNothing);
      // El toque que salteó no empezó a grabar.
      expect(find.byKey(const ValueKey('recordIdle')), findsOneWidget);
    });

    testWidgets('no se repite en el mismo proceso (remontar, cambiar tema)',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(host());
      await pumpUntilGone(tester);
      expect(HorizonIntroHost.coldStartPending, isFalse);

      // Árbol reconstruido desde cero en el mismo proceso.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(brightness: Brightness.dark));
      expect(find.byKey(_introKey), findsNothing);
      await tester.pumpWidget(const VoiceBubbleApp(showIntro: true));
      expect(find.byKey(_introKey), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('con animaciones desactivadas no aparece', (tester) async {
      phone(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(host());
      expect(find.byKey(_introKey), findsNothing);
      expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
      // El arranque del proceso quedó consumido: no aparece más tarde.
      expect(HorizonIntroHost.coldStartPending, isFalse);
    });

    testWidgets('si se abre otra pantalla encima, termina en el acto',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 16));
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_introKey, skipOffstage: false), findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('Arranque: presupuesto', () {
    test('pool fijo ≤ 120 y paso acotado ante un primer cuadro lento', () {
      expect(HorizonIntroScene.maxParticles, lessThanOrEqualTo(120));
      expect(HorizonIntroScene.glyphs.length, 17);
      final scene = HorizonIntroScene(random: math.Random(1))
        ..resize(const Size(411, 891));
      expect(scene.activeParticles, HorizonIntroScene.maxParticles);
      scene.step(2.5); // cuadro de 2,5 s: no salta a la fase 2.
      expect(scene.clock, closeTo(HorizonIntroScene.maxStep, 1e-9));
      expect(scene.landing, isFalse);
      scene.dispose();
    });

    testWidgets(
        'partículas ≤ 120 por cuadro y TextPainter cacheados, no por '
        'cuadro', (tester) async {
      phone(tester);
      final before = HorizonIntroPainter.debugTextPainterCount;
      await tester.pumpWidget(host(brightness: Brightness.dark));
      final scene = HorizonIntro.debugLastScene!;
      var frames = 0;
      var maxActive = 0;
      while (find.byKey(_introKey).evaluate().isNotEmpty && frames < 200) {
        maxActive = math.max(maxActive, scene.activeParticles);
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(maxActive, lessThanOrEqualTo(120));
      expect(maxActive, greaterThan(0));
      // ~70 cuadros con decenas de glifos cada uno: si se armaran por
      // cuadro serían miles; el tope es el caché de un modo.
      final created = HorizonIntroPainter.debugTextPainterCount - before;
      expect(frames, greaterThan(60));
      expect(
          created, lessThanOrEqualTo(HorizonIntroPainter.textPainterCapacity));

      // Un segundo arranque en el mismo modo reutiliza el caché: entre
      // los dos nunca se supera el tope de un modo.
      HorizonIntroHost.debugResetColdStart();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(brightness: Brightness.dark));
      final second = await pumpUntilGone(tester);
      expect(second, greaterThan(60));
      expect(HorizonIntroPainter.debugTextPainterCount - before,
          lessThanOrEqualTo(HorizonIntroPainter.textPainterCapacity));
    });
  });

  group('Arranque: aterriza sobre el botón de dictar', () {
    for (final size in const [
      Size(320, 640),
      Size(411, 891),
      Size(800, 1280)
    ]) {
      testWidgets(
          '${size.width.toInt()} dp: centro y radio coinciden '
          '(≤ 0,5 px)', (tester) async {
        phone(tester, width: size.width, height: size.height);
        if (size.width < 360) _ignoreTestFontOverflow();
        await tester.pumpWidget(host());
        final scene = HorizonIntro.debugLastScene!;
        await pumpUntilGone(tester);
        expect(scene.done, isTrue);
        expect(scene.landProgress, 1.0);
        final button = tester.getRect(find.byKey(_recordKey));
        expect(button.width, closeTo(kRecordButtonSize, 1e-6));
        expect((scene.holeCenter.dx - button.center.dx).abs(),
            lessThanOrEqualTo(0.5));
        expect((scene.holeCenter.dy - button.center.dy).abs(),
            lessThanOrEqualTo(0.5));
        expect((scene.holeRadius - button.width / 2).abs(),
            lessThanOrEqualTo(0.5));
        // El destino se midió (no es el respaldo).
        expect(scene.target, isNotNull);
        expect((scene.target!.center - button.center).distance,
            lessThanOrEqualTo(0.5));
      });
    }
  });

  // -------------------------------------------------------------------------
  // Fase 1 más larga: siguen entrando símbolos
  // -------------------------------------------------------------------------
  group('Arranque: la simulación no se vacía durante la fase 1', () {
    for (final size in const [
      Size(320, 640),
      Size(411, 891),
      Size(800, 1280)
    ]) {
      for (final seed in const [1, 2, 3]) {
        test('${size.width.toInt()} dp, semilla $seed', () {
          final scene = HorizonIntroScene(random: math.Random(seed))
            ..resize(size);
          expect(scene.swallowSeconds, closeTo(1.3, 1e-9));
          var tracked = 0;
          while (scene.clock < scene.swallowSeconds - 0.02) {
            scene.step(0.016);
            tracked++;
            if (tracked % 10 == 0) {
              // Siempre hay símbolos cerca del agujero, no solo al inicio.
              expect(scene.countNear(0.3), greaterThanOrEqualTo(20));
            }
          }
          expect(scene.activeParticles, HorizonIntroScene.maxParticles);
          expect(scene.countNear(0.3), greaterThanOrEqualTo(20));
          scene.dispose();
        });
      }
    }

    test('las duraciones de cada reproducción', () {
      final cold = HorizonIntroScene.forKind(HorizonIntroKind.cold);
      final back = HorizonIntroScene.forKind(HorizonIntroKind.returning);
      final exit = HorizonIntroScene.forKind(HorizonIntroKind.exit);
      expect(cold.swallowSeconds, closeTo(1.3, 1e-9));
      expect(back.swallowSeconds, closeTo(0.6, 1e-9));
      expect(cold.landSeconds, closeTo(0.45, 1e-9));
      expect(back.landSeconds, closeTo(0.45, 1e-9));
      expect(exit.swallowSeconds, 0);
      expect(exit.landSeconds, closeTo(0.5, 1e-9));
      expect(exit.reverse, isTrue);
      for (final s in [cold, back, exit]) {
        s.dispose();
      }
    });
  });

  // -------------------------------------------------------------------------
  // Volver de Ajustes, salida con «atrás»
  // -------------------------------------------------------------------------
  group('Volver de Ajustes y salida', () {
    late List<String> popCalls;

    setUp(() {
      popCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') popCalls.add(call.method);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    /// Superficie alta: Ajustes es más larga que el viewport por defecto.
    void tall(WidgetTester tester) {
      tester.view.physicalSize = const Size(1600, 4800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
    }

    /// Monta Inicio con el host y deja pasar el arranque en frío.
    Future<void> mountAfterColdStart(WidgetTester tester,
        {_CountingNotes? notes}) async {
      await tester.pumpWidget(host(notes: notes));
      await pumpUntilGone(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(_introKey), findsNothing);
    }

    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('homeSettingsButton')));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }

    /// Cuadros de 16 ms hasta que aparece [key]; devuelve si apareció.
    Future<bool> pumpUntilShown(WidgetTester tester, Key key,
        {int maxFrames = 60}) async {
      for (var i = 0; i < maxFrames; i++) {
        if (find.byKey(key).evaluate().isNotEmpty) return true;
        await tester.pump(const Duration(milliseconds: 16));
      }
      return find.byKey(key).evaluate().isNotEmpty;
    }

    Future<int> pumpFramesUntilCalls(WidgetTester tester,
        {int max = 200}) async {
      var frames = 0;
      while (popCalls.isEmpty && frames < max) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      return frames;
    }

    void animationsOff(WidgetTester tester) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    group('al volver de Ajustes', () {
      testWidgets('se reproduce la versión corta (600 + 450 ms) y se desmonta',
          (tester) async {
        tall(tester);
        await mountAfterColdStart(tester);
        await openSettings(tester);
        await tester.binding.handlePopRoute();
        expect(await pumpUntilShown(tester, _introKey), isTrue);
        final scene = HorizonIntro.debugLastScene!;
        expect(scene.swallowSeconds, closeTo(0.6, 1e-9));
        // Inicio ya está construido debajo.
        expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
        final frames = await pumpUntilGone(tester);
        expect(frames * 16, greaterThanOrEqualTo(_totalReturn.inMilliseconds));
        expect(frames * 16,
            lessThanOrEqualTo(_totalReturn.inMilliseconds + 4 * 16));
        expect(scene.landProgress, 1.0);
        expect(popCalls, isEmpty);
        await tester.pumpAndSettle();
      });

      testWidgets('un toque la saltea (fase 2 acelerada) sin tocar Inicio',
          (tester) async {
        tall(tester);
        await mountAfterColdStart(tester);
        await openSettings(tester);
        await tester.binding.handlePopRoute();
        expect(await pumpUntilShown(tester, _introKey), isTrue);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tapAt(tester.getCenter(find.byKey(_recordKey)));
        await tester.pump(const Duration(milliseconds: 16));
        final frames = await pumpUntilGone(tester);
        expect(frames * 16,
            lessThanOrEqualTo(kIntroSkipLand.inMilliseconds + 4 * 16));
        expect(find.byKey(const ValueKey('recordIdle')), findsOneWidget);
      });

      testWidgets('se repite en cada vuelta', (tester) async {
        tall(tester);
        await mountAfterColdStart(tester);
        for (var i = 0; i < 2; i++) {
          await openSettings(tester);
          await tester.binding.handlePopRoute();
          expect(await pumpUntilShown(tester, _introKey), isTrue);
          await pumpUntilGone(tester);
          await tester.pumpAndSettle();
        }
      });

      testWidgets('NO al volver de una subpantalla de Ajustes hacia Ajustes',
          (tester) async {
        tall(tester);
        await mountAfterColdStart(tester);
        await openSettings(tester);
        await tester.tap(find.byKey(const ValueKey('nav-transcripcion')));
        await tester.pumpAndSettle();
        // «Atrás» dentro de Ajustes: sube a la raíz de Ajustes.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byKey(_introKey, skipOffstage: false), findsNothing);
        // Control: al salir de la raíz sí se reproduce.
        await tester.binding.handlePopRoute();
        expect(await pumpUntilShown(tester, _introKey), isTrue);
        await pumpUntilGone(tester);
      });

      testWidgets('NO al volver del editor de notas', (tester) async {
        tall(tester);
        await mountAfterColdStart(tester, notes: _OneNote());
        await tester.tap(find.byKey(const ValueKey('n1')));
        await tester.pumpAndSettle();
        expect(find.byType(NoteEditorScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(find.byKey(_introKey, skipOffstage: false), findsNothing);
        }
        await tester.pumpAndSettle();
        expect(find.byType(NoteEditorScreen), findsNothing);
        expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
        expect(popCalls, isEmpty);
      });

      testWidgets('NO al cerrar una hoja modal', (tester) async {
        tall(tester);
        await mountAfterColdStart(tester, notes: _OneNote());
        await tester.longPress(find.byKey(const ValueKey('n1')));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        await tester.binding.handlePopRoute();
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(find.byKey(_introKey, skipOffstage: false), findsNothing);
          expect(find.byKey(_exitKey, skipOffstage: false), findsNothing);
        }
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(popCalls, isEmpty);
      });

      testWidgets('con animaciones desactivadas no hay capa', (tester) async {
        tall(tester);
        animationsOff(tester);
        await tester.pumpWidget(host());
        await openSettings(tester);
        await tester.binding.handlePopRoute();
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(find.byKey(_introKey, skipOffstage: false), findsNothing);
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
      });

      testWidgets('con TalkBack activo no hay capa', (tester) async {
        tall(tester);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pumpWidget(host());
        await openSettings(tester);
        await tester.binding.handlePopRoute();
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(find.byKey(_introKey, skipOffstage: false), findsNothing);
        }
        await tester.pumpAndSettle();
      });

      testWidgets('con el host apagado no hay capa', (tester) async {
        tall(tester);
        await tester.pumpWidget(host(enabled: false));
        await openSettings(tester);
        await tester.binding.handlePopRoute();
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(find.byKey(_introKey, skipOffstage: false), findsNothing);
        }
        await tester.pumpAndSettle();
      });
    });

    group('salida con «atrás» desde Inicio', () {
      testWidgets('se reproduce (≈ 500 ms) y recién al terminar cierra la app',
          (tester) async {
        phone(tester);
        await mountAfterColdStart(tester);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(_exitKey), findsOneWidget);
        // Arranca sin cerrar.
        expect(popCalls, isEmpty);
        final scene = HorizonIntro.debugLastScene!;
        expect(scene.reverse, isTrue);
        final frames = await pumpFramesUntilCalls(tester);
        expect(popCalls, ['SystemNavigator.pop']);
        expect(frames * 16, greaterThanOrEqualTo(kIntroExit.inMilliseconds));
        expect(
            frames * 16, lessThanOrEqualTo(kIntroExit.inMilliseconds + 4 * 16));
        // Último cuadro: el fondo cubre todo y la capa sigue puesta.
        expect(scene.landProgress, 0.0);
        expect(find.byKey(_exitKey), findsOneWidget);
        // Una sola llamada de cierre.
        await tester.pump(const Duration(milliseconds: 200));
        expect(popCalls, hasLength(1));
      });

      testWidgets('un segundo «atrás» durante la animación cierra de inmediato',
          (tester) async {
        phone(tester);
        await mountAfterColdStart(tester);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(popCalls, isEmpty);
        await tester.binding.handlePopRoute();
        expect(popCalls, hasLength(1));
        // Terminar la animación no vuelve a cerrar.
        await pumpFramesUntilCalls(tester, max: 5);
        await tester.pump(const Duration(milliseconds: 600));
        expect(popCalls, hasLength(1));
      });

      testWidgets('un toque durante la animación cierra de inmediato',
          (tester) async {
        phone(tester);
        await mountAfterColdStart(tester);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(popCalls, isEmpty);
        await tester.tapAt(const Offset(200, 300));
        await tester.pump();
        expect(popCalls, hasLength(1));
        await tester.pump(const Duration(milliseconds: 600));
        expect(popCalls, hasLength(1));
      });

      testWidgets('al reanudar con la capa puesta, Inicio vuelve a verse',
          (tester) async {
        phone(tester);
        await mountAfterColdStart(tester);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await pumpFramesUntilCalls(tester);
        expect(find.byKey(_exitKey), findsOneWidget);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(find.byKey(_exitKey), findsOneWidget);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump();
        expect(find.byKey(_exitKey), findsNothing);
        expect(find.byKey(const ValueKey('recordIdle')), findsOneWidget);
        await tester.pumpAndSettle();
        // Y un «atrás» posterior vuelve a animar y a cerrar.
        popCalls.clear();
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(_exitKey), findsOneWidget);
        await pumpFramesUntilCalls(tester);
        expect(popCalls, hasLength(1));
      });

      testWidgets('con búsqueda activa, «atrás» cierra como antes (sin capa)',
          (tester) async {
        phone(tester);
        await mountAfterColdStart(tester);
        await tester.enterText(
            find.byKey(const ValueKey('homeSearchField')), 'algo');
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(_exitKey), findsNothing);
        expect(popCalls, hasLength(1));
      });

      testWidgets('«atrás» en Ajustes o en el editor no dispara la salida',
          (tester) async {
        tall(tester);
        await mountAfterColdStart(tester, notes: _OneNote());
        await openSettings(tester);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(_exitKey, skipOffstage: false), findsNothing);
        await pumpUntilGone(tester);
        await tester.pumpAndSettle();
        expect(popCalls, isEmpty);
        await tester.tap(find.byKey(const ValueKey('n1')));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byKey(_exitKey, skipOffstage: false), findsNothing);
        expect(popCalls, isEmpty);
      });

      testWidgets('con animaciones desactivadas cierra directo, sin capa',
          (tester) async {
        phone(tester);
        animationsOff(tester);
        await tester.pumpWidget(host());
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(_exitKey), findsNothing);
        expect(popCalls, hasLength(1));
      });

      testWidgets('con TalkBack activo cierra directo, sin capa',
          (tester) async {
        phone(tester);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pumpWidget(host());
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(_exitKey), findsNothing);
        expect(popCalls, hasLength(1));
      });

      testWidgets('con el host apagado y sin host cierra directo',
          (tester) async {
        phone(tester);
        await tester.pumpWidget(host(enabled: false));
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(_exitKey), findsNothing);
        expect(popCalls, hasLength(1));
        popCalls.clear();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(
          theme: buildLightTheme(),
          home: HomeScreen(
            notesService: _CountingNotes(),
            storageService: _MemoryHistory(),
          ),
        ));
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byKey(_exitKey), findsNothing);
        expect(popCalls, hasLength(1));
      });

      testWidgets('«atrás» durante el arranque en frío cierra de inmediato',
          (tester) async {
        phone(tester);
        await tester.pumpWidget(host());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.binding.handlePopRoute();
        expect(popCalls, hasLength(1));
        expect(find.byKey(_exitKey), findsNothing);
        await pumpUntilGone(tester);
      });

      testWidgets('presupuesto: ≤ 120 partículas y TextPainter acotados',
          (tester) async {
        phone(tester);
        await mountAfterColdStart(tester);
        final before = HorizonIntroPainter.debugTextPainterCount;
        await tester.binding.handlePopRoute();
        await tester.pump();
        final scene = HorizonIntro.debugLastScene!;
        var maxActive = 0;
        while (popCalls.isEmpty) {
          maxActive = math.max(maxActive, scene.activeParticles);
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(maxActive, inInclusiveRange(1, 120));
        expect(HorizonIntroPainter.debugTextPainterCount - before,
            lessThanOrEqualTo(HorizonIntroPainter.textPainterCapacity));
      });
    });

    group('alineación con el botón de dictar', () {
      for (final size in const [
        Size(320, 640),
        Size(411, 891),
        Size(800, 1280)
      ]) {
        testWidgets(
            '${size.width.toInt()} dp: la salida empieza sobre el '
            'botón (centro y radio ≤ 0,5 px)', (tester) async {
          phone(tester, width: size.width, height: size.height);
          if (size.width < 360) _ignoreTestFontOverflow();
          await mountAfterColdStart(tester);
          await tester.binding.handlePopRoute();
          await tester.pump();
          final scene = HorizonIntro.debugLastScene!;
          expect(scene.reverse, isTrue);
          final button = tester.getRect(find.byKey(_recordKey));
          expect(scene.landProgress, 1.0);
          expect((scene.holeCenter - button.center).distance,
              lessThanOrEqualTo(0.5));
          expect((scene.holeRadius - button.width / 2).abs(),
              lessThanOrEqualTo(0.5));
          await pumpFramesUntilCalls(tester);
        });

        testWidgets(
            '${size.width.toInt()} dp: la vuelta de Ajustes termina '
            'sobre el botón (centro y radio ≤ 0,5 px)', (tester) async {
          phone(tester, width: size.width, height: size.height);
          if (size.width < 360) _ignoreTestFontOverflow();
          await mountAfterColdStart(tester);
          tester.view.physicalSize = const Size(1600, 4800);
          tester.view.devicePixelRatio = 2.0;
          await openSettings(tester);
          await tester.binding.handlePopRoute();
          expect(await pumpUntilShown(tester, _introKey), isTrue);
          final scene = HorizonIntro.debugLastScene!;
          await pumpUntilGone(tester);
          final button = tester.getRect(find.byKey(_recordKey));
          expect(scene.target, isNotNull);
          expect((scene.holeCenter - button.center).distance,
              lessThanOrEqualTo(0.5));
          expect((scene.holeRadius - button.width / 2).abs(),
              lessThanOrEqualTo(0.5));
        });
      }
    });
  });
}

/// A 320 dp, la fuente cuadrada de los tests (cada letra mide 1 em) desborda
/// las pestañas de Inicio; con Sora real entran. Solo se toleran los avisos
/// de desborde de RenderFlex en ese test de geometría: cualquier otro
/// error sigue fallando.
void _ignoreTestFontOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}
