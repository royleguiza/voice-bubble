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
  final Completer<bool> addCompleted = Completer<bool>();
  final Completer<void> showUserSaved = Completer<void>();
  final Completer<void> keyboardCredentialsKeySaved = Completer<void>();
  final Completer<bool> deleteCompleted = Completer<bool>();
  final List<Completer<void>> _expectedCredentialsLoads = <Completer<void>>[];
  final List<Completer<void>> _expectedShowUserLoads = <Completer<void>>[];
  int credentialsLoadCount = 0;
  int showUserLoadCount = 0;
  bool? savedKeyboardCredentialsKeyVisible;

  Future<void> expectNextCredentialsLoad() {
    final completion = Completer<void>();
    _expectedCredentialsLoads.add(completion);
    return completion.future;
  }

  Future<void> expectNextShowUserLoad() {
    final completion = Completer<void>();
    _expectedShowUserLoads.add(completion);
    return completion.future;
  }

  Completer<void>? _takeExpected(List<Completer<void>> expected) {
    return expected.isEmpty ? null : expected.removeAt(0);
  }

  @override
  Future<List<VbCredential>> loadCredentials() async {
    credentialsLoadCount += 1;
    final completion = _takeExpected(_expectedCredentialsLoads);
    try {
      return await super.loadCredentials();
    } finally {
      completion?.complete();
    }
  }

  @override
  Future<bool> loadCredShowUser() async {
    showUserLoadCount += 1;
    final completion = _takeExpected(_expectedShowUserLoads);
    try {
      return await super.loadCredShowUser();
    } finally {
      completion?.complete();
    }
  }

  @override
  Future<bool> addCredential({
    required String nombre,
    required String usuario,
    required String password,
  }) async {
    final result = await super.addCredential(
      nombre: nombre,
      usuario: usuario,
      password: password,
    );
    if (!addCompleted.isCompleted) addCompleted.complete(result);
    return result;
  }

  @override
  Future<void> saveCredShowUser(bool value) async {
    await super.saveCredShowUser(value);
    if (!showUserSaved.isCompleted) showUserSaved.complete();
  }

  @override
  Future<void> saveKeyboardCredentialsKeyVisible(bool visible) async {
    savedKeyboardCredentialsKeyVisible = visible;
    try {
      await super.saveKeyboardCredentialsKeyVisible(visible);
    } finally {
      if (!keyboardCredentialsKeySaved.isCompleted) {
        keyboardCredentialsKeySaved.complete();
      }
    }
  }

  @override
  Future<bool> deleteCredential(String id) async {
    final result = await super.deleteCredential(id);
    if (!deleteCompleted.isCompleted) deleteCompleted.complete(result);
    return result;
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
    final credentialsLoaded = storageService.expectNextCredentialsLoad();
    final showUserLoaded = storageService.expectNextShowUserLoad();
    await tester.pumpWidget(buildTestableWidget(tester));
    await tester.tap(find.byKey(const ValueKey('tab-credenciales')));
    await tester.pump();
    await tester.runAsync(() => credentialsLoaded);
    await tester.pump();
    await tester.runAsync(() => showUserLoaded);
    await tester.pump();
    expect(storageService.credentialsLoadCount, 1);
    expect(storageService.showUserLoadCount, 1);
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
      final credentialsReloaded =
          storageService.expectNextCredentialsLoad();
      final showUserReloaded = storageService.expectNextShowUserLoad();
      await tester.tap(find.byKey(const ValueKey('credenciales-add-button')));
      await tester.runAsync(() => storageService.addCompleted.future);
      await tester.pump();
      await tester.runAsync(() => credentialsReloaded);
      await tester.pump();
      await tester.runAsync(() => showUserReloaded);
      await tester.pump();
      expect(storageService.credentialsLoadCount, 2);
      expect(storageService.showUserLoadCount, 2);

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
      final credentialsReloaded =
          storageService.expectNextCredentialsLoad();
      final showUserReloaded = storageService.expectNextShowUserLoad();
      await tester.tap(find.byKey(const ValueKey('credenciales-add-button')));
      await tester.runAsync(() => storageService.addCompleted.future);
      await tester.pump();
      await tester.runAsync(() => credentialsReloaded);
      await tester.pump();
      await tester.runAsync(() => showUserReloaded);
      await tester.pump();
      expect(storageService.credentialsLoadCount, 2);
      expect(storageService.showUserLoadCount, 2);

      await tester.tap(find.byKey(const ValueKey('credenciales-show-user')));
      await tester.runAsync(() => storageService.showUserSaved.future);
      await tester.pump();
      expect(find.text('juan@mail.com'), findsOneWidget);

      final credentialsReloaded =
          storageService.expectNextCredentialsLoad();
      final showUserReloaded = storageService.expectNextShowUserLoad();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.runAsync(() => storageService.deleteCompleted.future);
      await tester.pump();
      await tester.runAsync(() => credentialsReloaded);
      await tester.pump();
      await tester.runAsync(() => showUserReloaded);
      await tester.pump();
      expect(storageService.credentialsLoadCount, 3);
      expect(storageService.showUserLoadCount, 3);
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
      await tester.runAsync(
        () => storageService.keyboardCredentialsKeySaved.future,
      );
      await tester.pump();
      expect(storageService.savedKeyboardCredentialsKeyVisible, isFalse);
      expect(
        tester.widget<SwitchListTile>(switchFinder).value,
        isFalse,
      );
    });
  });
}
