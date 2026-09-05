import 'package:flutter/foundation.dart';
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
  static const String _mReloadIslandConfig = 'reloadIslandConfig';
  static const String _mPushHistoryEntry = 'pushHistoryEntry';
  static const String _mUpdateWaveformLevel = 'updateWaveformLevel';

  // Nivel de onda del mic: rango válido 0..1.
  static const double minWaveformLevel = 0.0;
  static const double maxWaveformLevel = 1.0;

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

  /// Notifica al servicio nativo para recargar la configuración visual de la pastilla flotante.
  Future<bool> reloadIslandConfig() => _invokeBool(_mReloadIslandConfig);

  /// Escribe una transcripción en el historial unificado nativo para que la
  /// modal de la isla la vea (misma fuente que el teclado).
  Future<bool> pushHistoryEntry(String text) =>
      _invokeBool(_mPushHistoryEntry, {'text': text});

  /// Nivel real del mic (0..1) para la onda reactiva de la isla en grabación.
  Future<void> updateWaveformLevel(double level) async {
    try {
      await _channel.invokeMethod(_mUpdateWaveformLevel, {
        'level': level.clamp(minWaveformLevel, maxWaveformLevel),
      });
    } on PlatformException catch (e) {
      if (isPermissionDeniedCode(e.code)) {
        debugPrint(
            'FloatingBubbleService.updateWaveformLevel: permiso denegado (${e.code})');
      } else {
        debugPrint(
            'FloatingBubbleService.updateWaveformLevel: PlatformException (${e.code}): ${e.message}');
      }
    } on MissingPluginException catch (e) {
      debugPrint(
          'FloatingBubbleService.updateWaveformLevel: canal no disponible: $e');
    } catch (e) {
      debugPrint(
          'FloatingBubbleService.updateWaveformLevel: error inesperado: $e');
    }
  }
}
