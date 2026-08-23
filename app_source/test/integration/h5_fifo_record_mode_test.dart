import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

/// Matriz H5-T5 (Lane A): persistencia a nivel servicio.
///
/// Punto 3: el modo de grabacion toque/mantener sobrevive a instancias
/// NUEVAS de StorageService (equivalente a recrear pantalla/proceso).
/// Punto 4: FIFO-20 exacto sobre un historial sembrado en prefs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Punto 3 - modo toque/mantener persiste entre instancias', () {
    test('default tap cuando nunca se guardo', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();

      expect(await service.loadRecordMode(), StorageService.defaultRecordMode);
      expect(await service.loadRecordMode(), 'tap');
    });

    test("guardar 'hold' en instancia A lo lee una instancia NUEVA B",
        () async {
      SharedPreferences.setMockInitialValues({});
      final writer = StorageService();
      await writer.saveRecordMode('hold');

      final fresh = StorageService();
      expect(await fresh.loadRecordMode(), 'hold');
    });

    test('round trip hold -> tap leido por instancia fresca cada vez',
        () async {
      SharedPreferences.setMockInitialValues({});
      final writer = StorageService();

      await writer.saveRecordMode('hold');
      expect(await StorageService().loadRecordMode(), 'hold');

      await writer.saveRecordMode('tap');
      expect(await StorageService().loadRecordMode(), 'tap');
    });

    test('persiste bajo la clave recording_mode compartida', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.saveRecordMode('hold');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('recording_mode'), 'hold');
    });
  });

  group('Punto 4 - FIFO-20 exacto sobre datos sembrados', () {
    test(
        'sembrar 25, guardar 1 nueva: quedan exactamente 20, las mas viejas fuera y timestamps descendentes',
        () async {
      final base = DateTime.utc(2026, 8, 23, 10, 0, 0);
      Transcription seeded(int i) => Transcription(
            text: 'seed-$i',
            timestamp: base.add(Duration(minutes: i)),
            isLocal: i.isEven,
          );

      // Sembrar 25 en prefs, mas-nuevo-primero (orden que escriben la app
      // y el teclado nativo al serializar la lista).
      final seeds = <String>[
        for (var i = 25; i >= 1; i--) jsonEncode(seeded(i).toJson()),
      ];
      SharedPreferences.setMockInitialValues({'transcriptions': seeds});

      final service = StorageService();
      await service.load();
      // El lote sembrado entra completo; el tope se aplica al agregar.
      expect(service.transcriptions.length, 25);

      final nueva = Transcription(
        text: 'nueva-26',
        timestamp: base.add(const Duration(minutes: 26)),
        isLocal: false,
      );
      await service.add(nueva);

      final history = service.transcriptions;
      // EXACTAMENTE 20.
      expect(history.length, 20);
      // La mas nueva queda primera.
      expect(history.first.text, 'nueva-26');
      // Las 6 mas viejas (seed-1..seed-6) salieron del FIFO.
      for (var i = 1; i <= 6; i++) {
        expect(
          history.any((t) => t.text == 'seed-$i'),
          isFalse,
          reason: 'seed-$i debe haber sido expulsada del historial',
        );
      }
      // La mas vieja restante cierra la lista.
      expect(history.last.text, 'seed-7');
      // Orden estrictamente descendente por timestamp.
      for (var i = 0; i < history.length - 1; i++) {
        expect(
          history[i].timestamp.isAfter(history[i + 1].timestamp),
          isTrue,
          reason: 'posicion $i debe ser mas reciente que la posicion ${i + 1}',
        );
      }

      // El recorte persiste: una instancia nueva lee exactamente las 20.
      final fresh = StorageService();
      await fresh.load();
      expect(fresh.transcriptions.length, 20);
      expect(fresh.transcriptions.first.text, 'nueva-26');
      expect(fresh.transcriptions.last.text, 'seed-7');
    });
  });
}
