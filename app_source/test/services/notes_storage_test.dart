import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/voice_note.dart';
import 'package:voice_bubble_stt/services/notes_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotesService - contrato', () {
    test('expone claves canonicas', () {
      expect(NotesService.notesKey, 'voice_notes_v1');
      expect(NotesService.maxNotes, 50);
    });

    test('persiste STRING con JSON array de claves exactas', () async {
      final s = NotesService();
      expect(await s.addNote(titulo: 'T', cuerpo: 'C'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('voice_notes_v1');
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect((decoded.single as Map).keys.toSet(),
          {'id', 'titulo', 'cuerpo', 'createdAt', 'updatedAt'});
    });
  });

  group('NotesService - CRUD', () {
    test('addNote agrega al inicio y persiste', () async {
      final s = NotesService();
      expect(await s.addNote(titulo: 'Uno', cuerpo: 'u'), isTrue);
      expect(await s.addNote(titulo: 'Dos', cuerpo: 'd'), isTrue);
      final fresh = NotesService();
      await fresh.load();
      expect(fresh.notes.map((n) => n.titulo).toList(), ['Dos', 'Uno']);
    });

    test('addFromTranscription usa titulo truncado', () async {
      final s = NotesService();
      expect(await s.addFromTranscription('Hola mundo desde widget'), isTrue);
      final n = s.notes.first;
      expect(n.titulo, 'Hola mundo desde widget');
      expect(n.cuerpo, 'Hola mundo desde widget');
    });

    test('addFromTranscription titulo largo trunca a 32 chars', () async {
      final s = NotesService();
      final long = 'a' * 40;
      await s.addFromTranscription(long);
      expect(s.notes.first.titulo.length, 35); // 32 + ...
      expect(s.notes.first.titulo.endsWith('...'), isTrue);
    });

    test('updateNote cambia titulo y cuerpo', () async {
      final s = NotesService();
      await s.addNote(titulo: 'Viejo', cuerpo: 'viejo');
      final id = s.notes.first.id;
      expect(await s.updateNote(id, titulo: 'Nuevo'), isTrue);
      expect(s.notes.first.titulo, 'Nuevo');
    });

    test('deleteNote elimina', () async {
      final s = NotesService();
      await s.addNote(titulo: 'a', cuerpo: 'a');
      await s.addNote(titulo: 'b', cuerpo: 'b');
      final id = s.notes.last.id;
      expect(await s.deleteNote(id), isTrue);
      expect(s.notes.length, 1);
    });
  });

  group('NotesService - limites', () {
    test('rechaza nota 51', () async {
      final s = NotesService();
      for (var i = 0; i < 50; i++) {
        expect(await s.addNote(titulo: 't$i', cuerpo: 'c$i'), isTrue);
      }
      expect(await s.addNote(titulo: 'extra', cuerpo: 'x'), isFalse);
      expect(s.notes.length, 50);
    });

    test('rechaza cuerpo 2001', () async {
      final s = NotesService();
      expect(await s.addNote(titulo: 't', cuerpo: 'a' * 2001), isFalse);
    });

    test('rechaza titulo vacio', () async {
      final s = NotesService();
      expect(await s.addNote(titulo: '', cuerpo: 'c'), isFalse);
      expect(await s.addNote(titulo: '  ', cuerpo: 'c'), isFalse);
    });

    test('search filtra insensible a mayusculas', () async {
      final s = NotesService();
      await s.addNote(titulo: 'Reunion', cuerpo: 'presupuesto');
      await s.addNote(titulo: 'Compra', cuerpo: 'super');
      expect(s.search('reunion').length, 1);
      expect(s.search('SUPER').length, 1);
      expect(s.search('').length, 2);
    });
  });

  group('NotesService - tolerancia', () {
    test('JSON invalido devuelve vacio', () async {
      SharedPreferences.setMockInitialValues({'voice_notes_v1': '{bad'});
      final s = NotesService();
      await s.load();
      expect(s.notes, isEmpty);
    });

    test('tipo incorrecto devuelve vacio', () async {
      SharedPreferences.setMockInitialValues({'voice_notes_v1': '"solo"'});
      final s = NotesService();
      await s.load();
      expect(s.notes, isEmpty);
    });
  });

  group('VoiceNote model', () {
    test('toJson/fromJson round-trip', () {
      final n = VoiceNote(
        id: '1',
        titulo: 'T',
        cuerpo: 'C',
        createdAt: DateTime(2026, 1, 1, 10),
        updatedAt: DateTime(2026, 1, 1, 11),
      );
      final json = n.toJson();
      final restored = VoiceNote.fromJson(json);
      expect(restored.id, n.id);
      expect(restored.titulo, n.titulo);
      expect(restored.cuerpo, n.cuerpo);
    });

    test('fromJson tolera campos ausentes', () {
      final n = VoiceNote.fromJson({});
      expect(n.id, '');
      expect(n.titulo, '');
    });
  });
}
