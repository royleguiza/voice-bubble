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

/// Etiqueta del botón de copiado (popup + historial).
const String copyButtonLabel = 'Copiar';

/// Tooltip / anuncio de lector de pantalla del botón de copiado.
const String copyTooltipMessage = 'Copiar al portapapeles';

/// Confirmación de copiado exitoso (SnackBar).
const String copiedToClipboardMessage = 'Texto copiado';

/// Aviso de fallo de portapapeles: se muestra clasificado como fallo de
/// clipboard, NUNCA como "error de red" ni con reintento de transcripción.
const String clipboardFailureMessage =
    'No se pudo copiar al portapapeles';

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
