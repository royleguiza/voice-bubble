// Arranque Horizonte (design.md §15): Inicio se construye debajo desde el
// primer cuadro, la capa se desmonta al terminar, un toque la saltea, no se
// repite en el mismo proceso, no aparece con reducir movimiento, respeta el
// presupuesto (≤ 120 partículas, TextPainter acotados) y aterriza
// exactamente sobre el agujero del botón de dictar.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/main.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/models/voice_note.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
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

class _MemoryHistory extends StorageService {
  @override
  Future<bool> load() async => true;

  @override
  List<Transcription> get transcriptions => const [];
}

const _introKey = ValueKey('horizonIntro');
const _recordKey = ValueKey('recordButton');

/// Duración nominal del arranque.
final Duration _total = kIntroSwallow + kIntroLand;

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
      theme: brightness == Brightness.light
          ? buildLightTheme()
          : buildDarkTheme(),
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

    testWidgets('la carga de notas arranca en el primer cuadro, sin esperar '
        'a la animación', (tester) async {
      phone(tester);
      final notes = _CountingNotes();
      await tester.pumpWidget(host(notes: notes));
      expect(find.byKey(_introKey), findsOneWidget);
      expect(notes.loads, 1);
      await pumpUntilGone(tester);
    });

    testWidgets('la capa se desmonta al terminar, en ≤ ~1,2 s', (tester) async {
      phone(tester);
      await tester.pumpWidget(host());
      final frames = await pumpUntilGone(tester);
      expect(find.byKey(_introKey), findsNothing);
      // 16 ms por cuadro: duración nominal + el cuadro final ya aterrizado.
      expect(frames * 16, lessThanOrEqualTo(_total.inMilliseconds + 3 * 16));
      expect(frames * 16, greaterThanOrEqualTo(_total.inMilliseconds));
      expect(_total, lessThanOrEqualTo(const Duration(milliseconds: 1200)));
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
      tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()));
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

    testWidgets('partículas ≤ 120 por cuadro y TextPainter cacheados, no por '
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
      expect(created,
          lessThanOrEqualTo(HorizonIntroPainter.textPainterCapacity));

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
    for (final size in const [Size(320, 640), Size(411, 891), Size(800, 1280)]) {
      testWidgets('${size.width.toInt()} dp: centro y radio coinciden '
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
