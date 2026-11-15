import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/ui/debouncer.dart';

/// [Throttler]: envíos en vivo mientras se arrastra, como mucho uno cada
/// intervalo, siempre con la última acción y sin temporizadores sueltos.
void main() {
  const gap = Duration(milliseconds: 60);

  testWidgets('la primera acción corre enseguida', (tester) async {
    final t = Throttler(interval: gap);
    addTearDown(t.dispose);
    final seen = <int>[];
    t.run(() async => seen.add(1));
    await tester.pump();
    expect(seen, [1]);
    await tester.pump(gap * 2);
  });

  testWidgets('en ráfaga: la primera y la última, nada en el medio',
      (tester) async {
    final t = Throttler(interval: gap);
    addTearDown(t.dispose);
    final seen = <int>[];
    for (var i = 1; i <= 10; i++) {
      t.run(() async => seen.add(i));
    }
    await tester.pump();
    expect(seen, [1], reason: 'solo la primera, las demás esperan');
    await tester.pump(gap);
    await tester.pump();
    expect(seen, [1, 10], reason: 'al vencer el intervalo sale la última');
    await tester.pump(gap * 2);
  });

  testWidgets('como mucho una vez por intervalo en un arrastre largo',
      (tester) async {
    final t = Throttler(interval: gap);
    addTearDown(t.dispose);
    var runs = 0;
    // 1 s de arrastre con un evento cada 10 ms.
    for (var ms = 0; ms < 1000; ms += 10) {
      t.run(() async => runs++);
      await tester.pump(const Duration(milliseconds: 10));
    }
    await tester.pump(gap * 2);
    expect(runs, lessThanOrEqualTo(1000 ~/ 60 + 2));
    expect(runs, greaterThan(8));
  });

  testWidgets('flush deja pasar ya lo pendiente y espera a que termine',
      (tester) async {
    final t = Throttler(interval: gap);
    addTearDown(t.dispose);
    final seen = <int>[];
    t.run(() async => seen.add(1));
    t.run(() async => seen.add(2));
    t.run(() async => seen.add(3));
    await tester.pump();
    expect(seen, [1]);
    await t.flush();
    expect(seen, [1, 3]);
    expect(t.isBusy, isFalse);
  });

  testWidgets('nunca corren dos acciones a la vez y salen en orden',
      (tester) async {
    final t = Throttler(interval: const Duration(milliseconds: 1));
    addTearDown(t.dispose);
    var active = 0;
    var maxActive = 0;
    final seen = <int>[];
    Future<void> slow(int n) async {
      active++;
      if (active > maxActive) maxActive = active;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      seen.add(n);
      active--;
    }

    t.run(() => slow(1));
    await tester.pump(const Duration(milliseconds: 5));
    t.run(() => slow(2));
    t.run(() => slow(3));
    await tester.pump(const Duration(milliseconds: 100));
    await t.flush();
    await tester.pump(const Duration(milliseconds: 100));
    expect(maxActive, 1);
    expect(seen, [1, 3]);
  });

  testWidgets('una acción que falla no frena a las siguientes', (tester) async {
    final t = Throttler(interval: gap);
    addTearDown(t.dispose);
    final before = debouncerErrorCount;
    final seen = <int>[];
    t.run(() async => throw StateError('falla'));
    t.run(() async => seen.add(2));
    await tester.pump();
    await t.flush();
    expect(seen, [2]);
    expect(debouncerErrorCount, before + 1);
  });

  testWidgets('dispose descarta lo pendiente y no deja temporizadores',
      (tester) async {
    final t = Throttler(interval: gap);
    final seen = <int>[];
    t.run(() async => seen.add(1));
    t.run(() async => seen.add(2));
    t.dispose();
    await tester.pump(gap * 3);
    expect(seen, [1]);
    t.run(() async => seen.add(3));
    await tester.pump(gap * 3);
    expect(seen, [1], reason: 'después de dispose no corre nada');
  });
}
