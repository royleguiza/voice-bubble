import 'dart:io';

/// Prefijo que identifica al proceso dueño de un archivo de lock.
///
/// Si Android mata la app con un lock tomado, el archivo queda huérfano y,
/// sin dueño identificable, solo se libera por antigüedad (30 s): al reabrir
/// antes de eso la lectura de notas agotaba la espera y mostraba "Notas no
/// disponibles". Con el pid adentro, el proceso nuevo lo libera al instante.
String lockOwnerPrefix() => 'p$pid:';

/// true solo si el lock lo creó OTRO proceso que ya no existe. Ante cualquier
/// duda (formato viejo, sin /proc, error de lectura) devuelve false y manda la
/// regla por antigüedad de siempre.
bool lockOwnerIsDead(File lockFile) {
  try {
    final match =
        RegExp(r'^p(\d+):').firstMatch(lockFile.readAsStringSync());
    if (match == null) return false;
    final owner = int.parse(match.group(1)!);
    if (owner == pid) return false;
    if (!Directory('/proc/self').existsSync()) return false;
    return !Directory('/proc/$owner').existsSync();
  } catch (_) {
    return false;
  }
}
