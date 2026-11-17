import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/l10n/app_localizations.dart';
import 'package:voice_bubble_stt/main.dart';
import 'package:voice_bubble_stt/ui/app_locale.dart';

import 'helpers/mock_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    registerAppChannelMocks();
    // El entorno de test es en-US: las aserciones de abajo son en español.
    appLocale.value = const Locale('es');
  });

  tearDown(() {
    appLocale.value = null;
    unregisterAppChannelMocks();
  });

  group('Idioma de la app (etapa 4)', () {
    String title(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('homeTitleText')))
        .data!;

    testWidgets('sigue al teléfono; sin traducción cae en inglés',
        (tester) async {
      appLocale.value = null;
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(const VoiceBubbleApp());
      await tester.pumpAndSettle();
      expect(title(tester), 'Notes');
    });

    testWidgets('el elegido en Ajustes manda y cambia en vivo',
        (tester) async {
      await tester.pumpWidget(const VoiceBubbleApp());
      await tester.pumpAndSettle();
      expect(title(tester), 'Notas');
      appLocale.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(title(tester), 'Notes');
      appLocale.value = const Locale('pt');
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byKey(const ValueKey('homeTitleText')));
      expect(AppLocalizations.of(ctx).localeName, 'pt');
      expect(AppLocalizations.of(ctx).homeTabHistory, 'Histórico');
    });
  });

  group('VoiceBubbleApp Widget Tests', () {
    // Smoke único de lanzamiento + grabación. La navegación Home→Settings
    // vive solo en integration/full_flow_test.dart y settings_screen_test.dart
    // (sin duplicarla aquí).
    testWidgets('La app abre y alterna estado de grabación', (tester) async {
      await tester.pumpWidget(const VoiceBubbleApp());
      await tester.pumpAndSettle();

      // Estado inicial: abre en Notas con la burbuja en reposo.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('homeTitleText'))).data,
        'Notas',
      );
      expect(find.byKey(const ValueKey('recordIdle')), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsNothing);

      // Iniciar grabación: tap en el botón de grabar
      await tester.tap(find.byKey(const ValueKey('recordButton')));
      await tester.pump(const Duration(milliseconds: 400));

      // Verificación: la burbuja se estiró en pastilla de grabación.
      expect(find.byKey(const ValueKey('recordPill')), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);

      // Detener grabación: segundo tap alterna a detener
      await tester.tap(find.byKey(const ValueKey('recordButton')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Verificación: grabación detenida, vuelve al estado inicial
      expect(find.byKey(const ValueKey('recordPill')), findsNothing);
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });
  });
}
