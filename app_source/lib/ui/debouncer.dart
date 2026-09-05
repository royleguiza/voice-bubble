import 'dart:async';

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
  /// Los errores de [action] se tragan: un persist diferido jamás debe
  /// tumbar la pantalla con pantalla roja.
  void run(Future<void> Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(() async {
        try {
          await action();
        } catch (_) {}
      }());
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
