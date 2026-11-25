import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado de Orison Pro para mostrar en Ajustes.
class ProStatus {
  const ProStatus({
    required this.unlocked,
    required this.trialDaysLeft,
    required this.usedToday,
  });

  final bool unlocked;

  /// Días de prueba que quedan (0 = terminó).
  final int trialDaysLeft;

  /// Dictados de hoy (solo cuentan pasada la prueba y sin Pro).
  final int usedToday;

  bool get inTrial => !unlocked && trialDaysLeft > 0;
  int get freeLeftToday =>
      (ProGate.freeDailyDictations - usedToday).clamp(0, ProGate.freeDailyDictations);
}

/// T15 · Espejo en Dart de `ProGate.kt`: 30 días con todo desde el primer
/// uso, después 10 dictados por día; Pro (pago único) ilimitado. Mismas
/// claves de preferencias que lee el teclado, el widget y la barra, para que
/// todos cuenten lo mismo.
abstract final class ProGate {
  static const int trialDays = 30;
  static const int freeDailyDictations = 10;

  static const String unlockedKey = 'pro_unlocked';
  static const String trialStartKey = 'pro_trial_start_ms';
  static const String dayKey = 'pro_day';
  static const String dayCountKey = 'pro_day_count';

  static const int _dayMs = 86400000;

  static String _day(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    final d = now.toLocal();
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// Marca el inicio de la prueba la primera vez (no pisa uno existente).
  static Future<void> ensureTrialStarted({DateTime? now}) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      if ((p.getInt(trialStartKey) ?? 0) <= 0) {
        await p.setInt(trialStartKey, (now ?? DateTime.now()).millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  static Future<ProStatus> status({DateTime? now}) async {
    final t = now ?? DateTime.now();
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final unlocked = p.getBool(unlockedKey) ?? false;
      final start = p.getInt(trialStartKey) ?? 0;
      final elapsed = start <= 0 ? 0 : t.millisecondsSinceEpoch - start;
      final left = start <= 0
          ? trialDays
          : (trialDays - (elapsed / _dayMs).floor()).clamp(0, trialDays);
      final used = p.getString(dayKey) == _day(t) ? (p.getInt(dayCountKey) ?? 0) : 0;
      return ProStatus(unlocked: unlocked, trialDaysLeft: left, usedToday: used);
    } catch (_) {
      return const ProStatus(unlocked: false, trialDaysLeft: trialDays, usedToday: 0);
    }
  }

  /// ¿Se puede empezar un dictado? Si sí, ya lo cuenta. Ante un error deja
  /// dictar: un fallo nuestro nunca bloquea.
  static Future<bool> tryStartDictation({DateTime? now}) async {
    final t = now ?? DateTime.now();
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      var start = p.getInt(trialStartKey) ?? 0;
      if (start <= 0) {
        start = t.millisecondsSinceEpoch;
        await p.setInt(trialStartKey, start);
      }
      if (p.getBool(unlockedKey) ?? false) return true;
      if (t.millisecondsSinceEpoch - start < trialDays * _dayMs) return true;
      final today = _day(t);
      final count = p.getString(dayKey) == today ? (p.getInt(dayCountKey) ?? 0) : 0;
      if (count >= freeDailyDictations) return false;
      await p.setString(dayKey, today);
      await p.setInt(dayCountKey, count + 1);
      return true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markUnlocked() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(unlockedKey, true);
    } catch (_) {}
  }
}

/// T15 · Compra de Orison Pro con Google Play (pago único `pro_lifetime`).
/// Escucha las compras desde el arranque (Play entrega también las
/// pendientes y las restauradas) y guarda el desbloqueo localmente, así el
/// teclado lo lee sin red.
class ProService {
  ProService._();
  static final ProService instance = ProService._();

  static const String productId = 'pro_lifetime';

  /// Fin del precio de lanzamiento (null = sin promoción). Lo fija el dueño
  /// cuando publique; la pantalla Pro muestra «hasta el …» mientras dure.
  static final DateTime? launchPriceUntil = null;

  final ValueNotifier<ProductDetails?> product = ValueNotifier(null);
  final ValueNotifier<bool> unlocked = ValueNotifier(false);
  final ValueNotifier<String?> lastError = ValueNotifier(null);
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    unlocked.value = (await ProGate.status()).unlocked;
    try {
      final iap = InAppPurchase.instance;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      if (!await iap.isAvailable()) return;
      final res = await iap.queryProductDetails({productId});
      if (res.productDetails.isNotEmpty) product.value = res.productDetails.first;
    } catch (_) {}
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId) continue;
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        await ProGate.markUnlocked();
        unlocked.value = true;
        lastError.value = null;
      } else if (p.status == PurchaseStatus.error) {
        lastError.value = 'error';
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  Future<bool> buy() async {
    final details = product.value;
    if (details == null) return false;
    try {
      return await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
    } catch (_) {
      return false;
    }
  }

  Future<void> restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _sub?.cancel();
  }
}
