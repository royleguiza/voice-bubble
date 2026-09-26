import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/uuid_helper.dart';
import '../models/snippet.dart';

/**
 * SnippetRepository - Repositorio modular de snippets / plantillas (C-25).
 * Extraído de StorageService para desacoplar el god-object de persistencia.
 */
class SnippetRepository {
  static const String snippetsKey = 'voice_snippets_v1';
  static const String snippetsSeededKey = 'kb_snippets_seeded';

  static const int maxSnippets = 50;
  static const int maxSnippetLength = 2000;

  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  String nextSnippetId() => generateUuidV4();

  Future<List<Snippet>> loadSnippets() async =>
      await readSnippets() ?? const [];

  Future<List<Snippet>?> readSnippets() async {
    try {
      final prefs = await _prefs();
      await prefs.reload();
      final raw = prefs.getString(snippetsKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return null;
      final loaded = <Snippet>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) return null;
        final id = item['id'] as String?;
        final nombre = item['nombre'] as String?;
        final contenido = item['contenido'] as String?;
        final orden = item['orden'] as int?;
        final color = item['color'] as String?;
        if (id == null || nombre == null || contenido == null || orden == null) {
          return null;
        }
        loaded.add(Snippet(
          id: id,
          nombre: nombre,
          contenido: contenido,
          orden: orden,
          color: color,
        ));
      }
      return loaded;
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveSnippets(List<Snippet> snippets) async {
    try {
      final jsonList = snippets
          .map((s) => {
                'id': s.id,
                'nombre': s.nombre,
                'contenido': s.contenido,
                'orden': s.orden,
                if (s.color != null && s.color!.isNotEmpty) 'color': s.color,
              })
          .toList();
      final prefs = await _prefs();
      return await prefs.setString(snippetsKey, jsonEncode(jsonList));
    } catch (_) {
      return false;
    }
  }

  static const List<Snippet> seedSnippets = [
    Snippet(
      id: 'seed-1',
      nombre: 'Mail formal',
      contenido: 'Estimado/a,\n\nEspero que te encuentres muy bien.\n\nSaludos cordiales,',
      orden: 0,
      color: 'azul',
    ),
    Snippet(
      id: 'seed-2',
      nombre: 'WhatsApp rápido',
      contenido: '¡Hola! ¿Cómo estás? Te escribo por lo siguiente: ',
      orden: 1,
      color: 'verde',
    ),
    Snippet(
      id: 'seed-3',
      nombre: 'Urgente',
      contenido: 'URGENTE: necesitamos resolver esto cuanto antes.',
      orden: 2,
      color: 'rojo',
    ),
    Snippet(
      id: 'seed-4',
      nombre: 'Recordatorio',
      contenido: 'Recordá que tenemos pendiente: ',
      orden: 3,
      color: 'naranja',
    ),
    Snippet(
      id: 'seed-5',
      nombre: 'Firma corta',
      contenido: 'Abrazo grande,\nRoy',
      orden: 4,
      color: 'violeta',
    ),
  ];

  Future<void> seedDefaultsIfEmpty() async {
    try {
      final prefs = await _prefs();
      final seeded = prefs.getBool(snippetsSeededKey) ?? false;
      if (seeded) return;
      final existing = await readSnippets();
      if (existing != null && existing.isEmpty) {
        await saveSnippets(seedSnippets);
      }
      await prefs.setBool(snippetsSeededKey, true);
    } catch (_) {}
  }
}
