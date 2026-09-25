import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/models/transcription.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

import '../helpers/mock_channels.dart';

/// Contrato del historial compartido Flutter<->teclado (K3).
///
/// El lado nativo se ejecuta en su prueba Kotlin/JUnit; esta suite fija el
/// contrato de datos que atraviesan archivo y StringList de prefs.
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
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('history_bridge_');
      registerAppChannelMocks(temporaryDirectory: tempDir.path);
    });

    tearDown(() {
      unregisterAppChannelMocks();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

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
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('history_bridge_');
      registerAppChannelMocks(temporaryDirectory: tempDir.path);
    });

    tearDown(() {
      unregisterAppChannelMocks();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

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

  group('Contrato historial - merge de archivo y prefs (C-02)', () {
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('history_bridge_');
      registerAppChannelMocks(temporaryDirectory: tempDir.path);
    });

    tearDown(() {
      unregisterAppChannelMocks();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('conserva textos distintos con el mismo instante en ambos origenes',
        () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        {'text': 'archivo', 'timestamp': '2026-08-23T10:00:00Z'},
        {'text': 'invalida', 'timestamp': 'no-es-fecha'},
      ]));
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode({
            'text': 'prefs',
            'timestamp': '2026-08-23T12:00:00.000+02:00',
          }),
        ],
      });

      final service = StorageService();
      await service.load();

      final texts = service.transcriptions.map((t) => t.text).toList();
      expect(texts, ['archivo', 'prefs']);
      expect(service.transcriptions.length, 2);
    });

    test('recupera el StringList cuando el archivo falta', () async {
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode({
            'text': 'visible-desde-prefs',
            'timestamp': '2026-08-23T10:00:00Z',
          }),
        ],
      });

      final service = StorageService();
      await service.load();

      expect(
        service.transcriptions.map((t) => t.text).toList(),
        ['visible-desde-prefs'],
      );
    });

    test('no recupera ni sobrescribe cuando el archivo esta corrupto (fail-closed)',
        () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync('{archivo-roto');
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode({
            'text': 'visible-desde-prefs',
            'timestamp': '2026-08-23T10:00:00Z',
          }),
        ],
      });

      final service = StorageService();
      final ok = await service.load();

      expect(ok, isFalse);
      expect(service.transcriptions, isEmpty);
      expect(file.readAsStringSync(), '{archivo-roto');
      final added = await service.add(
        keyboardStyleTranscription('nueva', 0),
      );
      expect(added, isFalse);
      expect(file.readAsStringSync(), '{archivo-roto');
    });

    test('descarta overflow, date-only y basura antes de ordenar', () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        {'text': 'overflow', 'timestamp': '2026-02-30T10:00:00Z'},
        {'text': 'date-only', 'timestamp': '2026-08-23'},
        {'text': 'archivo-valido', 'timestamp': '2026-08-23T10:00:00Z'},
        {'text': 'borde-14', 'timestamp': '2026-08-23T10:00:00+14:00'},
        {'text': 'borde-14-neg', 'timestamp': '2026-08-23T10:00:00-14:00'},
        {'text': 'mas-14', 'timestamp': '2026-08-23T10:00:00+14:01'},
        {'text': 'mas-15', 'timestamp': '2026-08-23T10:00:00+15:00'},
        {'text': 'submicro-7', 'timestamp': '2026-08-23T10:00:00.1234567Z'},
        {'text': 'anio-0000', 'timestamp': '0000-01-01T00:00:00Z'},
        {'text': 'anio-9999', 'timestamp': '9999-12-31T23:59:59Z'},
        {'text': 'dst-antes', 'timestamp': '2026-03-29T01:30:00+01:00'},
        {'text': 'dst-despues', 'timestamp': '2026-03-29T03:30:00+02:00'},
      ]));
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode({
            'text': 'prefs-valido',
            'timestamp': '2026-08-23T12:00:00+02:00',
          }),
          jsonEncode({
            'text': 'offset-invalido',
            'timestamp': '2026-08-23T11:00:00+19:00',
          }),
          jsonEncode({
            'text': 'offset-18',
            'timestamp': '2026-08-23T11:00:00+18:00',
          }),
        ],
      });

      final service = StorageService();
      await service.load();

      final texts = service.transcriptions.map((t) => t.text).toSet();
      expect(texts.contains('archivo-valido'), isTrue);
      expect(texts.contains('prefs-valido'), isTrue);
      expect(texts.contains('borde-14'), isTrue);
      expect(texts.contains('borde-14-neg'), isTrue);
      expect(texts.contains('submicro-7'), isTrue);
      expect(texts.contains('anio-0000'), isTrue);
      expect(texts.contains('anio-9999'), isTrue);
      expect(texts.contains('dst-antes'), isTrue);
      expect(texts.contains('dst-despues'), isTrue);
      expect(texts.contains('mas-14'), isFalse);
      expect(texts.contains('mas-15'), isFalse);
      expect(texts.contains('offset-invalido'), isFalse);
      expect(texts.contains('offset-18'), isFalse);
      expect(texts.contains('overflow'), isFalse);
      expect(texts.contains('date-only'), isFalse);
    });

    test('colapsa la entrada identica aunque cambie timezone y precision',
        () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        {
          'text': 'duplicada',
          'timestamp': '2026-08-23T10:00:00.1234567Z',
        },
        {
          'text': 'duplicada',
          'timestamp': '2026-08-23T10:00:00.123456Z',
        },
      ]));
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode({
            'text': 'duplicada',
            'timestamp': '2026-08-23T12:00:00.123456+02:00',
          }),
        ],
      });

      final service = StorageService();
      await service.load();
      await service.add(Transcription(
        text: 'duplicada',
        timestamp: DateTime.utc(2026, 8, 23, 10, 0, 0, 123, 456),
      ));

      expect(service.transcriptions.length, 1);
      expect(service.transcriptions.single.text, 'duplicada');
    });

    test('acepta el formato local histórico solo con offset explícito',
        () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        {'text': 'archivo-local', 'timestamp': '2026-08-23T10:00:00'},
        {'text': 'legacy-sin-zona-rechazado', 'timestamp': '2026-08-23T10:00:00.123'},
      ]));
      SharedPreferences.setMockInitialValues({
        'transcriptions': [
          jsonEncode({
            'text': 'prefs-local',
            'timestamp': '2026-08-23T11:00:00',
          }),
        ],
      });

      final implicit = StorageService();
      await implicit.load();
      expect(implicit.transcriptions, isEmpty);

      final explicit =
          StorageService(historyLegacyOffsetMinutes: -180);
      await explicit.load();

      expect(
        explicit.transcriptions.map((t) => t.text).toSet(),
        {'archivo-local', 'legacy-sin-zona-rechazado', 'prefs-local'},
      );
      final byText = {
        for (final t in explicit.transcriptions) t.text: t.timestamp.toUtc(),
      };
      expect(byText['archivo-local'], DateTime.utc(2026, 8, 23, 13, 0, 0));
      expect(byText['prefs-local'], DateTime.utc(2026, 8, 23, 14, 0, 0));
      final persisted = jsonDecode(file.readAsStringSync()) as List<dynamic>;
      expect(
        persisted.every(
          (item) => RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$')
              .hasMatch(
            (item as Map<String, dynamic>)['timestamp'].toString(),
          ),
        ),
        isTrue,
      );
    });

    test('descarta los mismos blank Unicode en Kotlin y Dart', () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        for (final text in ['\u001C', '\u0085', '\uFEFF'])
          {'text': text, 'timestamp': '2026-08-23T10:00:00Z'},
      ]));

      final service = StorageService();
      await service.load();

      expect(service.transcriptions, isEmpty);
    });

    test('desempata 33 entradas al mismo timestamp por fuente e indice',
        () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        for (var index = 0; index < 33; index++)
          {'text': 'item-$index', 'timestamp': '2026-08-23T10:00:00.000000Z'},
      ]));

      final service = StorageService();
      await service.load();

      expect(
        service.transcriptions.map((t) => t.text).toList(),
        [for (var index = 0; index < 20; index++) 'item-$index'],
      );
    });

    test('si falla la sustitucion atomica conserva el archivo publicado',
        () async {
      final target = Directory(
        '${tempDir.path}/transcription_history.json',
      )..createSync();
      final marker = File('${target.path}/published')
        ..writeAsStringSync('published');

      final result = publishHistoryFileAtomically(
        File(target.path),
        jsonEncode([
          {'text': 'nueva', 'timestamp': '2026-08-23T10:00:00Z'},
        ]),
      );

      expect(result, isFalse);
      expect(marker.readAsStringSync(), 'published');
      expect(
        Directory(tempDir.path)
            .listSync()
            .whereType<File>()
            .every((file) => !file.path.endsWith('.tmp')),
        isTrue,
      );
    });

    test('no publica cuando falla la lectura de un archivo existente',
        () async {
      final target = Directory(
        '${tempDir.path}/transcription_history.json',
      )..createSync();
      final marker = File('${target.path}/published')
        ..writeAsStringSync('published');
      final service = StorageService();

      final result = await service.add(
        keyboardStyleTranscription('nueva', 20),
      );

      expect(result, isFalse);
      expect(marker.readAsStringSync(), 'published');
    });

    test('serializa dos adds sobre el mismo archivo real', () async {
      SharedPreferences.setMockInitialValues({});
      final first = StorageService();
      final second = StorageService();

      final results = await Future.wait([
        first.add(keyboardStyleTranscription('uno', 0)),
        second.add(keyboardStyleTranscription('dos', 1)),
      ]);
      final reader = StorageService();
      await reader.load();

      expect(results, [isTrue, isTrue]);
      expect(
        reader.transcriptions.map((entry) => entry.text).toSet(),
        {'uno', 'dos'},
      );
    });

    test('valida overflow legacy despues de convertir a UTC en zona positiva',
        () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        {'text': 'overflow-0000', 'timestamp': '0000-01-01T00:00:00'},
        {'text': 'valid-9999', 'timestamp': '9999-12-31T23:59:59'},
      ]));
      final service = StorageService(historyLegacyOffsetMinutes: 120);

      await service.load();

      expect(
        service.transcriptions.map((entry) => entry.text).toList(),
        ['valid-9999'],
      );
    });

    test('valida overflow legacy despues de convertir a UTC en zona negativa',
        () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        {'text': 'valid-0000', 'timestamp': '0000-01-01T00:00:00'},
        {'text': 'overflow-9999', 'timestamp': '9999-12-31T23:59:59'},
      ]));
      final service = StorageService(historyLegacyOffsetMinutes: -120);

      await service.load();

      expect(
        service.transcriptions.map((entry) => entry.text).toList(),
        ['valid-0000'],
      );
    });

    test('canonicaliza timestamp y payload antes de guardar', () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        {
          'text': 'archivo',
          'timestamp': '2026-08-23T12:00:00.1234567+02:00',
        },
      ]));
      final service = StorageService();

      expect(
        await service.add(
          Transcription(
            text: 'nuevo',
            timestamp: DateTime.parse('2026-08-23T13:00:00+02:00'),
          ),
        ),
        isTrue,
      );
      final persisted = jsonDecode(file.readAsStringSync()) as List<dynamic>;

      expect(
        persisted.map((item) => (item as Map<String, dynamic>)['timestamp']),
        [
          '2026-08-23T11:00:00.000000Z',
          '2026-08-23T10:00:00.123456Z',
        ],
      );
      expect(file.readAsStringSync(), isNot(contains('+02:00')));
      expect(file.readAsStringSync(), isNot(contains('1234567')));
    });

    test('lock stale obsoleto se recupera y adquiere', () async {
      final file = File('${tempDir.path}/transcription_history.json');
      file.writeAsStringSync(jsonEncode([
        {'text': 'prev', 'timestamp': '2026-08-23T10:00:00Z'},
      ]));
      final lock =
          File('${tempDir.path}/transcription_history.json.lock');
      lock.writeAsStringSync(
        'stale-token\n${DateTime.now().millisecondsSinceEpoch - 20000}\n',
      );
      lock.setLastModifiedSync(
        DateTime.now().subtract(const Duration(seconds: 20)),
      );
      final service = StorageService();

      final ok = await service.add(
        keyboardStyleTranscription('tras-stale', 5),
      );

      expect(ok, isTrue);
      expect(lock.existsSync(), isFalse);
    });

    test('lock timeout es fail-closed sin escribir', () async {
      final file = File('${tempDir.path}/transcription_history.json');
      final original = jsonEncode([
        {'text': 'prev', 'timestamp': '2026-08-23T10:00:00Z'},
      ]);
      file.writeAsStringSync(original);
      final lock =
          File('${tempDir.path}/transcription_history.json.lock');
      lock.writeAsStringSync(
        'holder\n${DateTime.now().millisecondsSinceEpoch}\n',
      );
      final service = StorageService();

      var timedOut = false;
      try {
        await service.withTranscriptionHistoryFileLock(
          file,
          () async => true,
          timeoutMs: 200,
        );
      } catch (_) {
        timedOut = true;
      }

      expect(timedOut, isTrue);
      expect(file.readAsStringSync(), original);
    });

    test('publisher controla directorio ausente sin parcial (missing)', () async {
      final missing =
          File('${tempDir.path}/ausente/sub/transcription_history.json');
      final result = publishHistoryFileAtomically(missing, '[]');

      // Sin mkdirs: falla cerrado sin crear el archivo esperado ni parciales.
      expect(result, isFalse);
      expect(missing.existsSync(), isFalse);
      expect(
        Directory(tempDir.path)
            .listSync(recursive: true)
            .whereType<File>()
            .every((file) => !file.path.endsWith('.tmp')),
        isTrue,
      );
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
