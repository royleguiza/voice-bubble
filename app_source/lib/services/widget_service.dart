import 'package:flutter/services.dart';

class WidgetService {
  static const _channel = MethodChannel('com.royleguiza.voicebubblestt/widgets');

  Future<void> updateWidgets() async {
    try {
      await _channel.invokeMethod('updateWidgets');
    } catch (_) {}
  }
}
