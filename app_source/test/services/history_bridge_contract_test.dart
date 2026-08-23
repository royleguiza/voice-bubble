import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

/// Contrato del historial compartido Flutter<->teclado (K3).
///
/// El teclado nativo escribe entradas JSON con la misma forma que
/// Transcription.toJson() de Dart: {"text", "timestamp" (ISO-8601, con
/// sufijo Z cuando viene de Instant.now())}. Estos tests fijan ese
/// contrato por ambos lados sin necesidad de runner Kotlin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Contrato historial - formato de entrada del teclado', () {
    test('entrada estilo Kotlin se parsea con Transcription.fromJson', () {
      final json = keyboardEntry('dictado desde el teclado',
          DateTime.parse('2026-08-23T10:00:00Z'));

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final t = Transcription.fromJson(decoded);

      expect(t.text, 'dictado desde el teclado');
      // El instante UTC se conserva y se muestra en hora local.
      expect(t.timestamp, DateTime.utc(2026, 8, 23, 10).toLocal());
      expect(t.timestamp.isUtc, isFalse);
    });

    test('round-trip toJson/fromJson preserva los campos', () {
      // fromJson normaliza a hora local (contrato K3); DateTime.== exige
      // igualdad de bandera isUtc, asi que el esperado se construye con la
      // misma normalizacion y se compara como instante.
      final base = Transcription(
        text: 'hola mundo',
        timestamp: DateTime.parse('2026-08-23T10:00:00Z').toLocal(),
      );

      final restored = Transcription.fromJson(base.toJson());

      expect(restored, base);
    });
  });

  group('Contrato historial - FIFO 20 con entradas del teclado', () {
    test('carga el lote del teclado en orden mas-nuevo-primero', () async {
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          keyboardEntry('c', DateTime.parse('2026-08-23T12:00:00Z')),
          keyboardEntry('b', DateTime.parse('2026-08-23T11:00:00Z')),
          keyboardEntry('a', DateTime.parse('2026-08-23T10:00:00Z')),
        ],
      });

      final service = StorageService();
      await service.load();

      expect(
        service.transcriptions.map((t) => t.text).toList(),
        ['c', 'b', 'a'],
      );
    });

    test('add respeta el limite de 20 mezclando entradas del teclado',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();

      for (var i = 0; i < 20; i++) {
        await service.add(keyboardStyleTranscription('item $i', i));
      }
      // La entrada numero 21 llega desde el teclado.
      await service.add(keyboardStyleTranscription('nueva', 20));

      expect(service.transcriptions.length, 20);
      expect(service.transcriptions.first.text, 'nueva');
      // El mas viejo ("item 0") salio del FIFO.
      expect(service.transcriptions.any((t) => t.text == 'item 0'), isFalse);
    });
  });

  group('Contrato historial - tolerancia ante datos rotos', () {
    test('entrada con JSON roto se ignora sin crashear la carga', () async {
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          '{texto-roto',
          keyboardEntry('valida', DateTime.parse('2026-08-23T10:00:00Z')),
        ],
      });

      final service = StorageService();
      await service.load();

      expect(service.transcriptions.length, 1);
      expect(service.transcriptions.single.text, 'valida');
    });

    test('entrada con timestamp ilegible se ignora sin crashear', () async {
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          '{"text":"ts-roto","timestamp":"no-es-fecha"}',
          keyboardEntry('valida', DateTime.parse('2026-08-23T10:00:00Z')),
        ],
      });

      final service = StorageService();
      await service.load();

      expect(service.transcriptions.length, 1);
      expect(service.transcriptions.single.text, 'valida');
    });
  });
}

/// Forma EXACTA que produce org.json en el lado Kotlin.
String keyboardEntry(String text, DateTime timestamp) {
  return '{"text":"$text","timestamp":"${timestamp.toUtc().toIso8601String()}"}';
}

/// Replica la entrada que persiste el teclado nativo (K3): JSON plano con
/// timestamp UTC, convertido a Transcription para la app.
Transcription keyboardStyleTranscription(String text, int minuteOffset) {
  return Transcription.fromJson(
    jsonDecode(keyboardEntry(
      text,
      DateTime.parse('2026-08-23T10:00:00Z').add(Duration(minutes: minuteOffset)),
    )) as Map<String, dynamic>,
  );
}
