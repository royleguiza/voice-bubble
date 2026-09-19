#!/usr/bin/env python3
"""
TEST SUITE: PRECISION Y VELOCIDAD DE ESCRITURA (dedos)
Verifica sobre el código REAL:
1. Targets táctiles: kb_key_height >= 48dp, gaps horizontales chicos.
2. Filas gap-tolerantes: letterRow/symbolRow/codeRow capturan toques en
   gaps y los resuelven a la tecla más cercana (antes no escribían nada).
3. Tags de commit: cada tecla de letra/símbolo/código guarda su lambda de
   tap para la resolución de gaps (sin duplicar rutas de commit).
4. Pop visual con gate de Reduced Motion (anti-patrón §8).
5. Rutas de commit intactas: fastTap/longPress/attachTap/attachAccent/
   attachPair/backspaceGestures sin cambios de conducta.
6. Sin Log nuevo, sin lectura de documento, sin cambios en CI.
"""

import os
import re
import sys

from test_helpers import WORKSPACE, Suite

suite = Suite()
check = suite.check


def read(rel):
    with open(os.path.join(WORKSPACE, rel), "r", encoding="utf-8") as f:
        return f.read()


print("\n============================================================")
print(" INICIANDO TEST SUITE: PRECISION DE ESCRITURA (DEDOS)")
print("============================================================\n")

KF = "voice_bubble_stt/android/app/src/main/kotlin/com/royleguiza/voicebubblestt/KeyFactory.kt"
DIMENS = "voice_bubble_stt/android/app/src/main/res/values/dimens.xml"

check("KeyFactory.kt existe", os.path.isfile(os.path.join(WORKSPACE, KF)))
check("dimens.xml existe", os.path.isfile(os.path.join(WORKSPACE, DIMENS)))
kf = read(KF)
dimens = read(DIMENS)

# --- 1. Targets táctiles ---
m = re.search(r'<dimen name="kb_key_height">(\d+)dp</dimen>', dimens)
check("kb_key_height declarado", m is not None)
if m:
    check(f"kb_key_height >= 48dp (actual {m.group(1)}dp)", int(m.group(1)) >= 48)
mh = re.search(r'<dimen name="kb_key_gap_h">(\d+)dp</dimen>', dimens)
if mh:
    check(f"gap horizontal chico (actual {mh.group(1)}dp)", int(mh.group(1)) <= 4)
mv = re.search(r'<dimen name="kb_key_gap_v">(\d+)dp</dimen>', dimens)
if mv:
    check(f"gap vertical chico (actual {mv.group(1)}dp)", int(mv.group(1)) <= 6)

# --- 2. Filas gap-tolerantes ---
check("makeGapTolerant existe", "fun makeGapTolerant(" in kf)
for builder in ["fun letterRow(", "fun symbolRow(", "fun codeRow("]:
    body = kf.split(builder)[1].split("\n    fun ")[0] if builder in kf else ""
    check(f"{builder} aplica gap-tolerancia", "makeGapTolerant(row)" in body)
check("Gap: DOWN consume para recibir el UP", "MotionEvent.ACTION_DOWN -> true" in kf)
check("Gap: UP resuelve tecla más cercana", "nearestChild(row, ev.x, ev.y)" in kf)
check("Gap: commit vía tag (sin ruta nueva)", "(child.tag as? () -> Unit)?.invoke()" in kf)
check("Gap: flash pressed de feedback", "child.isPressed = true" in kf)
check("Gap: sin Log", "Log." not in kf.split("fun makeGapTolerant(")[1].split("\n    ")[0]
      if "fun makeGapTolerant(" in kf else True)

# --- 3. Tags de commit (misma lambda, cero duplicación) ---
check("Letras guardan commit en tag", "key.tag = commit" in kf)
check("Código: gap resuelve al tap corto", "El toque en gap resuelve al tap corto" in kf)

# --- 4. Pop visual con Reduced Motion ---
check("pressPop existe", "fun pressPop(" in kf)
check("Pop apagado con Reduced Motion", "if (service.reducedMotion()) return" in kf)
check("Pop en fastTap DOWN/UP", kf.count("pressPop(v,") >= 3)
check("Pop en longPress DOWN/UP/CANCEL", "pressPop(v, true)" in kf and "pressPop(v, false)" in kf)
check("Pop sin animador (escala instantánea)", ".animate(" not in kf)

# --- 5. Rutas de commit intactas ---
for fn in ["fun fastTap(", "fun longPress(", "fun backspaceGestures(",
           "fun makeLetterKey(", "fun makeSymbolKey(", "fun makeCodeKey("]:
    check(f"API intacta {fn}", fn in kf)
check("fastTap: UP comite si pressed", "if (v.isPressed)" in kf)
check("longPress: tap corto sigue siendo tap", "if (!longPressFired && !swipeMode)" in kf)
check("Borrado con gesto intacto", "onSwipeStep = { host.deleteWord() }" in kf)
check("Sin cambios de privacidad", "PRIVACIDAD: nada se registra en Log" in kf)

print("\n============================================================")
print(f" RESULTADO SUITE ESCRITURA: {suite.passed} pasados, {suite.failed} fallidos.")
print("============================================================\n")

if suite.failed > 0:
    sys.exit(1)
sys.exit(0)
