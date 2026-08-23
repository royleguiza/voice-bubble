import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/snippet.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const expectedSeeds = [
    Snippet(id: 'seed-codex', nombre: 'Codex', contenido: 'codex "', orden: 0),
    Snippet(
      id: 'seed-gemini',
      nombre: 'Gemini',
      contenido: 'gemini -p "',
      orden: 1,
    ),
    Snippet(
      id: 'seed-git-commit',
      nombre: 'Git commit',
      contenido: 'git add . && git commit -m "',
      orden: 2,
    ),
    Snippet(
      id: 'seed-git-push',
      nombre: 'Git push',
      contenido: 'git push origin main',
      orden: 3,
    ),
    Snippet(
      id: 'seed-supabase-push',
      nombre: 'Supabase push',
      contenido: 'supabase db push',
      orden: 4,
    ),
  ];

  group('StorageService - contrato de claves de snippets', () {
    test('expone las claves canonicas del contrato', () {
      expect(StorageService.snippetsKey, 'voice_snippets_v1');
      expect(StorageService.snippetsSeededKey, 'kb_snippets_seeded');
    });

    test('persiste un STRING con JSON array de claves exactas', () async {
      final service = StorageService();
      expect(await service.addSnippet(nombre: 'N', contenido: 'C'), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('voice_snippets_v1');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect(decoded, hasLength(1));
      expect((decoded.single as Map).keys.toList(),
          ['id', 'nombre', 'contenido', 'orden']);
    });
  });

  group('StorageService - CRUD de snippets', () {
    test('addSnippet agrega al final con orden secuencial y persiste',
        () async {
      final service = StorageService();
      expect(await service.addSnippet(nombre: 'Uno', contenido: 'u'), isTrue);
      expect(await service.addSnippet(nombre: 'Dos', contenido: 'd'), isTrue);

      final fresh = StorageService();
      final loaded = await fresh.loadSnippets();
      expect(loaded.map((s) => s.nombre).toList(), ['Uno', 'Dos']);
      expect(loaded.map((s) => s.orden).toList(), [0, 1]);
      expect(loaded.map((s) => s.id).toSet().length, 2);
    });

    test('updateSnippet cambia nombre y contenido manteniendo id y orden',
        () async {
      final service = StorageService();
      await service.addSnippet(nombre: 'Viejo', contenido: 'viejo');
      final id = (await service.loadSnippets()).single.id;

      expect(await service.updateSnippet(id, nombre: 'Nuevo'), isTrue);
      expect(await service.updateSnippet(id, contenido: 'nuevo'), isTrue);

      final loaded = await service.loadSnippets();
      expect(loaded.single.id, id);
      expect(loaded.single.nombre, 'Nuevo');
      expect(loaded.single.contenido, 'nuevo');
      expect(loaded.single.orden, 0);
    });

    test('updateSnippet con id inexistente devuelve false', () async {
      final service = StorageService();
      expect(await service.updateSnippet('no-existe', nombre: 'X'), isFalse);
    });

    test('deleteSnippet elimina y renumera orden contiguo', () async {
      final service = StorageService();
      for (final n in ['a', 'b', 'c', 'd']) {
        await service.addSnippet(nombre: n, contenido: n);
      }
      final targetId = (await service.loadSnippets())[1].id;

      expect(await service.deleteSnippet(targetId), isTrue);

      final loaded = await service.loadSnippets();
      expect(loaded.map((s) => s.nombre).toList(), ['a', 'c', 'd']);
      expect(loaded.map((s) => s.orden).toList(), [0, 1, 2]);
    });

    test('deleteSnippet con id inexistente devuelve false', () async {
      final service = StorageService();
      expect(await service.deleteSnippet('no-existe'), isFalse);
    });
  });

  group('StorageService - limites de snippets', () {
    test('rechaza el snippet numero 51', () async {
      final service = StorageService();
      for (var i = 0; i < 50; i++) {
        expect(
          await service.addSnippet(nombre: 'n$i', contenido: 'c$i'),
          isTrue,
        );
      }

      expect(
        await service.addSnippet(nombre: 'extra', contenido: 'x'),
        isFalse,
      );
      expect((await service.loadSnippets()).length, 50);
    });

    test('acepta contenido de exactamente 2000 caracteres', () async {
      final service = StorageService();
      expect(
        await service.addSnippet(nombre: 'limite', contenido: 'a' * 2000),
        isTrue,
      );
    });

    test('rechaza contenido de 2001 caracteres', () async {
      final service = StorageService();
      expect(
        await service.addSnippet(nombre: 'largo', contenido: 'a' * 2001),
        isFalse,
      );
      expect(await service.loadSnippets(), isEmpty);
    });

    test('rechaza nombre vacio o solo espacios', () async {
      final service = StorageService();
      expect(await service.addSnippet(nombre: '', contenido: 'c'), isFalse);
      expect(await service.addSnippet(nombre: '   ', contenido: 'c'), isFalse);
      expect(await service.loadSnippets(), isEmpty);
    });

    test('updateSnippet aplica los mismos limites sin tocar el original',
        () async {
      final service = StorageService();
      await service.addSnippet(nombre: 'ok', contenido: 'ok');
      final id = (await service.loadSnippets()).single.id;

      expect(await service.updateSnippet(id, contenido: 'a' * 2001), isFalse);
      expect(await service.updateSnippet(id, nombre: ''), isFalse);

      final loaded = await service.loadSnippets();
      expect(loaded.single.nombre, 'ok');
      expect(loaded.single.contenido, 'ok');
    });
  });

  group('StorageService - tolerancia a storage corrupto', () {
    test('JSON invalido devuelve lista vacia sin lanzar excepcion', () async {
      SharedPreferences.setMockInitialValues({
        'voice_snippets_v1': '{broken json',
      });
      final service = StorageService();

      expect(await service.loadSnippets(), isEmpty);
    });

    test('JSON de tipo incorrecto devuelve lista vacia', () async {
      final service = StorageService();
      final badValues = [
        '"solo un string"',
        '42',
        '{"id": "objeto-suelto"}',
      ];
      for (final bad in badValues) {
        SharedPreferences.setMockInitialValues({'voice_snippets_v1': bad});
        expect(await service.loadSnippets(), isEmpty);
      }
    });

    test('ignora entradas no-objeto dentro del array', () async {
      SharedPreferences.setMockInitialValues({
        'voice_snippets_v1':
            '[{"id":"a","nombre":"A","contenido":"x","orden":0},"junk",7]',
      });
      final service = StorageService();

      final loaded = await service.loadSnippets();
      expect(loaded.length, 1);
      expect(loaded.single.id, 'a');
    });

    test('fromJson tolera campos ausentes o de tipo equivocado', () async {
      SharedPreferences.setMockInitialValues({
        'voice_snippets_v1': '[{"id": 123, "orden": "3"}]',
      });
      final service = StorageService();

      expect(
        await service.loadSnippets(),
        [const Snippet(id: '', nombre: '', contenido: '', orden: 0)],
      );
    });
  });

  group('StorageService - seeds de snippets', () {
    test('primera llamada escribe los 5 seeds exactos y marca el flag',
        () async {
      final service = StorageService();
      await service.ensureSeeds();

      expect(await service.loadSnippets(), expectedSeeds);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_snippets_seeded'), isTrue);
    });

    test('segunda llamada no duplica seeds', () async {
      final service = StorageService();
      await service.ensureSeeds();
      await service.ensureSeeds();

      expect(await service.loadSnippets(), expectedSeeds);
    });

    test('con snippets previos del usuario solo marca el flag', () async {
      final service = StorageService();
      const mine = Snippet(id: 'mio', nombre: 'Mio', contenido: 'm', orden: 0);
      await service.saveSnippets([mine]);

      await service.ensureSeeds();

      expect(await service.loadSnippets(), [mine]);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kb_snippets_seeded'), isTrue);
    });

    test('flag ya marcado no resucita seeds borrados por el usuario',
        () async {
      SharedPreferences.setMockInitialValues({'kb_snippets_seeded': true});
      final service = StorageService();

      await service.ensureSeeds();

      expect(await service.loadSnippets(), isEmpty);
    });
  });

  group('StorageService - reorden de snippets', () {
    test('asigna orden segun la posicion nueva y persiste el resultado',
        () async {
      final service = StorageService();
      for (final n in ['a', 'b', 'c']) {
        await service.addSnippet(nombre: n, contenido: n);
      }
      final ids =
          (await service.loadSnippets()).map((s) => s.id).toList();

      await service.reorderSnippets([ids[2], ids[0], ids[1]]);

      final loaded = await StorageService().loadSnippets();
      expect(loaded.map((s) => s.nombre).toList(), ['c', 'a', 'b']);
      expect(loaded.map((s) => s.orden).toList(), [0, 1, 2]);
    });

    test('ignora ids desconocidos y mantiene el resto al final', () async {
      final service = StorageService();
      for (final n in ['a', 'b']) {
        await service.addSnippet(nombre: n, contenido: n);
      }
      final ids =
          (await service.loadSnippets()).map((s) => s.id).toList();

      await service.reorderSnippets(['fantasma', ids[1]]);

      final loaded = await service.loadSnippets();
      expect(loaded.map((s) => s.nombre).toList(), ['b', 'a']);
      expect(loaded.map((s) => s.orden).toList(), [0, 1]);
    });
  });

  group('StorageService - persistencia round-trip de snippets', () {
    test('los datos sobreviven a una instancia nueva del servicio', () async {
      final first = StorageService();
      await first.ensureSeeds();
      await first.addSnippet(nombre: 'Propio', contenido: 'propio');
      final seedGitPush = (await first.loadSnippets())[3].id;
      await first.updateSnippet(seedGitPush, contenido: 'git push origin');
      await first.deleteSnippet((await first.loadSnippets())[0].id);

      final second = StorageService();
      final loaded = await second.loadSnippets();

      // Tras borrar "Codex", deleteSnippet renumera el orden contiguo.
      expect(loaded.length, 5);
      expect(loaded[0].nombre, 'Gemini');
      expect(loaded[0].orden, 0);
      expect(loaded[2].nombre, 'Git push');
      expect(loaded[2].contenido, 'git push origin');
      expect(loaded[3].nombre, 'Supabase push');
      expect(loaded[3].orden, 3);
      expect(loaded[4].nombre, 'Propio');
      expect(loaded[4].orden, 4);
    });

    test('saveSnippets serializa ordenado por campo orden (estable)',
        () async {
      final service = StorageService();
      await service.saveSnippets([
        const Snippet(id: 'b', nombre: 'B', contenido: 'cb', orden: 1),
        const Snippet(id: 'a', nombre: 'A', contenido: 'ca', orden: 0),
        const Snippet(id: 'c', nombre: 'C', contenido: 'cc', orden: 1),
      ]);

      final loaded = await service.loadSnippets();
      expect(loaded.map((s) => s.id).toList(), ['a', 'b', 'c']);
    });
  });
}
