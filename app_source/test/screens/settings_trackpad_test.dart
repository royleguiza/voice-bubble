import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/settings_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = SettingsHarness();

  setUp(() => h.setUp());
  tearDown(h.tearDown);

  Future<void> openTrackpad(WidgetTester tester, {bool enabled = true}) async {
    h.setUp(prefs: {'kb_trackpad_enabled': enabled});
    await h.pump(tester);
    await openPage(tester, 'trackpad');
  }

  group('Trackpad', () {
    testWidgets('apagado solo muestra los interruptores', (tester) async {
      await openTrackpad(tester, enabled: false);

      expect(switchValue(tester, 'kb-trackpad-enabled-switch'), isFalse);
      expect(byKey('kb-trackpad-toolbar-switch'), findsOneWidget);
      expect(byKey('kb-trackpad-sensitivity-slider'), findsNothing);
      expect(byKey('kb-trackpad-scroll-position-selector'), findsNothing);
    });

    testWidgets('encender persiste y muestra las opciones', (tester) async {
      await openTrackpad(tester, enabled: false);

      await tapKey(tester, 'kb-trackpad-enabled-switch');

      expect(await h.storage.getTrackpadEnabled(), isTrue);
      expect(byKey('kb-trackpad-sensitivity-slider'), findsOneWidget);
      expect(byKey('kb-trackpad-pointer-style-selector'), findsOneWidget);
    });

    testWidgets('acceso en la barra persiste', (tester) async {
      await openTrackpad(tester);
      await tapKey(tester, 'kb-trackpad-toolbar-switch');
      expect(await h.storage.getTrackpadToolbarVisible(), isTrue);
    });

    testWidgets('barra de scroll persiste (izquierda y oculta)',
        (tester) async {
      await openTrackpad(tester);

      await pickOption(tester, 'kb-trackpad-scroll-position-selector', 'left');
      expect((await prefs()).getString('kb_trackpad_scroll_position'), 'left');

      await pickOption(
          tester, 'kb-trackpad-scroll-position-selector', 'disabled');
      expect(
          (await prefs()).getString('kb_trackpad_scroll_position'), 'disabled');
      expect(rowShows('kb-trackpad-scroll-position-selector', 'Oculta'),
          isTrue);
    });

    testWidgets('forma del puntero persiste', (tester) async {
      await openTrackpad(tester);

      await pickOption(tester, 'kb-trackpad-pointer-style-selector', 'dot');
      expect((await prefs()).getString('kb_trackpad_pointer_style'), 'dot');

      await pickOption(tester, 'kb-trackpad-pointer-style-selector', 'cross');
      expect((await prefs()).getString('kb_trackpad_pointer_style'), 'cross');
    });

    testWidgets('distribución de botones persiste', (tester) async {
      await openTrackpad(tester);

      await pickOption(tester, 'kb-trackpad-button-layout-selector', 'wings');
      expect((await prefs()).getString('kb_trackpad_button_layout'), 'wings');

      await pickOption(tester, 'kb-trackpad-button-layout-selector', 'top');
      expect((await prefs()).getString('kb_trackpad_button_layout'), 'top');
    });

    testWidgets('aceleración, clic secundario, dirección y vibración persisten',
        (tester) async {
      await openTrackpad(tester);

      await pickOption(tester, 'kb-trackpad-accel-curve-selector', 'precision');
      await pickOption(
          tester, 'kb-trackpad-secondary-click-selector', 'button');
      await pickOption(
          tester, 'kb-trackpad-scroll-direction-selector', 'standard');
      await pickOption(tester, 'kb-trackpad-haptic-selector', 'none');

      expect(await h.storage.getTrackpadAccelCurve(), 'precision');
      expect(await h.storage.getTrackpadSecondaryClick(), 'button');
      expect(await h.storage.getTrackpadScrollDirection(), 'standard');
      expect(await h.storage.getTrackpadHaptic(), 'none');
    });

    testWidgets('tocar para hacer clic y volver al teclado persisten',
        (tester) async {
      await openTrackpad(tester);

      await tapKey(tester, 'kb-trackpad-tap-to-click-switch');
      await pickOption(tester, 'kb-trackpad-auto-return-selector', 15);

      expect(await h.storage.getTrackpadTapToClick(), isFalse);
      expect(await h.storage.getTrackpadAutoReturn(), 15);
    });

    testWidgets('mover la velocidad guarda tras el debounce', (tester) async {
      await openTrackpad(tester);

      final slider = tester.widget<Slider>(byKey('kb-trackpad-sensitivity-slider'));
      slider.onChanged!(2.0);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(await h.storage.getTrackpadSensitivity(), 2.0);
      expect(find.text('2.0×'), findsOneWidget);
    });
  });
}
