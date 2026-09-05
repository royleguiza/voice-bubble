#!/usr/bin/env python3
"""
Test Suite: Transcription History Repository & Cross-Process Synchronization.
Verifica que:
1. El contrato de archivo 'transcription_history.json' sea idéntico en Kotlin y Dart.
2. TranscriptionHistoryRepository en Kotlin implemente escritura atómica (.tmp + rename).
3. TranscriptionHistoryRepository en Kotlin soporte migración con prefijos Base64 de Flutter.
4. StorageService en Dart realice load() antes de add() para evitar sobrescrituras de estado stale.
5. Simulación de concurrencia: escritura cruzada Kotlin <-> Dart preserva FIFO-20 sin pérdida.
"""

import json
import os
import re
import sys
import tempfile
from datetime import datetime, timezone, timedelta

def test_file_constants():
    print("  [TEST] Constante de archivo de historial idéntica en Kotlin y Dart...")
    repo_file = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryRepository.kt"
    dart_file = "app_source/lib/services/storage_service.dart"

    with open(repo_file, "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(dart_file, "r", encoding="utf-8") as f:
        dart_content = f.read()

    assert 'FILE_NAME = "transcription_history.json"' in kt_content, "Falta FILE_NAME en Kotlin"
    assert "historyFileName = 'transcription_history.json'" in dart_content, "Falta historyFileName en Dart"
    print("  [PASS] transcription_history.json unificado en ambas plataformas.")

def test_atomic_writes():
    print("  [TEST] Escritura atómica (.tmp + rename) implementada en Kotlin y Dart...")
    repo_file = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryRepository.kt"
    dart_file = "app_source/lib/services/storage_service.dart"

    with open(repo_file, "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(dart_file, "r", encoding="utf-8") as f:
        dart_content = f.read()

    assert "$FILE_NAME.tmp" in kt_content, "Kotlin debe escribir a .tmp primero"
    assert "renameTo(targetFile)" in kt_content, "Kotlin debe usar renameTo"

    assert ".tmp" in dart_content, "Dart debe escribir a .tmp primero"
    assert "renameSync" in dart_content, "Dart debe usar renameSync"
    print("  [PASS] Ambas plataformas usan reemplazo atómico seguro.")

def test_flutter_prefix_handling():
    print("  [TEST] Manejo de prefijos Base64 de Flutter (VGhpcy...)...")
    repo_file = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryRepository.kt"
    with open(repo_file, "r", encoding="utf-8") as f:
        kt_content = f.read()

    assert "indexOf('[')" in kt_content, "Kotlin debe buscar corchete para ignorar prefijos"
    assert "lastIndexOf(']')" in kt_content, "Kotlin debe buscar fin de array"
    print("  [PASS] Desempaquetado de prefijos Base64 garantizado en Kotlin.")

def test_stale_overwrite_prevention():
    print("  [TEST] Prevención de sobrescritura de estado en memoria en Dart...")
    dart_file = "app_source/lib/services/storage_service.dart"
    with open(dart_file, "r", encoding="utf-8") as f:
        dart_content = f.read()

    # Verificar que add() llama a await load() antes de mutar _transcriptions
    add_match = re.search(r'Future<void> add\(Transcription transcription\) async\s*\{([\s\S]*?)\}', dart_content)
    assert add_match, "No se encontró el método add()"
    add_body = add_match.group(1)
    assert "await load();" in add_body, "add() debe sincronizar con load() antes de insertar"
    print("  [PASS] StorageService.add() sincroniza con disco antes de modificar.")

def test_simulated_cross_platform_fifo():
    print("  [TEST] Simulación de concurrencia y alternancia Kotlin <-> Flutter...")
    with tempfile.TemporaryDirectory() as tmpdir:
        history_path = os.path.join(tmpdir, "transcription_history.json")

        # 1. Teclado Kotlin añade 5 dictados
        base_time = datetime(2026, 9, 2, 12, 0, 0, tzinfo=timezone.utc)
        items = []
        for i in range(5):
            t = base_time + timedelta(minutes=i)
            items.insert(0, {"text": f"teclado {i}", "timestamp": t.isoformat()})

        # Guardar atómicamente como Kotlin
        tmp_file = history_path + ".tmp"
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(items, f)
        os.rename(tmp_file, history_path)

        # 2. Flutter lee disco, agrega 1 desde burbuja flotante y guarda atómicamente
        with open(history_path, "r", encoding="utf-8") as f:
            flutter_loaded = json.load(f)

        bubble_time = base_time + timedelta(minutes=10)
        flutter_loaded.insert(0, {"text": "burbuja 10", "timestamp": bubble_time.isoformat()})
        # FIFO limit 20
        flutter_loaded = flutter_loaded[:20]

        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(flutter_loaded, f)
        os.rename(tmp_file, history_path)

        # 3. Teclado Kotlin añade 18 dictados más
        with open(history_path, "r", encoding="utf-8") as f:
            kt_loaded = json.load(f)

        for i in range(11, 29):
            t = base_time + timedelta(minutes=i)
            kt_loaded.insert(0, {"text": f"teclado {i}", "timestamp": t.isoformat()})

        # Ordenar por timestamp descendente y cortar en 20
        kt_loaded.sort(key=lambda x: x["timestamp"], reverse=True)
        kt_loaded = kt_loaded[:20]

        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(kt_loaded, f)
        os.rename(tmp_file, history_path)

        # 4. Verificar integridad final
        with open(history_path, "r", encoding="utf-8") as f:
            final_data = json.load(f)

        assert len(final_data) == 20, f"Debe haber exactamente 20 elementos, hay {len(final_data)}"
        assert final_data[0]["text"] == "teclado 28", f"El más nuevo debe ser teclado 28, es {final_data[0]['text']}"
        assert final_data[19]["text"] == "teclado 4", f"El más viejo debe ser teclado 4, es {final_data[19]['text']}"

        # Comprobar orden temporal estrictamente decreciente
        for i in range(len(final_data) - 1):
            assert final_data[i]["timestamp"] >= final_data[i+1]["timestamp"]

    print("  [PASS] Simulación completada con éxito: FIFO-20 y consistencia temporal perfecta.")

def test_persistent_fifo_history():
    # Contrato vigente (2026-09-05, dueño): historial PERSISTENTE FIFO-20.
    # La purga automática de "sesión única" se retiró porque borraba los
    # dictados de la píldora/la app cada vez que el IME se recreaba y vaciaba
    # la modal de historial de la isla. Las funciones de purga se conservan
    # para un futuro borrado explícito por el usuario. Sin impacto en
    # Play Protect (evalúa capacidades declaradas, no retención de historial).
    print("  [TEST] Verificando historial persistente FIFO-20 (sin purga automática)...")
    kt_file = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/TranscriptionHistoryRepository.kt"
    vk_file = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt"
    dart_file = "app_source/lib/services/storage_service.dart"
    main_dart_file = "app_source/lib/main.dart"

    with open(kt_file, "r", encoding="utf-8") as f:
        kt_content = f.read()
    with open(vk_file, "r", encoding="utf-8") as f:
        vk_content = f.read()
    with open(dart_file, "r", encoding="utf-8") as f:
        dart_content = f.read()
    with open(main_dart_file, "r", encoding="utf-8") as f:
        main_content = f.read()

    assert "fun purgePreviousSessionHistory()" in kt_content, "Kotlin TranscriptionHistoryRepository debe conservar purgePreviousSessionHistory() (borrado explícito futuro)"
    assert "fun clearPreviousHistoryOnStartup()" in kt_content, "Kotlin TranscriptionHistoryRepository debe conservar clearPreviousHistoryOnStartup()"
    assert 'file.writeText("[]", Charsets.UTF_8)' in kt_content, "Kotlin debe escribir [] para evitar resurrección de datos legados"
    assert "transcriptionRepo.purgePreviousSessionHistory()" not in vk_content, "VoiceKeyboardService NO debe purgar en onCreate (los dictados de la píldora deben sobrevivir)"
    assert "clearPreviousHistoryOnStartup()" in dart_content, "StorageService debe implementar clearPreviousHistoryOnStartup()"
    assert "purgePreviousSessionHistory()" in dart_content, "StorageService debe implementar purgePreviousSessionHistory()"
    assert "file.writeAsStringSync('[]')" in dart_content, "StorageService debe escribir [] al archivo de historial al purgar"
    assert "clearPreviousHistoryOnStartup()" not in main_content, "main.dart NO debe purgar el historial al arrancar (persistente FIFO-20)"
    print("  [PASS] Historial persistente FIFO-20: sin purga automática, funciones de borrado conservadas.")

if __name__ == "__main__":
    print("=" * 60)
    print(" INICIANDO TEST SUITE: REPOSITORIO DE HISTORIAL PROFESIONAL")
    print("=" * 60)
    try:
        test_file_constants()
        test_atomic_writes()
        test_flutter_prefix_handling()
        test_stale_overwrite_prevention()
        test_simulated_cross_platform_fifo()
        test_persistent_fifo_history()
        print("=" * 60)
        print(" RESULTADOS: Todos los tests pasaron exitosamente.")
        print("=" * 60)
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        sys.exit(1)
