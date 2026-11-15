import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/widgets/settings_v2.dart';

import '../helpers/settings_harness.dart' show sliderSpokenValue;

/// [SettingsStepperRow]: deslizador con «−» y «+» de un paso (mantener
/// apretado repite) y [SettingsOption.enabled] del menú.
void main() {
  Widget host({
    required int value,
    int min = 10,
    int max = 100,
    required List<int> changes,
    required List<String> ends,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: SettingsStepperRow(
            id: 'demo',
            title: 'Ancho',
            value: value,
            min: min,
            max: max,
            minusLabel: 'Un píxel menos',
            plusLabel: 'Un píxel más',
            onChanged: changes.add,
            onChangeEnd: () => ends.add('fin'),
          ),
        ),
      );

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('muestra el valor en mono con su unidad', (tester) async {
    await tester.pumpWidget(host(value: 42, changes: [], ends: []));
    expect(tester.widget<Text>(key('demo-value')).data, '42 px');
    expect(tester.widget<Text>(key('demo-value')).style?.fontFamily,
        contains('JetBrainsMono'));
  });

  testWidgets('un toque en + y en − da un paso de a uno y avisa que terminó',
      (tester) async {
    final changes = <int>[];
    final ends = <String>[];
    await tester.pumpWidget(host(value: 50, changes: changes, ends: ends));
    await tester.tap(key('demo-plus'));
    await tester.pump();
    await tester.tap(key('demo-minus'));
    await tester.pump();
    // El valor se lleva adentro: el − parte del 51 que dejó el +.
    expect(changes, [51, 50]);
    expect(ends.length, 2);
  });

  testWidgets('mantener apretado repite y al soltar avisa una sola vez',
      (tester) async {
    final changes = <int>[];
    final ends = <String>[];
    var value = 50;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return SettingsStepperRow(
            id: 'demo',
            title: 'Ancho',
            value: value,
            min: 10,
            max: 100,
            minusLabel: 'menos',
            plusLabel: 'más',
            onChanged: (v) {
              changes.add(v);
              setState(() => value = v);
            },
            onChangeEnd: () => ends.add('fin'),
          );
        }),
      ),
    ));
    final gesture =
        await tester.startGesture(tester.getCenter(key('demo-plus')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(changes.length, greaterThan(3),
        reason: 'repite mientras se mantiene');
    expect(ends, isEmpty, reason: 'sigue apretado');
    await gesture.up();
    await tester.pump();
    expect(ends.length, 1);
    final after = changes.length;
    await tester.pump(const Duration(seconds: 1));
    expect(changes.length, after, reason: 'al soltar deja de repetir');
    // Los pasos son de a uno.
    for (var i = 1; i < changes.length; i++) {
      expect(changes[i] - changes[i - 1], 1);
    }
  });

  testWidgets('el repetir se corta en el tope y no deja temporizadores',
      (tester) async {
    final changes = <int>[];
    var value = 98;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          return SettingsStepperRow(
            id: 'demo',
            title: 'Ancho',
            value: value,
            min: 10,
            max: 100,
            minusLabel: 'menos',
            plusLabel: 'más',
            onChanged: (v) {
              changes.add(v);
              setState(() => value = v);
            },
            onChangeEnd: () {},
          );
        }),
      ),
    ));
    final gesture =
        await tester.startGesture(tester.getCenter(key('demo-plus')));
    await tester.pump(const Duration(seconds: 2));
    expect(changes, [99, 100]);
    expect(tester.widget<Text>(key('demo-value')).data, '100 px');
    await gesture.up();
    await tester.pump();
  });

  testWidgets('en los topes el botón queda deshabilitado', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(host(value: 100, changes: changes, ends: []));
    await tester.tap(key('demo-plus'));
    await tester.pump();
    expect(changes, isEmpty);
    await tester.pumpWidget(host(value: 10, changes: changes, ends: []));
    await tester.tap(key('demo-minus'));
    await tester.pump();
    expect(changes, isEmpty);
  });

  testWidgets(
      'arrastrar el deslizador informa de a un entero y al soltar avisa',
      (tester) async {
    final changes = <int>[];
    final ends = <String>[];
    await tester.pumpWidget(host(value: 10, changes: changes, ends: ends));
    await tester.drag(key('demo-slider'), const Offset(150, 0));
    await tester.pump();
    expect(changes, isNotEmpty);
    expect(changes.last, greaterThan(10));
    expect(changes.last, lessThanOrEqualTo(100));
    expect(ends.length, 1);
  });

  testWidgets('el deslizador es de un paso (un entero por división)',
      (tester) async {
    await tester.pumpWidget(host(value: 20, changes: [], ends: []));
    final slider = tester.widget<Slider>(key('demo-slider'));
    expect(slider.divisions, 90);
    expect(slider.min, 10);
    expect(slider.max, 100);
    expect(slider.value, 20);
  });

  testWidgets('un rango vacío no rompe el deslizador', (tester) async {
    await tester
        .pumpWidget(host(value: 5, min: 5, max: 5, changes: [], ends: []));
    expect(tester.takeException(), isNull);
  });

  testWidgets('semántica en español: botones, valor y paso', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(value: 42, changes: [], ends: []));
    expect(find.bySemanticsLabel('Un píxel menos'), findsOneWidget);
    expect(find.bySemanticsLabel('Un píxel más'), findsOneWidget);
    final spoken = sliderSpokenValue(tester, key('demo-slider'));
    expect(spoken, contains('42 píxeles'));
    expect(spoken, contains('Ancho'));
    handle.dispose();
  });

  testWidgets('los botones miden al menos 48 dp', (tester) async {
    await tester.pumpWidget(host(value: 42, changes: [], ends: []));
    for (final k in ['demo-minus', 'demo-plus']) {
      final size = tester.getSize(key(k));
      expect(size.width, greaterThanOrEqualTo(48), reason: k);
      expect(size.height, greaterThanOrEqualTo(48), reason: k);
    }
  });

  group('SettingsOption.enabled', () {
    testWidgets('una opción deshabilitada se ve pero no se puede elegir',
        (tester) async {
      String? picked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsMenuRow<String>(
            id: 'menu',
            title: 'Forma',
            value: 'a',
            options: const [
              SettingsOption('a', 'Uno'),
              SettingsOption('b', 'Dos', enabled: false, detail: 'No hay'),
            ],
            onSelected: (v) => picked = v,
          ),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('menu')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MenuItemButton>(find.byKey(const ValueKey('menu-b')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('menu-b')));
      await tester.pumpAndSettle();
      expect(picked, isNull);
      expect(find.text('No hay'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('menu-a')));
      await tester.pumpAndSettle();
      expect(picked, 'a');
    });
  });
}
