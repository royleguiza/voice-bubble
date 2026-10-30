import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/models/snippet.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

import '../helpers/settings_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final h = SettingsHarness();

  setUp(() => h.setUp());
  tearDown(h.tearDown);

  Future<void> openSnippets(WidgetTester tester) async {
    await h.pump(tester);
    await openPage(tester, 'snippets');
  }

  Future<List<Snippet>> stored() async {
    final list = await StorageService().loadSnippets();
    return list..sort((a, b) => a.orden.compareTo(b.orden));
  }

  Future<void> fillAndSave(WidgetTester tester, String name, String content) async {
    await tester.enterText(byKey('snippet-name-field'), name);
    await tester.enterText(byKey('snippet-content-field'), content);
    await tapKey(tester, 'snippet-save-button');
  }

  group('Snippets (K4)', () {
    testWidgets('muestra los 5 seeds tras ensureSeeds al entrar',
        (tester) async {
      await openSnippets(tester);

      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('5 de 50 · Se insertan con un toque desde el teclado.'),
          findsOneWidget);
      expect((await stored()).length, 5);
    });

    testWidgets('crear desde el + lo muestra en la lista y persiste',
        (tester) async {
      await openSnippets(tester);
      await tapKey(tester, 'snippets-add-button');
      expect(find.text('Nuevo snippet'), findsOneWidget);

      await fillAndSave(tester, 'Mi snippet', 'Hola mundo');

      expect(find.text('Mi snippet'), findsOneWidget);
      final list = await stored();
      expect(list.length, 6);
      expect(list.last.contenido, 'Hola mundo');
    });

    testWidgets('tocar un snippet precarga el formulario y guarda cambios',
        (tester) async {
      await openSnippets(tester);
      await tapKey(tester, 'snippet-edit-seed-codex');

      expect(find.text('Editar snippet'), findsOneWidget);
      final nameField = tester.widget<TextField>(find.descendant(
        of: byKey('snippet-name-field'),
        matching: find.byType(TextField),
      ));
      expect(nameField.controller!.text, 'Codex');

      await tester.enterText(byKey('snippet-name-field'), 'Codex editado');
      await tapKey(tester, 'snippet-save-button');

      expect(find.text('Codex editado'), findsOneWidget);
      final edited = (await stored()).firstWhere((s) => s.id == 'seed-codex');
      expect(edited.nombre, 'Codex editado');
    });

    testWidgets('eliminar desde el formulario pide confirmación y persiste',
        (tester) async {
      await openSnippets(tester);
      await tapKey(tester, 'snippet-edit-seed-codex');
      await tapKey(tester, 'snippet-delete-button');

      expect(find.text('Eliminar snippet'), findsWidgets);
      await tapKey(tester, 'snippet-dialog-confirm-delete');

      expect(byKey('snippet-name-field'), findsNothing);
      expect(byKey('snippet-edit-seed-codex'), findsNothing);
      expect((await stored()).any((s) => s.id == 'seed-codex'), isFalse);
    });

    testWidgets('cancelar el borrado deja el snippet', (tester) async {
      await openSnippets(tester);
      await tapKey(tester, 'snippet-edit-seed-codex');
      await tapKey(tester, 'snippet-delete-button');
      await tapKey(tester, 'snippet-dialog-cancel-delete');

      expect((await stored()).any((s) => s.id == 'seed-codex'), isTrue);
    });

    testWidgets('Ordenar muestra flechas que reordenan y persisten',
        (tester) async {
      await openSnippets(tester);
      expect(byKey('snippet-down-seed-codex'), findsNothing);

      await tapKey(tester, 'snippets-reorder-button');
      final firstBefore = (await stored()).first.id;
      expect(firstBefore, 'seed-codex');

      await tapKey(tester, 'snippet-down-seed-codex');

      final list = await stored();
      expect(list[1].id, 'seed-codex');
      final up = tester.widget<IconButton>(byKey('snippet-up-${list.first.id}'));
      expect(up.onPressed, isNull, reason: 'el primero no puede subir');
    });

    testWidgets('límite 50: el 51 muestra el aviso y no se agrega',
        (tester) async {
      final fifty = List<Snippet>.generate(
        50,
        (i) => Snippet(id: 'gen-$i', nombre: 'Gen $i', contenido: 'c$i', orden: i),
      );
      await h.storage.saveSnippets(fifty);
      await openSnippets(tester);

      await tapKey(tester, 'snippets-add-button');
      await fillAndSave(tester, 'Extra', 'x');

      expect(find.textContaining('Límite de 50'), findsOneWidget);
      expect(byKey('snippet-save-button'), findsOneWidget);
      expect((await stored()).length, 50);
    });

    testWidgets('más de 2000 caracteres muestra error y no guarda',
        (tester) async {
      await openSnippets(tester);
      await tapKey(tester, 'snippets-add-button');

      await fillAndSave(tester, 'Largo', 'a' * 2001);

      expect(find.text('Máximo 2000 caracteres'), findsOneWidget);
      expect(find.text('2001 / 2000'), findsOneWidget);
      expect((await stored()).length, 5);
    });

    testWidgets('nombre vacío muestra error y no guarda', (tester) async {
      await openSnippets(tester);
      await tapKey(tester, 'snippets-add-button');

      await fillAndSave(tester, '   ', 'contenido');

      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      expect((await stored()).length, 5);
    });

    testWidgets('elegir color de paleta persiste en el snippet',
        (tester) async {
      await openSnippets(tester);
      await tapKey(tester, 'snippets-add-button');
      await tester.enterText(byKey('snippet-name-field'), 'Azulado');
      await tester.enterText(byKey('snippet-content-field'), 'texto');
      await tapKey(tester, 'snippet-color-azul');
      await tapKey(tester, 'snippet-save-button');

      final created = (await stored()).firstWhere((s) => s.nombre == 'Azulado');
      expect(created.color, 'azul');
    });

    testWidgets('editar puede limpiar el color a Sin color', (tester) async {
      await h.storage.saveSnippets(const [
        Snippet(id: 'c1', nombre: 'Con color', contenido: 'x', orden: 0, color: 'verde'),
      ]);
      await openSnippets(tester);
      await tapKey(tester, 'snippet-edit-c1');
      await tapKey(tester, 'snippet-color-none');
      await tapKey(tester, 'snippet-save-button');

      final edited = (await stored()).firstWhere((s) => s.id == 'c1');
      expect(edited.color, isNull);
    });

    testWidgets('el buscador filtra por nombre y contenido', (tester) async {
      await openSnippets(tester);

      await tester.enterText(byKey('snippets-search-field'), 'push');
      await tester.pumpAndSettle();

      expect(byKey('snippet-edit-seed-codex'), findsNothing);
      expect(find.text('Git push'), findsOneWidget);

      await tester.enterText(byKey('snippets-search-field'), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados para "zzz".'), findsOneWidget);
    });
  });
}
