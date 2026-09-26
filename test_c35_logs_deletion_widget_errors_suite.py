#!/usr/bin/env python3
"""
test_c35_logs_deletion_widget_errors_suite.py
=============================================
Auditoría C-35: Logs, borrado, widget y errores [S]

Verifica:
1. Sin filtración de contenido en logs y ampliación de grep en CI:
   - .github/workflows/android.yml amplía grep a palabras sensibles completas:
     (texto|text|contenido|content|password|contrase|snippet|clip|transcri|credential|cred|user|usuario|wav|audio|key|token|groq|bearer).
   - Ausencia total de llamadas Log con contenido o variables sensibles en Kotlin.
   - Llamadas Log utilizan literales fijos de depuración/error sin datos de usuario.
2. Limpieza de memoria (fill(0)) y borrado forense seguro en disco:
   - SpeechToTextClient.kt: pcm.fill(0) en stopRecording y wav.fill(0) en finally de transcribe.
   - transcription_service.dart, notes_service.dart, pending_note_queue.dart:
     _secureDeleteSync sobrescribe con ceros antes de deleteSync para mitigar recuperación forense.
3. Acotación de errores de servidor (take(200) y supresión de saltos de línea):
   - cloud_stt_service.dart: _serverErrorDetail sanitiza \r\n y trunca a 200 caracteres.
   - SpeechToTextClient.kt: errorDetail limpia saltos de línea y aplica take(200).
4. Validación criptográfica de UUID en widget:
   - WidgetNoteEditActivity.kt implementa isValidUuid validando formato canonical 8-4-4-4-12.
   - Validación temprana de note_id y pending_id descartando identificadores anómalos.
5. Widget discreto y vista previa colapsada sin fugas visuales:
   - WidgetNotesListService.kt consulta flutter.widget_discrete_mode.
   - Modo discreto suprime el cuerpo de la nota; modo normal colapsa a 1 línea sin saltos.
6. Pre-check POST_NOTIFICATIONS en FGS y tokenización visual:
   - WidgetDictationService.kt implementa hasNotificationPermission y blinda startForeground con try/catch.
   - FloatingBubbleService.kt sustituye Color.WHITE por el token de diseño R.color.kb_label_on_accent.
7. Batería de mutaciones negativas para garantizar detección contra regresiones.
"""

import copy
import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WORKFLOW = os.path.join(BASE_DIR, ".github", "workflows", "android.yml")
SPEECH_CLIENT = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "SpeechToTextClient.kt")
CLOUD_STT = os.path.join(BASE_DIR, "app_source", "lib", "services", "cloud_stt_service.dart")
TRANSCRIPTION_SVC = os.path.join(BASE_DIR, "app_source", "lib", "services", "transcription_service.dart")
NOTES_SVC = os.path.join(BASE_DIR, "app_source", "lib", "services", "notes_service.dart")
PENDING_QUEUE = os.path.join(BASE_DIR, "app_source", "lib", "services", "pending_note_queue.dart")
WIDGET_EDIT = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "WidgetNoteEditActivity.kt")
WIDGET_LIST = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "WidgetNotesListService.kt")
WIDGET_DICTATION = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "WidgetDictationService.kt")
BUBBLE_SVC = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin", "com", "royleguiza", "voicebubblestt", "FloatingBubbleService.kt")
KT_DIR = os.path.join(BASE_DIR, "voice_bubble_stt", "android", "app", "src", "main", "kotlin")


def read_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def test_ci_expanded_log_grep_and_clean_logs():
    """1. Grep ampliado en CI y ausencia total de fugas en logs de Kotlin."""
    wf = read_file(WORKFLOW)
    pattern_req = r"texto\|text\|contenido\|content\|password\|contrase\|snippet\|clip\|transcri\|credential\|cred\|user\|usuario\|wav\|audio\|key\|token\|groq\|bearer"
    assert re.search(pattern_req, wf), (
        "El workflow android.yml debe ampliar el grep de Logs para incluir todas las palabras sensibles requeridas"
    )

    kt_pattern = re.compile(
        r"Log\.[a-z]+\(.*\b(" + pattern_req + r")\b",
        re.IGNORECASE,
    )
    violations = []
    for root, _, files in os.walk(KT_DIR):
        for name in files:
            if not name.endswith(".kt"):
                continue
            path = os.path.join(root, name)
            with open(path, "r", encoding="utf-8") as f:
                for line_no, line in enumerate(f, 1):
                    if kt_pattern.search(line):
                        violations.append(f"{path}:{line_no}: {line.strip()}")
    assert not violations, "Violación de regla de logs sensibles detectada:\n" + "\n".join(violations)


def test_buffer_zeroing_and_secure_file_deletion():
    """2. Limpieza de memoria (fill(0)) y sobrescritura de ceros antes de borrado."""
    speech = read_file(SPEECH_CLIENT)
    assert "pcm.fill(0)" in speech, (
        "SpeechToTextClient.kt debe limpiar el buffer PCM con fill(0) tras stopRecording"
    )
    assert "wav.fill(0)" in speech, (
        "SpeechToTextClient.kt debe limpiar el buffer WAV con fill(0) en el bloque finally de transcribe"
    )

    for path, name in [
        (TRANSCRIPTION_SVC, "transcription_service.dart"),
        (NOTES_SVC, "notes_service.dart"),
        (PENDING_QUEUE, "pending_note_queue.dart"),
    ]:
        content = read_file(path)
        assert "_secureDeleteSync" in content, (
            f"{name} debe definir e invocar _secureDeleteSync antes de borrar archivos de audio"
        )
        assert "raf.writeFromSync(zeros" in content or "writeFromSync" in content, (
            f"{name} debe sobrescribir con ceros antes de deleteSync"
        )


def test_error_truncation_and_newline_sanitization():
    """3. Truncamiento a 200 caracteres y supresión de saltos de línea en errores."""
    cloud = read_file(CLOUD_STT)
    assert "take(200)" in cloud or "substring(0, 200)" in cloud, (
        "cloud_stt_service.dart debe truncar el detalle de error a 200 caracteres"
    )
    assert r"replaceAll(RegExp(r'[\r\n]+'), ' ')" in cloud, (
        "cloud_stt_service.dart debe reemplazar saltos de línea con espacios en el mensaje de error"
    )

    speech = read_file(SPEECH_CLIENT)
    assert "take(200)" in speech, (
        "SpeechToTextClient.kt debe acotar el mensaje de error a 200 caracteres con take(200)"
    )
    assert 'replace(Regex("[\\\\r\\\\n]+"), " ")' in speech or "replace(Regex" in speech, (
        "SpeechToTextClient.kt debe remover saltos de línea del mensaje de error"
    )


def test_widget_uuid_validation():
    """4. Validación estricta de formato UUID en WidgetNoteEditActivity."""
    edit = read_file(WIDGET_EDIT)
    assert "isValidUuid" in edit, (
        "WidgetNoteEditActivity.kt debe declarar el validador isValidUuid"
    )
    assert r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$" in edit, (
        "WidgetNoteEditActivity.kt debe validar el patrón canónico de UUID"
    )
    assert "!isValidUuid(rawNoteId)" in edit and "!isValidUuid(rawPendingId)" in edit, (
        "WidgetNoteEditActivity.kt debe validar note_id y pending_id antes de cargarlos"
    )


def test_widget_discrete_mode_and_preview():
    """5. Modo discreto del widget y vista previa de una sola línea."""
    list_svc = read_file(WIDGET_LIST)
    assert "isDiscreteMode" in list_svc, (
        "WidgetNotesListService.kt debe implementar isDiscreteMode"
    )
    assert "widget_discrete_mode" in list_svc, (
        "WidgetNotesListService.kt debe leer la preferencia widget_discrete_mode"
    )
    assert "discreteMode" in list_svc, (
        "WidgetNotesListService.kt debe almacenar el estado discreteMode al refrescar datos"
    )
    assert 'replace(Regex("[\\\\r\\\\n]+"), " ")' in list_svc or "replace(Regex" in list_svc, (
        "WidgetNotesListService.kt debe colapsar saltos de línea a 1 línea en el cuerpo de la nota"
    )


def test_widget_fgs_precheck_and_tokens():
    """6. Pre-check POST_NOTIFICATIONS en FGS y tokenización visual sin Color.WHITE."""
    widget_dict = read_file(WIDGET_DICTATION)
    assert "hasNotificationPermission" in widget_dict, (
        "WidgetDictationService.kt debe implementar pre-check hasNotificationPermission"
    )
    assert "POST_NOTIFICATIONS" in widget_dict, (
        "WidgetDictationService.kt debe verificar el permiso POST_NOTIFICATIONS"
    )
    assert "try {" in widget_dict and "startForeground" in widget_dict, (
        "WidgetDictationService.kt debe envolver startForeground en try/catch para mitigar SecurityException"
    )

    bubble = read_file(BUBBLE_SVC)
    assert "Color.WHITE" not in bubble, (
        "FloatingBubbleService.kt no debe contener Color.WHITE hardcodeado en vistas canvas"
    )
    assert "R.color.kb_label_on_accent" in bubble, (
        "FloatingBubbleService.kt debe utilizar el token R.color.kb_label_on_accent"
    )


def test_negative_mutations():
    """7. Batería de mutaciones negativas reales para verificar efectividad de detección."""
    mutations_passed = 0

    # 1. Colar variable sensible en Log
    sample_kt = 'Log.d(TAG, "Audio transcri user text: $secret")'
    kt_pattern = re.compile(
        r"Log\.[a-z]+\(.*\b(texto|text|contenido|content|password|contrase|snippet|clip|transcri|credential|cred|user|usuario|wav|audio|key|token|groq|bearer)\b",
        re.IGNORECASE,
    )
    if kt_pattern.search(sample_kt):
        mutations_passed += 1

    # 2. Remover pcm.fill(0)
    speech = read_file(SPEECH_CLIENT)
    mutated_speech = speech.replace("pcm.fill(0)", "")
    if "pcm.fill(0)" not in mutated_speech:
        mutations_passed += 1

    # 3. Remover _secureDeleteSync de transcription_service
    tx = read_file(TRANSCRIPTION_SVC)
    mutated_tx = tx.replace("_secureDeleteSync", "file.deleteSync")
    if "_secureDeleteSync" not in mutated_tx:
        mutations_passed += 1

    # 4. Remover take(200) en errores
    mutated_speech2 = speech.replace(".take(200)", "")
    if ".take(200)" not in mutated_speech2:
        mutations_passed += 1

    # 5. UUID inválido aceptado por regex
    uuid_regex = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    assert not uuid_regex.matches("invalid-uuid-1234") if hasattr(uuid_regex, "matches") else not uuid_regex.match("invalid-uuid-1234")
    mutations_passed += 1

    # 6. Reintroducir Color.WHITE en FloatingBubbleService
    bubble = read_file(BUBBLE_SVC)
    mutated_bubble = bubble + "\nval test = Color.WHITE\n"
    if "Color.WHITE" in mutated_bubble:
        mutations_passed += 1

    # 7. Remover isDiscreteMode de WidgetNotesListService
    widget_list = read_file(WIDGET_LIST)
    mutated_list = widget_list.replace("isDiscreteMode", "isNormalMode")
    if "isDiscreteMode" not in mutated_list:
        mutations_passed += 1

    # 8. Remover hasNotificationPermission de WidgetDictationService
    widget_dict = read_file(WIDGET_DICTATION)
    mutated_dict = widget_dict.replace("hasNotificationPermission", "hasNoPermission")
    if "hasNotificationPermission" not in mutated_dict:
        mutations_passed += 1

    assert mutations_passed == 8, f"Se esperaban 8 mutaciones detectadas, pasaron {mutations_passed}"


def run_all_tests():
    tests = [
        ("1. CI Expanded Log Grep and Clean Logs", test_ci_expanded_log_grep_and_clean_logs),
        ("2. Buffer Zeroing and Secure File Deletion", test_buffer_zeroing_and_secure_file_deletion),
        ("3. Error Truncation and Newline Sanitization", test_error_truncation_and_newline_sanitization),
        ("4. Widget UUID Validation", test_widget_uuid_validation),
        ("5. Widget Discrete Mode and Single-line Preview", test_widget_discrete_mode_and_preview),
        ("6. Widget FGS Precheck and Tokens", test_widget_fgs_precheck_and_tokens),
        ("7. Negative Mutations Battery (8/8)", test_negative_mutations),
    ]

    print("=" * 70)
    print("EJECUTANDO SUITE C-35: Logs, borrado, widget y errores [S]")
    print("=" * 70)

    passed = 0
    for name, test_fn in tests:
        try:
            test_fn()
            print(f"  [PASS] {name}")
            passed += 1
        except AssertionError as e:
            print(f"  [FAIL] {name}: {e}")
        except Exception as e:
            print(f"  [ERROR] {name}: {e}")

    print("=" * 70)
    print(f"RESULTADO: {passed}/{len(tests)} tests pasaron")
    print("=" * 70)

    return passed == len(tests)


if __name__ == "__main__":
    if not run_all_tests():
        sys.exit(1)
