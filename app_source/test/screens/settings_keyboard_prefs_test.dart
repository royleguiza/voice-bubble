import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';

import '../helpers/settings_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = SettingsHarness();

  setUp(() => h.setUp());
  tearDown(h.tearDown);

  Future<void> openTeclado(WidgetTester tester) async {
    await h.pump(tester);
    await openPage(tester, 'teclado');
  }

  Future<void> openSonido(WidgetTester tester) async {
    await openTeclado(tester);
    await tapKey(tester, 'nav-sonido');
  }

  group('Teclado - tamaño', () {
    testWidgets('altura Media por defecto; Alta y Muy alta persisten',
        (tester) async {
      await openTeclado(tester);
      expect(rowShows('kb-height-profile-selector', 'Media'), isTrue);

      await pickOption(tester, 'kb-height-profile-selector', 'alta');
      expect((await prefs()).getString('kb_height_profile'), 'alta');

      await pickOption(tester, 'kb-height-profile-selector', 'muy_alta');
      expect((await prefs()).getString('kb_height_profile'), 'muy_alta');
      expect(rowShows('kb-height-profile-selector', 'Muy alta'), isTrue);
    });

    testWidgets('altura corrupta en prefs cae a Media sin crash',
        (tester) async {
      h.setUp(prefs: {'kb_height_profile': 'gigante'});
      await openTeclado(tester);
      expect(rowShows('kb-height-profile-selector', 'Media'), isTrue);
    });

    testWidgets('separación Normal por defecto; Amplia y Máxima persisten',
        (tester) async {
      await openTeclado(tester);
      expect(rowShows('kb-key-spacing-selector', 'Normal'), isTrue);

      await pickOption(tester, 'kb-key-spacing-selector', 'amplio');
      expect((await prefs()).getString('kb_key_spacing'), 'amplio');

      await pickOption(tester, 'kb-key-spacing-selector', 'extra');
      expect((await prefs()).getString('kb_key_spacing'), 'extra');
    });

    testWidgets('distancia al borde persiste en dp', (tester) async {
      await openTeclado(tester);
      expect(rowShows('kb-bottom-elevation-selector', '24 dp'), isTrue);

      await pickOption(tester, 'kb-bottom-elevation-selector', 48);
      expect(await h.storage.getBottomElevationDp(), 48);
    });
  });

  group('Teclado - teclas visibles', () {
    final cases = <String, Future<bool> Function()>{
      'kb-terminal-row-switch': () => h.storage.loadKeyboardTerminalRowVisible(),
      'kb-code-key-switch': () => h.storage.loadKeyboardCodeKeyVisible(),
      'kb-language-key-switch': () => h.storage.loadKeyboardLanguageKeyVisible(),
      'credenciales-key-visible-switch': () =>
          h.storage.loadKeyboardCredentialsKeyVisible(),
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key}: visible por defecto y apagar persiste',
          (tester) async {
        await openTeclado(tester);
        expect(switchValue(tester, entry.key), isTrue);

        await tapKey(tester, entry.key);

        expect(switchValue(tester, entry.key), isFalse);
        expect(await entry.value(), isFalse);
      });
    }

    testWidgets('refleja una tecla oculta guardada antes', (tester) async {
      h.setUp(prefs: {'kb_terminal_row_visible': false});
      await openTeclado(tester);
      expect(switchValue(tester, 'kb-terminal-row-switch'), isFalse);
    });
  });

  group('Teclado - escritura', () {
    testWidgets('gesto de la barra espaciadora persiste', (tester) async {
      await openTeclado(tester);
      expect(rowShows('kb-spacebar-trackpad-mode-selector', 'Mantener'), isTrue);

      await pickOption(
          tester, 'kb-spacebar-trackpad-mode-selector', 'gboard_horizontal');
      expect((await prefs()).getString('kb_spacebar_trackpad_mode'),
          'gboard_horizontal');

      await pickOption(tester, 'kb-spacebar-trackpad-mode-selector', 'ios_2d');
      expect((await prefs()).getString('kb_spacebar_trackpad_mode'), 'ios_2d');
    });

    testWidgets('posición de la barra espaciadora persiste', (tester) async {
      await openTeclado(tester);
      await pickOption(tester, 'kb-spacebar-alignment-selector', 'left');
      expect(await h.storage.getSpacebarAlignment(), 'left');
    });

    testWidgets('micrófono a la izquierda persiste', (tester) async {
      await openTeclado(tester);
      expect(switchValue(tester, 'kb-invert-toolbar-switch'), isFalse);
      await tapKey(tester, 'kb-invert-toolbar-switch');
      expect(await h.storage.getInvertToolbar(), isTrue);
    });

    testWidgets('símbolos al mantener: ON y Normal por defecto',
        (tester) async {
      await openTeclado(tester);
      expect(switchValue(tester, 'kb-long-press-symbols-switch'), isTrue);
      expect(rowShows('kb-long-press-delay-selector', 'Normal'), isTrue);
    });

    testWidgets('apagar símbolos persiste y oculta la espera', (tester) async {
      await openTeclado(tester);
      await tapKey(tester, 'kb-long-press-symbols-switch');

      expect((await prefs()).getBool('kb_long_press_symbols'), isFalse);
      expect(byKey('kb-long-press-delay-selector'), findsNothing);
    });

    testWidgets('elegir espera Larga persiste', (tester) async {
      await openTeclado(tester);
      await pickOption(tester, 'kb-long-press-delay-selector', 'relajado');
      expect((await prefs()).getString('kb_long_press_delay'), 'relajado');
    });
  });

  group('Teclado - portapapeles (SPK-10)', () {
    testWidgets('imágenes apagadas por defecto; encender persiste',
        (tester) async {
      await openTeclado(tester);
      expect(switchValue(tester, 'kb-clipboard-images-switch'), isFalse);

      await tapKey(tester, 'kb-clipboard-images-switch');

      expect((await prefs()).getBool('kb_clipboard_images_enabled'), isTrue);
    });
  });

  group('Teclado - vista previa', () {
    testWidgets('refleja altura, teclas y posición del micrófono',
        (tester) async {
      await openTeclado(tester);
      KeyboardPreview preview() =>
          tester.widget<KeyboardPreview>(byKey('kb-preview'));
      expect(preview().heightProfile, 'media');
      expect(preview().showTerminalRow, isTrue);
      expect(preview().invertToolbar, isFalse);

      await pickOption(tester, 'kb-height-profile-selector', 'alta');
      await tapKey(tester, 'kb-terminal-row-switch');
      await tapKey(tester, 'kb-invert-toolbar-switch');

      expect(preview().heightProfile, 'alta');
      expect(preview().showTerminalRow, isFalse);
      expect(preview().invertToolbar, isTrue);
      expect(find.text('esc'), findsNothing);
    });
  });

  group('Vibración y sonido', () {
    testWidgets('vibración de teclas ON y Nítida por defecto', (tester) async {
      await openSonido(tester);
      expect(switchValue(tester, 'kb-haptics-switch'), isTrue);
      expect(rowShows('kb-haptic-style-selector', 'Nítida'), isTrue);
    });

    testWidgets('elegir intensidad Firme persiste', (tester) async {
      await openSonido(tester);
      await pickOption(tester, 'kb-haptic-style-selector', 'firme');
      expect((await prefs()).getString('kb_haptic_style'), 'firme');
    });

    testWidgets('apagar la vibración persiste y oculta la intensidad',
        (tester) async {
      await openSonido(tester);
      await tapKey(tester, 'kb-haptics-switch');

      expect((await prefs()).getBool('kb_haptics_enabled'), isFalse);
      expect(byKey('kb-haptic-style-selector'), findsNothing);
    });

    testWidgets('micrófono: vibración ON con los 4 eventos, sonidos OFF',
        (tester) async {
      await openSonido(tester);
      expect(switchValue(tester, 'kb-mic-haptics-enabled'), isTrue);
      for (final k in const [
        'kb-mic-haptic-start',
        'kb-mic-haptic-recording',
        'kb-mic-haptic-paste',
        'kb-mic-haptic-cancel',
      ]) {
        expect(switchValue(tester, k), isTrue, reason: k);
      }
      expect(switchValue(tester, 'kb-mic-sounds-enabled'), isFalse);
      expect(byKey('kb-mic-start-style'), findsNothing);
    });

    testWidgets('apagar vibrar al cancelar persiste', (tester) async {
      await openSonido(tester);
      await tapKey(tester, 'kb-mic-haptic-cancel');
      expect((await prefs()).getBool('kb_mic_haptic_cancel'), isFalse);
    });

    testWidgets('apagar la vibración del micrófono oculta los eventos',
        (tester) async {
      await openSonido(tester);
      await tapKey(tester, 'kb-mic-haptics-enabled');
      expect(await h.storage.getMicHapticsEnabled(), isFalse);
      expect(byKey('kb-mic-haptic-start'), findsNothing);
    });

    testWidgets('encender sonidos persiste y muestra tonos (default 3)',
        (tester) async {
      await openSonido(tester);
      await tapKey(tester, 'kb-mic-sounds-enabled');

      expect(await h.storage.getMicSoundsEnabled(), isTrue);
      expect(rowShows('kb-mic-start-style', 'Tono 3'), isTrue);
      expect(rowShows('kb-mic-stop-style', 'Tono 3'), isTrue);
    });

    testWidgets('elegir tono 2 al empezar persiste', (tester) async {
      h.setUp(prefs: {'kb_mic_sounds_enabled': true});
      await openSonido(tester);

      await pickOption(tester, 'kb-mic-start-style', '2');

      expect((await prefs()).getString('kb_mic_start_style'), '2');
      expect(rowShows('kb-mic-start-style', 'Tono 2'), isTrue);
    });
  });

  group('Menú desplegable', () {
    testWidgets('marca con check la opción elegida', (tester) async {
      await openTeclado(tester);
      await tapKey(tester, 'kb-key-spacing-selector');

      expect(
        find.descendant(
          of: byKey('kb-key-spacing-selector-normal'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: byKey('kb-key-spacing-selector-extra'),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
    });
  });
}
