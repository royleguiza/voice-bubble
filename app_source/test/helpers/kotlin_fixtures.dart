import 'dart:convert';
import 'package:voice_bubble_stt/models/transcription.dart';

/// Forma EXACTA que produce org.json en el lado Kotlin.
String keyboardEntry(String text, DateTime timestamp) {
  return '{"text":"$text","timestamp":"${timestamp.toUtc().toIso8601String()}"}';
}

/// Replica la entrada que persiste el teclado nativo (K3): JSON plano con
/// timestamp UTC, convertido a Transcription para la app.
Transcription keyboardStyleTranscription(String text, int minuteOffset) {
  return Transcription.fromJson(
    jsonDecode(keyboardEntry(
      text,
      DateTime.parse('2026-08-23T10:00:00Z').add(Duration(minutes: minuteOffset)),
    )) as Map<String, dynamic>,
  );
}

/// Snapshot canónico de las 51 claves del contrato maestro (docs/contract-keys.txt).
/// Usado para verificar paridad triangular sin acoplarse al filesystem de disco en tests.
const Set<String> kContractKeysSnapshot = {
  'bubble_history_enabled',
  'kb_bottom_elevation_dp',
  'kb_clipboard_images_enabled',
  'kb_code_key_visible',
  'kb_credentials_key_visible',
  'kb_haptic_style',
  'kb_haptics_enabled',
  'kb_height_profile',
  'kb_invert_toolbar',
  'kb_key_spacing',
  'kb_language_key_visible',
  'kb_long_press_delay',
  'kb_long_press_symbols',
  'kb_mic_haptic_cancel',
  'kb_mic_haptic_paste',
  'kb_mic_haptic_recording',
  'kb_mic_haptic_start',
  'kb_mic_haptics_enabled',
  'kb_mic_sounds_enabled',
  'kb_mic_start_style',
  'kb_mic_stop_style',
  'kb_snippets_seeded',
  'kb_spacebar_alignment',
  'kb_spacebar_trackpad_mode',
  'kb_stt_api_key',
  'kb_stt_key_configured',
  'kb_stt_language',
  'kb_stt_model',
  'kb_stt_url',
  'kb_terminal_row_visible',
  'kb_trackpad_accel_curve',
  'kb_trackpad_auto_return',
  'kb_trackpad_button_layout',
  'kb_trackpad_enabled',
  'kb_trackpad_haptic',
  'kb_trackpad_pointer_style',
  'kb_trackpad_scroll_direction',
  'kb_trackpad_scroll_position',
  'kb_trackpad_secondary_click',
  'kb_trackpad_sensitivity',
  'kb_trackpad_tap_to_click',
  'kb_trackpad_toolbar_visible',
  'notes_deferred_queue_enabled',
  'transcriptions',
  'vb_cred_pass_v1',
  'vb_cred_show_user',
  'vb_credentials_v1',
  'voice_notes_pending_v1',
  'voice_notes_v1',
  'voice_snippets_v1',
  'widget_mic_position',
};
