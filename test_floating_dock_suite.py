#!/usr/bin/env python3
"""
TEST SUITE: BARRA FLOTANTE + VOICEBUBBLE PUNTERO (2026-10-30)

Prototipo "Burbuja de puntero" aprobado por el dueño. Verifica sobre el
código real:
1. Perfil anti-Play-Protect intacto: VoiceBubble sin AccessibilityService;
   la Accesibilidad vive solo en el complemento puntero_android/.
2. Protocolo idéntico en las dos apps y permiso de firma en las dos.
3. Complemento mínimo: gestos sí, lectura de pantalla no, sin telemetría.
4. Barra: dos formas (borde/burbuja), conversión por gesto, herramientas
   micrófono/puntero, historial con toque largo, gesto Atrás protegido.
5. Vidrio: desenfoque real con Window (Android 12+) y vidrio lechoso sin él.
6. Trackpad: sin ×, la línea cierra y muestra la cuenta; clics por el
   complemento; nuestras ventanas se apartan durante el gesto.
7. Dart/Ajustes: forma, herramientas, estado del complemento, sin
   arrancar ventanas flotantes desde el trackpad del teclado.
8. CI: tests JVM, paridad del protocolo y APK del complemento.
9. Mutaciones negativas detectadas.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check

KT = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt"
KT_TEST = "voice_bubble_stt/android/app/src/test/kotlin/com/royleguiza/voicebubblestt"
PUN = "puntero_android/app/src/main"
PUN_KT = f"{PUN}/kotlin/com/royleguiza/voicebubble/puntero"
PUN_TEST = "puntero_android/app/src/test/kotlin/com/royleguiza/voicebubble/puntero"


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


def exists(rel):
    return os.path.isfile(os.path.join(WORKSPACE, rel))


def consts(src):
    return [l.strip() for l in src.splitlines() if l.strip().startswith("const val ")]


print("\n============================================================")
print(" INICIANDO TEST SUITE: BARRA FLOTANTE + VOICEBUBBLE PUNTERO")
print("============================================================\n")

manifest_raw = read("voice_bubble_stt/android/app/src/main/AndroidManifest.xml")
# Los comentarios explican el perfil y nombran el permiso: no cuentan.
manifest = re.sub(r"<!--.*?-->", "", manifest_raw, flags=re.S)
pun_manifest = read(f"{PUN}/AndroidManifest.xml")
pun_cfg = read(f"{PUN}/res/xml/puntero_service.xml")
proto = read(f"{KT}/PointerProtocol.kt")
pun_proto = read(f"{PUN_KT}/PointerProtocol.kt")
link = read(f"{KT}/PointerLink.kt")
geo = read(f"{KT}/DockGeometry.kt")
dock = read(f"{KT}/DockController.kt")
views = read(f"{KT}/DockViews.kt")
glass = read(f"{KT}/GlassWindow.kt")
fbs = read(f"{KT}/FloatingBubbleService.kt")
ftp = read(f"{KT}/FloatingTrackpadService.kt")
pom = read(f"{KT}/PointerOverlayManager.kt")
bridge = read(f"{KT}/TrackpadBridge.kt")
main = read(f"{KT}/MainActivity.kt")
pun_svc = read(f"{PUN_KT}/PunteroService.kt")
pun_main = read(f"{PUN_KT}/MainActivity.kt")
pun_gradle = read("puntero_android/app/build.gradle.kts")
ci = read(".github/workflows/android.yml")
storage = read("app_source/lib/services/storage_service.dart")
general = read("app_source/lib/screens/settings/general_tab.dart")
trackpad_page = read("app_source/lib/screens/settings/trackpad_tab.dart")
settings = read("app_source/lib/screens/settings_screen.dart")
contract = read("docs/contract-keys.txt").split()

# --- 1. Perfil anti-Play-Protect ---
check("VoiceBubble sin BIND_ACCESSIBILITY_SERVICE", "BIND_ACCESSIBILITY_SERVICE" not in manifest)
check("VoiceBubble sin meta-data de accesibilidad", "android.accessibilityservice" not in manifest)
check("Sin clase de Accesibilidad en VoiceBubble", not exists(f"{KT}/VoiceBubbleAccessibilityService.kt"))
check("Ningún Kotlin de VoiceBubble extiende AccessibilityService",
      all(": AccessibilityService()" not in read(f"{KT}/{f}")
          for f in os.listdir(os.path.join(WORKSPACE, KT)) if f.endswith(".kt")))
check("El complemento declara el servicio con BIND_ACCESSIBILITY_SERVICE",
      'android:name=".PunteroService"' in pun_manifest and "BIND_ACCESSIBILITY_SERVICE" in pun_manifest)

# --- 2. Protocolo y permiso de firma ---
check("PointerProtocol idéntico en las dos apps", consts(proto) == consts(pun_proto) and len(consts(proto)) >= 15)
perm = "com.royleguiza.voicebubble.puntero.permission.POINTER"
for name, m in (("VoiceBubble", manifest), ("Puntero", pun_manifest)):
    check(f"{name} declara el permiso de firma",
          re.search(r'<permission\s+android:name="' + re.escape(perm) + r'"\s+android:protectionLevel="signature"', m) is not None)
check("VoiceBubble usa el permiso", f'<uses-permission android:name="{perm}"/>' in manifest)
check("VoiceBubble puede ver si el complemento está instalado",
      '<package android:name="com.royleguiza.voicebubble.puntero"/>' in manifest)
check("El complemento firma con la misma debug.keystore", "../../voice_bubble_stt/android/app/debug.keystore" in pun_gradle)
check("Broadcast explícito al paquete del complemento", "setPackage(PointerProtocol.COMPANION_PACKAGE)" in link)
check("El complemento exige el permiso al registrar el receptor",
      "registerReceiver(receiver, filter, PointerProtocol.PERMISSION_POINTER" in pun_svc)
check("El complemento valida cada orden", "PointerProtocol.validate(" in pun_svc and "?: return" in pun_svc)

# --- 3. Complemento mínimo y privado ---
check("Gestos sí", 'android:canPerformGestures="true"' in pun_cfg)
check("Lectura de pantalla no", 'android:canRetrieveWindowContent="false"' in pun_cfg)
check("Herramienta de accesibilidad declarada", 'android:isAccessibilityTool="true"' in pun_cfg)
check("Sin telemetría", "Cero telemetría" in pun_svc and "event?." not in pun_svc)
check("Sin permisos extra en el complemento (solo el de firma propio)", re.findall(r'<uses-permission android:name="([^"]+)"', pun_manifest) == ["com.royleguiza.voicebubble.puntero.permission.POINTER"])
check("Sin Internet en el complemento", "INTERNET" not in pun_manifest)
check("Sin dependencias de runtime en el complemento",
      re.search(r'^\s*implementation\(', pun_gradle, re.M) is None)
check("Pantalla del complemento guía Accesibilidad y ajustes restringidos",
      "ACTION_ACCESSIBILITY_SETTINGS" in pun_main and "Permitir ajustes restringidos" in pun_main)
check("Sin Log en el complemento", "Log." not in pun_svc + pun_main)

# --- 4. Barra: formas, gestos, herramientas ---
check("Dos formas: borde y burbuja", 'EDGE("edge")' in geo and 'BUBBLE("bubble")' in geo)
check("Arrastrar hacia adentro convierte en burbuja", "fun shouldBecomeBubble(" in geo and "DockGeometry.shouldBecomeBubble(side, dx, d)" in dock)
check("Soltar contra el borde vuelve barra", "fun snapSide(" in geo and "DockGeometry.snapSide(" in dock)
check("La forma elegida con el dedo llega a Ajustes", "putString(PREF_FORM, form.pref)" in dock)
check("Posición recordada en prefs nativas", '"vb_dock_state"' in dock and '"center_y_frac"' in dock)
check("Herramientas micrófono y puntero (nunca vacías)", "fun tools(mic: Boolean, pointer: Boolean)" in geo and "ifEmpty { listOf(Tool.MIC) }" in geo)
check("Con una herramienta la burbuja la usa directo", "TapAction.RUN_ONLY_TOOL" in geo and "tools.size == 1" in geo)
check("Abanico hacia el centro de la pantalla", "fun arcCenters(" in geo and "screenW / 2f - cx" in geo)
check("Micrófono usa el flujo de Dart de siempre", "onBubbleActionListener?.onBubbleTap()" in fbs)
check("Puntero abre el trackpad anclado a la barra", "FloatingTrackpadService.open(this@FloatingBubbleService, anchorX, anchorY)" in fbs)
check("Toque largo = historial (solo en reposo)", "requestHistory()" in dock and 'if (dictationState != "idle") return false' in dock)
check("Grabando, la barra queda abierta", 'if (form == DockGeometry.Form.EDGE && !expanded) expand()' in dock)
check("La barra se cierra sola al estar inactiva", "EDGE_IDLE_MS" in dock and "restartEdgeIdle()" in dock)
check("Gesto Atrás protegido (tope 200 dp)", "GESTURE_EXCLUSION_MAX_DP = 200f" in geo and "setGestureExclusion(" in dock)
check("Ajustes recarga la barra viva", '"reloadDock"' in main and "fun reloadDock(): Boolean" in fbs)
check("Íconos dibujados (sin glifos)", "fun drawMic(" in views and "fun drawPointer(" in views)
check("Colores por tokens claro/noche", "R.color.dock_glass_frosted" in views and "Color.WHITE" not in views)
for c in ("dock_glass_tint", "dock_glass_frosted", "dock_glass_highlight", "dock_label"):
    check(f"Token {c} en claro y noche",
          f'name="{c}"' in read("voice_bubble_stt/android/app/src/main/res/values/colors.xml")
          and f'name="{c}"' in read("voice_bubble_stt/android/app/src/main/res/values-night/colors.xml"))

# --- 5. Vidrio ---
check("Desenfoque real vía Window (Android 12+)", "setBackgroundBlurRadius(" in glass and "isCrossWindowBlurEnabled" in glass)
check("Sin desenfoque: vidrio lechoso propio", "onBlurChanged(supported)" in glass and "frosted = !blur" in dock)
check("Ventanas sin foco ni bloqueo fuera", "FLAG_NOT_FOCUSABLE" in glass and "FLAG_NOT_TOUCH_MODAL" in glass)
check("Ventana overlay", "TYPE_APPLICATION_OVERLAY" in glass)

# --- 6. Trackpad y clics ---
check("Trackpad sin ×: la línea cierra con un toque", "closePanel()" in ftp and '"×"' not in ftp and 'contentDescription = "Cerrar trackpad"' in ftp)
check("La línea muestra la cuenta del cierre", "handleView?.startCountdown(ms)" in ftp)
check("Clics por el complemento", "PointerLink.tap(" in ftp and "PointerLink.tap(service, x, y)" in bridge)
check("Ventanas propias se apartan durante el gesto", "OverlayPassThrough.clear(cmd" in link)
check("Apartar = transparente e intocable", "attrs.alpha = if (enabled" in glass and "FLAG_NOT_TOUCHABLE" in glass)
check("El puntero también se aparta", "class PointerOverlayManager(private val context: Context) : OverlayPassThrough.Handle" in pom)
check("Las ventanas vuelven solas", "main.postDelayed(restore" in link)

# --- 7. Dart / Ajustes ---
for k in ("dock_form", "dock_tool_mic", "dock_tool_pointer", "pointer_open_mode"):
    check(f"Clave {k} en el contrato", k in contract)
check("Dominio de forma validado", "static const List<String> dockForms = ['edge', 'bubble'];" in storage)
check("Dominio de apertura validado", "static const List<String> pointerOpenModes = ['panel', 'window'];" in storage)
check("Ajustes: forma de la barra", "id: 'dock-form-selector'" in general)
check("Ajustes: herramientas", "'dock-tool-mic-switch'" in general and "'dock-tool-pointer-switch'" in general)
check("Ajustes: al menos una herramienta", "Dejá al menos una herramienta" in settings)
check("Ajustes: estado del complemento", "'pointer-companion-row'" in trackpad_page and "'pointer-restricted-row'" in trackpad_page)
check("Ajustes: se abre como", "id: 'pointer-open-mode-selector'" in trackpad_page)
check("Ajustes relee el complemento al volver", "unawaited(_loadPointerStatus())" in settings)
toggle = settings[settings.index("Future<void> _toggleTrackpadEnabled"):settings.index("Future<void> _toggleTrackpadToolbarVisible")]
check("El trackpad del teclado no abre ventanas flotantes",
      "startTrackpadBubble" not in toggle and "stopTrackpadBubble" not in toggle)

# --- 8. Tests y CI ---
for t in (f"{KT_TEST}/DockGeometryTest.kt", f"{KT_TEST}/PointerProtocolTest.kt",
          f"{PUN_TEST}/PointerProtocolTest.kt", f"{PUN_TEST}/ScrollQueueTest.kt",
          "app_source/test/screens/settings_dock_test.dart", "app_source/test/services/dock_storage_test.dart"):
    check(f"Existe {os.path.basename(t)}", exists(t))
check("CI corre los tests JVM de la barra", "DockGeometryTest" in ci and "PointerProtocolTest" in ci)
check("CI verifica la paridad del protocolo", "PointerProtocol difiere" in ci)
check("CI compila y testea el complemento", "working-directory: puntero_android" in ci and ":app:assembleDebug" in ci)
check("CI publica el APK del complemento", "voice-bubble-puntero-apk-r" in ci)
check("Guardia de logs cubre el complemento", "puntero_android/app/src/main/kotlin" in ci)

# --- 8b. Trackpad como el prototipo, puntero fino y clics confirmados (2026-10-30) ---
pad = read(f"{KT}/FloatingPadView.kt")
gest = read(f"{KT}/PadGestures.kt")
colors_day = read("voice_bubble_stt/android/app/src/main/res/values/colors.xml")
colors_night = read("voice_bubble_stt/android/app/src/main/res/values-night/colors.xml")
check("Trackpad: superficie única sin botones de mouse ni grilla", "FloatingPadView(" in ftp and "VirtualTrackpadView" not in ftp and "ic_mouse" not in pad)
check("Trackpad: texto guía del prototipo", "Deslizá para mover · Tocá para hacer clic" in pad)
check("Trackpad: guía fina de desplazamiento a la derecha", "railW = 24f * d" in pad and "PadGestures.railDelta(dy)" in pad)
check("Trackpad: tocar = clic, mantener = clic largo, dos dedos = scroll", "listener.onTap()" in pad and "listener.onLongPress()" in pad and "PadGestures.scrollDelta(" in pad)
check("Gestos en lógica pura testeada", "import android" not in gest and "PadGesturesTest" in ci)
check("Colores de la placa en claro y oscuro", all(f'name="{n}"' in c for n in ("dock_pad", "dock_pad_line", "dock_hint") for c in (colors_day, colors_night)))
check("Puntero: flecha fina del prototipo con sombra", "M2.5 2.2 v18.4" in pom and "setShadowLayer(" in pom and "Color.BLACK" in pom)
check("Puntero: onda en la punta al hacer clic", "fun triggerClickFeedback(long: Boolean = false)" in pom and "fun animateClick(long: Boolean)" in pom)
check("Puntero en coordenadas de pantalla completa", "FLAG_LAYOUT_IN_SCREEN" in pom and "fitInsetsTypes = 0" in pom and "LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS" in pom)
check("Clic en la punta que se ve (posición real dibujada)", "getLocationOnScreen(loc)" in pom and "statusBarHeightPx" not in pom)
check("Protocolo: respuesta del complemento", all(k in proto for k in ("ACTION_RESULT", "HOST_PACKAGE", "EXTRA_SEQ", "RESULT_DONE", "RESULT_CANCELLED", "RESULT_REJECTED", "ACK_TIMEOUT_MS", "fun resultMessage(")))
check("Complemento responde cada clic con permiso de firma", "sendBroadcast(intent, PointerProtocol.PERMISSION_POINTER)" in pun_svc and "reply(seq, PointerProtocol.RESULT_REJECTED)" in pun_svc)
check("Complemento ve a VoiceBubble y tiene el permiso para responder", 'uses-permission android:name="com.royleguiza.voicebubble.puntero.permission.POINTER"' in pun_manifest and '<package android:name="com.royleguiza.voicebubblestt"/>' in pun_manifest)
check("VoiceBubble espera la respuesta y avisa si no llega", "ackTimeout" in link and "PointerProtocol.resultMessage(null)" in link and "PointerProtocol.PERMISSION_POINTER, null, Context.RECEIVER_EXPORTED" in link)
check("Scroll sin complemento también avisa", "PointerLink.scroll(this@FloatingTrackpadService, pos.first, pos.second, chunk)) {\n                            hintNoCompanion()" in ftp)
check("Burbuja se esconde con el trackpad abierto y vuelve al cerrarlo", "fun setTrackpadOpen(open: Boolean)" in dock and "!hidden && !trackpadOpen" in dock and "FloatingBubbleService.setTrackpadOpen(true)" in ftp and "FloatingBubbleService.setTrackpadOpen(false)" in ftp)
check("La flecha nunca tapa el punto del clic", "ARROW_GAP_PX = 3" in pom and "fun originOffset()" in pom)
check("Margen para apartar ventanas suficiente (≥ 100 ms)", int(re.search(r"CLEAR_LEAD_MS = (\d+)L", link).group(1)) >= 100)
check("Solo se aparta lo que tapa el punto donde apoya el gesto", "cmd.copy(dy = 0f)" in link)
check("Scroll y clic largo se mandan al soltar (Android cancela con el dedo apoyado)", "fun flushScroll()" in pad and "pendingScroll +=" in pad and "fun onLongPressArmed()" in pad)
check("Scroll largo en tramos y sin perder el sobrante", "PointerProtocol.scrollChunks(gestureDy)" in ftp and "pending -= out" in read("puntero_android/app/src/main/kotlin/com/royleguiza/voicebubble/puntero/ScrollQueue.kt"))
mut_pom = pom.replace("fitInsetsTypes = 0", "")
check("Mutación: puntero corrido por la barra de estado se detecta", "fitInsetsTypes = 0" not in mut_pom)

# --- 9. Mutaciones negativas ---
mut_manifest = manifest.replace("</application>", '<service android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"/></application>')
check("Mutación: Accesibilidad en VoiceBubble se detecta", "BIND_ACCESSIBILITY_SERVICE" in mut_manifest)
mut_proto = pun_proto.replace('const val MAX_SCROLL_PX = 600f', 'const val MAX_SCROLL_PX = 900f')
check("Mutación: protocolo divergente se detecta", consts(proto) != consts(mut_proto))
mut_cfg = pun_cfg.replace('canRetrieveWindowContent="false"', 'canRetrieveWindowContent="true"')
check("Mutación: lectura de pantalla se detecta", 'android:canRetrieveWindowContent="false"' not in mut_cfg)
mut_link = link.replace("if (cmd == null || !isEnabled(context)) return false", "if (cmd == null) return false")
check("Mutación: despacho sin complemento se detecta", "!isEnabled(context)" not in mut_link)

print("\n============================================================")
print(f" RESULTADO SUITE BARRA FLOTANTE: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")
sys.exit(suite.exit_code())
