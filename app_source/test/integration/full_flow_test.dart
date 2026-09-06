import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';

import '../helpers/mock_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    registerAppChannelMocks();
  });

  tearDown(unregisterAppChannelMocks);

  Widget buildTestApp({Widget? home}) {
    return MaterialApp(
      home: home ?? const HomeScreen(),
    );
  }

  group('Full user flow – VoiceBubble STT', () {
    testWidgets(
      'App launches and shows HomeScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('VoiceBubble STT'), findsOneWidget);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Settings button opens SettingsScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.text('Configuración'), findsOneWidget);
      },
    );

    testWidgets(
      'SettingsScreen shows API key input',
      (WidgetTester tester) async {
        // Superficie alta para ver toda la pagina sin scroll: la tarjeta del
        // teclado y la seccion de snippets alargan la lista (9.1-17 / 9.1-21).
        tester.view.physicalSize = const Size(1600, 4800);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(buildTestApp(home: const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.text('API Key de Groq'), findsOneWidget);
        expect(find.byKey(const ValueKey('api-cta-button')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('api-cta-button')));
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('gsk_...'), findsOneWidget);
      },
    );

    testWidgets(
      'User can enter and save API key',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1600, 4800);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(buildTestApp(home: const SettingsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('api-cta-button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'gsk_test_key_123');
        await tester.pumpAndSettle();

        expect(find.text('gsk_test_key_123'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();

        expect(find.text('API key guardada'), findsOneWidget);
      },
    );

    testWidgets(
      'Back button returns to HomeScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Record button shows recording state',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
        expect(find.text('Listo para transcribir'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('recordButton')));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
        expect(find.text('Grabando...'), findsOneWidget);
      },
    );
  });

  group('SettingsScreen navigation round-trip', () {
    testWidgets(
      'Home → Settings → Back preserves state',
      (WidgetTester tester) async {
        // Superficie alta para ver toda la pagina sin scroll (hay tarjeta nueva).
        tester.view.physicalSize = const Size(1600, 4800);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('api-cta-button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'gsk_round_trip');
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.save));
        await tester.pumpAndSettle();
        expect(find.text('API key guardada'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
      },
    );
  });
}
