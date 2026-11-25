import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/screens/onboarding/onboarding_screen.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

import '../helpers/l10n_app.dart';
import '../helpers/test_app.dart';

/// T13 · Primer uso: de la instalación limpia al primer dictado sin Ajustes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const keyboardChannel = MethodChannel(KeyboardService.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  var keyboardEnabled = false;
  var keyboardSelected = false;
  String? clipboard;

  setUp(() {
    calls.clear();
    keyboardEnabled = false;
    keyboardSelected = false;
    clipboard = null;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    messenger.setMockMethodCallHandler(keyboardChannel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isKeyboardEnabled':
          return keyboardEnabled;
        case 'isKeyboardSelected':
          return keyboardSelected;
        default:
          return true;
      }
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return clipboard == null ? null : {'text': clipboard};
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(keyboardChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Abre el primer uso empujado sobre una pantalla, como en la app.
  Future<void> pumpOnboarding(WidgetTester tester, {bool mic = true}) async {
    configureTestViewSize(tester, physicalSize: const Size(1200, 2600));
    await tester.pumpWidget(esMaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            key: const ValueKey('open-onb'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => OnboardingScreen(
                storageService: StorageService(),
                keyboardService: KeyboardService(channel: keyboardChannel),
                requestMicrophone: () async => mic,
              ),
            )),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('open-onb')));
    await tester.pumpAndSettle();
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> tap(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.tap(key(k));
    await tester.pumpAndSettle();
  }

  testWidgets('recorrido completo hasta el primer dictado', (tester) async {
    await pumpOnboarding(tester);
    expect(find.text('Bienvenido a Orison'), findsOneWidget);

    await tap(tester, 'onb-next');
    // Para qué: vender precarga snippets de ejemplo.
    await tap(tester, 'onb-use-sales');
    final snippets = await StorageService().loadSnippets();
    expect(snippets.map((s) => s.nombre), containsAll(['Saludo', 'Precios', 'Envíos']));

    await tap(tester, 'onb-next');
    // Privacidad: aceptar guarda el aviso.
    expect(find.text('Antes de dictar'), findsOneWidget);
    await tap(tester, 'onb-next');
    expect(await StorageService().loadPrivacyNoticeAccepted(), isTrue);

    // Clave de Groq: el botón abre la página de claves.
    await tap(tester, 'onb-open-groq');
    expect(calls, contains('openUrl'));
    await tester.enterText(key('onb-key-field'), 'gsk_clave_de_prueba_123456');
    await tap(tester, 'onb-key-save');
    const secure = FlutterSecureStorage(aOptions: StorageService.espOptions);
    expect(await secure.read(key: 'groq_api_key'), 'gsk_clave_de_prueba_123456');
    expect(key('onb-key-ready'), findsOneWidget);

    await tap(tester, 'onb-next');
    await tap(tester, 'onb-mic-button');
    expect(find.text('Micrófono permitido'), findsOneWidget);

    await tap(tester, 'onb-next');
    await tap(tester, 'onb-kb-enable');
    expect(calls, contains('openKeyboardSettings'));

    await tap(tester, 'onb-next');
    await tester.enterText(key('onb-try-field'), 'hola mundo');
    await tester.pumpAndSettle();
    expect(key('onb-try-done'), findsOneWidget);

    await tap(tester, 'onb-next');
    expect(await StorageService().loadOnboardingDone(), isTrue);
    // Bug del 25/11: «Empezar a usar» volvía al paso anterior en vez de cerrar.
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('una clave copiada se ofrece para pegar', (tester) async {
    clipboard = 'gsk_copiada_desde_groq_1234567890';
    await pumpOnboarding(tester);
    await tap(tester, 'onb-next');
    await tap(tester, 'onb-next');
    await tap(tester, 'onb-next');
    expect(key('onb-paste-copied-key'), findsOneWidget);
    await tap(tester, 'onb-paste-copied-key');
    const secure = FlutterSecureStorage(aOptions: StorageService.espOptions);
    expect(await secure.read(key: 'groq_api_key'), clipboard);
  });

  testWidgets('una clave inválida muestra el error y no se guarda', (tester) async {
    await pumpOnboarding(tester);
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'onb-next');
    }
    await tester.enterText(key('onb-key-field'), 'sk-otra-cosa-123');
    await tap(tester, 'onb-key-save');
    const secure = FlutterSecureStorage(aOptions: StorageService.espOptions);
    expect(await secure.read(key: 'groq_api_key'), isNull);
    expect(key('onb-key-ready'), findsNothing);
  });

  testWidgets('saltear todo lo da por hecho', (tester) async {
    await pumpOnboarding(tester);
    await tap(tester, 'onb-skip-all');
    expect(await StorageService().loadOnboardingDone(), isTrue);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
