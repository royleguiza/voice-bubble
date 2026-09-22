import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/snippet.dart';
import 'package:voice_bubble_stt/screens/settings_screen.dart';
import 'package:voice_bubble_stt/services/floating_bubble_service.dart';
import 'package:voice_bubble_stt/services/keyboard_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(FloatingBubbleService.channelName);
  const keyboardChannel = MethodChannel(KeyboardService.channelName);

  late StorageService storageService;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();

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
    // Superficie alta (800x2400 logicos): la pagina de Settings crece con la
    // seccion de snippets y el ListView lazy no construye lo que queda fuera
    // del viewport (9.1-17 / 9.1-21).
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

  // Icono de accion dentro de la tarjeta de UN snippet concreto.
  Finder tileAction(String nombre, IconData icon) => find.descendant(
        of: find.ancestor(of: find.text(nombre), matching: find.byType(Card)),
        matching: find.byIcon(icon),
      );

  group('SettingsScreen - Gestión de snippets (K4)', () {
    testWidgets('muestra los 5 seeds tras ensureSeeds al entrar',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      for (final nombre in [
        'Codex',
        'Gemini',
        'Git commit',
        'Git push',
        'Supabase push',
      ]) {
        expect(find.text(nombre), findsOneWidget);
      }
      expect(find.text('Snippets'), findsWidgets);
      expect(find.text('5 / 50'), findsOneWidget);
      expect(find.byKey(const ValueKey('snippets-add-button')),
          findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    testWidgets('crear snippet lo muestra en la lista y persiste',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('snippets-add-button')));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo snippet'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('snippet-name-field')),
        'Mi snippet',
      );
      await tester.enterText(
        find.byKey(const ValueKey('snippet-content-field')),
        'texto de prueba',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Mi snippet'), findsOneWidget);
      expect(find.text('6 / 50'), findsOneWidget);

      // Persistencia verificada desde otra instancia del servicio.
      final loaded = await StorageService().loadSnippets();
      expect(loaded.length, 6);
      expect(loaded.last.nombre, 'Mi snippet');
      expect(loaded.last.contenido, 'texto de prueba');
    });

    testWidgets('editar snippet precarga el formulario y persiste los cambios',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      await tester.tap(tileAction('Codex', Icons.edit_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Editar snippet'), findsOneWidget);
      final nameField = tester.widget<TextField>(
        find.byKey(const ValueKey('snippet-name-field')),
      );
      expect(nameField.controller?.text, 'Codex');

      await tester.enterText(
        find.byKey(const ValueKey('snippet-name-field')),
        'Codex editado',
      );
      await tester.enterText(
        find.byKey(const ValueKey('snippet-content-field')),
        'codex --nuevo ',
      );
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Codex editado'), findsOneWidget);
      expect(find.text('Codex'), findsNothing);

      final loaded = await StorageService().loadSnippets();
      final edited = loaded.firstWhere((s) => s.nombre == 'Codex editado');
      expect(edited.id, 'seed-codex');
      expect(edited.contenido, 'codex --nuevo ');

      // Regresion del bug "guardar borra todo": editar UN snippet no debe
      // alterar el total persistido ni el resto de los snippets.
      expect(loaded.length, 5);
      const intactos = {
        'Gemini': 'gemini -p "',
        'Git commit': 'git add . && git commit -m "',
        'Git push': 'git push origin main',
        'Supabase push': 'supabase db push',
      };
      for (final entry in intactos.entries) {
        final otro = loaded.singleWhere((s) => s.nombre == entry.key);
        expect(otro.contenido, entry.value, reason: entry.key);
      }
    });

    testWidgets('borrar snippet pide confirmación y persiste', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      await tester.tap(tileAction('Gemini', Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar snippet'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Gemini'), findsNothing);
      expect(find.text('4 / 50'), findsOneWidget);

      final loaded = await StorageService().loadSnippets();
      expect(loaded.length, 4);
      expect(loaded.where((s) => s.nombre == 'Gemini'), isEmpty);
    });

    testWidgets('las flechas reordenan snippets y persisten el orden',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      final upCodex = tester.widget<IconButton>(
        find.byKey(const ValueKey('snippet-up-seed-codex')),
      );
      expect(upCodex.onPressed, isNull);

      await tester.tap(tileAction('Codex', Icons.arrow_downward_rounded));
      await tester.pumpAndSettle();

      final loaded = await StorageService().loadSnippets();
      expect(
        loaded.map((s) => s.nombre).toList(),
        ['Gemini', 'Codex', 'Git commit', 'Git push', 'Supabase push'],
      );
      expect(loaded.map((s) => s.orden).toList(), [0, 1, 2, 3, 4]);
    });

    testWidgets('límite 50: crear el 51 muestra feedback y no agrega',
        (tester) async {
      final fifty = List<Snippet>.generate(
        50,
        (i) => Snippet(id: 'gen-$i', nombre: 'Gen $i', contenido: 'c$i', orden: i),
      );
      await storageService.saveSnippets(fifty);

      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('snippets-add-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('snippet-name-field')),
        'Extra',
      );
      await tester.enterText(
        find.byKey(const ValueKey('snippet-content-field')),
        'x',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Límite de 50'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      // El sheet sigue abierto con el error: el snippet rechazado no debe
      // aparecer en las tarjetas de snippets de Settings.
      expect(
        find.descendant(of: find.byType(Card), matching: find.text('Extra')),
        findsNothing,
      );

      final loaded = await StorageService().loadSnippets();
      expect(loaded.length, 50);
    });

    testWidgets('contenido mayor a 2000 caracteres muestra error y no guarda',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('snippets-add-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('snippet-name-field')),
        'Largo',
      );
      await tester.enterText(
        find.byKey(const ValueKey('snippet-content-field')),
        'a' * 2001,
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Máximo 2000 caracteres'), findsOneWidget);
      expect(find.text('2001 / 2000'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);

      final loaded = await StorageService().loadSnippets();
      expect(loaded.length, 5);
      expect(loaded.where((s) => s.nombre == 'Largo'), isEmpty);
    });

    testWidgets('nombre vacío muestra error y no guarda', (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('snippets-add-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('snippet-content-field')),
        'sin nombre',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre es obligatorio'), findsOneWidget);
      expect(find.text('Nuevo snippet'), findsOneWidget);

      final loaded = await StorageService().loadSnippets();
      expect(loaded.length, 5);
      expect(loaded.where((s) => s.contenido == 'sin nombre'), isEmpty);
    });

    testWidgets('elegir color de paleta persiste en el snippet',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('snippets-add-button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('snippet-name-field')),
        'Con color',
      );
      await tester.enterText(
        find.byKey(const ValueKey('snippet-content-field')),
        'contenido',
      );
      await tester.tap(find.byKey(const ValueKey('snippet-color-azul')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final loaded = await StorageService().loadSnippets();
      final created = loaded.singleWhere((s) => s.nombre == 'Con color');
      expect(created.color, 'azul');
    });

    testWidgets('editar snippet puede limpiar el color a Sin color',
        (tester) async {
      final withColor = const Snippet(
        id: 'c1',
        nombre: 'Teñido',
        contenido: 'x',
        orden: 0,
        color: 'verde',
      );
      await storageService.saveSnippets([withColor]);

      await tester.pumpWidget(buildTestableWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('tab-snippets')));
      await tester.pumpAndSettle();

      await tester.tap(tileAction('Teñido', Icons.edit_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('snippet-color-none')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      final loaded = await StorageService().loadSnippets();
      expect(loaded.single.color, isNull);
    });
  });
}
