import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/pro_service.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

/// T15 · Espejo de ProGate.kt: 30 días con todo, después 10 por día.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final t0 = DateTime(2027, 1, 1, 10);
  const day = Duration(days: 1);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('mismas claves que el puente del teclado', () {
    expect(ProGate.unlockedKey, StorageService.proUnlockedKey);
    expect(ProGate.trialStartKey, StorageService.proTrialStartKey);
    expect(ProGate.dayKey, StorageService.proDayKey);
    expect(ProGate.dayCountKey, StorageService.proDayCountKey);
  });

  test('el primer uso arranca la prueba y deja dictar sin contar', () async {
    expect(await ProGate.tryStartDictation(now: t0), isTrue);
    final st = await ProGate.status(now: t0);
    expect(st.inTrial, isTrue);
    expect(st.trialDaysLeft, ProGate.trialDays);
    expect(st.usedToday, 0);
  });

  test('pasada la prueba: 10 por día y al otro día vuelve', () async {
    await ProGate.ensureTrialStarted(now: t0);
    final after = t0.add(const Duration(days: 31));
    for (var i = 0; i < ProGate.freeDailyDictations; i++) {
      expect(await ProGate.tryStartDictation(now: after), isTrue, reason: 'dictado $i');
    }
    expect(await ProGate.tryStartDictation(now: after), isFalse);
    final st = await ProGate.status(now: after);
    expect(st.inTrial, isFalse);
    expect(st.freeLeftToday, 0);
    expect(await ProGate.tryStartDictation(now: after.add(day)), isTrue);
  });

  test('con Pro no hay límite', () async {
    await ProGate.ensureTrialStarted(now: t0);
    await ProGate.markUnlocked();
    final later = t0.add(const Duration(days: 400));
    for (var i = 0; i < 30; i++) {
      expect(await ProGate.tryStartDictation(now: later), isTrue);
    }
    expect((await ProGate.status(now: later)).unlocked, isTrue);
  });

  test('la prueba no se reinicia', () async {
    await ProGate.ensureTrialStarted(now: t0);
    await ProGate.ensureTrialStarted(now: t0.add(const Duration(days: 20)));
    expect((await ProGate.status(now: t0.add(const Duration(days: 20)))).trialDaysLeft, 10);
  });
}
