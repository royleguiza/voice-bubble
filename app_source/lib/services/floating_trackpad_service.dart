import 'package:flutter/services.dart';

import 'channel_guard.dart';

/// Canal con el trackpad flotante y el complemento VoiceBubble Puntero.
///
/// El trackpad se abre desde la barra flotante (herramienta Puntero); desde
/// acá Ajustes consulta el estado del complemento y abre sus pantallas del
/// sistema. La config fina del trackpad (sensibilidad, layout…) viaja por
/// `StorageService` prefs, que el nativo lee con prefijo "flutter.".
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
  static const String _mGetPointerStatus = 'getPointerStatus';
  static const String _mOpenCompanionDetails = 'openCompanionDetails';

  /// Estados del complemento VoiceBubble Puntero (ver PointerProtocol.kt).
  static const String pointerMissing = 'missing';
  static const String pointerDisabled = 'disabled';
  static const String pointerReady = 'ready';
  static const List<String> pointerStatuses = [
    pointerMissing,
    pointerDisabled,
    pointerReady,
  ];

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

  /// true si el complemento VoiceBubble Puntero está instalado y activo.
  /// (VoiceBubble no declara Accesibilidad: perfil anti-Play-Protect intacto;
  /// los clics los hace el complemento.)
  Future<bool> isAccessibilityGranted() =>
      _invokeBool(_mIsAccessibilityGranted);

  /// Estado del complemento: [pointerMissing], [pointerDisabled] o
  /// [pointerReady]. Ante cualquier fallo de canal devuelve [pointerMissing].
  Future<String> getPointerStatus() async {
    try {
      final value = await _channel.invokeMethod<String>(_mGetPointerStatus);
      return pointerStatuses.contains(value) ? value! : pointerMissing;
    } catch (_) {
      recordBackgroundError('FloatingTrackpadService.getPointerStatus');
      return pointerMissing;
    }
  }

  /// Información de la app del complemento ("Permitir ajustes restringidos").
  Future<bool> openCompanionDetails() => _invokeBool(_mOpenCompanionDetails);

  /// Abre los Ajustes de Accesibilidad del sistema.
  Future<bool> openAccessibilitySettings() =>
      _invokeBool(_mOpenAccessibilitySettings);

  /// Abre la pantalla de Informacion de la App en Ajustes (para Ajustes Restringidos en Android 13/14+).
  Future<bool> openAppDetailsSettings() =>
      _invokeBool(_mOpenAppDetailsSettings);

  /// Abre el panel del trackpad (normalmente lo abre la barra flotante).
  Future<bool> startTrackpadBubble() => _invokeBool(_mStartTrackpadBubble);

  /// Cierra el panel del trackpad.
  Future<bool> stopTrackpadBubble() => _invokeBool(_mStopTrackpadBubble);

  /// Verifica si el servicio de la burbuja del trackpad esta actualmente activo.
  Future<bool> isTrackpadBubbleRunning() =>
      _invokeBool(_mIsTrackpadBubbleRunning);
}
