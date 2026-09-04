import 'package:flutter/services.dart';

/// Servicio de comunicacion bidireccional con el servicio de Burbuja Flotante
/// de Trackpad y Puntero Virtual en Android.
class FloatingTrackpadService {
  static const String channelName =
      'com.royleguiza.voicebubblestt/floating_trackpad';

  final MethodChannel _channel;

  FloatingTrackpadService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// Comprueba si la aplicacion tiene permiso SYSTEM_ALERT_WINDOW (overlay).
  Future<bool> canDrawOverlays() async {
    try {
      final res = await _channel.invokeMethod<bool>('canDrawOverlays');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla del sistema para conceder el permiso de superposicion.
  Future<bool> requestOverlayPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Comprueba si VoiceBubbleAccessibilityService esta activo y conectado.
  Future<bool> isAccessibilityGranted() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAccessibilityGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre los Ajustes de Accesibilidad del sistema.
  Future<bool> openAccessibilitySettings() async {
    try {
      final res =
          await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla de Informacion de la App en Ajustes (para Ajustes Restringidos en Android 13/14+).
  Future<bool> openAppDetailsSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAppDetailsSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Inicia el servicio de la burbuja flotante del trackpad.
  Future<bool> startTrackpadBubble() async {
    try {
      final res = await _channel.invokeMethod<bool>('startTrackpadBubble');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Detiene el servicio de la burbuja flotante del trackpad.
  Future<bool> stopTrackpadBubble() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopTrackpadBubble');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el servicio de la burbuja del trackpad esta actualmente activo.
  Future<bool> isTrackpadBubbleRunning() async {
    try {
      final res =
          await _channel.invokeMethod<bool>('isTrackpadBubbleRunning');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
