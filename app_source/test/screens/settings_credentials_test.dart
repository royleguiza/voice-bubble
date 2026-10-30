import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/models/credential.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

import '../helpers/settings_harness.dart';

/// Almacenamiento en memoria para credenciales: aísla la bóveda cifrada y
/// permite verificar que la contraseña nunca vuelve a la UI.
class _MemoryCredentialStorage extends StorageService {
  final List<VbCredential> credentials = <VbCredential>[];
  final Map<String, String> passwords = <String, String>{};
  bool showUser = false;

  @override
  Future<List<VbCredential>> loadCredentials() =>
      Future.value(List<VbCredential>.unmodifiable(credentials));

  @override
  Future<bool> loadCredShowUser() => Future.value(showUser);

  @override
  Future<void> saveCredShowUser(bool value) async => showUser = value;

  @override
  Future<bool> addCredential({
    required String nombre,
    required String usuario,
    required String password,
  }) async {
    if (nombre.trim().isEmpty || usuario.trim().isEmpty) return false;
    final id = '${credentials.length + 1}';
    credentials.add(VbCredential(id: id, nombre: nombre, usuario: usuario));
    passwords[id] = password;
    return true;
  }

  @override
  Future<bool> deleteCredential(String id) async {
    final before = credentials.length;
    credentials.removeWhere((c) => c.id == id);
    passwords.remove(id);
    return credentials.length != before;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = SettingsHarness();
  late _MemoryCredentialStorage storage;

  setUp(() {
    h.setUp();
    storage = _MemoryCredentialStorage();
  });
  tearDown(h.tearDown);

  Future<void> openClaves(WidgetTester tester) async {
    await h.pump(tester, storageService: storage);
    await openPage(tester, 'claves');
  }

  Future<void> addCredential(WidgetTester tester) async {
    await tapKey(tester, 'credenciales-open-add');
    await tester.enterText(byKey('credenciales-add-nombre'), 'Banco');
    await tester.enterText(byKey('credenciales-add-usuario'), 'juan@mail.com');
    await tester.enterText(byKey('credenciales-add-password'), 's3creta');
    await tapKey(tester, 'credenciales-add-button');
  }

  group('Claves (credenciales)', () {
    testWidgets('sin claves muestra el estado vacío con acción',
        (tester) async {
      await openClaves(tester);

      expect(find.text('Sin claves guardadas'), findsOneWidget);
      await tapKey(tester, 'credenciales-empty-add');
      expect(byKey('credenciales-add-nombre'), findsOneWidget);
    });

    testWidgets('la contraseña es oculta y no hay botón de ver',
        (tester) async {
      await openClaves(tester);
      await tapKey(tester, 'credenciales-open-add');

      final field = tester.widget<TextField>(find.descendant(
        of: byKey('credenciales-add-password'),
        matching: find.byType(TextField),
      ));
      expect(field.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility), findsNothing);
      expect(find.byIcon(Icons.visibility_off), findsNothing);
    });

    testWidgets('guardar agrega y muestra solo el nombre', (tester) async {
      await openClaves(tester);
      await addCredential(tester);

      expect(byKey('credenciales-add-nombre'), findsNothing);
      expect(find.text('Banco'), findsOneWidget);
      expect(find.text('juan@mail.com'), findsNothing);
      expect(find.text('s3creta'), findsNothing);
      expect(storage.passwords['1'], 's3creta');
    });

    testWidgets('campos vacíos muestran aviso y no cierran el sheet',
        (tester) async {
      await openClaves(tester);
      await tapKey(tester, 'credenciales-open-add');
      await tapKey(tester, 'credenciales-add-button');

      expect(byKey('credenciales-add-nombre'), findsOneWidget);
      expect(find.textContaining('Revisá los campos'), findsOneWidget);
      expect(storage.credentials, isEmpty);
    });

    testWidgets('Mostrar usuario revela el usuario y persiste',
        (tester) async {
      await openClaves(tester);
      await addCredential(tester);

      await tapKey(tester, 'credenciales-show-user');

      expect(find.text('juan@mail.com'), findsOneWidget);
      expect(storage.showUser, isTrue);
    });

    testWidgets('borrar pide confirmación y limpia la clave', (tester) async {
      await openClaves(tester);
      await addCredential(tester);

      await tapKey(tester, 'credenciales-delete-1');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tapKey(tester, 'credenciales-confirm-delete');

      expect(find.text('Banco'), findsNothing);
      expect(storage.credentials, isEmpty);
      expect(storage.passwords, isEmpty);
    });

    testWidgets('la llave del teclado se gobierna desde Teclado',
        (tester) async {
      await h.pump(tester, storageService: storage);
      await openPage(tester, 'teclado');
      expect(switchValue(tester, 'credenciales-key-visible-switch'), isTrue);

      await tapKey(tester, 'credenciales-key-visible-switch');

      expect((await prefs()).getBool('kb_credentials_key_visible'), isFalse);
    });
  });
}
