import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/l10n/app_localizations.dart';
import 'package:voice_bubble_stt/l10n/service_error_text.dart';
import 'package:voice_bubble_stt/services/cloud_stt_service.dart';
import 'package:voice_bubble_stt/services/gemini_note_service.dart';

/// Ruta IA, etapa 4: los errores que nacen en servicios se muestran en el
/// idioma de la app (antes salían siempre en español).
void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final en = lookupAppLocalizations(const Locale('en'));
  final pt = lookupAppLocalizations(const Locale('pt'));

  test('cada ServiceError tiene texto en es, en y pt', () {
    for (final reason in ServiceError.values) {
      final e = GeminiException('x', reason: reason, code: 500, detail: 'd', provider: 'Groq');
      for (final l in [es, en, pt]) {
        expect(serviceErrorText(l, e), isNotEmpty, reason: '$reason');
      }
    }
  });

  test('transcripción sin red sale en el idioma elegido', () {
    const e = TranscriptionException('Sin conexión a internet.',
        kind: TranscriptionErrorKind.network, reason: ServiceError.noInternet);
    expect(serviceErrorText(es, e), 'Sin conexión a internet.');
    expect(serviceErrorText(en, e), 'No internet connection.');
    expect(serviceErrorText(pt, e), 'Sem conexão com a internet.');
  });

  test('error de IA con proveedor, código y detalle', () {
    const e = GeminiException('Clave de Groq inválida (401) bad',
        kind: GeminiErrorKind.auth,
        reason: ServiceError.aiKeyInvalid,
        code: 401,
        detail: 'bad',
        provider: 'Groq');
    expect(serviceErrorText(en, e), 'Invalid Groq key (401) bad');
    expect(serviceErrorText(es, e), 'Clave de Groq inválida (401) bad');
  });

  test('sin motivo se muestra el mensaje original', () {
    expect(serviceErrorText(en, const TranscriptionException('raw')), 'raw');
    expect(serviceErrorText(en, StateError('boom')), contains('boom'));
  });
}
