import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';

import '../helpers/mock_channels.dart';
import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    registerAppChannelMocks();
  });

  tearDown(unregisterAppChannelMocks);

  Widget wrapHome({Widget? home}) {
    return MaterialApp(
      home: home ?? const HomeScreen(),
    );
  }

  group('Full user flow – VoiceBubble STT', () {
    testWidgets(
      'App launches and shows HomeScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapHome());
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('homeTitleText')), findsOneWidget);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Settings button opens SettingsScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapHome());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('homeSettingsButton')));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byKey(const ValueKey('tab-general')), findsOneWidget);
      },
    );

    testWidgets(
      'SettingsScreen shows API key input',
      (WidgetTester tester) async {
        // Superficie alta para ver toda la pagina sin scroll: la tarjeta del
        // teclado y la seccion de snippets alargan la lista (9.1-17 / 9.1-21).
        configureTestViewSize(tester, physicalSize: const Size(1600, 4800));
        await tester.pumpWidget(wrapHome(home: const SettingsScreen()));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('api-cta-button')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('api-cta-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('api-key-input-field')), findsOneWidget);
      },
    );

    testWidgets(
      'User can enter and save API key',
      (WidgetTester tester) async {
        configureTestViewSize(tester, physicalSize: const Size(1600, 4800));
        await tester.pumpWidget(wrapHome(home: const SettingsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('api-cta-button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('api-key-input-field')),
          'gsk_test_key_123',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('api-key-save-button')));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'Back button returns to HomeScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapHome());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('homeSettingsButton')));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Sin AppBar (v2): Back del sistema (gesto/botón Android, sin
        // botón visible). handlePopRoute lo despacha al framework.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Record button shows recording state',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapHome());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
        expect(find.byKey(const ValueKey('homeStatusText')), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('recordButton')));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
        expect(find.byKey(const ValueKey('homeStatusText')), findsOneWidget);
      },
    );
  });

  group('SettingsScreen navigation round-trip', () {
    testWidgets(
      'Home → Settings → Back preserves state',
      (WidgetTester tester) async {
        configureTestViewSize(tester, physicalSize: const Size(1600, 4800));

        await tester.pumpWidget(wrapHome());
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('homeSettingsButton')));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('api-cta-button')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('api-key-input-field')),
          'gsk_round_trip',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('api-key-save-button')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SnackBar), findsOneWidget);

        // Sin AppBar (v2): Back del sistema (gesto/botón Android, sin
        // botón visible). handlePopRoute lo despacha al framework.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.byType(SettingsScreen), findsNothing);
      },
    );
  });
}
