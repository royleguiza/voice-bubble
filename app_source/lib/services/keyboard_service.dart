import 'package:flutter/services.dart';

import 'channel_guard.dart';

/// Acceso al estado y configuracion del teclado del sistema VoiceBubble.
/// Espeja los metodos nativos registrados en MainActivity (canal /keyboard).
class KeyboardService {
  static const String channelName =
      'com.royleguiza.voicebubblestt/keyboard';

  static const String _mIsKeyboardEnabled = 'isKeyboardEnabled';
  static const String _mIsKeyboardSelected = 'isKeyboardSelected';
  static const String _mOpenKeyboardSettings = 'openKeyboardSettings';
  static const String _mShowInputMethodPicker = 'showInputMethodPicker';
  static const String _mCommitText = 'commitText';

  final MethodChannel _channel;

  KeyboardService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  /// Fachada fina sobre [invokeChannelBool] (se conserva el nombre para
  /// los llamadores y suites existentes).
  Future<bool> _invokeBool(String method,
          [Map<String, Object?>? args]) =>
      invokeChannelBool(_channel, 'KeyboardService', method, args);

  /// true si el teclado aparece habilitado en "Administrar teclados".
  Future<bool> isKeyboardEnabled() => _invokeBool(_mIsKeyboardEnabled);

  /// true si el teclado es el metodo de entrada seleccionado del sistema.
  Future<bool> isKeyboardSelected() => _invokeBool(_mIsKeyboardSelected);

  /// Abre la pantalla del sistema con la lista de teclados instalados.
  Future<bool> openKeyboardSettings() => _invokeBool(_mOpenKeyboardSettings);

  /// Abre el diálogo modal del sistema para seleccionar el método de entrada activo.
  Future<bool> showInputMethodPicker() =>
      _invokeBool(_mShowInputMethodPicker);

  /// Intenta pegar [text] en el cursor si el teclado propio está activo.
  /// false con otro teclado (ahí solo queda el portapapeles).
  Future<bool> commitText(String text) =>
      _invokeBool(_mCommitText, {'text': text});
}
