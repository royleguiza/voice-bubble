import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transcription.dart';

/**
 * HistoryRepository - Repositorio modular de historial de transcripciones (C-25).
 * Extraído de StorageService para desacoplar el god-object de persistencia.
 */
class HistoryRepository {
  static const String key = 'transcriptions';
  static const String historyFileName = 'voice_notes.json';
  static const String historyLockFileName = 'voice_notes.lock';
  static const int maxItems = 20;
  static const String historyTmpSuffix = '.tmp';

  static int _historyTempCounter = 0;

  Future<SharedPreferences> _prefs() async =>
      await SharedPreferences.getInstance();

  Future<File> getHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$historyFileName');
  }

  Future<File> getHistoryLockFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$historyLockFileName');
  }

  static bool publishAtomically(File file, String contents) {
    File? tmpFile;
    try {
      final token = '${pid}_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}_${_historyTempCounter++}';
      tmpFile = File('${file.path}.${token}$historyTmpSuffix');
      tmpFile.writeAsStringSync(contents, flush: true);
      if (!tmpFile.existsSync()) return false;
      tmpFile.renameSync(file.path);
      return true;
    } catch (_) {
      try {
        if (tmpFile != null && tmpFile.existsSync()) {
          tmpFile.deleteSync();
        }
      } catch (_) {}
      return false;
    }
  }
}
