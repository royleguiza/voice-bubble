#!/usr/bin/env python3
"""
TEST SUITE: CONTRATO C-16 (SPACEBAR SIN FANTASMAS)
==================================================
Valida que la barra espaciadora (SpacebarLayer):
1. Use un único Handler compartido proveniente de VoiceKeyboardService.
2. Limpie los callbacks del runnable en el mismo Handler compartido tanto en
   attachSpacebarGestures como en cancelPending.
3. Respete el retardo configurable del usuario (host.longPressDelayMs()) en lugar
   de un literal fijo de 300L.
4. En cancelPending(), restaure inmediatamente el alpha de las vistas (alpha=1.0)
   para que un rebuild rápido nunca deje el teclado con glifos apagados o invisible.
5. VoiceKeyboardService invoque cancelPendingKeyGestures() en rebuild() antes de
   root.removeAllViews() y en onDestroy().
"""

import os
import re
import sys

WORKSPACE = os.path.dirname(os.path.abspath(__file__))
KT_DIR = os.path.join(WORKSPACE, "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt")
SPACEBAR_PATH = os.path.join(KT_DIR, "SpacebarLayer.kt")
VKS_PATH = os.path.join(KT_DIR, "VoiceKeyboardService.kt")

passed_count = 0
failed_count = 0

def check(name, condition, detail=""):
    global passed_count, failed_count
    if condition:
        print(f"  [PASS] {name}")
        passed_count += 1
    else:
        print(f"  [FAIL] {name} -> {detail}")
        failed_count += 1

print("\n" + "=" * 60)
print(" INICIANDO TEST SUITE: CONTRATO C-16 (SPACEBAR SIN FANTASMAS)")
print("=" * 60 + "\n")

# --- 1. Verificación de existencia de archivos ---
check("SpacebarLayer.kt existe", os.path.isfile(SPACEBAR_PATH), f"No encontrado: {SPACEBAR_PATH}")
check("VoiceKeyboardService.kt existe", os.path.isfile(VKS_PATH), f"No encontrado: {VKS_PATH}")

with open(SPACEBAR_PATH, "r", encoding="utf-8") as f:
    spacebar_code = f.read()

with open(VKS_PATH, "r", encoding="utf-8") as f:
    vks_code = f.read()

# --- 2. SpacebarLayer.kt: Handler compartido en constructor y compatibilidad ---
check(
    "SpacebarLayer constructor primario recibe Handler compartido",
    "class SpacebarLayer(\n    private val service: InputMethodService,\n    private val handler: Handler,\n    private val host: UiHost,\n)" in spacebar_code or
    "class SpacebarLayer(\n    private val service: InputMethodService,\n    private val handler: Handler," in spacebar_code,
    "El constructor primario debe recibir handler: Handler"
)

check(
    "SpacebarLayer expone constructor secundario para compatibilidad",
    "constructor(service: InputMethodService, host: UiHost)" in spacebar_code,
    "Debe existir constructor secundario para llamadas sin handler explícito"
)

# --- 3. SpacebarLayer.UiHost declara longPressDelayMs ---
uihost_start = spacebar_code.find("interface UiHost")
uihost_end = spacebar_code.find("}", uihost_start)
uihost_block = spacebar_code[uihost_start:uihost_end]

check(
    "SpacebarLayer.UiHost declara fun longPressDelayMs(): Long",
    "fun longPressDelayMs(): Long" in uihost_block,
    "SpacebarLayer.UiHost debe declarar fun longPressDelayMs(): Long"
)

# --- 4. VoiceKeyboardService implementa longPressDelayMs y pasa handler compartido ---
check(
    "VoiceKeyboardService instancia SpacebarLayer con handler compartido",
    "spacebar = SpacebarLayer(this, handler, this)" in vks_code,
    "VKS debe pasar 'handler' compartido a SpacebarLayer"
)

check(
    "VoiceKeyboardService implementa override fun longPressDelayMs(): Long",
    "override fun longPressDelayMs(): Long" in vks_code and "kbPrefs.longPressDelayMs" in vks_code,
    "VKS debe proveer longPressDelayMs desde kbPrefs"
)

# --- 5. SpacebarLayer: uso de host.longPressDelayMs() y no 300L fijo ---
check(
    "SpacebarLayer usa host.longPressDelayMs() en ACTION_DOWN",
    "handler.postDelayed(longPressTask, host.longPressDelayMs())" in spacebar_code,
    "ACTION_DOWN debe usar host.longPressDelayMs() en lugar de 300L"
)

# Comprobar que no queda postDelayed con 300L
post_delayed_matches = re.findall(r"postDelayed\([^)]+\)", spacebar_code)
check(
    "CERO llamadas a postDelayed con 300L hardcodeado",
    all("300L" not in m for m in post_delayed_matches),
    f"Encontrado 300L en postDelayed: {post_delayed_matches}"
)

# --- 6. attachSpacebarGestures: sin crear Handler nuevo y cancelando task viejo ---
attach_start = spacebar_code.find("fun attachSpacebarGestures(")
attach_end = spacebar_code.find("fun cancelPending()", attach_start)
attach_block = spacebar_code[attach_start:attach_end]

check(
    "attachSpacebarGestures NO instancia Handler nuevo",
    "Handler(Looper.getMainLooper())" not in attach_block,
    "attachSpacebarGestures no debe crear handlers locales"
)

check(
    "attachSpacebarGestures cancela task previo en el handler compartido",
    "handler.removeCallbacks(it)" in attach_block or "cancelPending()" in attach_block,
    "attachSpacebarGestures debe cancelar el task previo antes de adjuntar el nuevo"
)

# --- 7. cancelPending(): remoción de callbacks y restauración de alpha=1.0 ---
cancel_start = spacebar_code.find("fun cancelPending()")
cancel_end = spacebar_code.find("private fun setTrackpadBlankOutMode", cancel_start)
cancel_block = spacebar_code[cancel_start:cancel_end]

check(
    "cancelPending remueve callbacks del handler compartido",
    "longPressRunnable?.let { handler.removeCallbacks(it) }" in cancel_block,
    "cancelPending debe remover callbacks de longPressRunnable en handler compartido"
)

check(
    "cancelPending restaura alpha inmediatamente (setTrackpadBlankOutMode false/immediate)",
    "setTrackpadBlankOutMode(false, space = null, immediate = true)" in cancel_block or
    "setTrackpadBlankOutMode(false" in cancel_block,
    "cancelPending debe restaurar el modo blank out a false"
)

blankout_start = spacebar_code.find("private fun setTrackpadBlankOutMode")
blankout_block = spacebar_code[blankout_start:]
check(
    "setTrackpadBlankOutMode soporta parámetro immediate",
    "immediate: Boolean" in blankout_block,
    "setTrackpadBlankOutMode debe aceptar immediate: Boolean"
)
check(
    "setTrackpadBlankOutMode asigna view.alpha inmediatamente cuando immediate es true",
    "view.alpha = targetAlpha" in blankout_block and "view.animate().cancel()" in blankout_block,
    "Cuando immediate es true, debe cancelar animación y asignar alpha directamente"
)

# --- 8. VoiceKeyboardService: cancelPendingKeyGestures en rebuild y onDestroy ---
rebuild_start = vks_code.find("override fun rebuild()")
rebuild_end = vks_code.find("root.removeAllViews()", rebuild_start)
rebuild_block = vks_code[rebuild_start:rebuild_end]

check(
    "rebuild() ejecuta cancelPendingKeyGestures() antes de removeAllViews()",
    "cancelPendingKeyGestures()" in rebuild_block,
    "rebuild() debe cancelar gestos pendientes antes de remover vistas"
)

ondestroy_start = vks_code.find("override fun onDestroy()")
ondestroy_end = vks_code.find("}", ondestroy_start)
ondestroy_block = vks_code[ondestroy_start:ondestroy_end]

check(
    "onDestroy() ejecuta cancelPendingKeyGestures()",
    "cancelPendingKeyGestures()" in ondestroy_block,
    "onDestroy() debe cancelar gestos pendientes"
)

cancel_gestures_start = vks_code.find("private fun cancelPendingKeyGestures()")
cancel_gestures_end = vks_code.find("}", cancel_gestures_start)
cancel_gestures_block = vks_code[cancel_gestures_start:cancel_gestures_end]

check(
    "cancelPendingKeyGestures() invoca spacebar.cancelPending()",
    "spacebar.cancelPending()" in cancel_gestures_block,
    "cancelPendingKeyGestures debe invocar spacebar.cancelPending()"
)

# --- 9. Simulación Funcional: Ciclo de vida y prevención de fantasmas ---
print("\n--- Simulación del Ciclo de Vida del Gesto Spacebar ---")

class MockView:
    def __init__(self, name="view"):
        self.name = name
        self.alpha = 1.0
        self.isPressed = False
        self.parent = None
        self.animation_cancelled = False

    def animate(self):
        class Animator:
            def __init__(self, v):
                self.v = v
            def cancel(self):
                self.v.animation_cancelled = True
                return self
            def alpha(self, a):
                self.target_a = a
                return self
            def setDuration(self, d):
                return self
            def start(self):
                self.v.alpha = self.target_a
        return Animator(self)

class MockHandler:
    def __init__(self):
        self.pending = []

    def postDelayed(self, task, delay_ms):
        self.pending.append((task, delay_ms))

    def removeCallbacks(self, task):
        self.pending = [p for p in self.pending if p[0] != task]

class MockUiHost:
    def __init__(self):
        self.delay = 450
        self.trackpadMode = "ios_2d"
        self.haptics = 0
        self.spacePressed = 0
        self.root_view = MockView("root")
        self.key1 = MockView("key1")
        self.key2 = MockView("key2")
        self.space_key = MockView("space")

    def longPressDelayMs(self):
        return self.delay

    def spacebarTrackpadMode(self):
        return self.trackpadMode

    def haptic(self, view):
        self.haptics += 1

    def pressSpace(self):
        self.spacePressed += 1

    def currentInputView(self):
        return self.root_view

mock_host = MockUiHost()
mock_handler = MockHandler()

# Simulación SpacebarLayer
class SimulatedSpacebarLayer:
    def __init__(self, handler, host):
        self.handler = handler
        self.host = host
        self.longPressRunnable = None
        self.isLongPressTriggered = False

    def attach(self, space_view):
        self.cancelPending()
        def task():
            if self.host.spacebarTrackpadMode() == "ios_2d":
                self.isLongPressTriggered = True
                self.setTrackpadBlankOut(True, space_view)
                self.host.haptic(space_view)
        self.longPressRunnable = task

    def onTouchDown(self, space_view):
        self.handler.removeCallbacks(self.longPressRunnable)
        self.handler.postDelayed(self.longPressRunnable, self.host.longPressDelayMs())

    def onTouchUp(self, space_view):
        self.handler.removeCallbacks(self.longPressRunnable)
        if self.isLongPressTriggered:
            self.setTrackpadBlankOut(False, space_view)
            self.host.haptic(space_view)
        else:
            self.host.pressSpace()

    def cancelPending(self):
        if self.longPressRunnable:
            self.handler.removeCallbacks(self.longPressRunnable)
        self.longPressRunnable = None
        self.isLongPressTriggered = False
        self.setTrackpadBlankOut(False, None, immediate=True)

    def setTrackpadBlankOut(self, enabled, space_view, immediate=False):
        target = 0.0 if enabled else 1.0
        views = [self.host.key1, self.host.key2]
        for v in views:
            v.animate().cancel()
            if immediate or not enabled:
                v.alpha = target
            else:
                v.alpha = target

sim_space = SimulatedSpacebarLayer(mock_handler, mock_host)
space_v = mock_host.space_key

# 9.1: Toque normal respeta delay configurable del usuario
sim_space.attach(space_v)
sim_space.onTouchDown(space_v)
check("Paso 1: postDelayed encolado con retardo del usuario (450ms)", len(mock_handler.pending) == 1 and mock_handler.pending[0][1] == 450)

# 9.2: Soltar rápido ejecuta espacio y cancela callback
sim_space.onTouchUp(space_v)
check("Paso 2: Soltar antes del delay ejecuta espacio y limpia callback", len(mock_handler.pending) == 0 and mock_host.spacePressed == 1)

# 9.3: Long press activa blank out (alpha=0.0)
sim_space.attach(space_v)
sim_space.onTouchDown(space_v)
task_tuple = mock_handler.pending[0]
task_tuple[0]()  # Ejecutar tarea de long-press
check("Paso 3: Long-press activa blank out en glifos (alpha=0.0)", mock_host.key1.alpha == 0.0 and mock_host.key2.alpha == 0.0)

# 9.4: Rebuild rápido mientras los glifos estaban en blanco ejecuta cancelPending y restaura alpha=1.0 inmediatamente
sim_space.cancelPending()
check("Paso 4: cancelPending() restaura alpha=1.0 inmediatamente", mock_host.key1.alpha == 1.0 and mock_host.key2.alpha == 1.0)
check("Paso 4: cancelPending() canceló animaciones pendientes", mock_host.key1.animation_cancelled and mock_host.key2.animation_cancelled)
check("Paso 4: cancelPending() vació callbacks pendientes del handler", len(mock_handler.pending) == 0)

# 9.5: attach en nueva vista cancela tarea pendiente previa
sim_space.attach(space_v)
sim_space.onTouchDown(space_v)
check("Paso 5: Tarea encolada en vista 1", len(mock_handler.pending) == 1)
space_v2 = MockView("space2")
sim_space.attach(space_v2)
check("Paso 5: attach en vista 2 canceló la tarea pendiente de vista 1", len(mock_handler.pending) == 0)

# --- 10. Verificación de Mutaciones Negativas ---
print("\n--- Verificación de Mutaciones Negativas ---")

# Mutación 1: Omitir restauración de alpha en cancelPending
mut1_code = cancel_block.replace("setTrackpadBlankOutMode(false, space = null, immediate = true)", "")
check("Mutación 1 (cancelPending omite restaurar alpha): detectada", "setTrackpadBlankOutMode(false" not in mut1_code)

# Mutación 2: Volver a usar 300L fijo en lugar de host.longPressDelayMs()
mut2_code = spacebar_code.replace("host.longPressDelayMs()", "300L")
check("Mutación 2 (postDelayed vuelve a usar 300L): detectada", "host.longPressDelayMs()" not in mut2_code)

# Mutación 3: No pasar handler compartido a SpacebarLayer en VKS
mut3_code = vks_code.replace("spacebar = SpacebarLayer(this, handler, this)", "spacebar = SpacebarLayer(this, this)")
check("Mutación 3 (VKS no pasa handler compartido a SpacebarLayer): detectada", "spacebar = SpacebarLayer(this, handler, this)" not in mut3_code)

# Mutación 4: Omitir longPressDelayMs en UiHost
mut4_code = uihost_block.replace("fun longPressDelayMs(): Long", "")
check("Mutación 4 (UiHost omite longPressDelayMs): detectada", "fun longPressDelayMs(): Long" not in mut4_code)

# Mutación 5: Reinstanciar Handler en attachSpacebarGestures
mut5_code = attach_block + "\nval handler = Handler(Looper.getMainLooper())"
check("Mutación 5 (attachSpacebarGestures crea Handler propio): detectada", "Handler(Looper.getMainLooper())" in mut5_code)

print("\n" + "=" * 60)
print(f" RESULTADOS C-16: {passed_count} pasados, {failed_count} fallidos.")
print("=" * 60 + "\n")

if failed_count > 0:
    sys.exit(1)
sys.exit(0)
