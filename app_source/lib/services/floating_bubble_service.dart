import 'package:flutter/services.dart';

enum BubbleVisualState {
  idle,
  recording,
  transcribing;
}

class FloatingBubbleService {
  static const String channelName =
      'com.royleguiza.voicebubblestt/floating_bubble';

  final MethodChannel _channel;
  void Function()? onBubbleTap;
  void Function()? onBubbleClose;
  /// La ✕ nativa descarta el audio en curso: detener el recorder y borrar
  /// el temporal sin transcribir (el próximo mic inicia audio nuevo).
  void Function()? onBubbleCancel;

  FloatingBubbleService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBubbleTap':
        onBubbleTap?.call();
        break;
      case 'onBubbleClose':
        onBubbleClose?.call();
        break;
      case 'onBubbleCancel':
        onBubbleCancel?.call();
        break;
      default:
        break;
    }
  }

  /// Comprueba si la aplicación tiene permiso SYSTEM_ALERT_WINDOW (overlay).
  Future<bool> canDrawOverlays() async {
    try {
      final res = await _channel.invokeMethod<bool>('canDrawOverlays');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla de configuración del sistema para conceder el permiso de overlay.
  Future<bool> requestOverlayPermission() async {
    try {
      final res =
          await _channel.invokeMethod<bool>('requestOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Inicia el Foreground Service y muestra la burbuja flotante sobre la pantalla.
  Future<bool> startBubble() async {
    try {
      final res = await _channel.invokeMethod<bool>('startBubble');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Detiene el Foreground Service y elimina la burbuja flotante.
  Future<bool> stopBubble() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopBubble');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el servicio de la burbuja está actualmente en ejecución.
  Future<bool> isBubbleRunning() async {
    try {
      final res = await _channel.invokeMethod<bool>('isBubbleRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Actualiza el estado visual de la burbuja (idle, recording, transcribing).
  Future<bool> updateBubbleState(BubbleVisualState state) async {
    try {
      final res = await _channel.invokeMethod<bool>('updateBubbleState', {
        'state': state.name,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Notifica al servicio nativo para recargar la configuración visual de la pastilla flotante.
  Future<bool> reloadIslandConfig() async {
    try {
      final res = await _channel.invokeMethod<bool>('reloadIslandConfig');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Escribe una transcripción en el historial unificado nativo para que la
  /// modal de la isla la vea (misma fuente que el teclado).
  Future<bool> pushHistoryEntry(String text) async {
    try {
      final res = await _channel.invokeMethod<bool>('pushHistoryEntry', {
        'text': text,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Nivel real del mic (0..1) para la onda reactiva de la isla en grabación.
  Future<void> updateWaveformLevel(double level) async {
    try {
      await _channel.invokeMethod('updateWaveformLevel', {
        'level': level.clamp(0.0, 1.0),
      });
    } catch (_) {}
  }
}
