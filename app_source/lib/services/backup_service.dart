import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_info.dart';
import 'channel_guard.dart';

/// Resultado de exportar o importar la copia de seguridad (T1).
enum BackupStatus { saved, imported, cancelled, error }

/// Conteos y motivo que devuelve el lado nativo. Sin contenido: solo números.
class BackupResult {
  const BackupResult({
    required this.status,
    this.reason,
    this.notes = 0,
    this.notesUpdated = 0,
    this.notesSkipped = 0,
    this.audio = 0,
    this.history = 0,
    this.snippets = 0,
    this.snippetsSkipped = 0,
    this.clips = 0,
    this.settings = 0,
  });

  final BackupStatus status;

  /// `format`, `version`, `unavailable`, `too_big`, `io`, `busy`, `no_picker`.
  final String? reason;
  final int notes;
  final int notesUpdated;
  final int notesSkipped;
  final int audio;
  final int history;
  final int snippets;
  final int snippetsSkipped;
  final int clips;
  final int settings;

  factory BackupResult.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const BackupResult(status: BackupStatus.error, reason: 'io');
    }
    int n(String key) {
      final v = map[key];
      return v is int ? v : 0;
    }

    final status = switch (map['status']) {
      'saved' => BackupStatus.saved,
      'imported' => BackupStatus.imported,
      'cancelled' => BackupStatus.cancelled,
      _ => BackupStatus.error,
    };
    final reason = map['reason'];
    return BackupResult(
      status: status,
      reason: reason is String ? reason : null,
      notes: n('notes'),
      notesUpdated: n('notesUpdated'),
      notesSkipped: n('notesSkipped'),
      audio: n('audio'),
      history: n('history'),
      snippets: n('snippets'),
      snippetsSkipped: n('snippetsSkipped'),
      clips: n('clips'),
      settings: n('settings'),
    );
  }
}

/// Copia de seguridad (T1): el `.zip` lo arma y lo lee Kotlin
/// (`BackupManager.kt`) con los mismos almacenes y candados que el teclado
/// y el widget; acá solo se abre el selector de archivos y se recargan las
/// preferencias. Nunca incluye claves de API ni credenciales.
class BackupService {
  BackupService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'com.royleguiza.voicebubblestt/backup';
  static const String appVersion = AppInfo.version;

  final MethodChannel _channel;

  /// Nombre sugerido: `orison-copia-AAAA-MM-DD.zip`.
  static String suggestedFileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'orison-copia-${now.year}-${two(now.month)}-${two(now.day)}.zip';
  }

  Future<BackupResult> export({DateTime? now}) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'export',
        {
          'fileName': suggestedFileName(now ?? DateTime.now()),
          'appVersion': appVersion,
        },
      );
      return BackupResult.fromMap(res);
    } catch (_) {
      recordBackgroundError('BackupService.export');
      return const BackupResult(status: BackupStatus.error, reason: 'io');
    }
  }

  Future<BackupResult> import() async {
    try {
      final res =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('import');
      final result = BackupResult.fromMap(res);
      if (result.status == BackupStatus.imported) {
        // Kotlin escribió las preferencias: la caché de Dart quedó vieja.
        try {
          await (await SharedPreferences.getInstance()).reload();
        } catch (_) {}
      }
      return result;
    } catch (_) {
      recordBackgroundError('BackupService.import');
      return const BackupResult(status: BackupStatus.error, reason: 'io');
    }
  }
}
