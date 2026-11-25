import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(BackupService.channelName);
  late List<MethodCall> log;

  setUp(() {
    log = <MethodCall>[];
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  void answer(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      return handler(call);
    });
  }

  test('export sends a dated .zip name and the app version', () async {
    answer((_) => {'status': 'saved', 'notes': 28, 'snippets': 5, 'audio': 3});
    final result = await BackupService().export(now: DateTime(2026, 11, 5));
    expect(result.status, BackupStatus.saved);
    expect(result.notes, 28);
    expect(result.audio, 3);
    expect(log.single.method, 'export');
    final args = log.single.arguments as Map;
    expect(args['fileName'], 'orison-copia-2026-11-05.zip');
    expect(args['appVersion'], BackupService.appVersion);
  });

  test('import maps counts and errors', () async {
    answer((_) => {
          'status': 'imported',
          'notes': 2,
          'notesUpdated': 1,
          'notesSkipped': 0,
          'history': 4,
          'snippets': 1,
          'clips': 3,
        });
    final ok = await BackupService().import();
    expect(ok.status, BackupStatus.imported);
    expect(ok.notes, 2);
    expect(ok.notesUpdated, 1);
    expect(ok.history, 4);
    expect(ok.clips, 3);

    answer((_) => {'status': 'error', 'reason': 'format'});
    final bad = await BackupService().import();
    expect(bad.status, BackupStatus.error);
    expect(bad.reason, 'format');

    answer((_) => {'status': 'cancelled'});
    expect((await BackupService().import()).status, BackupStatus.cancelled);
  });

  test('a channel failure is an io error, never an exception', () async {
    answer((_) => throw PlatformException(code: 'X'));
    final result = await BackupService().export();
    expect(result.status, BackupStatus.error);
    expect(result.reason, 'io');
    answer((_) => null);
    expect((await BackupService().import()).status, BackupStatus.error);
  });
}
