import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/credential.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
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
      final decoded = jsonDecode(raw!) as List<dynamic>;
      expect(decoded, hasLength(1));
      expect(
        (decoded.single as Map<dynamic, dynamic>).keys.toList(),
        ['id', 'nombre', 'usuario'],
      );
    });

    test('la contraseña JAMAS va en prefs planas (solo bóveda)', () async {
      final service = StorageService();
      await service.addCredential(
        nombre: 'Banco',
        usuario: 'juan@mail.com',
        password: 's3creta-invisible',
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('vb_credentials_v1')!;
      expect(raw.contains('s3creta-invisible'), isFalse);
      expect(prefs.getString('vb_cred_pass_v1'), isNull);
      const secure =
          FlutterSecureStorage(aOptions: StorageService.espOptions);
      final passes = await secure.read(key: 'vb_cred_pass_v1');
      expect(passes, isNotNull);
      expect(passes!.contains('s3creta-invisible'), isTrue);
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
      final credentials = await service.loadCredentials();
      expect(credentials, hasLength(1));

      expect(await service.deleteCredential(credentials.single.id), isTrue);
      expect(await service.loadCredentials(), isEmpty);
      const secure =
          FlutterSecureStorage(aOptions: StorageService.espOptions);
      expect(await secure.read(key: 'vb_cred_pass_v1'), '{}');
      expect(await service.deleteCredential('inexistente'), isFalse);
    });

    test('migra el mapa plano legado a la bóveda una sola vez', () async {
      SharedPreferences.setMockInitialValues({
        'vb_cred_pass_v1': '{"abc":"legada123"}',
      });
      final service = StorageService();
      expect(
        await service.addCredential(
          nombre: 'n',
          usuario: 'u',
          password: 'nueva',
        ),
        isTrue,
      );

      const secure =
          FlutterSecureStorage(aOptions: StorageService.espOptions);
      final blob = await secure.read(key: 'vb_cred_pass_v1');
      expect(blob, isNotNull);
      expect(blob!.contains('legada123'), isTrue);
      expect(blob.contains('nueva'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('vb_cred_pass_v1'), isNull);
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
        await service.addCredential(
          nombre: 'n',
          usuario: 'u',
          password: 'p',
        ),
        isFalse,
      );
    });
  });

  group('C-03 atomicidad todo-o-nada + barrido de huerfanos', () {
    test('null es missing y string vacío sigue corrupto', () async {
      final missing = _service(_ScriptedIndexStore(), _ScriptedVault());
      expect(
        await missing.addCredential(
          nombre: 'missing',
          usuario: 'u',
          password: 'p-missing',
        ),
        isTrue,
      );

      final empty = _service(
        _ScriptedIndexStore(raw: '[]'),
        _ScriptedVault(raw: ''),
      );
      expect(
        await empty.addCredential(
          nombre: 'empty',
          usuario: 'u',
          password: 'p-empty',
        ),
        isFalse,
      );
    });

    test('un índice missing preserva una bóveda válida y no purga', () async {
      const vaultRaw = '{"existing":"p-existing"}';
      final index = _ScriptedIndexStore();
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      await service.sweepCredentialOrphans();

      expect(index.raw, isNull);
      expect(vault.raw, vaultRaw);
      expect(index.writeCount, 0);
      expect(vault.writeCount, 0);
      expect(await service.loadCredentials(), isEmpty);
    });

    test('add desde índice missing conserva la bóveda existente', () async {
      const vaultRaw = '{"existing":"p-existing"}';
      final index = _ScriptedIndexStore();
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isTrue,
      );

      final entries = _indexEntries(index);
      expect(entries, hasLength(1));
      expect(entries.single['nombre'], 'new');
      final id = entries.single['id']!;
      expect(_passMap(vault), {
        'existing': 'p-existing',
        id: 'p-new',
      });
    });

    test('bóveda vacía o corrupta bloquea add, delete y sweep', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"target","nombre":"Target","usuario":"u"}]';
      for (final raw in <String>['', 'no-json{{{', '[]', '{"x":1}']) {
        final index = _ScriptedIndexStore(raw: indexRaw);
        final vault = _ScriptedVault(raw: raw);
        final service = _service(index, vault);

        expect(
          await service.addCredential(
            nombre: 'new',
            usuario: 'u',
            password: 'new-password',
          ),
          isFalse,
        );
        expect(await service.deleteCredential('target'), isFalse);
        await service.sweepCredentialOrphans();
        expect(await service.loadCredentials(), hasLength(2));
        expect(index.raw, indexRaw);
        expect(vault.raw, raw);
        expect(index.writeCount, 0);
        expect(index.removeCount, 0);
        expect(vault.writeCount, 0);
        expect(vault.deleteCount, 0);
      }
    });

    test('legacy corrupto o vacío no bloquea sweep con bóveda válida',
        () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"target","nombre":"Target","usuario":"u"}]';
      for (final legacyRaw in <String>[
        '',
        'no-json{{{',
        '[]',
        '"legacy"',
        '{"legacy":1}',
      ]) {
        SharedPreferences.setMockInitialValues({
          StorageService.credPassKey: legacyRaw,
        });
        final index = _ScriptedIndexStore(raw: indexRaw);
        final vault = _ScriptedVault(
          raw: '{"keep":"p-keep","target":"p-target"}',
        );
        final service = _service(index, vault);

        final credentials = await service.loadCredentials();
        expect(
          credentials.map((credential) => credential.id).toList(),
          ['keep', 'target'],
        );
        await service.sweepCredentialOrphans();

        expect(index.raw, indexRaw);
        expect(vault.raw, '{"keep":"p-keep","target":"p-target"}');
        expect(index.writeCount, 0);
        expect(vault.writeCount, 0);
        expect(await _legacyRaw(), legacyRaw);
      }
    });

    test('legacy corrupto no bloquea mutaciones con bóveda válida', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"target","nombre":"Target","usuario":"u"}]';
      SharedPreferences.setMockInitialValues({
        StorageService.credPassKey: 'legacy-corrupto',
      });
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: '{"keep":"p-keep","target":"p-target"}',
      );
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isTrue,
      );
      expect(await service.deleteCredential('target'), isTrue);
      final ids = _indexEntries(index).map((entry) => entry['id']).toSet();
      expect(ids, hasLength(2));
      expect(ids, contains('keep'));
      expect(ids, isNot(contains('target')));
      final passwords = _passMap(vault);
      expect(passwords, hasLength(2));
      expect(passwords.values.toSet(), {'p-keep', 'p-new'});
      expect(await _legacyRaw(), 'legacy-corrupto');
    });

    test('legacy corrupto con bóveda ausente conserva el índice', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      SharedPreferences.setMockInitialValues({
        StorageService.credPassKey: 'legacy-corrupto',
      });
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault();
      final service = _service(index, vault);

      expect((await service.loadCredentials()).single.id, 'keep');
      expect(await service.deleteCredential('keep'), isFalse);
      await service.sweepCredentialOrphans();

      expect(index.raw, indexRaw);
      expect(vault.raw, isNull);
      expect(await _legacyRaw(), 'legacy-corrupto');
    });

    test('migración válida fusiona, verifica y borra legacy', () async {
      const indexRaw =
          '[{"id":"shared","nombre":"Shared","usuario":"u"},{"id":"vault-only","nombre":"Vault","usuario":"u"},{"id":"plain-only","nombre":"Plain","usuario":"u"}]';
      const legacyRaw =
          '{"shared":"plain-loses","plain-only":"p-plain"}';
      SharedPreferences.setMockInitialValues({
        StorageService.credPassKey: legacyRaw,
      });
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: '{"shared":"p-vault","vault-only":"p-vault-only"}',
      );
      final service = _service(index, vault);

      final credentials = await service.loadCredentials();

      expect(credentials.map((credential) => credential.id).toList(), [
        'shared',
        'vault-only',
        'plain-only',
      ]);
      expect(_passMap(vault), {
        'shared': 'p-vault',
        'vault-only': 'p-vault-only',
        'plain-only': 'p-plain',
      });
      expect(index.raw, indexRaw);
      expect(await _legacyRaw(), isNull);
    });

    test('migración válida con vault ausente conserva todos los legacy',
        () async {
      const legacyRaw = '{"one":"p-one","two":"p-two"}';
      SharedPreferences.setMockInitialValues({
        StorageService.credPassKey: legacyRaw,
      });
      final index = _ScriptedIndexStore(
        raw: '[{"id":"one","nombre":"One","usuario":"u"},{"id":"two","nombre":"Two","usuario":"u"}]',
      );
      final vault = _ScriptedVault();
      final service = _service(index, vault);

      final credentials = await service.loadCredentials();

      expect(credentials.map((credential) => credential.id).toList(), [
        'one',
        'two',
      ]);
      expect(_passMap(vault), {'one': 'p-one', 'two': 'p-two'});
      expect(await _legacyRaw(), isNull);
    });

    test('fallo de write de migración restaura vault y conserva legacy',
        () async {
      const legacyRaw = '{"legacy":"p-legacy"}';
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      SharedPreferences.setMockInitialValues({
        StorageService.credPassKey: legacyRaw,
      });
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: vaultRaw,
        failWriteAt: <int>{1},
        persistBeforeFailedWrite: true,
      );
      final service = _service(index, vault);

      final credentials = await service.loadCredentials();

      expect(
        credentials.map((credential) => credential.id).toList(),
        ['keep'],
      );
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep'});
      expect(await _legacyRaw(), legacyRaw);
    });

    test('migración fallida no pisa una bóveda concurrente', () async {
      const legacyRaw = '{"legacy":"p-legacy"}';
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const externalVault =
          '{"keep":"p-keep","external":"p-external"}';
      SharedPreferences.setMockInitialValues({
        StorageService.credPassKey: legacyRaw,
      });
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(raw: '{"keep":"p-keep"}');
      vault.beforeWriteHook = () {
        vault.raw = externalVault;
        return Future<void>.value();
      };
      final service = _service(index, vault);

      expect(await service.loadCredentials(), hasLength(1));
      expect(vault.raw, externalVault);
      expect(index.raw, indexRaw);
      expect(await _legacyRaw(), legacyRaw);
    });

    test('add concurrente conserva estado real de índice y bóveda', () async {
      final first = StorageService().addCredential(
        nombre: 'Uno',
        usuario: 'u1',
        password: 'p1',
      );
      final second = StorageService().addCredential(
        nombre: 'Dos',
        usuario: 'u2',
        password: 'p2',
      );

      expect(await Future.wait([first, second]), [isTrue, isTrue]);
      final credentials = await StorageService().loadCredentials();
      expect(credentials, hasLength(2));
      expect(
        credentials.map((credential) => credential.nombre).toSet(),
        {'Uno', 'Dos'},
      );
      const secure = FlutterSecureStorage(aOptions: StorageService.espOptions);
      final raw = await secure.read(key: StorageService.credPassKey);
      expect(raw, isNotNull);
      expect(jsonDecode(raw!) as Map<String, dynamic>, hasLength(2));
    });

    test('add concurrente serializa snapshots y conserva ambos ids',
        () async {
      final index = _ScriptedIndexStore();
      final vault = _ScriptedVault();
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      index.writeHook = () {
        writeStarted.complete();
        return releaseWrite.future;
      };
      final firstService = _service(index, vault);
      final secondService = _service(index, vault);

      final first = firstService.addCredential(
        nombre: 'Uno',
        usuario: 'u1',
        password: 'p1',
      );
      await writeStarted.future;
      final readsBeforeSecond = vault.readCount;
      final second = secondService.addCredential(
        nombre: 'Dos',
        usuario: 'u2',
        password: 'p2',
      );
      await Future<void>.delayed(Duration.zero);
      expect(vault.readCount, readsBeforeSecond);
      releaseWrite.complete();

      expect(await first, isTrue);
      expect(await second, isTrue);
      final entries = _indexEntries(index);
      expect(entries, hasLength(2));
      expect(
        entries.map((entry) => entry['id']).toSet(),
        hasLength(2),
      );
      expect(
        entries.map((entry) => entry['nombre']).toSet(),
        {'Uno', 'Dos'},
      );
      final passwords = _passMap(vault);
      expect(passwords, hasLength(2));
      expect(passwords.values.toSet(), {'p1', 'p2'});
    });

    test('add falla CAS y no pisa un índice concurrente', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      const externalIndex =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"external","nombre":"External","usuario":"u"}]';
      final index = _ScriptedIndexStore(raw: indexRaw);
      index.beforeWriteHook = () {
        index.raw = externalIndex;
        return Future<void>.value();
      };
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(index.raw, externalIndex);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep'});
    });

    test('delete falla CAS y conserva vault concurrente', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"target","nombre":"Target","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","target":"p-target"}';
      const externalVault =
          '{"keep":"p-keep","target":"p-target","external":"p-external"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(raw: vaultRaw);
      vault.beforeWriteHook = () {
        vault.raw = externalVault;
        return Future<void>.value();
      };
      final service = _service(index, vault);

      expect(await service.deleteCredential('target'), isFalse);
      expect(index.raw, indexRaw);
      expect(vault.raw, externalVault);
      expect(_passMap(vault), {
        'keep': 'p-keep',
        'target': 'p-target',
        'external': 'p-external',
      });
    });

    test('sweep falla CAS y no restaura ni pisa estado concurrente',
        () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"index-orphan","nombre":"Broken","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","vault-orphan":"p-orphan"}';
      const externalIndex =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"external","nombre":"External","usuario":"u"}]';
      final index = _ScriptedIndexStore(raw: indexRaw);
      index.beforeWriteHook = () {
        index.raw = externalIndex;
        return Future<void>.value();
      };
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      await service.sweepCredentialOrphans();

      expect(index.raw, externalIndex);
      expect(vault.raw, vaultRaw);
    });

    test('fallo de read inicial aborta antes de cualquier escritura',
        () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: vaultRaw,
        failReadAt: <int>{1},
      );
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(index.writeCount, 0);
      expect(vault.writeCount, 0);
    });

    test('add hace rollback exacto si falla write de vault', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: vaultRaw,
        failWriteAt: <int>{1},
      );
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep'});
    });

    test('add reconcilia write de vault persistido antes del error',
        () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: vaultRaw,
        failWriteAt: <int>{1},
        persistBeforeFailedWrite: true,
      );
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(vault.writeCount, 2);
      expect(_passMap(vault), {'keep': 'p-keep'});
    });

    test('add hace rollback exacto si falla verify de vault', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: vaultRaw,
        failVerifyAt: <int>{1},
      );
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep'});
    });

    test('add hace rollback de vault e índice si falla índice', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      final index = _ScriptedIndexStore(
        raw: indexRaw,
        failWriteAt: <int>{1},
      );
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep'});
    });

    test('add rollback conserva la migración legacy sin volver a prefs planas',
        () async {
      const legacyRaw = '{"legacy":"p-legacy"}';
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      SharedPreferences.setMockInitialValues({
        StorageService.credPassKey: legacyRaw,
      });
      final index = _ScriptedIndexStore(
        raw: indexRaw,
        failWriteAt: <int>{1},
      );
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(index.raw, indexRaw);
      expect(vault.raw, '{"keep":"p-keep","legacy":"p-legacy"}');
      expect(_passMap(vault), {'keep': 'p-keep', 'legacy': 'p-legacy'});
      expect(await _legacyRaw(), isNull);
    });

    test('rollback de vault missing borra la clave y nunca escribe {}',
        () async {
      final index = _ScriptedIndexStore();
      final vault = _ScriptedVault(
        failWriteAt: <int>{1},
        persistBeforeFailedWrite: true,
      );
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(vault.raw, isNull);
      expect(vault.raw, isNot('{}'));
      expect(vault.deleteCount, 1);
      expect(index.raw, isNull);
    });

    test('si falla la lectura después de escribir, rollback queda fail-closed',
        () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep"}';
      final index = _ScriptedIndexStore(
        raw: indexRaw,
        failWriteAt: <int>{1},
        failReadAt: <int>{3},
        persistBeforeFailedWrite: true,
      );
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      expect(
        await service.addCredential(
          nombre: 'new',
          usuario: 'u',
          password: 'p-new',
        ),
        isFalse,
      );
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep'});
    });

    test('delete valida vault antes de tocar índice', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"target","nombre":"Target","usuario":"u"}]';
      for (final raw in <String>['', 'no-json{{{', '[]']) {
        final index = _ScriptedIndexStore(raw: indexRaw);
        final vault = _ScriptedVault(raw: raw);
        final service = _service(index, vault);

        expect(await service.deleteCredential('target'), isFalse);
        expect(index.raw, indexRaw);
        expect(index.writeCount, 0);
        expect(vault.raw, raw);
        expect(vault.writeCount, 0);
      }
    });

    test('delete con fallo de índice conserva ambos snapshots', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"target","nombre":"Target","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","target":"p-target"}';
      final index = _ScriptedIndexStore(
        raw: indexRaw,
        failWriteAt: <int>{1},
      );
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      expect(await service.deleteCredential('target'), isFalse);
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep', 'target': 'p-target'});
      await service.sweepCredentialOrphans();
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
    });

    test('delete con fallo de vault restaura índice y vault', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"target","nombre":"Target","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","target":"p-target"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: vaultRaw,
        failWriteAt: <int>{1},
        persistBeforeFailedWrite: true,
      );
      final service = _service(index, vault);

      expect(await service.deleteCredential('target'), isFalse);
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep', 'target': 'p-target'});
      await service.sweepCredentialOrphans();
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
    });

    test('delete con verify fallido no deja índice podado', () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"target","nombre":"Target","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","target":"p-target"}';
      final index = _ScriptedIndexStore(
        raw: indexRaw,
        failVerifyAt: <int>{1},
      );
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      expect(await service.deleteCredential('target'), isFalse);
      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep', 'target': 'p-target'});
    });

    test('sweep purga índice huérfano y conserva passwords válidos',
        () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"index-orphan","nombre":"Broken","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","vault-orphan":"p-orphan"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      await service.sweepCredentialOrphans();

      expect(index.raw,
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]');
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {
        'keep': 'p-keep',
        'vault-orphan': 'p-orphan',
      });
    });

    test('sweep no toca stores si índice o bóveda están corruptos',
        () async {
      const validIndex =
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      final cases = <({Object? indexRaw, String vaultRaw})>[
        (indexRaw: '', vaultRaw: '{"keep":"p-keep"}'),
        (indexRaw: 'no-json{{{', vaultRaw: '{"keep":"p-keep"}'),
        (indexRaw: validIndex, vaultRaw: ''),
        (indexRaw: validIndex, vaultRaw: 'no-json{{{'),
        (indexRaw: validIndex, vaultRaw: '[]'),
      ];
      for (final testCase in cases) {
        final index = _ScriptedIndexStore(raw: testCase.indexRaw);
        final vault = _ScriptedVault(raw: testCase.vaultRaw);
        final service = _service(index, vault);

        await service.sweepCredentialOrphans();

        expect(index.raw, testCase.indexRaw);
        expect(vault.raw, testCase.vaultRaw);
        expect(index.writeCount, 0);
        expect(vault.writeCount, 0);
      }
    });

    test('sweep no intenta escribir la bóveda para purgar su lado',
        () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"index-orphan","nombre":"Broken","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","vault-orphan":"p-orphan"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(
        raw: vaultRaw,
        failWriteAt: <int>{1},
        persistBeforeFailedWrite: true,
      );
      final service = _service(index, vault);

      await service.sweepCredentialOrphans();

      expect(index.raw,
          '[{"id":"keep","nombre":"Keep","usuario":"u"}]');
      expect(vault.raw, vaultRaw);
      expect(vault.writeCount, 0);
    });

    test('sweep con write de índice fallido conserva vault sin podar',
        () async {
      const indexRaw =
          '[{"id":"keep","nombre":"Keep","usuario":"u"},{"id":"index-orphan","nombre":"Broken","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","vault-orphan":"p-orphan"}';
      final index = _ScriptedIndexStore(
        raw: indexRaw,
        failWriteAt: <int>{1},
      );
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      await service.sweepCredentialOrphans();

      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {'keep': 'p-keep', 'vault-orphan': 'p-orphan'});
    });

    test('sweep con vault missing no fabrica {} y poda solo índice',
        () async {
      const indexRaw =
          '[{"id":"missing","nombre":"Missing","usuario":"u"}]';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault();
      final service = _service(index, vault);

      await service.sweepCredentialOrphans();

      expect(index.raw, '[]');
      expect(vault.raw, isNull);
      expect(vault.writeCount, 0);
      expect(vault.deleteCount, 0);
    });

    test('sweep posterior a delete conserva password huérfana válida',
        () async {
      const indexRaw = '[{"id":"keep","nombre":"Keep","usuario":"u"}]';
      const vaultRaw = '{"keep":"p-keep","orphan":"p-orphan"}';
      final index = _ScriptedIndexStore(raw: indexRaw);
      final vault = _ScriptedVault(raw: vaultRaw);
      final service = _service(index, vault);

      await service.sweepCredentialOrphans();

      expect(index.raw, indexRaw);
      expect(vault.raw, vaultRaw);
      expect(_passMap(vault), {
        'keep': 'p-keep',
        'orphan': 'p-orphan',
      });
    });
  });

  group('VbCredential - modelo sin secretos', () {
    test('toString nunca expone password (ni existe el campo)', () async {
      const credential = VbCredential(id: '1', nombre: 'Banco', usuario: 'u');
      expect(credential.toString().contains('p4ss'), isFalse);
      expect(credential.toJson().keys.toList(), ['id', 'nombre', 'usuario']);
    });
  });
}

StorageService _service(_ScriptedIndexStore index, _ScriptedVault vault) =>
    StorageService(
      credentialIndexStore: index,
      credentialVaultStore: vault,
    );

Future<String?> _legacyRaw() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(StorageService.credPassKey);
}

Map<String, String> _passMap(_ScriptedVault vault) {
  final raw = vault.raw;
  expect(raw, isNotNull);
  final decoded = jsonDecode(raw!);
  expect(decoded, isA<Map<dynamic, dynamic>>());
  return Map<String, String>.from(decoded as Map<dynamic, dynamic>);
}

List<Map<String, dynamic>> _indexEntries(_ScriptedIndexStore index) {
  final raw = index.raw;
  expect(raw, isA<String>());
  final decoded = jsonDecode(raw! as String);
  expect(decoded, isA<List<dynamic>>());
  return [
    for (final item in decoded as List<dynamic>)
      Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
  ];
}

class _ScriptedIndexStore implements CredentialIndexStore {
  _ScriptedIndexStore({
    this.raw,
    Set<int>? failReadAt,
    Set<int>? failWriteAt,
    Set<int>? failVerifyAt,
    this.persistBeforeFailedWrite = false,
  })  : failReadAt = failReadAt ?? <int>{},
        failWriteAt = failWriteAt ?? <int>{},
        failVerifyAt = failVerifyAt ?? <int>{};

  Object? raw;
  final Set<int> failReadAt;
  final Set<int> failWriteAt;
  final Set<int> failVerifyAt;
  final bool persistBeforeFailedWrite;
  Future<void> Function()? writeHook;
  Future<void> Function()? beforeWriteHook;
  int readCount = 0;
  int writeCount = 0;
  int verifyCount = 0;
  int removeCount = 0;

  @override
  Future<Object?> read() {
    readCount += 1;
    if (failReadAt.contains(readCount)) {
      return Future<Object?>.error(StateError('index read simulado'));
    }
    return Future<Object?>.value(raw);
  }

  @override
  Future<bool> write(String value) {
    writeCount += 1;
    if (failWriteAt.contains(writeCount)) {
      if (persistBeforeFailedWrite) raw = value;
      return Future<bool>.error(StateError('index write simulado'));
    }
    final hook = writeHook;
    if (hook != null) {
      writeHook = null;
      return hook().then((_) {
        raw = value;
        return true;
      });
    }
    raw = value;
    return Future<bool>.value(true);
  }

  @override
  Future<bool> verify(String? expected) {
    verifyCount += 1;
    if (failVerifyAt.contains(verifyCount)) {
      return Future<bool>.value(false);
    }
    return Future<bool>.value(raw == expected);
  }

  @override
  Future<bool> remove() {
    removeCount += 1;
    raw = null;
    return Future<bool>.value(true);
  }

  @override
  Future<bool> compareAndSet({
    required String? expectedRaw,
    required String? nextRaw,
  }) async {
    if (raw != expectedRaw) return false;
    final hook = beforeWriteHook;
    if (hook != null) {
      beforeWriteHook = null;
      await hook();
      if (raw != expectedRaw) return false;
    }
    if (nextRaw == null) return remove();
    if (!await write(nextRaw)) return false;
    verifyCount += 1;
    if (failVerifyAt.contains(verifyCount)) return false;
    return raw == nextRaw;
  }
}

class _ScriptedVault implements CredentialVaultStore {
  _ScriptedVault({
    this.raw,
    Set<int>? failReadAt,
    Set<int>? failWriteAt,
    Set<int>? failDeleteAt,
    Set<int>? failVerifyAt,
    this.persistBeforeFailedWrite = false,
  })  : failReadAt = failReadAt ?? <int>{},
        failWriteAt = failWriteAt ?? <int>{},
        failDeleteAt = failDeleteAt ?? <int>{},
        failVerifyAt = failVerifyAt ?? <int>{};

  String? raw;
  final Set<int> failReadAt;
  final Set<int> failWriteAt;
  final Set<int> failDeleteAt;
  final Set<int> failVerifyAt;
  final bool persistBeforeFailedWrite;
  Future<void> Function()? writeHook;
  Future<void> Function()? beforeWriteHook;
  int readCount = 0;
  int writeCount = 0;
  int deleteCount = 0;
  int verifyCount = 0;

  @override
  Future<String?> read() {
    readCount += 1;
    if (failReadAt.contains(readCount)) {
      return Future<String?>.error(StateError('vault read simulado'));
    }
    return Future<String?>.value(raw);
  }

  @override
  Future<void> write(String value) {
    writeCount += 1;
    if (failWriteAt.contains(writeCount)) {
      if (persistBeforeFailedWrite) raw = value;
      return Future<void>.error(StateError('vault write simulado'));
    }
    final hook = writeHook;
    if (hook != null) {
      writeHook = null;
      return hook().then((_) {
        raw = value;
      });
    }
    raw = value;
    return Future<void>.value();
  }

  @override
  Future<void> delete() {
    deleteCount += 1;
    if (failDeleteAt.contains(deleteCount)) {
      return Future<void>.error(StateError('vault delete simulado'));
    }
    raw = null;
    return Future<void>.value();
  }

  @override
  Future<bool> compareAndSet({
    required String? expectedRaw,
    required String? nextRaw,
  }) async {
    final current = await read();
    if (current != expectedRaw) return false;
    final hook = beforeWriteHook;
    if (hook != null) {
      beforeWriteHook = null;
      await hook();
      if (raw != expectedRaw) return false;
    }
    if (nextRaw == null) {
      await delete();
      return raw == null;
    }
    await write(nextRaw);
    verifyCount += 1;
    if (failVerifyAt.contains(verifyCount)) return false;
    return raw == nextRaw;
  }
}
