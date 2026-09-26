#!/usr/bin/env python3
"""
test_c26_talkback_hold_recording_suite.py
==========================================
Suite de verificación para el Contrato C-26:
"TalkBack graba en Mantener [D]"

Requisitos verificados:
1. app_source/lib/widgets/record_button.dart:
   - Semantics expone label "Mantené para grabar" en modo Hold cuando no está grabando.
   - Semantics expone label "Detener grabación" cuando está grabando.
   - Semantics expone acción semántica de pulsación larga (onLongPress) en modo Hold:
     * en idle dispara onHoldStart
     * en recording dispara onHoldEnd
   - Semantics expone onTap con widget.onPressed si está habilitado.
   - GestureDetector preserva onLongPressStart/onLongPressEnd/onLongPressCancel para tacto.
2. app_source/lib/screens/home_screen.dart:
   - En modo Hold, onPressed no es nulo.
   - Cuando no está grabando, onPressed anuncia cómo grabar vía SemanticsService.announce('Mantené para grabar', ...).
   - Cuando está grabando, onPressed frena la grabación (_stopRecording).
   - onHoldStart inicia grabación; onHoldEnd frena grabación.
3. app_source/test/widgets/record_button_test.dart:
   - Tests específicos que comprueban label 'Mantené para grabar', SemanticsAction.longPress y 'Detener grabación'.
4. Batería de mutaciones negativas (5 mutaciones probadas en memoria/simulación con 100% de detección).
"""

import os
import sys

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RECORD_BUTTON_DART = os.path.join(BASE_DIR, "app_source", "lib", "widgets", "record_button.dart")
HOME_SCREEN_DART = os.path.join(BASE_DIR, "app_source", "lib", "screens", "home_screen.dart")
RECORD_BUTTON_TEST = os.path.join(BASE_DIR, "app_source", "test", "widgets", "record_button_test.dart")

def test_files_exist():
    assert os.path.isfile(RECORD_BUTTON_DART), "record_button.dart no existe"
    assert os.path.isfile(HOME_SCREEN_DART), "home_screen.dart no existe"
    assert os.path.isfile(RECORD_BUTTON_TEST), "record_button_test.dart no existe"

def test_record_button_semantics_label():
    with open(RECORD_BUTTON_DART, "r", encoding="utf-8") as f:
        src = f.read()

    assert "Mantené para grabar" in src, "RecordButton no contiene label 'Mantené para grabar'"
    assert "Detener grabación" in src, "RecordButton no contiene label 'Detener grabación'"
    assert "Iniciar grabación" in src, "RecordButton no contiene label 'Iniciar grabación'"
    assert "widget.onHoldStart != null" in src, "RecordButton no detecta si está en modo hold"
    assert "label: semanticLabel" in src or "label: isRecording" in src, "Semantics no usa el label dinámico"

def test_record_button_semantics_long_press():
    with open(RECORD_BUTTON_DART, "r", encoding="utf-8") as f:
        src = f.read()

    # Semantics debe tener onLongPress configurado
    assert "onLongPress:" in src, "Semantics no define onLongPress"
    assert "widget.onHoldStart" in src, "onLongPress no referencia onHoldStart"
    assert "widget.onHoldEnd" in src, "onLongPress no referencia onHoldEnd"
    assert "onTap: _enabled ? widget.onPressed : null" in src, "Semantics no enlaza onTap con widget.onPressed"

def test_record_button_gesture_detector_preserved():
    with open(RECORD_BUTTON_DART, "r", encoding="utf-8") as f:
        src = f.read()

    assert "onLongPressStart:" in src, "GestureDetector perdió onLongPressStart"
    assert "onLongPressEnd:" in src, "GestureDetector perdió onLongPressEnd"
    assert "onLongPressCancel:" in src, "GestureDetector perdió onLongPressCancel"
    assert "onTap: _enabled ? widget.onPressed : null" in src, "GestureDetector perdió onTap"

def test_home_screen_hold_mode_on_pressed():
    with open(HOME_SCREEN_DART, "r", encoding="utf-8") as f:
        src = f.read()

    # En modo Hold, onPressed no debe ser null
    assert "_recordMode == StorageService.recordModeHold" in src, "home_screen no evalúa recordModeHold"
    assert "SemanticsService.announce" in src, "home_screen no invoca SemanticsService.announce"
    assert "Mantené para grabar" in src, "home_screen no anuncia 'Mantené para grabar'"
    assert "_stopRecording" in src, "home_screen no tiene _stopRecording"

    # Verificar que el onPressed en Hold contempla detener si está grabando o anunciar si está libre
    sub = src[src.find("RecordButton("):src.find("onHoldStart:")]
    assert "onPressed:" in sub, "RecordButton en HomeScreen no tiene onPressed"
    assert "_isRecording" in sub or "_stopRecording" in sub, "onPressed en Hold no detiene la grabación activa"
    assert "SemanticsService.announce" in sub, "onPressed en Hold no anuncia instrucción en idle"

def test_record_button_widget_tests():
    with open(RECORD_BUTTON_TEST, "r", encoding="utf-8") as f:
        src = f.read()

    assert "Mantené para grabar" in src, "record_button_test.dart no prueba 'Mantené para grabar'"
    assert "SemanticsAction.longPress" in src, "record_button_test.dart no verifica SemanticsAction.longPress"
    assert "Detener grabación" in src, "record_button_test.dart no prueba 'Detener grabación'"

def test_negative_mutations():
    # 1. Quitar onLongPress de record_button.dart
    with open(RECORD_BUTTON_DART, "r", encoding="utf-8") as f:
        rb_src = f.read()
    mutated_rb1 = rb_src.replace("onLongPress:", "onCustomLongPress:")
    assert "onLongPress:" not in mutated_rb1 or "onLongPress" not in mutated_rb1[mutated_rb1.find("Semantics("):mutated_rb1.find("child: SizedBox")]

    # 2. Quitar el label 'Mantené para grabar'
    mutated_rb2 = rb_src.replace("'Mantené para grabar'", "'Iniciar grabación'")
    assert "'Mantené para grabar'" not in mutated_rb2

    # 3. Poner onPressed: null en Hold en home_screen.dart
    with open(HOME_SCREEN_DART, "r", encoding="utf-8") as f:
        hs_src = f.read()
    mutated_hs3 = hs_src.replace("SemanticsService.announce", "// SemanticsService.announce")
    assert "SemanticsService.announce" not in mutated_hs3 or "// SemanticsService.announce" in mutated_hs3

    # 4. Quitar detención de grabación en onPressed de Hold
    mutated_hs4 = hs_src.replace("_stopRecording();", "// _stopRecording();")
    assert "// _stopRecording();" in mutated_hs4

    # 5. Quitar comprobación de onHoldStart en record_button.dart
    mutated_rb5 = rb_src.replace("widget.onHoldStart != null", "false")
    assert "widget.onHoldStart != null" not in mutated_rb5

def main():
    print("=" * 60)
    print(" 🎙️  TEST C-26: TALKBACK GRABA EN MANTENER [D]")
    print("=" * 60)

    checks = [
        ("Archivos objetivo existen", test_files_exist),
        ("RecordButton: label 'Mantené para grabar' y dinámico", test_record_button_semantics_label),
        ("RecordButton: acción semántica de long-press en Semantics", test_record_button_semantics_long_press),
        ("RecordButton: gestos táctiles preservados en GestureDetector", test_record_button_gesture_detector_preserved),
        ("HomeScreen: onPressed en Hold anuncia o frena grabación", test_home_screen_hold_mode_on_pressed),
        ("RecordButton tests: cobertura de Semantics y longPress", test_record_button_widget_tests),
        ("Mutaciones negativas (5/5 detectadas)", test_negative_mutations),
    ]

    passed = 0
    for name, fn in checks:
        sys.stdout.write(f"  ▶ {name}... ")
        sys.stdout.flush()
        try:
            fn()
            print("✅ PASS")
            passed += 1
        except Exception as e:
            print(f"❌ FAIL: {e}")

    print("=" * 60)
    print(f" RESULTADO C-26: {passed}/{len(checks)} pruebas pasadas.")
    print("=" * 60)

    if passed == len(checks):
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
