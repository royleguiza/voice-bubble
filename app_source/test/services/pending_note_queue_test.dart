import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/pending_note_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('pending_queue_');

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall call) async => tempDir.path,
      );
    }
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'plugins.flutter.io/path_provider',
      'plugins.flutter.io/path_provider_android',
      'plugins.flutter.io/path_provider_ios',
      'plugins.flutter.io/path_provider_macos',
      'plugins.flutter.io/path_provider_linux',
      'plugins.flutter.io/path_provider_windows',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  String makeTempWav(String name) {
    final p = '${tempDir.path}/$name';
    File(p).writeAsBytesSync(List<int>.filled(2048, 0x61));
    return p;
  }

  group('PendingNoteQueue - contrato', () {
    test('claves canonicas', () {
      expect(PendingNoteQueue.pendingKey, 'voice_notes_pending_v1');
      expect(PendingNoteQueue.maxPending, 15);
      expect(PendingNoteQueue.pendingDirName, 'pending_notes');
    });

    test('clave NO está en contract-keys.txt (solo Dart)', () {
      final f = File('docs/contract-keys.txt');
      if (!f.existsSync()) {
        // cwd puede ser app_source en algunos runners; buscar desde repo.
        final alt = File('../docs/contract-keys.txt');
        final raw = alt.existsSync()
            ? alt.readAsStringSync()
            : (f.existsSync() ? f.readAsStringSync() : '');
        expect(raw.contains('voice_notes_pending_v1'), isFalse);
        return;
      }
      expect(f.readAsStringSync().contains('voice_notes_pending_v1'),
          isFalse);
    });

    test('fromJson tolera campos ausentes', () {
      final p = PendingNote.fromJson(const {});
      expect(p.id, '');
      expect(p.audioPath, '');
    });
  });

  group('PendingNoteQueue - enqueue', () {
    test('mueve WAV a pending_notes durable y lo registra', () async {
      final q = PendingNoteQueue();
      await q.load();
      final src = makeTempWav('note_offline.wav');
      expect(File(src).existsSync(), isTrue);

      final item = await q.enqueueFromTemp(src);
      expect(item, isNotNull);
      expect(q.items.length, 1);
      expect(q.items.first.id, item!.id);
      expect(item.audioPath.contains('pending_notes'), isTrue);
      expect(File(item.audioPath).existsSync(), isTrue);
      // Temp original retirado (no duplicar).
      expect(File(src).existsSync(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(PendingNoteQueue.pendingKey);
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!) as List;
      expect((decoded.single as Map).keys.toSet(),
          {'id', 'audioPath', 'createdAtMs'});
    });

    test('recarga desde prefs tras instancia nueva', () async {
      final q1 = PendingNoteQueue();
      await q1.load();
      final item = await q1.enqueueFromTemp(makeTempWav('a.wav'));
      expect(item, isNotNull);

      final q2 = PendingNoteQueue();
      await q2.load();
      expect(q2.items.length, 1);
      expect(q2.items.first.id, item!.id);
      expect(q2.audioExists(q2.items.first), isTrue);
    });

    test('cap FIFO 15: descarta el más viejo y su WAV', () async {
      final q = PendingNoteQueue();
      await q.load();
      final paths = <String>[];
      for (var i = 0; i < PendingNoteQueue.maxPending + 3; i++) {
        final it =
            await q.enqueueFromTemp(makeTempWav('n$i.wav'));
        expect(it, isNotNull);
        paths.add(it!.audioPath);
      }
      expect(q.items.length, PendingNoteQueue.maxPending);
      // Los 3 más viejos (insert al inicio => los primeros paths) borrados.
      expect(File(paths[0]).existsSync(), isFalse);
      expect(File(paths[1]).existsSync(), isFalse);
      expect(File(paths[2]).existsSync(), isFalse);
      // El más reciente sigue vivo.
      expect(File(paths.last).existsSync(), isTrue);
    });

    test('archivo inexistente devuelve null', () async {
      final q = PendingNoteQueue();
      await q.load();
      final item = await q.enqueueFromTemp('${tempDir.path}/nope.wav');
      expect(item, isNull);
      expect(q.items, isEmpty);
    });
  });

  group('PendingNoteQueue - remove / discard', () {
    test('remove con deleteAudio borra WAV y actualiza prefs', () async {
      final q = PendingNoteQueue();
      await q.load();
      final item = await q.enqueueFromTemp(makeTempWav('x.wav'));
      expect(item, isNotNull);
      final path = item!.audioPath;

      expect(await q.remove(item.id, deleteAudio: true), isTrue);
      expect(q.items, isEmpty);
      expect(File(path).existsSync(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      final decoded =
          jsonDecode(prefs.getString(PendingNoteQueue.pendingKey)!) as List;
      expect(decoded, isEmpty);
    });

    test('remove sin deleteAudio conserva archivo en disco', () async {
      final q = PendingNoteQueue();
      await q.load();
      final item = await q.enqueueFromTemp(makeTempWav('keep.wav'));
      final path = item!.audioPath;
      expect(await q.remove(item.id, deleteAudio: false), isTrue);
      expect(q.items, isEmpty);
      expect(File(path).existsSync(), isTrue);
    });

    test('remove id inexistente devuelve false', () async {
      final q = PendingNoteQueue();
      await q.load();
      expect(await q.remove('missing'), isFalse);
    });

    test('discardAll limpia cola y audios', () async {
      final q = PendingNoteQueue();
      await q.load();
      final a = await q.enqueueFromTemp(makeTempWav('d1.wav'));
      final b = await q.enqueueFromTemp(makeTempWav('d2.wav'));
      expect(q.items.length, 2);
      await q.discardAll();
      expect(q.items, isEmpty);
      expect(File(a!.audioPath).existsSync(), isFalse);
      expect(File(b!.audioPath).existsSync(), isFalse);
    });
  });

  group('PendingNoteQueue - tolerancia', () {
    test('JSON invalido devuelve vacio', () async {
      SharedPreferences.setMockInitialValues(
          {'voice_notes_pending_v1': '{bad'});
      final q = PendingNoteQueue();
      await q.load();
      expect(q.items, isEmpty);
    });

    test('tipo incorrecto devuelve vacio', () async {
      SharedPreferences.setMockInitialValues(
          {'voice_notes_pending_v1': '"solo"'});
      final q = PendingNoteQueue();
      await q.load();
      expect(q.items, isEmpty);
    });
  });
}
