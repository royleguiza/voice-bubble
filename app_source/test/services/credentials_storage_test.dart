import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/credential.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService - contrato de claves de credenciales', () {
    test('expone las claves canonicas del contrato', () {
      expect(StorageService.credentialsKey, 'vb_credentials_v1');
      expect(StorageService.credPassKey, 'vb_cred_pass_v1');
      expect(StorageService.credShowUserKey, 'vb_cred_show_user');
    });

    test('persiste indice con claves exactas id/nombre/usuario', () async {
      final service = StorageService();
      expect(
        await service.addCredential(
          nombre: 'Banco',
          usuario: 'juan@mail.com',
          password: 's3creta',
        ),
        isTrue,
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('vb_credentials_v1');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect(decoded, hasLength(1));
      expect((decoded.single as Map).keys.toList(),
          ['id', 'nombre', 'usuario']);
    });

    test('la contraseña JAMAS va en el indice', () async {
      final service = StorageService();
      await service.addCredential(
        nombre: 'Banco',
        usuario: 'juan@mail.com',
        password: 's3creta-invisible',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('vb_credentials_v1')!;
      expect(raw.contains('s3creta-invisible'), isFalse);
      final passes = prefs.getString('vb_cred_pass_v1')!;
      expect(passes.contains('s3creta-invisible'), isTrue);
    });

    test('rechaza vacios, excesos y tope de 50', () async {
      final service = StorageService();
      expect(
        await service.addCredential(nombre: '', usuario: 'u', password: 'p'),
        isFalse,
      );
      expect(
        await service.addCredential(nombre: 'n', usuario: '', password: 'p'),
        isFalse,
      );
      expect(
        await service.addCredential(nombre: 'n', usuario: 'u', password: ''),
        isFalse,
      );
      expect(
        await service.addCredential(
          nombre: 'n' * 81,
          usuario: 'u',
          password: 'p',
        ),
        isFalse,
      );
    });

    test('deleteCredential borra indice Y contraseña', () async {
      final service = StorageService();
      await service.addCredential(
        nombre: 'Banco',
        usuario: 'u',
        password: 'p',
      );
      final creds = await service.loadCredentials();
      expect(creds, hasLength(1));

      expect(await service.deleteCredential(creds.single.id), isTrue);
      expect(await service.loadCredentials(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vb_cred_pass_v1'), '{}');
      expect(await service.deleteCredential('inexistente'), isFalse);
    });

    test('showUser persiste con default false', () async {
      final service = StorageService();
      expect(await service.loadCredShowUser(), isFalse);
      await service.saveCredShowUser(true);
      expect(await service.loadCredShowUser(), isTrue);
    });

    test('lectura corrupta devuelve vacio y bloquea escritura', () async {
      SharedPreferences.setMockInitialValues({
        'vb_credentials_v1': 'esto-no-es-json{{{',
      });
      final service = StorageService();
      expect(await service.loadCredentials(), isEmpty);
      expect(
        await service.addCredential(nombre: 'n', usuario: 'u', password: 'p'),
        isFalse,
      );
    });
  });

  group('VbCredential - modelo sin secretos', () {
    test('toString nunca expone password (ni existe el campo)', () async {
      const cred = VbCredential(id: '1', nombre: 'Banco', usuario: 'u');
      expect(cred.toString().contains('p4ss'), isFalse);
      expect(cred.toJson().keys.toList(), ['id', 'nombre', 'usuario']);
    });
  });
}
