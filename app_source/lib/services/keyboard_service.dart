import 'package:flutter/services.dart';

/// Acceso al estado y configuracion del teclado del sistema VoiceBubble.
/// Espeja los metodos nativos registrados en MainActivity (canal /keyboard).
class KeyboardService {
  static const String channelName =
      'com.royleguiza.voicebubblestt/keyboard';

  final MethodChannel _channel;

  KeyboardService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// true si el teclado aparece habilitado en "Administrar teclados".
  Future<bool> isKeyboardEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isKeyboardEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// true si el teclado es el metodo de entrada seleccionado del sistema.
  Future<bool> isKeyboardSelected() async {
    try {
      return await _channel.invokeMethod<bool>('isKeyboardSelected') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre la pantalla del sistema con la lista de teclados instalados.
  Future<bool> openKeyboardSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openKeyboardSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Abre el diálogo modal del sistema para seleccionar el método de entrada activo.
  Future<bool> showInputMethodPicker() async {
    try {
      return await _channel.invokeMethod<bool>('showInputMethodPicker') ??
          false;
    } catch (_) {
      return false;
    }
  }
}
