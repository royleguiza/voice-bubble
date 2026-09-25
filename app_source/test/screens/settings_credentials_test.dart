import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/credential.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

class _TrackedStorageService extends StorageService {
  final Completer<void> keyboardCredentialsKeySaved = Completer<void>();
  final List<VbCredential> _credentials = <VbCredential>[];
  bool _showUser = false;

  @override
  Future<List<VbCredential>> loadCredentials() =>
      Future<List<VbCredential>>.value(List<VbCredential>.unmodifiable(
        _credentials,
      ));

  @override
  Future<bool> loadCredShowUser() => Future<bool>.value(_showUser);

  @override
  Future<bool> addCredential({
    required String nombre,
    required String usuario,
    required String password,
  }) {
    _credentials.add(
      VbCredential(
        id: '${_credentials.length + 1}',
        nombre: nombre,
        usuario: usuario,
      ),
    );
    return Future<bool>.value(true);
  }

  @override
  Future<void> saveCredShowUser(bool value) {
    _showUser = value;
    return Future<void>.value();
  }

  @override
  Future<void> saveKeyboardCredentialsKeyVisible(bool visible) async {
    try {
      await super.saveKeyboardCredentialsKeyVisible(visible);
    } finally {
      if (!keyboardCredentialsKeySaved.isCompleted) {
        keyboardCredentialsKeySaved.complete();
      }
    }
  }

  @override
  Future<bool> loadKeyboardCredentialsKeyVisible() =>
      super.loadKeyboardCredentialsKeyVisible();

  @override
  Future<bool> deleteCredential(String id) {
    final previousLength = _credentials.length;
    _credentials.removeWhere((credential) => credential.id == id);
    return Future<bool>.value(_credentials.length != previousLength);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(FloatingBubbleService.channelName);
  const keyboardChannel = MethodChannel(KeyboardService.channelName);

  late _TrackedStorageService storageService;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    storageService = _TrackedStorageService();

    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'canDrawOverlays':
          return true;
        case 'requestOverlayPermission':
          return true;
        case 'startBubble':
          return true;
        case 'stopBubble':
          return true;
        case 'isBubbleRunning':
          return false;
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(keyboardChannel,
        (MethodCall call) async {
      switch (call.method) {
        case 'isKeyboardEnabled':
          return false;
        case 'isKeyboardSelected':
          return false;
        case 'openKeyboardSettings':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(keyboardChannel, null);
  });

  Widget buildTestableWidget(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 4800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    return MaterialApp(
      home: SettingsScreen(
        storageService: storageService,
        floatingBubbleService: FloatingBubbleService(),
        keyboardService: KeyboardService(channel: keyboardChannel),
      ),
    );
  }

  Future<void> openCredencialesTab(WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-credenciales')));
    await tester.pumpAndSettle();
  }

  group('SettingsScreen - tab Claves (credenciales)', () {
    testWidgets('el dock tiene Claves y abre su seccion propia',
        (tester) async {
      await openCredencialesTab(tester);

      expect(find.text('Claves'), findsWidgets);
      expect(
        find.byKey(const ValueKey('credenciales-add-nombre')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('credenciales-add-usuario')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('credenciales-add-password')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('credenciales-add-button')),
        findsOneWidget,
      );
      // Banner experimental por key (no por texto: el copy puede cambiar).
      expect(
        find.byKey(const ValueKey('experimental-banner-claves')),
        findsOneWidget,
      );
    });

    testWidgets('el campo password es obscure y no hay ojo', (tester) async {
      await openCredencialesTab(tester);

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('credenciales-add-password')),
      );
      expect(field.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.visibility_off), findsNothing);
    });

    testWidgets('guardar agrega y muestra solo el nombre', (tester) async {
      await openCredencialesTab(tester);

      await tester.enterText(
        find.byKey(const ValueKey('credenciales-add-nombre')),
        'Banco',
      );
      await tester.enterText(
        find.byKey(const ValueKey('credenciales-add-usuario')),
        'juan@mail.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('credenciales-add-password')),
        's3creta',
      );
      await tester.tap(find.byKey(const ValueKey('credenciales-add-button')));
      await tester.pumpAndSettle();

      expect(find.text('Banco'), findsOneWidget);
      // Sin showUser: el usuario no se muestra y la pass jamás aparece.
      expect(find.text('juan@mail.com'), findsNothing);
      expect(find.text('s3creta'), findsNothing);
    });

    testWidgets('el switch revela el usuario y borrar limpia todo',
        (tester) async {
      await openCredencialesTab(tester);

      await tester.enterText(
        find.byKey(const ValueKey('credenciales-add-nombre')),
        'Banco',
      );
      await tester.enterText(
        find.byKey(const ValueKey('credenciales-add-usuario')),
        'juan@mail.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('credenciales-add-password')),
        's3creta',
      );
      await tester.tap(find.byKey(const ValueKey('credenciales-add-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('credenciales-show-user')));
      await tester.pumpAndSettle();
      expect(find.text('juan@mail.com'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(find.text('Banco'), findsNothing);
    });

    testWidgets('el switch de la llave oculta la llavecita del teclado',
        (tester) async {
      await openCredencialesTab(tester);

      final switchFinder =
          find.byKey(const ValueKey('credenciales-key-visible-switch'));
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.runAsync(() async {
        await storageService.keyboardCredentialsKeySaved.future;
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getBool('kb_credentials_key_visible'), isFalse);
      });
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(switchFinder).value,
        isFalse,
      );
    });
  });
}
