import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Idioma vivo de la app (etapa 4). `null` = el del teléfono. Vive aquí,
/// como `appThemeMode`, para evitar el import circular main → settings.
final ValueNotifier<Locale?> appLocale = ValueNotifier<Locale?>(null);

/// `sistema` → null; `es`/`en`/`pt` → su Locale.
Locale? localeFromStorage(String raw) {
  switch (raw) {
    case 'es':
    case 'en':
    case 'pt':
      return Locale(raw);
    default:
      return null;
  }
}

/// Puente con Android para el «idioma por app» (Android 13+: lo guarda el
/// sistema y también se cambia desde Ajustes del sistema › Apps › Idioma).
/// En 9–12 el lado nativo solo confirma: la fuente es `kb_app_locale`.
class AppLocaleChannel {
  static const MethodChannel _channel =
      MethodChannel('com.royleguiza.voicebubblestt/locale');

  /// Pide a Android aplicar [code] (`sistema`, `es`, `en`, `pt`).
  static Future<void> apply(String code) async {
    try {
      await _channel.invokeMethod<void>('setAppLocale', {'tag': code});
    } on MissingPluginException {
      // Tests o plataforma sin el canal: solo cambia la app Flutter.
    } on PlatformException {
      // Sin LocaleManager: la preferencia del puente alcanza.
    }
  }

  /// Idioma que Android tiene guardado para la app (Android 13+), o null
  /// si no hay canal o es anterior a 13. `sistema` si sigue al teléfono.
  static Future<String?> current() async {
    try {
      return await _channel.invokeMethod<String>('getAppLocale');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
