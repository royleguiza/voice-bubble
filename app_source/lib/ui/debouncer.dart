import 'dart:async';

import 'package:flutter/foundation.dart';

/// Contador release-safe de persists diferidos fallidos (SPK-25).
int _debouncerErrorCount = 0;
int get debouncerErrorCount => _debouncerErrorCount;

/// Debouncer reutilizable para controles continuos (sliders).
///
/// El thumb actualiza el estado local de inmediato (respuesta visual sin
/// lag) y la persistencia costosa (prefs + MethodChannel al nativo) se
/// difiere [delay] tras el último tick, cancelando los intermedios.
/// Sin esto, arrastrar un slider dispara decenas de escrituras + llamadas
/// al canal por segundo.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 150)});

  final Duration delay;
  Timer? _timer;

  /// Programa [action]; cancela la programación anterior pendiente.
  /// SPK-25: ya no traga en silencio; [onError] opcional + contador y
  /// debugPrint en debug. La UI sigue optimista (no relanza).
  void run(Future<void> Function() action, {void Function(Object e)? onError}) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(() async {
        try {
          await action();
        } catch (e) {
          _debouncerErrorCount++;
          debugPrint('Debouncer persist falló: $e');
          try {
            onError?.call(e);
          } catch (_) {}
        }
      }());
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
