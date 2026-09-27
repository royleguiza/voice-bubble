import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/services/pending_note_queue.dart';
import 'package:voice_bubble_stt/widgets/pending_note_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PendingNote item(String id) => PendingNote(
        id: id,
        audioPath: '/tmp/pending_notes/$id.wav',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );

  Widget wrap(WidgetTester tester, PendingNoteTile tile) {
    // C-46: superficie y ancho de teléfono reales. El ancho fijo hace
    // determinista el LayoutBuilder del player (gap = 30% clamp 96-150),
    // y la superficie alta evita que la fila del player caiga bajo el
    // pliegue del viewport (§9.1-17/21).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    return MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: tile))),
    );
  }

  group('PendingNoteTile (C-45)', () {
    testWidgets('muestra transcribir, escuchar y descartar', (tester) async {
      const id = '11111111-1111-4111-8111-111111111111';
      await tester.pumpWidget(wrap(tester, PendingNoteTile(
        item: item(id),
        busy: false,
        onTranscribe: () {},
        onDiscard: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Audio sin transcribir'), findsOneWidget);
      expect(
        find.byKey(ValueKey('transcribeCloudButton-$id')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('playPendingButton-$id')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('closePendingPlayer-$id')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('pendingPlayerClock-$id')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('discardPendingButton-$id')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('C-46: play abre reloj+X y la X reagrupa en un play',
        (tester) async {
      const id = '44444444-4444-4444-8444-444444444444';
      await tester.pumpWidget(wrap(tester, PendingNoteTile(
        item: item(id),
        busy: false,
        onTranscribe: () {},
        onDiscard: () {},
      )));
      await tester.pumpAndSettle();

      IconButton buttonOf(String key) => tester.widget<IconButton>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(IconButton),
            ),
          );
      // El reloj siempre esta en el arbol; colapsado vale ancho 0.
      double clockWidth() => tester.widget<AnimatedContainer>(
            find.ancestor(
              of: find.byKey(ValueKey('pendingPlayerClock-$id')),
              matching: find.byType(AnimatedContainer),
            ),
          ).width ??
          0;
      double closeWidth() => tester
          .widgetList<AnimatedContainer>(
            find.byType(AnimatedContainer),
          )
          .last
          .width ??
          0;

      // --- Colapsado: una sola burbuja con play, reloj y X sin ancho,
      //     y el player en la MISMA fila que las acciones.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(clockWidth(), 0);
      expect(closeWidth(), 0);
      expect(buttonOf('playPendingButton-$id').onPressed, isNotNull);
      expect(buttonOf('closePendingPlayer-$id').onPressed, isNull,
          reason: 'la X colapsada no debe capturar el toque del play');

      // --- Abrir: el grupo se ensancha y empuja las acciones a los costados.
      buttonOf('playPendingButton-$id').onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(clockWidth(), greaterThan(0));
      expect(closeWidth(), 48);
      expect(find.text('00:00 / 00:00'), findsOneWidget);
      expect(find.text('No se pudo reproducir este audio'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(buttonOf('closePendingPlayer-$id').onPressed, isNotNull);
      // Las acciones siguen visibles: nada se sale de pantalla.
      expect(
        find.byKey(ValueKey('transcribeCloudButton-$id')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('discardPendingButton-$id')),
        findsOneWidget,
      );

      // --- Cerrar: la animacion inverse reagrupa las dos burbujas en un play.
      buttonOf('closePendingPlayer-$id').onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(clockWidth(), 0);
      expect(closeWidth(), 0);
      expect(find.text('No se pudo reproducir este audio'), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(buttonOf('closePendingPlayer-$id').onPressed, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('audio inexistente avisa sin crashear', (tester) async {
      const id = '22222222-2222-4222-8222-222222222222';
      await tester.pumpWidget(wrap(tester, PendingNoteTile(
        item: item(id),
        busy: false,
        onTranscribe: () {},
        onDiscard: () {},
      )));
      await tester.pumpAndSettle();

      // C-46: se invoca el callback del play, no un tap por coordenadas.
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byKey(ValueKey('playPendingButton-$id')),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('No se pudo reproducir este audio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('busy deshabilita las tres acciones', (tester) async {
      const id = '33333333-3333-4333-8333-333333333333';
      var transcribed = false;
      var discarded = false;
      await tester.pumpWidget(wrap(tester, PendingNoteTile(
        item: item(id),
        busy: true,
        onTranscribe: () => transcribed = true,
        onDiscard: () => discarded = true,
      )));
      // Sin pumpAndSettle en este test: con busy=true el botón ya muestra
      // CircularProgressIndicator (animación infinita, §9.1-14).
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(
        find.byKey(ValueKey('transcribeCloudButton-$id')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(ValueKey('discardPendingButton-$id')),
        warnIfMissed: false,
      );
      // Sin pumpAndSettle: con busy=true el botón muestra
      // CircularProgressIndicator (animación infinita, §9.1-14).
      await tester.pump(const Duration(milliseconds: 100));

      expect(transcribed, isFalse);
      expect(discarded, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
