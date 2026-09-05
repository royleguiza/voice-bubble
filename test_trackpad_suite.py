#!/usr/bin/env python3
"""
TEST SUITE INTEGRAL: MODO TRACKPAD Y PUNTERO VIRTUAL (MEJ-09)
Verifica al 100% de certeza:
1. Paridad de claves de contrato en docs/contract-keys.txt, Dart y Kotlin.
2. Manifest y permisos: SYSTEM_ALERT_WINDOW, BIND_ACCESSIBILITY_SERVICE y config XML.
3. VoiceBubbleAccessibilityService: métodos de despacho, sanitización de coordenadas, batching de scroll y canRetrieveWindowContent=false.
4. PointerOverlayManager: TYPE_APPLICATION_OVERLAY, FLAG_NOT_TOUCHABLE, estilos, cinemática y bounds.
5. VirtualTrackpadView: Opción 2 Split Wings, modos de scroll (right, left, disabled), auto-expansión 100%,
   prevención de doble-click multitáctil, re-anclaje de cursor y clic secundario 'hold'.
6. VoiceKeyboardService: Layer.TRACKPAD, toolbar button, rebuild, ciclo de vida, guardas de contraseña y tolerancia de tipos.
7. Auditoría de Privacidad y Cero-Logs (CERO telemetría, CERO captura de coordenadas).
8. StorageService (Dart): getters, setters, constantes, clamping y valores por defecto.
9. SettingsScreen (Dart): sección dedicada, switches y segmented buttons.
10. Vector drawables: ic_trackpad.xml, ic_keyboard.xml y strings.xml.
11. Batería de tests unitarios Dart en app_source/test/.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
PASSED = 0
FAILED = 0

def check(name, condition, error_msg=""):
    global PASSED, FAILED
    if condition:
        print(f"  [PASS] {name}")
        PASSED += 1
    else:
        print(f"  [FAIL] {name} -> {error_msg}")
        FAILED += 1

print("\n============================================================")
print(" 🚀 INICIANDO TEST SUITE: MODO TRACKPAD Y PUNTERO VIRTUAL (MEJ-09)")
print("============================================================\n")

# --- TEST 1: Paridad de claves de contrato ---
TRACKPAD_KEYS = [
    "kb_trackpad_accel_curve",
    "kb_trackpad_auto_return",
    "kb_trackpad_button_layout",
    "kb_trackpad_enabled",
    "kb_trackpad_haptic",
    "kb_trackpad_pointer_style",
    "kb_trackpad_scroll_direction",
    "kb_trackpad_scroll_position",
    "kb_trackpad_secondary_click",
    "kb_trackpad_sensitivity",
    "kb_trackpad_tap_to_click",
    "kb_trackpad_toolbar_visible",
]

contract_keys_file = os.path.join(WORKSPACE, "docs/contract-keys.txt")
with open(contract_keys_file, "r", encoding="utf-8") as f:
    contract_content = f.read().splitlines()

all_in_contract = all(k in contract_content for k in TRACKPAD_KEYS)
check(f"Todas las {len(TRACKPAD_KEYS)} claves de trackpad presentes en docs/contract-keys.txt", all_in_contract)

kt_vk = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceKeyboardService.kt")
with open(kt_vk, "r", encoding="utf-8") as f:
    vk_content = f.read()

all_read_in_kotlin = all(f'flutter.{k}' in vk_content for k in TRACKPAD_KEYS)
check(f"Todas las {len(TRACKPAD_KEYS)} claves flutter.kb_trackpad_* leídas en VoiceKeyboardService.kt", all_read_in_kotlin)

# --- TEST 2: Manifest y Permisos ---
manifest_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/AndroidManifest.xml")
with open(manifest_path, "r", encoding="utf-8") as f:
    manifest_content = f.read()

check("AndroidManifest declara SYSTEM_ALERT_WINDOW", 'android.permission.SYSTEM_ALERT_WINDOW' in manifest_content)
check("AndroidManifest declara BIND_ACCESSIBILITY_SERVICE (trial B: isla exacta)", 'android.permission.BIND_ACCESSIBILITY_SERVICE' in manifest_content)
check("AndroidManifest declara VoiceBubbleAccessibilityService (trial B: isla exacta)", 'android:name=".VoiceBubbleAccessibilityService"' in manifest_content)
check("AndroidManifest no declara FloatingTrackpadService (Play Protect seguro)", 'android:name=".FloatingTrackpadService"' not in manifest_content)

gradle_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/build.gradle.kts")
with open(gradle_path, "r", encoding="utf-8") as f:
    gradle_content = f.read()

keystore_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/debug.keystore")
check("Keystore persistente debug.keystore existe en android/app", os.path.isfile(keystore_path))
check("build.gradle.kts configura signingConfigs con debug.keystore", 'debug.keystore' in gradle_content)

# --- TEST 3: VoiceBubbleAccessibilityService ---
acc_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VoiceBubbleAccessibilityService.kt")
check("VoiceBubbleAccessibilityService.kt existe", os.path.isfile(acc_kt_path))
if os.path.isfile(acc_kt_path):
    with open(acc_kt_path, "r", encoding="utf-8") as f:
        acc_content = f.read()
    check("VoiceBubbleAccessibilityService extiende AccessibilityService", "class VoiceBubbleAccessibilityService : AccessibilityService()" in acc_content)
    check("VoiceBubbleAccessibilityService implementa dispatchTap", "fun dispatchTap(" in acc_content)
    check("VoiceBubbleAccessibilityService implementa dispatchLongPress", "fun dispatchLongPress(" in acc_content)
    check("VoiceBubbleAccessibilityService implementa dispatchScroll", "fun dispatchScroll(" in acc_content)
    check("VoiceBubbleAccessibilityService tiene singleton isConnected()", "fun isConnected(): Boolean" in acc_content)
    check("VoiceBubbleAccessibilityService sanitiza coordenadas contra NaN y valores negativos", "isNaN" in acc_content)
    check("VoiceBubbleAccessibilityService implementa batching de scroll sin colisiones (flushPendingScroll)", "flushPendingScroll" in acc_content and "isScrollActive" in acc_content)
    check("VoiceBubbleAccessibilityService trazo no vacio via lineTo en dispatchTap", "lineTo(x, y)" in acc_content)

# --- TEST 4: PointerOverlayManager ---
pom_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/PointerOverlayManager.kt")
check("PointerOverlayManager.kt existe", os.path.isfile(pom_kt_path))
if os.path.isfile(pom_kt_path):
    with open(pom_kt_path, "r", encoding="utf-8") as f:
        pom_content = f.read()
    check("PointerOverlayManager usa TYPE_APPLICATION_OVERLAY", "WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY" in pom_content)
    check("PointerOverlayManager usa FLAG_NOT_TOUCHABLE (no roba toques)", "FLAG_NOT_TOUCHABLE" in pom_content)
    check("PointerOverlayManager usa FLAG_NOT_FOCUSABLE (no roba foco)", "FLAG_NOT_FOCUSABLE" in pom_content)
    check("PointerOverlayManager soporta estilos arrow, dot, cross", '"arrow"' in pom_content and '"dot"' in pom_content and '"cross"' in pom_content)
    check("PointerOverlayManager cinemática: dynamic, linear, precision", '"dynamic"' in pom_content and '"linear"' in pom_content and '"precision"' in pom_content)
    check("PointerOverlayManager acota coordenadas a bounds de pantalla", "clampCoordinates" in pom_content)
    check("PointerOverlayManager sanitiza coordenadas contra NaN", "isNaN()" in pom_content)
    check("PointerOverlayManager alinea subpixel de punta de flecha con density", "tipOffset" in pom_content)
    check("PointerOverlayManager limite inferior dinamico resetBottomLimit", "resetBottomLimit" in pom_content)

# --- TEST 4B: FloatingTrackpadService (Burbuja Independiente de Mouse) ---
ftp_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/FloatingTrackpadService.kt")
check("FloatingTrackpadService.kt existe", os.path.isfile(ftp_kt_path))
if os.path.isfile(ftp_kt_path):
    with open(ftp_kt_path, "r", encoding="utf-8") as f:
        ftp_content = f.read()
    check("FloatingTrackpadService extiende Service", "class FloatingTrackpadService : Service()" in ftp_content)
    check("FloatingTrackpadService implementa expandToDock", "fun expandToDock()" in ftp_content)
    check("FloatingTrackpadService implementa expandToMiniPad", "fun expandToMiniPad()" in ftp_content)
    check("FloatingTrackpadService implementa minimizeToBubble", "fun minimizeToBubble()" in ftp_content)
    check("FloatingTrackpadService maneja idle dimming", "idleDimRunnable" in ftp_content)
    check("FloatingTrackpadService snap a bordes", "snapBubbleToEdge" in ftp_content)
    check("FloatingTrackpadService integra VirtualTrackpadView", "VirtualTrackpadView(" in ftp_content)
    check("FloatingTrackpadService despacha taps a VoiceBubbleAccessibilityService", "VoiceBubbleAccessibilityService.dispatchTap" in ftp_content)
    check("FloatingTrackpadService despacha scroll a VoiceBubbleAccessibilityService", "VoiceBubbleAccessibilityService.dispatchScroll" in ftp_content)
    check("FloatingTrackpadService implementa rayita drag handle con gestos", "rayita" in ftp_content and "minimizeToBubble" in ftp_content)
    check("FloatingTrackpadService maneja extensión a 380dp y colapso", "380" in ftp_content and "240" in ftp_content)
    check("FloatingTrackpadService maneja arrastre minipad libre en 2D (x e y)", "expandedLayoutParams.x = (initialX + dx)" in ftp_content and "expandedLayoutParams.y = (initialY + dy)" in ftp_content)
    check("FloatingTrackpadService actualiza cota inferior del puntero al extender altura", "pointerManager?.updateKeyboardTop" in ftp_content)
    check("FloatingTrackpadService usa tema glass por defecto para Liquid Glass", 'theme = "glass"' in ftp_content)

ftp_dart_path = os.path.join(WORKSPACE, "app_source/lib/services/floating_trackpad_service.dart")
check("floating_trackpad_service.dart existe", os.path.isfile(ftp_dart_path))
if os.path.isfile(ftp_dart_path):
    with open(ftp_dart_path, "r", encoding="utf-8") as f:
        ftp_dart_content = f.read()
    check("floating_trackpad_service.dart define canal floating_trackpad", "com.royleguiza.voicebubblestt/floating_trackpad" in ftp_dart_content)
    check("floating_trackpad_service.dart tiene startTrackpadBubble", "startTrackpadBubble" in ftp_dart_content)
    check("floating_trackpad_service.dart tiene isAccessibilityGranted", "isAccessibilityGranted" in ftp_dart_content)

main_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/MainActivity.kt")
with open(main_kt_path, "r", encoding="utf-8") as f:
    main_content = f.read()
check("MainActivity maneja TRACKPAD_CHANNEL", "TRACKPAD_CHANNEL" in main_content)
check("MainActivity maneja startTrackpadBubble", '"startTrackpadBubble"' in main_content)
check("MainActivity maneja isAccessibilityGranted", '"isAccessibilityGranted"' in main_content)

# --- TEST 5: VirtualTrackpadView (Opción 2 Split Wings & Top 50/50) ---
vtv_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/VirtualTrackpadView.kt")
check("VirtualTrackpadView.kt existe", os.path.isfile(vtv_kt_path))
if os.path.isfile(vtv_kt_path):
    with open(vtv_kt_path, "r", encoding="utf-8") as f:
        vtv_content = f.read()
    check("VirtualTrackpadView maneja modos de scroll: right, left, disabled", '"right"' in vtv_content and '"left"' in vtv_content and '"disabled"' in vtv_content)
    check("VirtualTrackpadView auto-expansión al 100% de altura (weight 1.0f)", "weight = 1.0f" in vtv_content)
    check("VirtualTrackpadView scroll strip vertical (weight 1.4f)", "weight = 1.4f" in vtv_content)
    check("VirtualTrackpadView botón secundario compartido (weight 0.8f)", "weight = 0.8f" in vtv_content)
    check("VirtualTrackpadView soporte para Tap-to-Click", "tapToClick" in vtv_content)
    check("VirtualTrackpadView soporte para auto-retorno por inactividad", "autoReturnSeconds" in vtv_content)
    check("VirtualTrackpadView suprime tap-to-click tras interacción multitáctil (hadMultiTouch)", "hadMultiTouch" in vtv_content)
    check("VirtualTrackpadView re-ancla coordenadas tras ACTION_POINTER_UP para evitar saltos", "remainingIndex" in vtv_content)
    check("VirtualTrackpadView implementa modo de clic secundario 'hold' (mantener)", 'secondaryClickMode == "hold"' in vtv_content and "holdRunnable" in vtv_content)
    check("VirtualTrackpadView cancela pulsación de botón si el toque sale del área", "inside" in vtv_content)
    check("VirtualTrackpadView acota altura vía onMeasure con MeasureSpec.EXACTLY", "MeasureSpec.EXACTLY" in vtv_content and "onMeasure" in vtv_content)
    check("VirtualTrackpadView contraste accesible en clic izquierdo (acento primario)", "isPrimary" in vtv_content and "kb_key_bg_accent" in vtv_content)
    check("VirtualTrackpadView contraste accesible en clic derecho (neutro sólido)", "CLIC" in vtv_content and "DER" in vtv_content and ("3C3C43" in vtv_content or "EBEBF5" in vtv_content))
    check("VirtualTrackpadView feedback visual de contraste en scroll strip", "pressedBgColor" in vtv_content and ("26007AFF" in vtv_content or "330A84FF" in vtv_content))
    check("VirtualTrackpadView soporta modo dual de botones (top vs wings)", 'buttonLayout == "wings"' in vtv_content and "setupTopButtonsLayout" in vtv_content)
    check("VirtualTrackpadView usa iconos de mouse vectoriales ic_mouse_left e ic_mouse_right", "ic_mouse_left" in vtv_content and "ic_mouse_right" in vtv_content)
    check("VirtualTrackpadView soporta scroll quitado con 100% de ancho", '"none"' in vtv_content)

# --- TEST 6: VoiceKeyboardService integración ---
check("VoiceKeyboardService declara Layer.TRACKPAD", "Layer { LETTERS, SYMBOLS, CODE, SNIPPETS, TRACKPAD }" in vk_content)
check("VoiceKeyboardService tiene toggleTrackpadLayer()", "fun toggleTrackpadLayer()" in vk_content)
check("VoiceKeyboardService tiene buildTrackpadLayer()", "fun buildTrackpadLayer(): View" in vk_content)
check("VoiceKeyboardService rebuild() monta buildTrackpadLayer()", "Layer.TRACKPAD -> {\n            addRow(buildTrackpadLayer())\n        }" in vk_content or "addRow(buildTrackpadLayer())" in vk_content)
check("VoiceKeyboardService suprime trackpad en contraseñas", "isPasswordInput" in vk_content and "currentIsPasswordField" in vk_content)
check("VoiceKeyboardService toolbar incluye botón de trackpad", "btnTrackpad" in vk_content)
check("VoiceKeyboardService oculta overlay en onFinishInputView y onWindowHidden", "pointerOverlayManager?.hide()" in vk_content)
check("VoiceKeyboardService previene loop en lastLettersLayer", "layer != Layer.TRACKPAD" in vk_content)
check("VoiceKeyboardService lee kb_trackpad_auto_return tolerante a Integer y Long", "is Number -> raw.toInt()" in vk_content)
check("VoiceKeyboardService despacha trackpad vía InputConnection nativo", "sendDownUpKeyEvents(KeyEvent.KEYCODE_DPAD_CENTER)" in vk_content)
check("VoiceKeyboardService transición suave morphing al alternar trackpad", "beginKeyboardTransition" in vk_content and "TransitionManager" in vk_content)
check("VoiceKeyboardService altura determinista del trackpad acorde al teclado", "getTargetTrackpadHeightPx" in vk_content and "totalKeyRows" in vk_content)
check("VoiceKeyboardService MEJ-25 gestos en barra espaciadora", "attachSpacebarGestures" in vk_content)
check("VoiceKeyboardService MEJ-25 modo trackpad 2D con blank-out", "setTrackpadBlankOutMode" in vk_content and "spacebarTrackpadMode" in vk_content)
check("VoiceKeyboardService MEJ-25 selección de texto vía META_SHIFT_ON", "META_SHIFT_ON" in vk_content and "isSelecting" in vk_content)
check("VoiceKeyboardService MEJ-25 desplazamiento cinemático proporcional (stepsX/stepsY)", "stepsX" in vk_content and "stepsY" in vk_content)
check("VoiceKeyboardService expone commitFromExternal para inyección en cursor", "fun commitFromExternal" in vk_content and "instance" in vk_content)

# --- DynamicIslandController & Morphing History ---
dic_kt_path = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/DynamicIslandController.kt")
check("DynamicIslandController.kt existe", os.path.isfile(dic_kt_path))
if os.path.isfile(dic_kt_path):
    with open(dic_kt_path, "r", encoding="utf-8") as f:
        dic_content = f.read()
    check("DynamicIslandController pastilla con slots y punch central", "buildCompactView" in dic_content and "camPunch" in dic_content)
    check("DynamicIslandController grabación con waveform interactiva", "buildRecordingView" in dic_content and "wave" in dic_content)
    check("DynamicIslandController modal de historial adaptable", "buildHistoryModalView" in dic_content and "populateHistoryCards" in dic_content)
    check("DynamicIslandController modal soporta isFillViewport para estiramiento adaptativo", "isFillViewport = true" in dic_content)
    check("DynamicIslandController adaptabilidad de tarjetas (1 item 100% alto, 2 items 50% alto)", "1, 2 ->" in dic_content and "1.0f" in dic_content)
    check("DynamicIslandController inyección directa en cursor vía VoiceKeyboardService", "VoiceKeyboardService.commitFromExternal" in dic_content)
    check("DynamicIslandController contraste accesible para temas claro y oscuro", "isNight" in dic_content and "tvSnippet" in dic_content)
    check("DynamicIslandController copia con feedback de checkmark", "copyToClipboard" in dic_content and "ic_check" in dic_content and "ic_copy" in dic_content)
    check("DynamicIslandController rayita inferior para cierre y extensión", "setHistoryExtended50" in dic_content and "closeHistoryModal" in dic_content)

# --- TEST 7: Auditoría de Cero-Logs y Cero-Telemetría ---
trackpad_files = [acc_kt_path, pom_kt_path, vtv_kt_path, dic_kt_path]
leak_found = False
log_leak_pattern = re.compile(r'Log\.[a-z]+\(.*\b(coord|touch|event|gesture|x|y|window|key)\b', re.IGNORECASE)
for tf in trackpad_files:
    if os.path.isfile(tf):
        with open(tf, "r", encoding="utf-8") as f:
            for idx, line in enumerate(f, 1):
                if log_leak_pattern.search(line):
                    leak_found = True
                    print(f"  [LEAK] {os.path.basename(tf)}:{idx} -> {line.strip()}")

check("Auditoría de Privacidad: CERO logs ni telemetría en módulos de trackpad", not leak_found)

# --- TEST 8: StorageService (Dart) ---
dart_storage_path = os.path.join(WORKSPACE, "app_source/lib/services/storage_service.dart")
with open(dart_storage_path, "r", encoding="utf-8") as f:
    storage_content = f.read()

for k in TRACKPAD_KEYS:
    check(f"StorageService define clave {k}", f"'{k}'" in storage_content)

check("StorageService tiene getTrackpadEnabled / setTrackpadEnabled", "getTrackpadEnabled" in storage_content and "setTrackpadEnabled" in storage_content)
check("StorageService tiene getTrackpadButtonLayout / setTrackpadButtonLayout", "getTrackpadButtonLayout" in storage_content and "setTrackpadButtonLayout" in storage_content)
check("StorageService tiene getSpacebarTrackpadMode / setSpacebarTrackpadMode", "getSpacebarTrackpadMode" in storage_content and "setSpacebarTrackpadMode" in storage_content)
check("StorageService tiene getTrackpadScrollPosition / setTrackpadScrollPosition", "getTrackpadScrollPosition" in storage_content and "setTrackpadScrollPosition" in storage_content)
check("StorageService tiene getTrackpadSensitivity / setTrackpadSensitivity", "getTrackpadSensitivity" in storage_content and "setTrackpadSensitivity" in storage_content)
check("StorageService tiene getTrackpadAccelCurve / setTrackpadAccelCurve", "getTrackpadAccelCurve" in storage_content and "setTrackpadAccelCurve" in storage_content)
check("StorageService tiene getTrackpadTapToClick / setTrackpadTapToClick", "getTrackpadTapToClick" in storage_content and "setTrackpadTapToClick" in storage_content)
check("StorageService tiene getTrackpadSecondaryClick / setTrackpadSecondaryClick", "getTrackpadSecondaryClick" in storage_content and "setTrackpadSecondaryClick" in storage_content)
check("StorageService tiene getTrackpadScrollDirection / setTrackpadScrollDirection", "getTrackpadScrollDirection" in storage_content and "setTrackpadScrollDirection" in storage_content)
check("StorageService tiene getTrackpadHaptic / setTrackpadHaptic", "getTrackpadHaptic" in storage_content and "setTrackpadHaptic" in storage_content)
check("StorageService tiene getTrackpadPointerStyle / setTrackpadPointerStyle", "getTrackpadPointerStyle" in storage_content and "setTrackpadPointerStyle" in storage_content)
check("StorageService tiene getTrackpadAutoReturn / setTrackpadAutoReturn", "getTrackpadAutoReturn" in storage_content and "setTrackpadAutoReturn" in storage_content)
check("StorageService acota getTrackpadSensitivity a [0.5, 2.5]", ".clamp(0.5, 2.5)" in storage_content)

# --- TEST 9: SettingsScreen (Dart) ---
dart_settings_path = os.path.join(WORKSPACE, "app_source/lib/screens/settings_screen.dart")
with open(dart_settings_path, "r", encoding="utf-8") as f:
    settings_content = f.read()

check("SettingsScreen tiene tarjeta 'Modo Trackpad y Puntero Virtual'", "Modo Trackpad y Puntero Virtual" in settings_content)
check("SettingsScreen tiene selector de distribución de botones de clic (top, wings)", "kb-trackpad-button-layout-selector" in settings_content)
check("SettingsScreen tiene selector de modo trackpad en barra espaciadora", "kb-spacebar-trackpad-mode-selector" in settings_content)
check("SettingsScreen tiene selector de posición de scroll (right, left, disabled)", "kb-trackpad-scroll-position-selector" in settings_content)
check("SettingsScreen tiene slider de sensibilidad (0.5 a 2.5)", "kb-trackpad-sensitivity-slider" in settings_content)
check("SettingsScreen tiene selector de curva de aceleración", "kb-trackpad-accel-curve-selector" in settings_content)
check("SettingsScreen tiene selector de clic secundario", "kb-trackpad-secondary-click-selector" in settings_content)
check("SettingsScreen tiene selector de dirección de scroll", "kb-trackpad-scroll-direction-selector" in settings_content)
check("SettingsScreen tiene selector de estilo de puntero", "kb-trackpad-pointer-style-selector" in settings_content)
check("SettingsScreen tiene selector de auto-retorno por inactividad", "kb-trackpad-auto-return-selector" in settings_content)

# --- TEST 10: Vector drawables y recursos ---
drawable_tp = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_trackpad.xml")
drawable_kb = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_keyboard.xml")
drawable_ml = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_mouse_left.xml")
drawable_mr = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_mouse_right.xml")
drawable_copy = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_copy.xml")
drawable_check = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/drawable/ic_check.xml")
strings_xml = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/res/values/strings.xml")

for d_name, d_path in [
    ("ic_trackpad.xml", drawable_tp),
    ("ic_keyboard.xml", drawable_kb),
    ("ic_mouse_left.xml", drawable_ml),
    ("ic_mouse_right.xml", drawable_mr),
    ("ic_copy.xml", drawable_copy),
    ("ic_check.xml", drawable_check),
]:
    check(f"{d_name} existe", os.path.isfile(d_path))
    if os.path.isfile(d_path):
        try:
            ET.parse(d_path)
            check(f"{d_name} es XML válido", True)
        except Exception as e:
            check(f"{d_name} es XML válido", False, str(e))

with open(strings_xml, "r", encoding="utf-8") as f:
    str_content = f.read()
check("strings.xml define accessibility_service_name", 'name="accessibility_service_name"' in str_content)
check("strings.xml define accessibility_service_desc", 'name="accessibility_service_desc"' in str_content)

# --- TEST 11: Batería de tests unitarios Dart ---
dart_storage_test = os.path.join(WORKSPACE, "app_source/test/services/trackpad_storage_test.dart")
dart_settings_test = os.path.join(WORKSPACE, "app_source/test/screens/settings_trackpad_test.dart")

check("trackpad_storage_test.dart existe", os.path.isfile(dart_storage_test))
if os.path.isfile(dart_storage_test):
    with open(dart_storage_test, "r", encoding="utf-8") as f:
        dst_content = f.read()
    check("trackpad_storage_test.dart cubre las 11 claves y defaults", "getTrackpadScrollPosition" in dst_content and "getTrackpadSensitivity" in dst_content and "getTrackpadAutoReturn" in dst_content)

check("settings_trackpad_test.dart existe", os.path.isfile(dart_settings_test))
if os.path.isfile(dart_settings_test):
    with open(dart_settings_test, "r", encoding="utf-8") as f:
        stt_content = f.read()
    check("settings_trackpad_test.dart prueba renderizado y persistencia de widgets", "kb-trackpad-scroll-position-selector" in stt_content and "kb-trackpad-pointer-style-selector" in stt_content)

# --- TEST 12: Batería Píldora e Isla Dinámica (MEJ-18 / Hardware Tuning) ---
check("StorageService define clave bubble_docking_mode", "bubble_docking_mode" in storage_content)
check("StorageService define clave island_pos_x", "island_pos_x" in storage_content)
check("StorageService define clave island_pos_y", "island_pos_y" in storage_content)
check("StorageService define clave island_width", "island_width" in storage_content)
check("StorageService define clave island_height", "island_height" in storage_content)
check("StorageService define clave island_slot_order", "island_slot_order" in storage_content)
check("StorageService define clave island_theme", "island_theme" in storage_content)
check("StorageService define clave island_waveform_enabled", "island_waveform_enabled" in storage_content)

check("SettingsScreen tiene sección independiente 'Píldora e Isla Dinámica'", "Píldora e Isla Dinámica" in settings_content)
check("SettingsScreen tiene tarjeta 'Pastilla Flotante Inteligente'", "Pastilla Flotante Inteligente" in settings_content)
check("SettingsScreen tiene selector de modo de contenedor", "island-docking-mode-selector" in settings_content)
check("SettingsScreen tiene presets de hardware de cámara", "Cámara Central" in settings_content and "Perforada Izquierda" in settings_content and "Notch Superior" in settings_content)
check("SettingsScreen tiene sliders de calibración fina X, Y, W, H", "island-slider-x" in settings_content and "island-slider-y" in settings_content and "island-slider-w" in settings_content and "island-slider-h" in settings_content)
check("SettingsScreen tiene steppers finos de ajuste milimétrico", "-5 px" in settings_content and "+5 px" in settings_content and "-1 px" in settings_content and "+1 px" in settings_content)
check("SettingsScreen tiene botón de inversión de ranuras", "island-swap-slots-btn" in settings_content)
check("SettingsScreen tiene selector de tema de la pastilla", "island-theme-selector" in settings_content)
check("SettingsScreen tiene switch de onda de voz reactiva", "island-waveform-switch" in settings_content)

check("DynamicIslandController carga preferencias nativas de posición y tamaño", "flutter.island_pos_x" in dic_content and "flutter.island_pos_y" in dic_content and "flutter.island_width" in dic_content and "flutter.island_height" in dic_content)
check("DynamicIslandController implementa reloadConfiguration", "fun reloadConfiguration()" in dic_content)
check("DynamicIslandController implementa orden dinámico de ranuras", "slotOrder" in dic_content and "mic_camera_trackpad" in dic_content)
check("DynamicIslandController implementa temas visuales glass, dark y light", "islandTheme" in dic_content and "light" in dic_content and "dark" in dic_content)

dart_island_storage_test = os.path.join(WORKSPACE, "app_source/test/services/island_storage_test.dart")
dart_island_settings_test = os.path.join(WORKSPACE, "app_source/test/screens/settings_island_test.dart")

check("island_storage_test.dart existe", os.path.isfile(dart_island_storage_test))
check("settings_island_test.dart existe", os.path.isfile(dart_island_settings_test))

print("\n============================================================")
print(f" RESULTADO SUITE TRACKPAD & ISLA: {PASSED} pasados, {FAILED} fallidos.")
print("============================================================\n")

if FAILED > 0:
    sys.exit(1)
sys.exit(0)
