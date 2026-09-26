import 'package:flutter/services.dart';
import 'channel_guard.dart';

class WidgetService {
  static const _channel = MethodChannel('com.royleguiza.voicebubblestt/widgets');

  /// Actualización de widgets en segundo plano (Nivel 2):
  /// Devuelve bool indicando si la plataforma respondió, y acumula
  /// cualquier fallo en [channelErrorCount] sin bloquear la UI del usuario.
  Future<bool> updateWidgets() async {
    final res = await invokeChannelResult(
      _channel,
      'WidgetService',
      'updateWidgets',
    );
    return res.ok;
  }

  Future<Map<String, String?>> getInitialAction() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInitialWidgetAction',
      );
      if (res == null) return {};
      return res.map((k, v) => MapEntry(k.toString(), v?.toString()));
    } catch (e) {
      recordBackgroundError('WidgetService.getInitialAction');
      return {};
    }
  }
}
