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
5. Superficie sólida (Horizonte fase 4): sin desenfoque de ventana; las
   vistas pintan dock_surface + borde dock_line y el micrófono es el
   agujero con HorizonView en modo CORONA.
6. Trackpad: sin ×, la línea cierra y muestra la cuenta; clics por el
   complemento; nuestras ventanas se apartan durante el gesto.
7. Dart/Ajustes: forma, herramientas, estado del complemento, sin
   arrancar ventanas flotantes desde el trackpad del teclado.
8. CI: tests JVM, paridad del protocolo y APK del complemento.
9. Mutaciones negativas detectadas.
10. Fase 1 del puntero por encima de todo (2026-11-15): puntero y panel del
    trackpad como ventanas TYPE_ACCESSIBILITY_OVERLAY en el complemento,
    fila de sistema, arrastre en dos pasos, protocolo v2, openTrackpad con
    respaldo, Horizonte en el complemento y tests JVM nuevos.
11. Fase 2A (2026-11-15): la barra flotante (borde · burbuja · isla) la dibuja
    el complemento como ventanas TYPE_ACCESSIBILITY_OVERLAY con estado en prefs
    propias; protocolo v3; dictado nativo del host (DockDictationService
    exportado SOLO con el permiso de firma, actividad trampolín); la barra de
    VoiceBubble queda de respaldo y nunca se ven dos.
12. Fase 2B (2026-11-15): Ajustes de Flutter para la isla: forma «Isla»
    (deshabilitada sin el complemento), pantalla «Ajustar isla» con maqueta a
    escala real, deslizadores y ±1 px, lado del micrófono, centrar/restablecer,
    envío en vivo limitado (Throttler) y claves nuevas en el contrato (61).
"""

import os
from pathlib import Path
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
check("Colores por tokens claro/noche", "R.color.dock_surface" in views and "R.color.dock_line" in views and "Color.WHITE" not in views)
for c in ("dock_surface", "dock_line", "dock_label", "dock_tool_pressed", "dock_tool_active", "dock_tool_active_icon"):
    check(f"Token {c} en claro y noche",
          f'name="{c}"' in read("voice_bubble_stt/android/app/src/main/res/values/colors.xml")
          and f'name="{c}"' in read("voice_bubble_stt/android/app/src/main/res/values-night/colors.xml"))

# --- 5. Superficie sólida (Horizonte fase 4: sin blur) ---
BLUR_APIS = ("setBackgroundBlurRadius", "isCrossWindowBlurEnabled", "CrossWindowBlurEnabledListener",
             "blurBehindRadius", "FLAG_BLUR_BEHIND", "createBlurEffect", "BlurMaskFilter")
def has_blur(src):
    return any(api in src for api in BLUR_APIS)
check("Sin desenfoque en ventanas flotantes (GlassWindow, barra, burbuja, trackpad)",
      not any(has_blur(src) for src in (glass, views, dock, fbs, ftp)))
check("GlassWindow sin vidrio: ventana transparente, sin radio de desenfoque ni aviso de blur",
      "class GlassWindow(\n    context: Context,\n    private val content: View,\n)" in glass
      and "cornerRadiusPx" not in glass and "onBlurChanged" not in glass and "frosted" not in dock + views)
check("Superficie sólida propia: dock_surface + borde dock_line de 1 dp",
      "fill.color = palette.surface" in views and "stroke.color = palette.line" in views
      and "stroke.strokeWidth = 1f * d" in views
      and '<color name="dock_surface">@color/hz_surf</color>' in read("voice_bubble_stt/android/app/src/main/res/values/colors.xml")
      and '<color name="dock_line">@color/hz_line</color>' in read("voice_bubble_stt/android/app/src/main/res/values/colors.xml"))
check("Micrófono = agujero con HorizonView CORONA y fases del dictado",
      views.count("HorizonView(context, HorizonView.Mode.CORONA)") == 2
      and '"recording" -> HorizonView.Phase.RECORDING' in views
      and '"transcribing" -> HorizonView.Phase.THINKING' in views
      and "horizon.setPhase(horizonPhaseOf(value))" in views
      and "palette.hole" in views and "palette.ember" in views)
check("Corona detenida al destruir la barra (ciclo de vida)",
      "edgeView.horizon.setPhase(HorizonView.Phase.IDLE)" in dock
      and "bubbleView.horizon.setPhase(HorizonView.Phase.IDLE)" in dock)
check("Herramienta activa en brasa suave + ember-t (como la barra del teclado)",
      "edgeView.pointerActive = open" in dock and "palette.active" in views and "palette.activeIcon" in views)
check("Trackpad flotante con superficie sólida que sigue el tema",
      "applyPanelSurface()" in ftp and "R.color.dock_surface" in ftp and "R.color.dock_line" in ftp)
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
check("Dominio de forma validado (borde, burbuja e isla)", "static const List<String> dockForms = ['edge', 'bubble', 'island'];" in storage)
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
check("Puntero: flecha Horizonte (tinta, borde claro, punto brasa) con sombra",
      "Flecha esbelta «Horizonte»" in pom and "setShadowLayer(" in pom
      and "INK = 0xFF08090E" in pom and "PAPER = 0xFFF7F5F0" in pom and "emberPaint" in pom)
# Diagnóstico (2026-11-14): avisos del complemento dentro del panel (no Toast)
# y prueba de clic con contadores en la app del complemento.
check("Avisos del puntero dentro del panel, sin Toast",
      "Toast.makeText" not in (Path(__file__).parent / "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/FloatingTrackpadService.kt").read_text()
      and "fun checkCompanion()" in (Path(__file__).parent / "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/FloatingTrackpadService.kt").read_text())
check("Complemento: prueba de clic y contadores sin coordenadas",
      "fun testTap(" in pun_svc and "received++" in pun_svc
      and "Probar el clic" in (Path(__file__).parent / "puntero_android/app/src/main/kotlin/com/royleguiza/voicebubble/puntero/MainActivity.kt").read_text())
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
mut_glass = glass.replace("    fun show(x: Int, y: Int, w: Int, h: Int) {",
                          "    fun show(x: Int, y: Int, w: Int, h: Int) {\n        window.setBackgroundBlurRadius(24)", 1)
check("Mutación: reintroducir el blur de GlassWindow se detecta", mut_glass != glass and has_blur(mut_glass))
mut_views = views.replace("fill.color = palette.surface", "fill.color = palette.pressed")
check("Mutación: barra sin superficie sólida se detecta", "fill.color = palette.surface" not in mut_views)

# --- 10. Fase 1: trackpad y puntero en el complemento (por encima de todo) ---
pun_overlay = read(f"{PUN_KT}/PointerOverlay.kt")
pun_panel = read(f"{PUN_KT}/TrackpadPanel.kt")
pun_ctrl = read(f"{PUN_KT}/TrackpadController.kt")
pun_views = read(f"{PUN_KT}/TrackpadViews.kt")
pun_pad = read(f"{PUN_KT}/PadView.kt")
pun_drag = read(f"{PUN_KT}/DragPlan.kt")
pun_geo = read(f"{PUN_KT}/TrackpadGeometry.kt")
pun_kin = read(f"{PUN_KT}/PointerKinematics.kt")
pun_palette = read(f"{PUN_KT}/Palette.kt")
pun_all_kt = "".join(read(f"{PUN_KT}/{f}") for f in sorted(os.listdir(os.path.join(WORKSPACE, PUN_KT))) if f.endswith(".kt"))
pun_res = f"{PUN}/res"
HZ_TOKENS = ("hz_bg", "hz_surf", "hz_surf2", "hz_line", "hz_fg", "hz_fg2", "hz_ember", "hz_ember_t",
             "hz_ember_soft", "hz_on_ember", "hz_hot", "hz_hole", "hz_danger", "hz_ok")

# Ventanas de Accesibilidad por encima de todo
check("Puntero del complemento: TYPE_ACCESSIBILITY_OVERLAY, sin toques ni foco, pantalla completa",
      "TYPE_ACCESSIBILITY_OVERLAY" in pun_overlay and "FLAG_NOT_TOUCHABLE" in pun_overlay and "FLAG_NOT_FOCUSABLE" in pun_overlay
      and "FLAG_LAYOUT_IN_SCREEN" in pun_overlay and "FLAG_LAYOUT_NO_LIMITS" in pun_overlay
      and "fitInsetsTypes = 0" in pun_overlay and "LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS" in pun_overlay)
check("Panel del complemento: TYPE_ACCESSIBILITY_OVERLAY tocable, sin foco y sin bloquear fuera",
      "TYPE_ACCESSIBILITY_OVERLAY" in pun_panel and "FLAG_NOT_FOCUSABLE" in pun_panel
      and "FLAG_NOT_TOUCH_MODAL" in pun_panel and "FLAG_LAYOUT_IN_SCREEN" in pun_panel
      and "FLAG_NOT_TOUCHABLE" in pun_panel and "TYPE_APPLICATION_OVERLAY" not in pun_panel + pun_overlay)
check("El complemento no usa TYPE_APPLICATION_OVERLAY (ni pide SYSTEM_ALERT_WINDOW)",
      "TYPE_APPLICATION_OVERLAY" not in pun_all_kt and "SYSTEM_ALERT_WINDOW" not in pun_manifest)
check("La punta dibujada ES el punto del clic (getLocationOnScreen, sin correrla ni apartarla)",
      "getLocationOnScreen(loc)" in pun_overlay and "ARROW_GAP_PX" not in pun_overlay and "OverlayPassThrough" not in pun_all_kt)
check("Estilos flecha Horizonte / punto / cruz y anillo brasa del clic en los tres",
      "Flecha esbelta «Horizonte»" in pun_overlay and "STYLE_DOT ->" in pun_overlay and "STYLE_CROSS ->" in pun_overlay
      and "INK = 0xFF08090E" in pun_overlay and "PAPER = 0xFFF7F5F0" in pun_overlay
      and "fun triggerClickFeedback(long: Boolean = false)" in pun_overlay and "rippleAnim" in pun_overlay)
check("Anillo brasa fijo del origen del arrastre, dibujado por PointerOverlay",
      "fun setOrigin(x: Float, y: Float)" in pun_overlay and "fun clearOrigin()" in pun_overlay and "class OriginMarkView" in pun_overlay)
check("Panel: superficie surf + borde line de 1 dp, radio 30, modos panel y window",
      "cornerRadius = 30 * d" in pun_panel and "palette.surf" in pun_panel and "palette.line" in pun_panel
      and "MODE_WINDOW" in pun_panel and "TrackpadGeometry.open(" in pun_panel)
check("Geometría: panel con margen 10 dp sobre la barra de navegación y ventana de 280 dp",
      "PANEL_MARGIN_DP = 10f" in pun_geo and "WINDOW_WIDTH_DP = 280f" in pun_geo and "bottomInset" in pun_geo)
check("Agarradera: un toque cierra y muestra la cuenta del cierre automático",
      "host.onCloseRequested()" in pun_panel and 'contentDescription = "Cerrar trackpad"' in pun_panel
      and "fun startCountdown(totalMs: Long)" in pun_views and "handle.startCountdown(ms)" in pun_panel)

# Fila de sistema
check("Fila de sistema: Atrás, Inicio, Recientes y Notificaciones por performGlobalAction",
      all(a in pun_panel for a in ("GLOBAL_ACTION_BACK", "GLOBAL_ACTION_HOME", "GLOBAL_ACTION_RECENTS", "GLOBAL_ACTION_NOTIFICATIONS"))
      and "performGlobalAction(action)" in pun_svc)
check("Botones circulares de 44 dp con contentDescription en español",
      "SIZE_DP = 44f" in pun_views
      and all(f'"{t}"' in pun_panel for t in ("Atrás", "Inicio", "Recientes", "Notificaciones", "Arrastrar")))
check("Íconos de trazo 2.2 en fg; Arrastrar activo en brasa suave",
      "STROKE_UNITS = 2.2f" in pun_views and "palette.fg" in pun_views and "palette.emberSoft" in pun_views and "palette.emberT" in pun_views)
check("Sin glifos ni imágenes: los íconos se dibujan en código", "enum class Icon" in pun_views and "drawable" not in pun_views)

# Gestos directos, siempre al soltar
check("Gestos directos con dispatchGesture, sin broadcast por clic",
      "dispatchGesture(" in pun_svc and "service.press(" in pun_ctrl and "service.scrollBy(" in pun_ctrl
      and "sendBroadcast" not in pun_ctrl + pun_panel + pun_pad)
check("Tap 40 ms, clic largo 450 ms y scroll por la cola existente",
      "PointerProtocol.TAP_MS" in pun_ctrl and "PointerProtocol.LONG_PRESS_MS" in pun_ctrl
      and "scroll.add(x, y, dy)" in pun_svc and "PointerProtocol.scrollChunks(gestureDy)" in pun_ctrl)
check("Todo se despacha AL SOLTAR (tap en ACTION_UP, clic largo armado, scroll acumulado)",
      "PadGestures.Action.Tap ->" in pun_pad and "fun flushScroll()" in pun_pad and "pendingScroll +=" in pun_pad
      and "fun onLongPressArmed()" in pun_pad)
check("Con el puntero bajo el panel, el panel deja pasar el gesto (y vuelve)",
      "p.setPassThrough(true)" in pun_ctrl and "restorePanel" in pun_ctrl and "FLAG_NOT_TOUCHABLE" in pun_panel)
check("Háptico por performHapticFeedback (sin permiso VIBRATE) respetando none/subtle/firm",
      "performHapticFeedback" in pun_pad and "HAPTIC_NONE" in pun_pad and "HAPTIC_FIRM" in pun_pad and "VIBRATE" not in pun_manifest)

# Arrastre en dos pasos
check("Arrastre: botón, primer toque agarra, segundo suelta, el modo se apaga solo",
      "override fun onDragButton()" in pun_ctrl and "private fun dragTouch()" in pun_ctrl
      and "ptr.setOrigin(" in pun_ctrl and "dragOn = false" in pun_ctrl and "DragPlan.of(" in pun_ctrl)
check("Arrastre: UN gesto de dos trazos continuos (willContinue) de 550 ms + 400 ms",
      "continueStroke(" in pun_svc and "DragPlan.HOLD_MS, true" in pun_svc and "DragPlan.MOVE_MS, false" in pun_svc
      and "HOLD_MS = 550L" in pun_drag and "MOVE_MS = 400L" in pun_drag)
check("Arrastre: construcción pura (sin android.*) con recorte a pantalla",
      "import android" not in pun_drag and "coerceIn(0f, maxX)" in pun_drag)
check("Arrastre: no se cierra solo a medias y se cancela al cerrar o girar",
      "dragOn) return" in pun_ctrl and "resetDrag()" in pun_ctrl)

# Ciclo de vida
check("Receptores y ventanas se sueltan al desvincular o destruir el servicio",
      "trackpad?.destroy()" in pun_svc and "unregisterReceiver(receiver)" in pun_svc
      and "handler.removeCallbacksAndMessages(null)" in pun_ctrl and "removeViewImmediate" in pun_panel + pun_overlay)
check("Cambios de orientación y tamaño de pantalla reacomodan las ventanas",
      "override fun onConfigurationChanged" in pun_svc and "fun onScreenChanged()" in pun_overlay + pun_panel
      and "TrackpadGeometry.refit(" in pun_panel)
check("Sin temporizadores sueltos: todo Handler del complemento se limpia",
      "removeCallbacks(idleClose)" in pun_ctrl and "removeCallbacks(longPressCheck)" in pun_pad)

# Protocolo v2
for c in ("ACTION_OPEN_TRACKPAD", "ACTION_CLOSE_TRACKPAD", "ACTION_TRACKPAD_STATE", "EXTRA_ANCHOR_X", "EXTRA_ANCHOR_Y",
          "EXTRA_MODE", "EXTRA_SENSITIVITY", "EXTRA_ACCEL", "EXTRA_STYLE", "EXTRA_HAPTIC", "EXTRA_SCROLL_DIR",
          "EXTRA_AUTO_RETURN", "EXTRA_OPEN"):
    check(f"Protocolo v2: {c} en las dos apps", f"const val {c} =" in proto and f"const val {c} =" in pun_proto)
check("Protocolo v2 idéntico (const val) en las dos apps y con más líneas que la v1",
      consts(proto) == consts(pun_proto) and len(consts(proto)) >= 45)
check("Las acciones v2 son del paquete del complemento",
      all(f'"com.royleguiza.voicebubble.puntero.{n}"' in proto for n in ("ACTION_OPEN_TRACKPAD", "ACTION_CLOSE_TRACKPAD", "ACTION_TRACKPAD_STATE")))
check("Configuración de OPEN_TRACKPAD validada con función pura",
      "fun normalizeTrackpadConfig(" in proto and "fun normalizeTrackpadConfig(" in pun_proto and "PointerProtocol.normalizeTrackpadConfig(" in pun_svc)
check("OP_TAP / OP_LONG_PRESS / OP_SCROLL por broadcast se conservan (trackpad del teclado)",
      all(c in pun_proto for c in ('const val OP_TAP = "tap"', 'const val OP_LONG_PRESS = "long_press"', 'const val OP_SCROLL = "scroll"'))
      and "PointerProtocol.OP_TAP -> press(" in pun_svc and "PointerLink.tap(service, x, y)" in bridge)
check("El complemento recibe OPEN/CLOSE con el permiso de firma y sigue validando órdenes",
      "addAction(PointerProtocol.ACTION_OPEN_TRACKPAD)" in pun_svc and "addAction(PointerProtocol.ACTION_CLOSE_TRACKPAD)" in pun_svc
      and "registerReceiver(receiver, filter, PointerProtocol.PERMISSION_POINTER" in pun_svc)
check("TRACKPAD_STATE: al abrir y al cerrar, solo a VoiceBubble y con permiso de firma",
      "setPackage(PointerProtocol.HOST_PACKAGE)" in pun_svc and "PointerProtocol.EXTRA_OPEN" in pun_svc
      and "announce(true)" in pun_ctrl and "announce(false)" in pun_ctrl and "service.sendTrackpadState(open)" in pun_ctrl)
check("Complemento: accessibility config sin lectura de pantalla ni permisos nuevos",
      'android:canRetrieveWindowContent="false"' in pun_cfg
      and re.findall(r'<uses-permission android:name="([^"]+)"', pun_manifest) == [perm])

# Host: openTrackpad con respaldo
check("Host: PointerLink.openTrackpad pide abrir solo si el complemento está listo",
      "fun openTrackpad(context: Context, anchorX: Int, anchorY: Int, onNoAnswer: (() -> Unit)? = null): Boolean" in link
      and "if (!isReady(context)) return false" in link
      and "Intent(PointerProtocol.ACTION_OPEN_TRACKPAD)" in link and "setPackage(PointerProtocol.COMPANION_PACKAGE)" in link)
check("Host: openTrackpad lee las prefs de Flutter del trackpad y las normaliza",
      '"flutter.$key"' in link and "FlutterSharedPreferences" in link
      and all(f'"{k}"' in link for k in ("pointer_open_mode", "kb_trackpad_accel_curve", "kb_trackpad_pointer_style", "kb_trackpad_haptic"))
      and all(f'"flutter.{k}"' in link for k in ("kb_trackpad_sensitivity", "kb_trackpad_auto_return"))
      and "kb_trackpad_scroll_direction" in link and "PointerProtocol.normalizeTrackpadConfig(" in link)
check("Host: la herramienta Puntero usa primero el complemento y cae al trackpad de siempre",
      "if (!PointerLink.openTrackpad(this@FloatingBubbleService, anchorX, anchorY, onNoAnswer = fallback)) {" in fbs
      and "FloatingTrackpadService.open(this@FloatingBubbleService, anchorX, anchorY)" in fbs
      and "fallback()" in fbs.split("PointerLink.openTrackpad(")[1][:200])
check("Host: si el complemento no contesta en 2,5 s, se abre el respaldo",
      "OPEN_ANSWER_MS = 2500L" in link and "if (open) FloatingTrackpadService.stop(this)" in fbs and "main.postDelayed(openTimeout, OPEN_ANSWER_MS)" in link
      and "main.removeCallbacks(openTimeout)" in link and "val fallback = { FloatingTrackpadService.open(" in fbs)
check("Complemento: el arrastre encadena dos gestos (la continuación va en el siguiente)",
      "grab.continueStroke(move, 0L, DragPlan.MOVE_MS, false)" in pun_svc
      and "addStroke(grab).addStroke(carry)" not in pun_svc)
check("Host: FloatingTrackpadService se conserva como respaldo", exists(f"{KT}/FloatingTrackpadService.kt") and 'android:name=".FloatingTrackpadService"' in manifest)
check("Host: escucha TRACKPAD_STATE con permiso de firma mientras vive el servicio",
      "fun listenTrackpadState(" in link and "IntentFilter(PointerProtocol.ACTION_TRACKPAD_STATE)" in link
      and "PointerProtocol.PERMISSION_POINTER, null, Context.RECEIVER_EXPORTED" in link
      and "PointerLink.listenTrackpadState(this)" in fbs and "dock?.setTrackpadOpen(open)" in fbs
      and "PointerLink.stopListeningTrackpadState(this)" in fbs)
check("Host: <queries> y permiso de firma ya cubren el protocolo v2",
      '<package android:name="com.royleguiza.voicebubble.puntero"/>' in manifest and f'<uses-permission android:name="{perm}"/>' in manifest)

# Horizonte en el complemento
colors_pun_day = read(f"{pun_res}/values/colors.xml")
colors_pun_night = read(f"{pun_res}/values-night/colors.xml")
colors_host_day = read("voice_bubble_stt/android/app/src/main/res/values/colors.xml")
colors_host_night = read("voice_bubble_stt/android/app/src/main/res/values-night/colors.xml")
def tok(src, name):
    m = re.search(r'<color name="' + name + r'">([^<]+)</color>', src)
    return m.group(1) if m else None
check("Complemento: tokens hz_* día y noche con los mismos valores que VoiceBubble",
      all(tok(colors_pun_day, t) is not None and tok(colors_pun_day, t) == tok(colors_host_day, t)
          and tok(colors_pun_night, t) is not None and tok(colors_pun_night, t) == tok(colors_host_night, t) for t in HZ_TOKENS))
check("Complemento: pantalla con tokens Horizonte (brasa con texto on-ember, tarjetas surf + line)",
      "R.color.hz_ember" in pun_main and "R.color.hz_on_ember" in pun_main and "R.color.hz_surf" in pun_main
      and "R.color.hz_line" in pun_main and "Color.parseColor" not in pun_main)
check("Complemento: sin colores genéricos viejos (azul del sistema)",
      all(re.search(r'name="' + n + r'"', colors_pun_day) is None for n in ("accent", "on_accent", "surface", "label", "secondary", "warn")))
check("Complemento: fuentes Horizonte (Sora semibold, Inter regular y medium) en res/font",
      all(exists(f"{pun_res}/font/{f}") for f in ("sora_semibold.ttf", "inter_regular.ttf", "inter_medium.ttf"))
      and "R.font.sora_semibold" in pun_palette and "R.font.inter_regular" in pun_palette and "R.font.inter_medium" in pun_palette
      and "Fonts.sora(this)" in pun_main)
check("Complemento: tema claro/oscuro del sistema (values-night con estilo propio)",
      exists(f"{pun_res}/values-night/styles.xml") and "hz_bg" in read(f"{pun_res}/values-night/styles.xml"))
check("Complemento sin androidx ni dependencias externas",
      "androidx" not in pun_all_kt + pun_gradle and re.search(r'^\s*implementation\(', pun_gradle, re.M) is None)

# Privacidad
check("Cero logs en todo el complemento", "Log." not in pun_all_kt and "println(" not in pun_all_kt)
# Fase 2A: la barra guarda SU estado en prefs propias (DockPrefs). Los contadores del
# clic siguen solo en memoria y ningún otro archivo del complemento toca el disco.
_pun_without_prefs = "".join(read(f"{PUN_KT}/{f}") for f in sorted(os.listdir(os.path.join(WORKSPACE, PUN_KT)))
                             if f.endswith(".kt") and f != "DockPrefs.kt")
check("Contadores solo en memoria (el único disco del complemento es DockPrefs, con ajustes de la barra)",
      "SharedPreferences" not in _pun_without_prefs and "openFileOutput" not in pun_all_kt and "File(" not in pun_all_kt
      and "received++" in pun_svc and "SharedPreferences" in read(f"{PUN_KT}/DockPrefs.kt"))

# Tests JVM nuevos
for t in ("PadGesturesTest.kt", "DragPlanTest.kt", "PointerKinematicsTest.kt", "TrackpadGeometryTest.kt"):
    check(f"Existe {t} en el complemento", exists(f"{PUN_TEST}/{t}"))
check("Test de la validación de OPEN_TRACKPAD en las dos apps",
      "normalizeTrackpadConfig" in read(f"{PUN_TEST}/PointerProtocolTest.kt") and "normalizeTrackpadConfig" in read(f"{KT_TEST}/PointerProtocolTest.kt"))
check("Test del gesto de arrastre (550 + 400 ms, recorte a pantalla)",
      "HOLD_MS" in read(f"{PUN_TEST}/DragPlanTest.kt") and "recorta origen y destino" in read(f"{PUN_TEST}/DragPlanTest.kt"))
check("CI: el complemento corre sus tests JVM y el protocolo se compara",
      ":app:testDebugUnitTest" in ci and "PointerProtocol difiere" in ci)

# Mutaciones de la fase 1
mut_overlay = pun_overlay.replace("TYPE_ACCESSIBILITY_OVERLAY", "TYPE_APPLICATION_OVERLAY")
check("Mutación: puntero del complemento como overlay de app se detecta", "TYPE_ACCESSIBILITY_OVERLAY" not in mut_overlay)
mut_proto2 = pun_proto.replace('const val ACTION_CLOSE_TRACKPAD = "com.royleguiza.voicebubble.puntero.ACTION_CLOSE_TRACKPAD"', '')
check("Mutación: protocolo v2 incompleto en el complemento se detecta", consts(proto) != consts(mut_proto2))
mut_fbs = fbs.replace("if (!PointerLink.openTrackpad(this@FloatingBubbleService, anchorX, anchorY, onNoAnswer = fallback)) {", "if (true) {")
check("Mutación: herramienta Puntero sin el complemento primero se detecta", "PointerLink.openTrackpad(" not in mut_fbs)
mut_cfg2 = pun_cfg.replace('canRetrieveWindowContent="false"', 'canRetrieveWindowContent="true"')
check("Mutación: lectura de pantalla en el complemento se detecta", 'android:canRetrieveWindowContent="false"' not in mut_cfg2)
mut_svc = pun_svc.replace("trackpad?.destroy()", "")
check("Mutación: ventanas sin quitar al desvincular se detecta", "trackpad?.destroy()" not in mut_svc)


# --- 11. Fase 2A: la barra flotante en el complemento + isla + dictado nativo ---
ISL = lambda n: read(f"{PUN_KT}/{n}")
d_win = ISL("DockWindow.kt")
d_mgr = ISL("DockManager.kt")
d_ctrl = ISL("DockController.kt")
d_isl_ctrl = ISL("IslandController.kt")
d_isl_view = ISL("IslandView.kt")
d_isl_geo = ISL("IslandGeometry.kt")
d_geo = ISL("DockGeometry.kt")
d_views = ISL("DockViews.kt")
d_horizon = ISL("HorizonView.kt")
d_prefs = ISL("DockPrefs.kt")
d_host_link = ISL("HostLink.kt")
d_tracker = ISL("MicStateTracker.kt")
d_surface = ISL("DockSurface.kt")
dock_pun_all = d_win + d_mgr + d_ctrl + d_isl_ctrl + d_isl_view + d_isl_geo + d_geo + d_views + d_horizon + d_prefs + d_host_link + d_tracker + d_surface
h_dlink = read(f"{KT}/DockLink.kt")
h_dsvc = read(f"{KT}/DockDictationService.kt")
h_dlogic = read(f"{KT}/DockDictationLogic.kt")
h_tramp = read(f"{KT}/DockTrampolineActivity.kt")
h_feedback = read(f"{KT}/DockMicFeedback.kt")
ISLA_HTML = "laboratorio_ui/isla.html"

def component(tag, name):
    """El bloque <tag ...> del manifiesto (sin comentarios) cuyo android:name es `name`."""
    m = re.search(r'<' + tag + r'\b[^>]*android:name="' + re.escape(name) + r'"[^>]*?(?:/>|>)', manifest, re.S)
    return m.group(0) if m else ""

# Ventanas: overlay de accesibilidad, no de aplicación
check("Barra del complemento: ventanas TYPE_ACCESSIBILITY_OVERLAY (por encima de la barra de estado y la cortina)",
      "TYPE_ACCESSIBILITY_OVERLAY" in d_win and "TYPE_APPLICATION_OVERLAY" not in dock_pun_all and "Dialog" not in d_win)
check("Barra del complemento: sin foco, sin bloquear toques fuera, en pantalla, sin insets y con la cámara incluida",
      all(k in d_win for k in ("FLAG_NOT_FOCUSABLE", "FLAG_NOT_TOUCH_MODAL", "FLAG_LAYOUT_IN_SCREEN", "fitInsetsTypes = 0",
                               "LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS")))
check("Solo la isla va sin límites de pantalla (sobre la barra de estado y la cámara)",
      "noLimits: Boolean = false" in d_win and "FLAG_LAYOUT_NO_LIMITS" in d_win
      and "DockWindow(windowManager, view, noLimits = true)" in d_isl_ctrl
      and "noLimits" not in d_ctrl)
check("Barra del complemento sin desenfoque ni vidrio (Horizonte: superficie sólida)",
      not any(has_blur(src) for src in (d_win, d_ctrl, d_views, d_isl_view, d_isl_ctrl, d_horizon)))
check("Barra del complemento: sin androidx, sin Log, sin parseColor",
      "androidx" not in dock_pun_all and "Log." not in dock_pun_all and "parseColor" not in dock_pun_all)
check("Barra del complemento: colores por tokens (hz_* y island_*), el negro de la isla igual de día y de noche",
      "R.color.hz_hole" in read(f"{PUN_KT}/Palette.kt") and "R.color.island_bg" in read(f"{PUN_KT}/Palette.kt")
      and tok(colors_pun_day, "island_bg") == "#FF000000" == tok(colors_pun_night, "island_bg")
      and tok(colors_pun_day, "island_line") == "#FF23252E" == tok(colors_pun_night, "island_line")
      and tok(colors_pun_day, "hz_on_hole") == tok(colors_host_day, "hz_on_hole")
      and tok(colors_pun_night, "hz_on_hole") == tok(colors_host_night, "hz_on_hole"))
check("Complemento: fuente mono (JetBrains Mono) y su licencia OFL empaquetadas",
      exists(f"{pun_res}/font/jetbrains_mono_medium.ttf") and exists(f"{pun_res}/raw/ofl_jetbrains_mono.txt")
      and "R.font.jetbrains_mono_medium" in read(f"{PUN_KT}/Palette.kt"))

# Port de la barra sin duplicar lógica
check("Port: DockGeometry, DockViews, HorizonView y DockController viven en el complemento",
      all(exists(f"{PUN_KT}/{f}") for f in ("DockGeometry.kt", "DockViews.kt", "HorizonView.kt", "DockController.kt", "DockWindow.kt")))
check("Port: mismas medidas y reglas que el host (lengüeta 7 dp, burbuja 56, tope 200 dp del gesto Atrás)",
      all(f"{k} = {v}" in d_geo and f"{k} = {v}" in geo for k, v in
          (("COLLAPSED_W_DP", "7f"), ("BUBBLE_DP", "56f"), ("GESTURE_EXCLUSION_MAX_DP", "200f"), ("EDGE_IDLE_MS", "4000L"))))
check("Port: tres formas con la isla; el host la ve como burbuja y no pisa la preferencia",
      'ISLAND("island")' in d_geo and 'EDGE("edge")' in d_geo and 'BUBBLE("bubble")' in d_geo
      and 'PREF_ISLAND = "island"' in geo and "if (value == PREF_ISLAND) BUBBLE" in geo
      and 'DockGeometry.Form.fromPref(flutterPrefs.getString(PREF_FORM, null)) != form' in dock)
check("Port: una sola barra a la vez en el complemento (DockManager elige la superficie según la forma)",
      "IslandController(service, windowManager, screen, palette, this, level)" in d_mgr
      and "DockController(service, windowManager, screen, palette, prefs, this, level)" in d_mgr
      and "surfaceIsIsland != wantIsland" in d_mgr and "dropSurface()" in d_mgr
      and "interface DockSurface" in d_surface and ": DockSurface" in d_ctrl and ": DockSurface" in d_isl_ctrl)
check("Port: mismo comportamiento de la barra (convertir por gesto, soltar contra el borde, abanico, Atrás protegido, cierre solo)",
      all(k in d_ctrl for k in ("DockGeometry.shouldBecomeBubble(side, dx, d)", "DockGeometry.snapSide(", "openArc()",
                                "setGestureExclusion(", "EDGE_IDLE_MS", "restartEdgeIdle()", "TapAction.RUN_ONLY_TOOL")))
check("Port: sin historial (toque largo anotado para la fase 4)",
      "requestHistory" not in d_ctrl and "fase 4" in d_ctrl)
check("La forma elegida con el dedo se recuerda en el complemento y se le cuenta a VoiceBubble",
      "callbacks.onFormChanged(form.pref)" in d_ctrl and "prefs.saveForm(form)" in d_mgr
      and "HostLink.state(service, announced ?: true, form)" in d_mgr
      and "PointerProtocol.EXTRA_DOCK_FORM" in d_host_link
      and 'putString(DockController.PREF_FORM, form)' in h_dlink)
check("Herramienta Puntero abre el trackpad del complemento directo, sin broadcast",
      "service.openTrackpadFromDock(" in d_mgr and "fun openTrackpadFromDock(" in pun_svc and "sendBroadcast" not in d_mgr)
check("El trackpad avisa a la barra del complemento (la burbuja se esconde, la isla enciende el puntero)",
      "dock?.setTrackpadOpen(open)" in pun_svc and "edgeView.pointerActive = open" in d_ctrl and "view.pointerActive = open" in d_isl_ctrl)

# Isla
check("Isla: cuatro estados (sin paso «abierta») con las medidas de la maqueta",
      "enum class State { IDLE, REC, THINK, DONE }" in d_isl_geo and "OPEN_W_DP" not in d_isl_geo
      and all(f"{k} = {v}" in d_isl_geo for k, v in (
          ("DEFAULT_W_DP", "112f"), ("DEFAULT_H_DP", "30f"),
          ("REC_W_DP", "252f"), ("REC_H_DP", "44f"), ("DONE_W_DP", "128f"), ("DONE_H_DP", "34f"),
          ("REC_HOLE_DP", "32f"), ("DONE_MS", "1300L"),
          ("MORPH_MS", "420L"))))
check("Isla: x = centro horizontal, y = borde superior, siempre dentro de la pantalla (recorte), también en pantallas angostas",
      "fun bounds(" in d_isl_geo and "val left = clamp(cx - w / 2, margin, screenW - w - margin)" in d_isl_geo
      and "val t = clamp(y, 0, screenH - h)" in d_isl_geo and "fun fitWidth(" in d_isl_geo.replace("private ", "")
      and "IslandGeometry.bounds(" in d_isl_ctrl)
check("Isla: ancho y alto en reposo acotados (72–180 dp y 22–48 dp)",
      all(f"{k} = {v}" in d_isl_geo for k, v in (("MIN_W_DP", "72f"), ("MAX_W_DP", "180f"), ("MIN_H_DP", "22f"), ("MAX_H_DP", "48f"))))
check("Isla: rebote de tamaño con overshoot leve y una sola ventana (unión de los dos tamaños solo mientras dura)",
      "OvershootInterpolator(" in d_isl_ctrl and "IslandGeometry.animationWindow(" in d_isl_ctrl
      and "w.setBounds(to.x, to.y, to.w, to.h)" in d_isl_ctrl)
check("Isla: con «quitar animaciones» del sistema el tamaño cambia directo",
      "ValueAnimator.areAnimatorsEnabled()" in d_isl_ctrl and "ValueAnimator.areAnimatorsEnabled()" in d_horizon)
check("Isla: píldora negra con borde de 1 dp y anillo brasa exterior grabando",
      "palette.islandBg" in d_isl_view and "palette.islandLine" in d_isl_view and "1.5f * d" in d_isl_view
      and "palette.ember" in d_isl_view)
check("Isla: la voz cae hacia el agujero (símbolos 0 1 { }) y pensando salen rayitas; sigue el nivel",
      "Mode { CORONA, HOLE, VOICE }" in d_horizon and "charArrayOf('0', '1', '{', '}')" in d_horizon
      and "holeOnLeft" in d_horizon and "levelSource" in d_horizon and "spinArc(" in d_horizon)
check("Isla: el lado del micrófono es configurable y el puntero va del otro (diseño en espejo)",
      "micOnLeft" in d_isl_geo and "fun mx(x: Int) = if (micOnLeft) x else w - x" in d_isl_geo
      and "cfg.micOnLeft" in d_isl_ctrl and "voiceView.holeOnLeft = micOnLeft" in d_isl_view)
check("Isla: en reposo cada mitad es su botón (micrófono o puntero), sin paso intermedio; con una sola herramienta, toda la isla",
      "fun idleTapTool(xInPill: Float, w: Int, micOnLeft: Boolean, hasMic: Boolean, hasPointer: Boolean): Tool" in d_isl_geo
      and "if ((xInPill < w / 2f) == micOnLeft) Tool.MIC else Tool.POINTER" in d_isl_geo
      and "IslandGeometry.idleTapTool(xInPill, w, c.micOnLeft, c.toolMic, c.toolPointer)" in d_isl_ctrl
      and "State.OPEN" not in d_isl_ctrl and "State.OPEN" not in d_isl_view)
check("Isla: grabando, tocar cualquier parte de la píldora termina (el dedo no busca el agujero)",
      "IslandGeometry.State.REC -> onMicTap?.invoke()" in d_isl_view
      and "isClickable = state == IslandGeometry.State.IDLE || state == IslandGeometry.State.REC" in d_isl_view)
check("Isla: cronómetro mono, ✕ de cancelar y terminar al tocar el agujero",
      "Fonts.mono(context)" in d_isl_view and "onCancelTap" in d_isl_view and "callbacks.onMicCancel()" in d_isl_ctrl
      and "callbacks.onMicTap()" in d_isl_ctrl)
check("Isla: listo muestra una frase corta y se ensancha lo justo (errores con «!» y más tiempo)",
      "fun doneWidth(" in d_isl_geo and "ERROR_MS" in d_isl_ctrl and "doneIsError" in d_isl_view)
check("Isla: accesibilidad en español (cada botón con contentDescription y región polite)",
      all(t in d_isl_view for t in ('"Dictar"', '"Terminar dictado"', '"Cancelar dictado"', '"Abrir el puntero"',
                                    "Isla de VoiceBubble", "ACCESSIBILITY_LIVE_REGION_POLITE"))
      and "AccessibilityNodeInfo.AccessibilityAction(DockController.ACTION_DICTATE" in d_isl_view
      and "AccessibilityNodeInfo.AccessibilityAction(DockController.ACTION_POINTER" in d_isl_view)
check("Barra y burbuja del complemento: acciones de TalkBack Dictar y Abrir el puntero",
      '"Dictar"' in d_ctrl and '"Abrir el puntero"' in d_ctrl and "AccessibilityNodeInfo.AccessibilityAction(" in d_ctrl
      and 'contentDescription = "Barra flotante de VoiceBubble"' in d_ctrl)
check("Maqueta de la isla copiada a laboratorio_ui/isla.html", exists(ISLA_HTML) and "Isla VoiceBubble" in read(ISLA_HTML) and "id=\"isla\"" in read(ISLA_HTML))

# Prefs propias y arranque
check("Estado en prefs PROPIAS del complemento (vb_puntero_dock): configuración y posición",
      '"vb_puntero_dock"' in d_prefs and "fun loadConfig()" in d_prefs and "fun saveConfig(" in d_prefs
      and "fun savePosition(" in d_prefs and "PointerProtocol.normalizeDockConfig(" in d_prefs
      and "FlutterSharedPreferences" not in dock_pun_all)
check("Sin configuración guardada la barra no se dibuja (enabled = false) hasta que VoiceBubble la encienda",
      "enabled = false," in d_prefs and "prefs.getBoolean(K_ENABLED, false)" in d_prefs)
check("Al conectarse el servicio dibuja lo guardado y manda DOCK_HELLO (la barra vuelve sola tras reiniciar)",
      "if (dock == null) dock = DockManager(this)" in pun_svc and "dock?.start()" in pun_svc
      and "HostLink.hello(service)" in d_mgr and "config = prefs.loadConfig()" in d_mgr)
check("El receptor del servicio escucha DOCK_CONFIG y MIC_STATE con el permiso de firma",
      "addAction(PointerProtocol.ACTION_DOCK_CONFIG)" in pun_svc and "addAction(PointerProtocol.ACTION_MIC_STATE)" in pun_svc
      and "dock?.onDockConfig(intent)" in pun_svc and "dock?.onMicState(intent)" in pun_svc
      and "registerReceiver(receiver, filter, PointerProtocol.PERMISSION_POINTER" in pun_svc)
check("DOCK_CONFIG se valida, se guarda y se aplica en vivo",
      "PointerProtocol.normalizeDockConfig(" in d_mgr and "prefs.saveConfig(cfg)" in d_mgr and "apply(force =" in d_mgr
      and "s.applyConfig(cfg)" in d_mgr)
check("Con la barra apagada en Ajustes el complemento no dibuja nada y se lo dice al host",
      "if (!cfg.enabled) {" in d_mgr and "announce(false, force)" in d_mgr)
check("El complemento dice si dibuja (DOCK_STATE active) solo si Android dejó crear la ventana",
      "announce(s.isDrawing(), force)" in d_mgr and "override fun isDrawing()" in d_ctrl and "override fun isDrawing()" in d_isl_ctrl
      and "PointerProtocol.EXTRA_ACTIVE" in d_host_link)

# Ciclo de vida
check("Ciclo de vida: onUnbind/onDestroy destruyen la barra (ventanas, animadores, temporizadores) y avisan",
      "dock?.destroy()" in pun_svc and "unregister()" in pun_svc.split("override fun onUnbind")[1]
      and "handler.removeCallbacksAndMessages(null)" in d_mgr and "dropSurface()" in d_mgr
      and "HostLink.state(service, false)" in d_mgr)
check("Ciclo de vida: DockController e IslandController no dejan nada corriendo al destruirse",
      "handler.removeCallbacksAndMessages(null)" in d_ctrl and "openAnimator?.cancel()" in d_ctrl and "closeArcNow()" in d_ctrl
      and "edgeWindow?.dismiss()" in d_ctrl and "bubbleWindow?.dismiss()" in d_ctrl
      and "handler.removeCallbacksAndMessages(null)" in d_isl_ctrl and "morphAnimator?.cancel()" in d_isl_ctrl
      and "window?.dismiss()" in d_isl_ctrl and "view.stopAnimations()" in d_isl_ctrl)
check("Ciclo de vida: giro, tamaño de pantalla y tema reacomodan la barra",
      "dock?.onConfigurationChanged()" in pun_svc and "palette.reload()" in d_mgr and "surface?.onConfigurationChanged()" in d_mgr
      and "prefs.centerYFrac() * sh" in d_ctrl and "settle()" in d_isl_ctrl)
check("Ciclo de vida: el vigilante vuelve a reposo si el host muere a mitad de un dictado",
      "fun isStale(" in d_tracker and "MIC_STALE_MS" in d_tracker and "tracker.isStale(now)" in d_mgr and "staleCheck" in d_mgr)

# Protocolo v3
V3 = ("ACTION_DOCK_CONFIG", "ACTION_MIC_STATE", "ACTION_DOCK_HELLO", "ACTION_DOCK_STATE", "EXTRA_DOCK_ENABLED", "EXTRA_DOCK_FORM",
      "EXTRA_TOOL_MIC", "EXTRA_TOOL_POINTER", "EXTRA_ISLAND_X", "EXTRA_ISLAND_Y", "EXTRA_ISLAND_W", "EXTRA_ISLAND_H",
      "EXTRA_ISLAND_SIDE", "EXTRA_ACTIVE", "EXTRA_MIC_STATE", "EXTRA_MIC_LEVEL", "EXTRA_MIC_MESSAGE", "MIC_RECORDING",
      "MIC_TRANSCRIBING", "MIC_DONE", "MIC_ERROR", "MIC_IDLE", "FORM_ISLAND", "MIC_LEVEL_EVERY_MS")
check("Protocolo v3: las mismas const val en las dos apps (DOCK_CONFIG, MIC_STATE, DOCK_HELLO, DOCK_STATE y extras)",
      all(f"const val {c} =" in proto and f"const val {c} =" in pun_proto for c in V3) and consts(proto) == consts(pun_proto)
      and "fun normalizeDockConfig(" in proto and "fun normalizeDockConfig(" in pun_proto
      and "fun normalizeMicState(" in proto and "fun normalizeMicState(" in pun_proto)
check("Protocolo v3: el nivel de voz va como mucho a 15 Hz",
      "const val MIC_LEVEL_EVERY_MS = 70L" in proto and "PointerProtocol.MIC_LEVEL_EVERY_MS" in h_dsvc)
check("Protocolo v3: el audio y el texto nunca pasan por el complemento (solo estados y frases fijas)",
      "TranscriptionHistoryRepository" not in dock_pun_all and "SpeechToTextClient" not in dock_pun_all
      and "ClipboardManager" not in dock_pun_all and "MAX_MIC_MESSAGE" in proto
      and "nunca texto dictado" in proto and "putExtra(PointerProtocol.EXTRA_MIC_MESSAGE, message)" in h_dlink)

# Host: dictado nativo
dsvc_tag = component("service", ".DockDictationService")
tramp_tag = component("activity", ".DockTrampolineActivity")
recv_tag = component("receiver", ".DockLinkReceiver")
SIGN = f'android:permission="{perm}"'
check("DockDictationService: exportado SOLO con el permiso de firma y tipo micrófono",
      dsvc_tag != "" and 'android:exported="true"' in dsvc_tag and SIGN in dsvc_tag
      and 'android:foregroundServiceType="microphone|shortService"' in dsvc_tag)
_dds = open(f"{KT}/DockDictationService.kt").read()
check("DockDictationService: cumple siempre la promesa de primer plano (si niegan el micrófono, servicio corto)",
      "micForeground = enterForeground()" in _dds and "FOREGROUND_SERVICE_TYPE_SHORT_SERVICE" in _dds
      and _dds.index("micForeground = enterForeground()") < _dds.index("toggle()"))
check("DockTrampolineActivity: exportada SOLO con el permiso de firma, translúcida, fuera de recientes",
      tramp_tag != "" and 'android:exported="true"' in tramp_tag and SIGN in tramp_tag
      and 'android:excludeFromRecents="true"' in tramp_tag and 'android:noHistory="true"' in tramp_tag
      and "DockTrampolineTheme" in tramp_tag)
check("Receptor del manifiesto (funciona con la app cerrada) con el permiso de firma: DOCK_HELLO y DOCK_STATE",
      recv_tag != "" and SIGN in recv_tag
      and 'name="com.royleguiza.voicebubble.puntero.ACTION_DOCK_HELLO"' in manifest
      and 'name="com.royleguiza.voicebubble.puntero.ACTION_DOCK_STATE"' in manifest
      and "PointerProtocol.ACTION_DOCK_HELLO -> DockLink.onHello(ctx)" in h_dlink)
check("Todo componente exportado nuevo de la barra exige el permiso de firma",
      all(SIGN in t for t in (dsvc_tag, tramp_tag, recv_tag)))
check("Las acciones del dictado coinciden entre el complemento y el servicio",
      "ACTION_DICTATION_TOGGLE" in h_dsvc and "ACTION_DICTATION_CANCEL" in h_dsvc and "PointerProtocol.HOST_DICTATION_SERVICE_CLASS" in d_host_link
      and 'HOST_DICTATION_SERVICE_CLASS = "com.royleguiza.voicebubblestt.DockDictationService"' in proto)
check("DockDictationService: foreground micrófono, misma clave/config y exclusión del micrófono que teclado y widget",
      "FOREGROUND_SERVICE_TYPE_MICROPHONE" in h_dsvc and "SpeechToTextClient(this)" in h_dsvc
      and "BackgroundWork.tryClaimMicrophone()" in h_dsvc and "BackgroundWork.releaseMicrophone(claim)" in h_dsvc
      and "speech.loadConfig()" in h_dsvc and "START_NOT_STICKY" in h_dsvc)
check("DockDictationService: resultado como la burbuja (historial nativo + portapapeles + pegado con el teclado propio)",
      "TranscriptionHistoryRepository(this).addTranscription(clean)" in h_dsvc and "ClipData.newPlainText(" in h_dsvc
      and "VoiceKeyboardService.commitFromExternal(clean)" in h_dsvc and "doneMessage(pasted)" in h_dsvc)
check("DockDictationService: respeta sonidos y hápticos de micrófono del teclado",
      all(k in h_feedback for k in ("kb_mic_haptics_enabled", "kb_mic_haptic_start", "kb_mic_haptic_cancel", "kb_mic_sounds_enabled",
                                    "kb_mic_start_style", "kb_mic_stop_style")) and "DockMicFeedback(this)" in h_dsvc)
check("DockDictationService: errores con frase corta fija vía MIC_STATE error (clave, permiso, micrófono ocupado, red)",
      all(m in h_dlogic for m in ("Falta la clave de Groq", "Falta el permiso del micrófono", "El micrófono está ocupado", "Sin conexión"))
      and "PointerProtocol.MIC_ERROR" in h_dsvc and "errorMessage(code)" in h_dsvc)
check("DockDictationService: si startForeground se niega avisa needs_ui y no queda colgado",
      "needsUi = !fromTrampoline" in h_dsvc and "EXTRA_NEEDS_UI" in proto and "fail(DockDictationLogic.MSG_MIC_FAILED" in h_dsvc)
check("DockDictationService: no deja temporizadores ni el micrófono al destruirse",
      "main.removeCallbacksAndMessages(null)" in h_dsvc and "client?.cancelRecording()" in h_dsvc
      and "releaseMicrophone()" in h_dsvc.split("override fun onDestroy()")[1].split("override fun")[0]
      and "Log." not in h_dsvc + h_dlogic + h_tramp + h_dlink + h_feedback)
check("Trampolín: arranca el servicio en primer plano con from_trampoline y se cierra sola",
      "startForegroundService(intent)" in h_tramp and "EXTRA_FROM_TRAMPOLINE" in h_tramp and "finish()" in h_tramp
      and "overridePendingTransition(0, 0)" in h_tramp)
check("Complemento: arranca el dictado con startForegroundService y, si Android lo niega, abre el trampolín",
      "context.startForegroundService(intent) != null" in d_host_link and "fun openTrampoline(" in d_host_link
      and "HostLink.toggleDictation(service)" in d_mgr and "HostLink.openTrampoline(service)" in d_mgr
      and "if (ms.needsUi)" in d_mgr and "FLAG_ACTIVITY_NEW_TASK" in d_host_link)
check("Complemento: no pide el micrófono si VoiceBubble no tiene el permiso",
      "fun hostHasMicPermission(" in d_host_link and "HostLink.hostHasMicPermission(service)" in d_mgr)

# Host: respaldo y «nunca dos barras»
check("Host: la barra de respaldo se esconde mientras el complemento dibuja",
      "fun setSuppressed(value: Boolean)" in dock and "!hidden && !suppressed" in dock
      and "dock?.setSuppressed(DockLink.complementDrawing || waitingComplement)" in fbs)
check("Host: nace escondida si el complemento está listo y se muestra si no contesta a tiempo (sin dos barras)",
      "it.setSuppressed(initiallySuppressed || PointerLink.isReady(this))" in fbs and "COMPLEMENT_ANSWER_MS" in fbs
      and "complementTimeout" in fbs and "DockLink.sendConfig(this, enabledOverride = true, ack = true)" in fbs)
check("Host: DOCK_STATE actualiza el estado y la barra de respaldo reacciona",
      "complementDrawing = active" in h_dlink and "onDrawingChanged?.invoke(active)" in h_dlink
      and "DockLink.onDrawingChanged = { drawing ->" in fbs)
check("Host: al cerrar el servicio de la barra, el complemento también la saca (y no vuelve tras reiniciar)",
      "closeComplementDock()" in fbs and "enabledOverride = false" in fbs and "putBoolean(FlutterPrefs.key(\"floating_bubble_enabled\"), false)" in fbs
      and "DockLink.onDrawingChanged = null" in fbs)
check("Host: Ajustes (startBubble, stopBubble, reloadDock) además manda DOCK_CONFIG",
      main.count("DockLink.sendConfig(") >= 3 and "enabledOverride = true" in main and "enabledOverride = false" in main)
check("Host: DOCK_CONFIG lleva forma, herramientas, isla y trackpad (prefs de Flutter, isla con valores por defecto si no existen)",
      all(k in h_dlink for k in ("EXTRA_DOCK_FORM", "EXTRA_TOOL_MIC", "EXTRA_ISLAND_X", "EXTRA_ISLAND_SIDE", "EXTRA_SENSITIVITY", "EXTRA_AUTO_RETURN"))
      and "DockController.PREF_FORM" in h_dlink and "PointerLink.readTrackpadConfig(context, -1, -1)" in h_dlink
      and "setPackage(PointerProtocol.COMPANION_PACKAGE)" in h_dlink and "sendBroadcast(intent, PointerProtocol.PERMISSION_POINTER)" in h_dlink)
check("Host: las claves de la isla y floating_bubble_enabled se leen con el literal del contrato (fase 2B, 61 claves)",
      all(f'"flutter.{k}"' in h_dlink for k in ("dock_island_x", "dock_island_y", "dock_island_w", "dock_island_h",
                                               "dock_island_side", "floating_bubble_enabled"))
      and "FlutterPrefs.key(" not in h_dlink and len(contract) == 61
      and all(k in contract for k in ("dock_island_x", "dock_island_y", "dock_island_w", "dock_island_h",
                                      "dock_island_side", "floating_bubble_enabled")))
check("Host: el dictado de la app por Flutter también se ve en la barra del complemento",
      "mirrorStateToComplement(state)" in fbs and "DockDictationService.isActive" in fbs and "MIRROR_REPEAT_MS" in fbs)
check("Host: el dictado de la burbuja de respaldo por Flutter no se tocó",
      "onBubbleActionListener?.onBubbleTap()" in fbs and "onBubbleActionListener?.onBubbleTap()" in main + fbs)

# Tests y CI
for t in (f"{PUN_TEST}/IslandGeometryTest.kt", f"{PUN_TEST}/MicStateTrackerTest.kt", f"{PUN_TEST}/DockGeometryTest.kt",
          f"{KT_TEST}/DockDictationLogicTest.kt"):
    check(f"Existe {os.path.basename(t)}", exists(t))
check("Tests JVM del protocolo v3 en las dos apps",
      all("normalizeDockConfig" in read(t) and "normalizeMicState" in read(t) for t in (f"{PUN_TEST}/PointerProtocolTest.kt", f"{KT_TEST}/PointerProtocolTest.kt")))
check("Tests JVM de la isla: tamaños por estado, centrado y recorte a pantalla",
      all(k in read(f"{PUN_TEST}/IslandGeometryTest.kt") for k in ("tamanos por estado", "se centra en x", "nunca sale de la pantalla", "pantallas muy angostas")))
check("Tests JVM del dictado: TOGGLE/CANCEL, toque mientras arranca y vigilante",
      "QUEUE_STOP" in read(f"{KT_TEST}/DockDictationLogicTest.kt") and "isStale" in read(f"{PUN_TEST}/MicStateTrackerTest.kt"))
check("CI corre los tests nuevos del host en el paso de la barra flotante", "DockDictationLogicTest" in ci)
check("Documentación: contrato de la barra, design.md (isla) y AGENTS.md",
      exists("docs/contrato-barra.md") and "Isla (tercera forma)" in read("design.md") and "fase 2A" in read("AGENTS.md")
      and "DOCK_CONFIG" in read("docs/contrato-barra.md") and "contrato-barra.md" in read("docs/contrato-trackpad.md"))

# Mutaciones de la fase 2A
mut_win = d_win.replace("TYPE_ACCESSIBILITY_OVERLAY", "TYPE_APPLICATION_OVERLAY")
check("Mutación: barra del complemento como overlay de app se detecta", "TYPE_ACCESSIBILITY_OVERLAY" not in mut_win)
mut_dsvc_tag = dsvc_tag.replace(SIGN, "")
check("Mutación: servicio de dictado exportado sin el permiso de firma se detecta",
      'android:exported="true"' in mut_dsvc_tag and SIGN not in mut_dsvc_tag and SIGN in dsvc_tag)
mut_fbs2 = fbs.replace("dock?.setSuppressed(DockLink.complementDrawing || waitingComplement)", "")
check("Mutación: dos barras a la vez (host sin esconderse) se detecta", "dock?.setSuppressed(DockLink.complementDrawing || waitingComplement)" not in mut_fbs2)
mut_isl = d_isl_ctrl.replace("DockWindow(windowManager, view, noLimits = true)", "DockWindow(windowManager, view)")
check("Mutación: isla sin NO_LIMITS (no llega a la cámara) se detecta", "noLimits = true" not in mut_isl)
mut_geo2 = d_isl_geo.replace("val left = clamp(cx - w / 2, margin, screenW - w - margin)", "val left = cx - w / 2")
check("Mutación: isla sin recorte a pantalla se detecta", "clamp(cx - w / 2, margin, screenW - w - margin)" not in mut_geo2)
mut_pun_proto = pun_proto.replace('const val ACTION_DOCK_STATE = "com.royleguiza.voicebubble.puntero.ACTION_DOCK_STATE"', "")
check("Mutación: protocolo v3 incompleto en el complemento se detecta", consts(proto) != consts(mut_pun_proto))
mut_dsvc = h_dsvc.replace("BackgroundWork.tryClaimMicrophone()", "1L")
check("Mutación: dictado sin exclusión del micrófono se detecta", "BackgroundWork.tryClaimMicrophone()" not in mut_dsvc)
mut_dock_destroy = pun_svc.replace("dock?.destroy()", "")
check("Mutación: barra sin destruir al desvincular se detecta", "dock?.destroy()" not in mut_dock_destroy)

# --- 12. Fase 2B: Ajustes de la isla (Flutter) ---
isl_page = read("app_source/lib/screens/settings/island_page.dart")
isl_mock = read("app_source/lib/widgets/island_mockup.dart")
isl_geo = read("app_source/lib/helpers/island_geometry.dart")
kit2 = read("app_source/lib/widgets/settings_v2.dart")
deb = read("app_source/lib/ui/debouncer.dart")
tokens2 = read("app_source/lib/ui/design_tokens.dart")
dart_keys = ("dock_island_x", "dock_island_y", "dock_island_w", "dock_island_h", "dock_island_side")
check("Forma Isla en el selector de Ajustes, deshabilitada sin el complemento activo",
      "SettingsOption(\n                  'island'" in general and "enabled: islandAvailable" in general
      and "o.enabled ? () => onSelected(o.value) : null" in kit2)
check("Sin complemento: sección que explica y el mismo acceso que Trackpad",
      "'island-companion-section'" in general and "Necesita VoiceBubble Puntero activo" in general
      and "_pointerCompanionRows()" in general and "_pointerCompanionRows()" in trackpad_page
      and "'pointer-companion-row'" in trackpad_page)
check("Elegir Isla sin el complemento activo se rechaza también en el código",
      "form == 'island' &&" in settings and "_pointerStatus != FloatingTrackpadService.pointerReady" in settings)
check("Subpágina «Ajustar isla»: enum, fila solo con la forma Isla y página propia",
      "  isla," in settings and "case SettingsPage.isla:" in settings and "part 'settings/island_page.dart';" in settings
      and "if (_dockForm == 'island')" in general and "'island-adjust-row'" in general and "title: 'Ajustar isla'" in isl_page)
check("Cuatro medidas con deslizador y ±1 px, lado, centrar arriba y restablecer",
      all(f"id: 'island-{i}'" in isl_page for i in "xywh") and "'island-side-selector'" in isl_page
      and "'island-center-button'" in isl_page and "'island-reset-button'" in isl_page
      and "class SettingsStepperRow" in kit2 and "Icons.remove_rounded" in kit2 and "Icons.add_rounded" in kit2)
check("Mantener apretado repite y el target mide 48 dp", "Timer.periodic(_repeatEvery" in kit2 and "kStepperButtonSize = 48.0" in tokens2)
check("Rangos: ancho 72–180 dp, alto 22–48 dp, y hasta un tercio del alto, convertidos con la densidad",
      "minWidthDp = 72" in isl_geo and "maxWidthDp = 180" in isl_geo and "minHeightDp = 22" in isl_geo
      and "maxHeightDp = 48" in isl_geo and "screenH ~/ 3" in isl_geo and "View.of(context)" in isl_page
      and "view.devicePixelRatio" in isl_page)
check("Envío en vivo limitado: Throttler de 60 ms, valor final al soltar y al salir de la página",
      "class Throttler" in deb and "Throttler(interval: const Duration(milliseconds: 60))" in isl_page
      and "_throttler.flush()" in isl_page and "_throttler.dispose()" in isl_page and "reloadDock()" in isl_page)
check("Cada cambio guarda las prefs ANTES de pedir el reenvío (DOCK_CONFIG)",
      isl_page.index("await _save(f)") < isl_page.index("floatingBubbleService.reloadDock()"))
check("Maqueta a escala real: misma geometría que el complemento, tamaño físico de la vista, sin desenfoque",
      "IslandGeometry(" in isl_mock and "kIslandBg" in isl_mock and "BackdropFilter" not in isl_mock
      and "ImageFilter" not in isl_mock and "view.physicalSize" in isl_page
      and "static const double defaultWidthDp = 112" in isl_geo and "DEFAULT_W_DP = 112f" in d_isl_geo)
check("Constantes de la geometría Dart == IslandGeometry.kt del complemento",
      all(re.search(rf"{k}\s*=\s*{v}f?\b", d_isl_geo) for k, v in (("MIN_W_DP", "72"), ("MAX_W_DP", "180"), ("MIN_H_DP", "22"), ("MAX_H_DP", "48"),
                                                                      ("DEFAULT_TOP_DP", "3"), ("EDGE_MARGIN_DP", "4"), ("IDLE_DOT_DP", "12"), ("IDLE_POINTER_DP", "14"), ("IDLE_PAD_DP", "10"))))
check("Claves de la isla en Dart: constantes, bridgeKeys y contrato",
      all(f"'{k}'" in storage for k in dart_keys) and all(k in contract for k in dart_keys)
      and "dockIslandXKey," in storage and "dockIslandSideKey," in storage and "_floatingBubbleKey,\n    kbBottomElevationDpKey" in storage
      and "floating_bubble_enabled" in contract)
check("Valores de la isla validados (−1 por defecto, tope 20000, lado left/right)",
      "dockIslandMaxPx = 20000" in storage and "dockIslandSides = ['left', 'right']" in storage
      and "ISLAND_MAX_PX = 20000" in proto and "defaultDockIslandSide = 'left'" in storage)
check("Tokens de la isla (negra siempre) en design_tokens, sin colores sueltos en la maqueta",
      "kIslandBg = Color(0xFF000000)" in tokens2 and "Color(0x" not in isl_mock and "Colors." not in isl_mock + isl_page)
for t in ("app_source/test/screens/settings_island_adjust_test.dart", "app_source/test/widgets/island_mockup_test.dart",
          "app_source/test/widgets/settings_stepper_row_test.dart", "app_source/test/services/dock_island_storage_test.dart",
          "app_source/test/helpers/island_geometry_test.dart", "app_source/test/ui/throttler_test.dart"):
    check(f"Existe {os.path.basename(t)}", exists(t))
check("Documentación 2B: design.md describe «Ajustar isla» y el contrato de la barra ya no lo deja pendiente",
      "Ajustar isla" in read("design.md") and "Ajustes de la isla (fase 2B)" in read("docs/contrato-barra.md")
      and "61" in read("docs/contrato-claves.md"))

# Mutaciones de la fase 2B
mut_form = storage.replace("['edge', 'bubble', 'island']", "['edge', 'bubble']")
check("Mutación: forma Isla fuera del dominio se detecta", "['edge', 'bubble', 'island'];" not in mut_form)
mut_en = general.replace("enabled: islandAvailable,", "")
check("Mutación: Isla habilitada sin el complemento se detecta", "enabled: islandAvailable" not in mut_en)
mut_thr = isl_page.replace("_throttler.run(_commit);", "_commit();")
check("Mutación: envío sin limitar se detecta", "_throttler.run(_commit);" not in mut_thr)
mut_lit = h_dlink.replace('"flutter.dock_island_x"', 'FlutterPrefs.key("dock_island_x")')
check("Mutación: clave de la isla sin literal del contrato se detecta", '"flutter.dock_island_x"' not in mut_lit)
mut_keys = storage.replace("    dockIslandHKey,\n", "")
check("Mutación: clave de la isla fuera de bridgeKeys se detecta", "    dockIslandHKey,\n" not in mut_keys)

print("\n============================================================")
print(f" RESULTADO SUITE BARRA FLOTANTE: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")
sys.exit(suite.exit_code())
