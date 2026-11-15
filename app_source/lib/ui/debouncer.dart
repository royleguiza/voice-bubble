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

/// Limitador para controles continuos que deben verse EN VIVO (la isla de
/// Ajustes): a diferencia de [Debouncer] —que espera a que el dedo pare—,
/// ejecuta enseguida y, mientras siga llegando gente, como mucho una vez
/// cada [interval] y siempre con la ÚLTIMA acción. Nunca corren dos acciones
/// a la vez (la siguiente espera a que termine la anterior, así el guardado
/// y el aviso al nativo salen en orden). [flush] deja pasar ya lo pendiente
/// (al soltar el deslizador) y espera a que todo termine.
class Throttler {
  Throttler({this.interval = const Duration(milliseconds: 60)});

  final Duration interval;
  Timer? _timer;
  Future<void> Function()? _pending;
  Future<void> _current = Future<void>.value();
  bool _inFlight = false;
  bool _disposed = false;

  /// Hay una acción corriendo o esperando su turno.
  bool get isBusy => _inFlight || _pending != null;

  /// Pide ejecutar [action]; si ya hay una corriendo o el intervalo no pasó,
  /// queda como la única pendiente (reemplaza a la anterior).
  void run(Future<void> Function() action) {
    if (_disposed) return;
    _pending = action;
    if (_timer != null || _inFlight) return;
    _fire();
  }

  void _fire() {
    final action = _pending;
    if (action == null || _disposed) return;
    _pending = null;
    _inFlight = true;
    _timer = Timer(interval, () {
      _timer = null;
      if (_pending != null && !_inFlight) _fire();
    });
    _current = () async {
      try {
        await action();
      } catch (e) {
        _debouncerErrorCount++;
        debugPrint('Throttler falló: $e');
      } finally {
        _inFlight = false;
        if (_timer == null && _pending != null) _fire();
      }
    }();
  }

  /// Ejecuta ya lo pendiente (sin esperar el intervalo) y espera a que no
  /// quede nada corriendo. No deja temporizadores vivos.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_pending != null && !_inFlight) _fire();
    while (_inFlight && !_disposed) {
      await _current;
    }
    _timer?.cancel();
    _timer = null;
  }

  /// Suelta el temporizador y descarta lo pendiente.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
