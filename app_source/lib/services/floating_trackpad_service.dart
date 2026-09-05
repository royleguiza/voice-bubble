import 'package:flutter/services.dart';

import 'channel_guard.dart';

/// Servicio de comunicacion bidireccional con el servicio de Burbuja Flotante
/// de Trackpad y Puntero Virtual en Android.
///
/// Cableado real: `SettingsScreen._toggleTrackpadEnabled` arranca/detiene la
/// burbuja a través de este servicio (antes tenía cero importadores). La
/// config fina del trackpad (sensibilidad, layout…) sigue viajando por
/// `StorageService` prefs, que el teclado nativo lee con prefijo "flutter.".
class FloatingTrackpadService {
  static const String channelName =
      'com.royleguiza.voicebubblestt/floating_trackpad';

  static const String _mCanDrawOverlays = 'canDrawOverlays';
  static const String _mRequestOverlayPermission = 'requestOverlayPermission';
  static const String _mIsAccessibilityGranted = 'isAccessibilityGranted';
  static const String _mOpenAccessibilitySettings = 'openAccessibilitySettings';
  static const String _mOpenAppDetailsSettings = 'openAppDetailsSettings';
  static const String _mStartTrackpadBubble = 'startTrackpadBubble';
  static const String _mStopTrackpadBubble = 'stopTrackpadBubble';
  static const String _mIsTrackpadBubbleRunning = 'isTrackpadBubbleRunning';

  final MethodChannel _channel;

  FloatingTrackpadService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// Fachada fina sobre [invokeChannelBool] (se conserva el nombre para
  /// los llamadores y suites existentes).
  Future<bool> _invokeBool(String method,
          [Map<String, Object?>? args]) =>
      invokeChannelBool(_channel, 'FloatingTrackpadService', method, args);

  /// Comprueba si la aplicacion tiene permiso SYSTEM_ALERT_WINDOW (overlay).
  Future<bool> canDrawOverlays() => _invokeBool(_mCanDrawOverlays);

  /// Abre la pantalla del sistema para conceder el permiso de superposicion.
  Future<bool> requestOverlayPermission() =>
      _invokeBool(_mRequestOverlayPermission);

  /// Comprueba si el acceso de asistencia está activo y conectado.
  /// (Solo invoca el canal nativo histórico; en Dart no se declara ni usa
  /// ningún servicio del sistema — perfil anti-Play-Protect intacto.)
  Future<bool> isAccessibilityGranted() =>
      _invokeBool(_mIsAccessibilityGranted);

  /// Abre los Ajustes de Accesibilidad del sistema.
  Future<bool> openAccessibilitySettings() =>
      _invokeBool(_mOpenAccessibilitySettings);

  /// Abre la pantalla de Informacion de la App en Ajustes (para Ajustes Restringidos en Android 13/14+).
  Future<bool> openAppDetailsSettings() =>
      _invokeBool(_mOpenAppDetailsSettings);

  /// Inicia el servicio de la burbuja flotante del trackpad.
  Future<bool> startTrackpadBubble() => _invokeBool(_mStartTrackpadBubble);

  /// Detiene el servicio de la burbuja flotante del trackpad.
  Future<bool> stopTrackpadBubble() => _invokeBool(_mStopTrackpadBubble);

  /// Verifica si el servicio de la burbuja del trackpad esta actualmente activo.
  Future<bool> isTrackpadBubbleRunning() =>
      _invokeBool(_mIsTrackpadBubbleRunning);
}
