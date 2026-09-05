import 'package:flutter/services.dart';

import 'channel_guard.dart';

enum BubbleVisualState {
  idle,
  recording,
  transcribing;
}

class FloatingBubbleService {
  static const String channelName =
      'com.royleguiza.voicebubblestt/floating_bubble';

  // Nombres de método del canal (sin literales sueltos en cada call).
  static const String _mCanDrawOverlays = 'canDrawOverlays';
  static const String _mRequestOverlayPermission = 'requestOverlayPermission';
  static const String _mStartBubble = 'startBubble';
  static const String _mStopBubble = 'stopBubble';
  static const String _mIsBubbleRunning = 'isBubbleRunning';
  static const String _mUpdateBubbleState = 'updateBubbleState';
  static const String _mPushHistoryEntry = 'pushHistoryEntry';

  final MethodChannel _channel;
  void Function()? onBubbleTap;
  void Function()? onBubbleClose;

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
      default:
        break;
    }
  }

  /// Invoca un método que devuelve bool, distinguiendo permiso-denegado
  /// (esperable sin overlay) de error real. Siempre devuelve valor seguro.
  /// (Fachada fina sobre [invokeChannelBool]; se conserva el nombre para
  /// los llamadores y suites existentes.)
  Future<bool> _invokeBool(String method,
          [Map<String, Object?>? args]) =>
      invokeChannelBool(_channel, 'FloatingBubbleService', method, args);

  /// Comprueba si la aplicación tiene permiso SYSTEM_ALERT_WINDOW (overlay).
  Future<bool> canDrawOverlays() => _invokeBool(_mCanDrawOverlays);

  /// Abre la pantalla de configuración del sistema para conceder el permiso de overlay.
  Future<bool> requestOverlayPermission() =>
      _invokeBool(_mRequestOverlayPermission);

  /// Inicia el Foreground Service y muestra la burbuja flotante sobre la pantalla.
  Future<bool> startBubble() => _invokeBool(_mStartBubble);

  /// Detiene el Foreground Service y elimina la burbuja flotante.
  Future<bool> stopBubble() => _invokeBool(_mStopBubble);

  /// Verifica si el servicio de la burbuja está actualmente en ejecución.
  Future<bool> isBubbleRunning() => _invokeBool(_mIsBubbleRunning);

  /// Actualiza el estado visual de la burbuja (idle, recording, transcribing).
  Future<bool> updateBubbleState(BubbleVisualState state) =>
      _invokeBool(_mUpdateBubbleState, {'state': state.name});

  /// Escribe una transcripción en el historial unificado nativo para que la
  /// modal de historial de la burbuja la vea (misma fuente que el teclado).
  Future<bool> pushHistoryEntry(String text) =>
      _invokeBool(_mPushHistoryEntry, {'text': text});
}
