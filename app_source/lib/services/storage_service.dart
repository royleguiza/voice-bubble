import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/snippet.dart';
import '../models/transcription.dart';
import 'cloud_stt_service.dart';

class StorageService {
  static const String _key = 'transcriptions';
  static const int _maxItems = 20;
  static const String _recordModeKey = 'recording_mode';
  static const String defaultRecordMode = 'tap';

  List<Transcription> _transcriptions = [];

  List<Transcription> get transcriptions =>
      List.unmodifiable(_transcriptions);

  /// Modo de interacción del botón: 'tap' (toque inicia/detiene)
  /// o 'hold' (mantener presionado graba, soltar transcribe).
  Future<String> loadRecordMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_recordModeKey) ?? defaultRecordMode;
  }

  Future<void> saveRecordMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordModeKey, mode);
  }

  static const String _floatingBubbleKey = 'floating_bubble_enabled';

  Future<bool> loadFloatingBubbleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_floatingBubbleKey) ?? false;
  }

  Future<void> saveFloatingBubbleEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_floatingBubbleKey, enabled);
  }

  static const String _keyboardTerminalRowKey = 'kb_terminal_row_visible';

  /// Fila terminal del teclado (TAB, ESC, CTRL, ALT, flechas).
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardTerminalRowVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyboardTerminalRowKey) ?? true;
  }

  Future<void> saveKeyboardTerminalRowVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyboardTerminalRowKey, visible);
  }

  static const String _keyboardCodeKeyVisibleKey = 'kb_code_key_visible';

  /// Tecla </> que abre la capa de simbolos de programacion.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardCodeKeyVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyboardCodeKeyVisibleKey) ?? true;
  }

  Future<void> saveKeyboardCodeKeyVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyboardCodeKeyVisibleKey, visible);
  }

  static const String _keyboardLanguageKeyVisibleKey =
      'kb_language_key_visible';

  /// Tecla ES/EN junto a la barra espaciadora para cambiar el idioma.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  Future<bool> loadKeyboardLanguageKeyVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyboardLanguageKeyVisibleKey) ?? true;
  }

  Future<void> saveKeyboardLanguageKeyVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyboardLanguageKeyVisibleKey, visible);
  }

  static const String kbHeightProfileKey = 'kb_height_profile';
  static const String kbHapticsEnabledKey = 'kb_haptics_enabled';

  /// Perfiles de altura del teclado validos, de menor a mayor.
  static const List<String> kbHeightProfiles = ['baja', 'media', 'alta'];
  static const String defaultHeightProfile = 'media';

  /// Altura global del teclado: 'baja', 'media' o 'alta'.
  /// El teclado nativo Kotlin lee esta misma clave con prefijo "flutter.".
  /// Un valor ausente o invalido cae al perfil por defecto.
  Future<String> getHeightProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = prefs.getString(kbHeightProfileKey);
    return kbHeightProfiles.contains(profile)
        ? profile!
        : defaultHeightProfile;
  }

  Future<void> setHeightProfile(String profile) async {
    if (!kbHeightProfiles.contains(profile)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kbHeightProfileKey, profile);
  }

  /// Vibracion hapatica al pulsar teclas. El teclado nativo Kotlin lee esta
  /// misma clave con prefijo "flutter.".
  Future<bool> getHapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kbHapticsEnabledKey) ?? true;
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kbHapticsEnabledKey, enabled);
  }

  // --- Espejo D7: credenciales STT para el teclado nativo (K3) ---
  // El teclado Kotlin lee estas claves con prefijo "flutter." en
  // FlutterSharedPreferences. La API key vive aqui en texto plano dentro de
  // las preferencias PRIVADAS del paquete (inaccesibles para otras apps),
  // nunca en el repo ni en storage externo.
  static const String _sttProviderKey = 'kb_stt_provider';
  static const String _sttUrlKey = 'kb_stt_url';
  static const String _sttModelKey = 'kb_stt_model';
  static const String _sttApiKeyKey = 'kb_stt_api_key';

  Future<void> saveSttMirror({required String apiKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sttApiKeyKey, apiKey);
    await prefs.setString(_sttProviderKey, CloudSttService.provider);
    await prefs.setString(_sttUrlKey, CloudSttService.endpoint);
    await prefs.setString(_sttModelKey, CloudSttService.model);
    await prefs.setString('kb_stt_language', CloudSttService.language);
  }

  Future<void> clearSttMirror() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sttApiKeyKey);
    await prefs.remove(_sttProviderKey);
    await prefs.remove(_sttUrlKey);
    await prefs.remove(_sttModelKey);
    await prefs.remove('kb_stt_language');
  }

  Future<String?> loadSttMirroredApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sttApiKeyKey);
  }

  // --- Snippets del teclado (K4) ---
  // Contrato compartido con el teclado nativo Kotlin: el valor de
  // [snippetsKey] es un STRING con un JSON array de objetos con claves
  // "id" (String), "nombre" (String), "contenido" (String) e "orden"
  // (int). El lado Kotlin lee estas mismas claves con prefijo "flutter.".
  static const String snippetsKey = 'voice_snippets_v1';
  static const String snippetsSeededKey = 'kb_snippets_seeded';
  static const int _maxSnippets = 50;
  static const int _maxSnippetLength = 2000;

  int _snippetIdCounter = 0;

  /// ID unico sin dependencias externas: timestamp + contador monotono,
  /// para que llamadas rapidas seguidas nunca colisionen.
  String _nextSnippetId() {
    _snippetIdCounter += 1;
    return '${DateTime.now().microsecondsSinceEpoch}-$_snippetIdCounter';
  }

  /// Carga los snippets guardados. Ante JSON corrupto o tipos inesperados
  /// devuelve lista vacia en lugar de lanzar excepcion al llamador.
  Future<List<Snippet>> loadSnippets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(snippetsKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final loaded = <Snippet>[];
      for (final item in decoded) {
        if (item is Map) {
          loaded.add(Snippet.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return loaded;
    } catch (_) {
      // JSON corrupto o tipo raiz incorrecto: se descarta sin fallar.
      return [];
    }
  }

  /// Serializa el JSON array ordenado por [Snippet.orden]; el orden es
  /// estable: empates conservan la posicion relativa de entrada.
  Future<void> saveSnippets(List<Snippet> snippets) async {
    final indexed = <(int, Snippet)>[
      for (var i = 0; i < snippets.length; i++) (i, snippets[i]),
    ];
    indexed.sort((a, b) {
      final byOrden = a.$2.orden.compareTo(b.$2.orden);
      return byOrden != 0 ? byOrden : a.$1.compareTo(b.$1);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      snippetsKey,
      jsonEncode(indexed.map((e) => e.$2.toJson()).toList()),
    );
  }

  /// Agrega un snippet al final de la lista. Devuelve false si viola los
  /// limites del contrato: nombre vacio, contenido mayor a 2000
  /// caracteres o ya existen 50 snippets.
  Future<bool> addSnippet({
    required String nombre,
    required String contenido,
  }) async {
    if (nombre.trim().isEmpty) return false;
    if (contenido.length > _maxSnippetLength) return false;
    final current = await loadSnippets();
    if (current.length >= _maxSnippets) return false;
    await saveSnippets([
      ...current,
      Snippet(
        id: _nextSnippetId(),
        nombre: nombre,
        contenido: contenido,
        orden: current.length,
      ),
    ]);
    return true;
  }

  /// Actualiza nombre y/o contenido del snippet con ese id. Devuelve false
  /// si el id no existe o los valores nuevos violan los limites de
  /// [addSnippet] (el snippet queda intacto en ese caso).
  Future<bool> updateSnippet(
    String id, {
    String? nombre,
    String? contenido,
  }) async {
    if (nombre != null && nombre.trim().isEmpty) return false;
    if (contenido != null && contenido.length > _maxSnippetLength) {
      return false;
    }
    final current = await loadSnippets();
    final index = current.indexWhere((s) => s.id == id);
    if (index == -1) return false;
    current[index] =
        current[index].copyWith(nombre: nombre, contenido: contenido);
    await saveSnippets(current);
    return true;
  }

  /// Elimina el snippet con ese id y renumera [Snippet.orden] para que
  /// quede contiguo. Devuelve false si el id no existia.
  Future<bool> deleteSnippet(String id) async {
    final current = await loadSnippets();
    final remaining =
        current.where((s) => s.id != id).toList(growable: false);
    if (remaining.length == current.length) return false;
    await saveSnippets([
      for (var i = 0; i < remaining.length; i++)
        remaining[i].copyWith(orden: i),
    ]);
    return true;
  }

  /// Recibe los ids en el nuevo orden deseado y reescribe [Snippet.orden]
  /// segun esa posicion. Los ids desconocidos se ignoran y los snippets no
  /// mencionados conservan su orden relativo al final de la lista.
  Future<void> reorderSnippets(List<String> idsInNewOrder) async {
    final current = await loadSnippets();
    final pending = {for (final s in current) s.id: s};
    final reordered = <Snippet>[];
    for (final id in idsInNewOrder) {
      final snippet = pending.remove(id);
      if (snippet != null) reordered.add(snippet);
    }
    reordered.addAll(pending.values);
    await saveSnippets([
      for (var i = 0; i < reordered.length; i++)
        reordered[i].copyWith(orden: i),
    ]);
  }

  /// Precarga los 5 seeds solo si nunca se sembro y ademas no hay snippets
  /// guardados. Idempotente: si el flag ya esta marcado no toca nada, asi
  /// que borrar todos los seeds manualmente no los resucita.
  Future<void> ensureSeeds() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(snippetsSeededKey) ?? false) return;
    final current = await loadSnippets();
    if (current.isEmpty) {
      await saveSnippets(_seedSnippets);
    }
    await prefs.setBool(snippetsSeededKey, true);
  }

  /// Seeds exactos definidos por el contrato K4 (orden/nombre/contenido).
  /// IDs estables con prefijo "seed-" para que ambos lados puedan
  /// referenciarlos.
  static const List<Snippet> _seedSnippets = [
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

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final jsonList = prefs.getStringList(_key) ?? [];
    final loaded = <Transcription>[];
    for (final json in jsonList) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map) {
          loaded.add(
            Transcription.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } catch (_) {
        // Ignore corrupt entry gracefully
      }
    }
    _transcriptions = loaded;
  }

  Future<void> add(Transcription transcription) async {
    _transcriptions.insert(0, transcription);
    if (_transcriptions.length > _maxItems) {
      _transcriptions = _transcriptions.sublist(0, _maxItems);
    }
    await _save();
  }

  Future<void> clear() async {
    _transcriptions.clear();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList =
        _transcriptions.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }
}
