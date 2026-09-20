import 'package:flutter/services.dart';

class WidgetService {
  static const _channel = MethodChannel('com.royleguiza.voicebubblestt/widgets');

  Future<void> updateWidgets() async {
    try {
      await _channel.invokeMethod('updateWidgets');
    } catch (_) {}
  }

  Future<Map<String, String?>> getInitialAction() async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInitialWidgetAction',
      );
      if (res == null) return {};
      return res.map((k, v) => MapEntry(k.toString(), v?.toString()));
    } catch (_) {
      return {};
    }
  }
}
