// Inicio sin tirones: desplazar Notas o Historial no reconstruye la
// pantalla ni las tarjetas ya construidas, y las listas son perezosas
// (con cientos de ítems solo existen los visibles).
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/models/voice_note.dart';
import 'package:voice_bubble_stt/screens/home_screen.dart';
import 'package:voice_bubble_stt/services/notes_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';
import 'package:voice_bubble_stt/ui/design_tokens.dart';
import 'package:voice_bubble_stt/widgets/history_list.dart';
import 'package:voice_bubble_stt/widgets/note_card.dart';

import '../helpers/mock_channels.dart';

/// Notas en memoria: sin disco ni locks, con más de las que admite el
/// servicio real para medir la pereza de la lista.
class _MemoryNotes extends NotesService {
  _MemoryNotes(this._list);
  final List<VoiceNote> _list;

  @override
  Future<bool> load() async => true;

  @override
  List<VoiceNote> get notes => List.unmodifiable(_list);

  @override
  List<VoiceNote> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return notes;
    return _list.where((n) => n.cuerpo.toLowerCase().contains(q)).toList();
  }
}

/// Historial en memoria (el real tiene tope 20; acá se mide la pereza).
class _MemoryHistory extends StorageService {
  _MemoryHistory(this._list);
  final List<Transcription> _list;

  @override
  Future<bool> load() async => true;

  @override
  List<Transcription> get transcriptions => List.unmodifiable(_list);
}

List<VoiceNote> _notes(int n) {
  final now = DateTime.now();
  return [
    for (var i = 0; i < n; i++)
      VoiceNote(
        id: 'note-$i',
        titulo: 'Nota $i',
        cuerpo: 'Cuerpo de la nota $i con algo de texto para dos renglones.',
        createdAt: now.subtract(Duration(hours: i * 6)),
        updatedAt: now.subtract(Duration(hours: i * 6)),
      ),
  ];
}

List<Transcription> _history(int n, {int repeat = 1}) {
  final now = DateTime.now();
  return [
    for (var i = 0; i < n; i++)
      Transcription(
        text: 'Dictado $i. ${'Una frase de prueba larga. ' * repeat}',
        timestamp: now.subtract(Duration(hours: i * 5)),
      ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    registerAppChannelMocks();
  });

  tearDown(() {
    debugOnRebuildDirtyWidget = null;
    unregisterAppChannelMocks();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(411, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openHistory(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('home-tab-historial')));
    await tester.pumpAndSettle();
  }

  ScrollPosition outerPosition(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;

  /// Cuenta, por tipo de widget, las reconstrucciones de elementos que ya
  /// existían antes de [body] (las primeras construcciones de filas que
  /// entran en pantalla no cuentan: eso es la pereza de la lista).
  Future<Map<Type, int>> countRebuilds(
      WidgetTester tester, Future<void> Function() body) async {
    final existing = tester.allElements.toSet();
    final counts = <Type, int>{};
    debugOnRebuildDirtyWidget = (element, _) {
      if (!existing.contains(element)) return;
      final type = element.widget.runtimeType;
      counts[type] = (counts[type] ?? 0) + 1;
    };
    await body();
    debugOnRebuildDirtyWidget = null;
    return counts;
  }

  testWidgets(
      'Notas: desplazar (cruzando el umbral de la barra compacta) no '
      'reconstruye la pantalla ni las tarjetas ya construidas',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(
        MaterialApp(home: HomeScreen(notesService: _MemoryNotes(_notes(60)))));
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard), findsWidgets);

    final counts = await countRebuilds(tester, () async {
      // Pasos cortos: cada uno es un cuadro de desplazamiento real.
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -60));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
    });

    // El título grande salió de pantalla: la barra compacta apareció.
    expect(outerPosition(tester).pixels,
        greaterThan(kLargeTitleCollapseOffset));
    expect(counts[HomeScreen] ?? 0, 0,
        reason: 'el desplazamiento no debe hacer setState de la pantalla');
    expect(counts[NoteCard] ?? 0, 0,
        reason: 'las tarjetas ya construidas no se reconstruyen al desplazar');
    // Lo único que reacciona al umbral es la barra compacta.
    expect(counts[ValueListenableBuilder<bool>] ?? 0, greaterThan(0), reason: "$counts");
  });

  testWidgets(
      'Historial: desplazar no reconstruye la pantalla ni las filas ya '
      'construidas', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: HomeScreen(storageService: _MemoryHistory(_history(40)))));
    await tester.pumpAndSettle();
    await openHistory(tester);
    expect(find.byType(HistoryTile), findsWidgets);

    final counts = await countRebuilds(tester, () async {
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -60));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
    });

    expect(outerPosition(tester).pixels,
        greaterThan(kLargeTitleCollapseOffset));
    expect(counts[HomeScreen] ?? 0, 0);
    expect(counts[HistoryTile] ?? 0, 0);
    expect(counts[ListTile] ?? 0, 0);
  });

  testWidgets('Notas: con 200 notas solo se construyen las visibles',
      (tester) async {
    phone(tester);
    final notes = _notes(200);
    await tester.pumpWidget(
        MaterialApp(home: HomeScreen(notesService: _MemoryNotes(notes))));
    await tester.pumpAndSettle();

    final built = find.byType(NoteCard).evaluate().length;
    expect(built, greaterThan(0));
    // Una pantalla de 800 dp + la franja de caché: unas pocas tarjetas.
    expect(built, lessThan(15));
    expect(find.byKey(ValueKey(notes.first.id)), findsOneWidget);
    expect(find.byKey(ValueKey(notes.last.id)), findsNothing);

    // Al bajar se construyen las nuevas y se sueltan las de arriba.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.byType(NoteCard).evaluate().length, lessThan(15));
    expect(find.byKey(ValueKey(notes.first.id)), findsNothing);
  });

  testWidgets('Historial: con 200 transcripciones solo se construyen las '
      'visibles', (tester) async {
    phone(tester);
    final items = _history(200);
    await tester.pumpWidget(MaterialApp(
        home: HomeScreen(storageService: _MemoryHistory(items))));
    await tester.pumpAndSettle();
    await openHistory(tester);

    final built = find.byType(HistoryTile).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(25));
    expect(find.byKey(ValueKey(items.first.id)), findsOneWidget);
    expect(find.byKey(ValueKey(items.last.id)), findsNothing);
    // Un solo desplazable: sin una lista anidada con shrinkWrap por día.
    expect(find.byType(Scrollable), findsWidgets);
    expect(
        find.descendant(
            of: find.byType(CustomScrollView), matching: find.byType(ListView)),
        findsNothing);
  });

  testWidgets(
      'Historial: arrastrar sobre una fila de más de dos renglones desplaza '
      'la página (el texto no se desplaza por dentro)', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
            storageService: _MemoryHistory(_history(20, repeat: 12)))));
    await tester.pumpAndSettle();
    await openHistory(tester);

    final position = outerPosition(tester);
    expect(position.pixels, 0);
    final row = find.byType(SelectableText).first;
    await tester.dragFrom(tester.getCenter(row), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(100));
  });
}
