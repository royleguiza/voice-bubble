import 'package:flutter/services.dart';

/// Fuente única de formato de fecha y textos de copiado para
/// transcripciones (popup + historial + home).
///
/// Antes cada widget formateaba la fecha a mano (`day/month...`) y usaba un
/// literal distinto ("Texto copiado" vs "Texto copiado al portapapeles" vs
/// "Copiado al portapapeles"): cualquier cambio de redacción exigía tocar
/// N sitios y los tests congelan uno de ellos
/// (`history_list_test.dart` exige 'Texto copiado' y '21/08/2026 14:30').
/// Centralizar aquí mantiene un solo punto de verdad sin romperlos.
String formatTranscriptionTimestamp(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day/$month/${dt.year} $hour:$minute';
}

/// Resultado clasificado de un intento de copiado.
enum ClipboardCopyResult { ok, failed }

/// Copia [text] al portapapeles sin lanzar: devuelve [ClipboardCopyResult].
/// Usar en TODOS los sitios que copien (home x3 + historial) para que un
/// fallo de clipboard no se confunda con un fallo de red/reintento.
Future<ClipboardCopyResult> copyTranscriptionText(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return ClipboardCopyResult.ok;
  } catch (_) {
    return ClipboardCopyResult.failed;
  }
}
