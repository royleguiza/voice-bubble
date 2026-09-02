import 'package:flutter/services.dart';

enum BubbleVisualState {
  idle,
  recording,
  transcribing;
}

class FloatingBubbleService {
  static const String channelName =
      'com.royleguiza.voicebubblestt/floating_bubble';

  static void Function()? _sharedOnBubbleTap;
  static void Function()? _sharedOnBubbleClose;

  final MethodChannel _channel;

  void Function()? get onBubbleTap => _sharedOnBubbleTap;
  set onBubbleTap(void Function()? callback) => _sharedOnBubbleTap = callback;

  void Function()? get onBubbleClose => _sharedOnBubbleClose;
  set onBubbleClose(void Function()? callback) =>
      _sharedOnBubbleClose = callback;

  FloatingBubbleService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBubbleTap':
        _sharedOnBubbleTap?.call();
        break;
      case 'onBubbleClose':
        _sharedOnBubbleClose?.call();
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
}
