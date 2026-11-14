#!/usr/bin/env python3
"""Genera las animaciones de carga de la IA del widget (AnimatedVectorDrawable).

Reemplazan al circulito que gira en los botones circulares de IA (lector del
widget y hoja de edición). Elegidas por el usuario en el artifact «Agujero
Horizonte» (2026-11-14):

  res/drawable/widget_ai_title_loading.xml    «Letras en órbita»: A, a y T
      giran en un disco inclinado y caen una por una al agujero.
  res/drawable/widget_ai_summary_loading.xml  «Bits que caen»: puntos y bits
      (0 y 1) que entran en espiral al agujero, grises lejos y brasa cerca.

Mismo modelo que el artifact: órbita alrededor de (24, 24) inclinada −0,32 rad
y aplastada; la partícula aparece con fundido, se acerca en espiral y se apaga
al tocar el borde del agujero (o al pasar por detrás de él). Los colores son
recursos (hz_fg2, hz_ember_t, hz_ember, hz_hole): sirven en claro y oscuro.

Uso: python3 docs/gen_widget_ai_loaders.py   (desde la raíz del repo)
"""
import math
import os

D = os.path.join(os.path.dirname(__file__), "..",
                 "voice_bubble_stt/android/app/src/main/res/drawable")
V = 48
CX = CY = 24
TILT = -0.32
STEPS = 36          # keyframes de posición por vuelta
STROKE = 1.1

LETTERS = {
    "A": "M-2.4,3.5L0,-3.5L2.4,3.5M-1.5,1H1.5",
    "a": "M1.9,-1V3.5M1.9,1.2C1.9,-0.5 1,-1.2 -0.1,-1.2C-1.3,-1.2 -2.1,-0.2 -2.1,1.2"
         "C-2.1,2.6 -1.3,3.5 -0.1,3.5C1,3.5 1.9,2.8 1.9,1.2",
    "T": "M-2.6,-3.5H2.6M0,-3.5V3.5",
    "0": "M0,-3.2C-1.4,-3.2 -1.9,-1.9 -1.9,0C-1.9,1.9 -1.4,3.2 0,3.2C1.4,3.2 1.9,1.9 1.9,0"
         "C1.9,-1.9 1.4,-3.2 0,-3.2Z",
    "1": "M-1.4,-2.1L0.3,-3.2V3.2M-1.6,3.2H1.9",
}
DOT = "M-1,0a1,1 0 1,0 2,0a1,1 0 1,0 -2,0z"

HEAD = """<?xml version="1.0" encoding="utf-8"?>
<!-- GENERADO por docs/gen_widget_ai_loaders.py: no editar a mano. %s -->
<animated-vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt">
    <aapt:attr name="android:drawable">
        <vector android:width="%ddp" android:height="%ddp"
            android:viewportWidth="%d" android:viewportHeight="%d">
"""


def f(v):
    return ("%.2f" % v).rstrip("0").rstrip(".") or "0"


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def orbit(r, th, flat):
    ox, oy = r * math.cos(th), r * math.sin(th) * flat
    return (CX + ox * math.cos(TILT) - oy * math.sin(TILT),
            CY + ox * math.sin(TILT) + oy * math.cos(TILT))


def kf(prop, vtype, frames):
    rows = "".join(
        '                        <keyframe android:fraction="%s" android:value="%s" />\n'
        % (("%.4f" % a).rstrip("0").rstrip(".") or "0", b) for a, b in frames)
    return ('                    <propertyValuesHolder android:propertyName="%s" android:valueType="%s">\n'
            '%s                    </propertyValuesHolder>\n') % (prop, vtype, rows)


def target(name, dur, holders):
    return ("""    <target android:name="%s">
        <aapt:attr name="android:animation">
            <objectAnimator android:duration="%d"
                    android:repeatCount="infinite" android:repeatMode="restart"
                    android:interpolator="@android:interpolator/linear">
%s                </objectAnimator>
        </aapt:attr>
    </target>
""") % (name, dur, "".join(holders))


def static_layers(glow_r, glow_a, hole_r, ring=None):
    """Brillo, anillo trasero opcional y agujero con su anillo brasa."""
    a = int(round(glow_a * 255))
    out = ('            <path android:pathData="M%s,%sa%s,%s 0 1,0 %s,0a%s,%s 0 1,0 -%s,0z">\n'
           '                <aapt:attr name="android:fillColor">\n'
           '                    <gradient android:type="radial" android:centerX="%d" android:centerY="%d"\n'
           '                        android:gradientRadius="%s">\n'
           '                        <item android:offset="0.4" android:color="#%02XFF8A1F" />\n'
           '                        <item android:offset="1" android:color="#00FF8A1F" />\n'
           '                    </gradient>\n'
           '                </aapt:attr>\n'
           '            </path>\n') % (f(CX - glow_r), CY, f(glow_r), f(glow_r), f(2 * glow_r),
                                        f(glow_r), f(glow_r), f(2 * glow_r), CX, CY, f(glow_r), a)
    if ring:
        rx, ry = ring
        out += ('            <group android:pivotX="%d" android:pivotY="%d" android:rotation="%s">\n'
                '                <path android:strokeColor="@color/hz_ember" android:strokeAlpha="0.45"\n'
                '                    android:strokeWidth="0.8"\n'
                '                    android:pathData="M%s,%sa%s,%s 0 1,0 %s,0a%s,%s 0 1,0 -%s,0" />\n'
                '            </group>\n') % (CX, CY, f(math.degrees(TILT)), f(CX - rx), CY,
                                             f(rx), f(ry), f(2 * rx), f(rx), f(ry), f(2 * rx))
    out += ('            <path android:fillColor="@color/hz_hole"\n'
            '                android:pathData="M%s,%sa%s,%s 0 1,0 %s,0a%s,%s 0 1,0 -%s,0z" />\n'
            '            <path android:strokeColor="@color/hz_ember" android:strokeWidth="1.3"\n'
            '                android:pathData="M%s,%sa%s,%s 0 1,0 %s,0a%s,%s 0 1,0 -%s,0" />\n') % (
        f(CX - hole_r), CY, f(hole_r), f(hole_r), f(2 * hole_r), f(hole_r), f(hole_r), f(2 * hole_r),
        f(CX - hole_r + 0.65), CY, f(hole_r - 0.65), f(hole_r - 0.65), f(2 * (hole_r - 0.65)),
        f(hole_r - 0.65), f(hole_r - 0.65), f(2 * (hole_r - 0.65)))
    return out


def particle(i, path, phase, dur, traj, alpha_of, scale_of, near_from, stroke):
    """Una partícula: grupo que se traslada y escala + trazo/relleno que cambia
    de color y opacidad. [traj](p) -> (x, y, behind); p es el avance 0..1."""
    frames = []
    wrap = 1 - phase
    fracs = sorted(set([k / STEPS for k in range(STEPS + 1)] +
                       ([wrap - 1e-3, wrap] if 0 < wrap < 1 else [])))
    for fr in fracs:
        p = (fr + phase) % 1.0
        if abs(fr - (wrap - 1e-3)) < 1e-9:
            p = 0.999
        frames.append((fr, p))
    tx, ty, sc, al, col = [], [], [], [], []
    for fr, p in frames:
        x, y, behind = traj(p)
        tx.append((fr, f(x)))
        ty.append((fr, f(y)))
        sc.append((fr, f(scale_of(p))))
        al.append((fr, f(0 if behind else alpha_of(p))))
        col.append((fr, "@color/hz_ember_t" if p > near_from else "@color/hz_fg2"))
    if stroke:
        shape = ('            <group android:name="g%d">\n'
                 '                <path android:name="p%d" android:strokeColor="@color/hz_fg2" android:strokeAlpha="0"\n'
                 '                    android:strokeWidth="%s" android:strokeLineCap="round" android:strokeLineJoin="round"\n'
                 '                    android:pathData="%s" />\n            </group>\n') % (i, i, f(STROKE), path)
        cprop, aprop = "strokeColor", "strokeAlpha"
    else:
        shape = ('            <group android:name="g%d">\n'
                 '                <path android:name="p%d" android:fillColor="@color/hz_fg2" android:fillAlpha="0"\n'
                 '                    android:pathData="%s" />\n            </group>\n') % (i, i, path)
        cprop, aprop = "fillColor", "fillAlpha"
    targets = target("g%d" % i, dur, [kf("translateX", "floatType", tx), kf("translateY", "floatType", ty),
                                      kf("scaleX", "floatType", sc), kf("scaleY", "floatType", sc)])
    targets += target("p%d" % i, dur, [kf(cprop, "colorType", col), kf(aprop, "floatType", al)])
    return shape, targets


def write(name, label, body, targets):
    out = HEAD % (label, V, V, V, V) + body + "        </vector>\n    </aapt:attr>\n" + targets
    out += "</animated-vector>\n"
    with open(os.path.join(D, name + ".xml"), "w") as fh:
        fh.write(out)


def title():
    hole_r, dur = 5.2, 2100
    shapes = targets = ""
    for i, letter in enumerate("AaT"):
        th0 = i * 2.1

        def traj(p, th0=th0):
            r = 5.5 + 12 * (1 - p)
            th = p * 3.2 * math.pi + th0
            x, y = orbit(r, th, 0.42)
            behind = math.sin(th) < 0 and math.hypot(x - CX, y - CY) < hole_r + 1.5
            return x, y, behind

        s, t = particle(i, LETTERS[letter], i / 3, dur, traj,
                        alpha_of=lambda p: clamp(p / 0.1) * clamp((5.5 + 12 * (1 - p) - 5.8) / 2.5),
                        scale_of=lambda p: 1 - p * 0.45, near_from=0.55, stroke=True)
        shapes += s
        targets += t
    write("widget_ai_title_loading", "IA, título: «Letras en órbita».",
          static_layers(13, 0.22, hole_r, ring=(11, 4.4)) + shapes, targets)


def summary():
    hole_r, dur, n = 6.0, 1800, 9
    shapes = targets = ""
    for i in range(n):
        th0 = i * 1.7
        bit = ("1" if i % 2 else "0") if i % 3 == 0 else None

        def traj(p, th0=th0):
            r = 6 + 13 * (1 - p)
            th = p * 2.8 * math.pi + th0
            x, y = orbit(r, th, 0.55)
            behind = math.sin(th) < 0 and math.hypot(x - CX, y - CY) < hole_r + 1
            return x, y, behind

        alpha = lambda p: clamp(p / 0.1) * clamp((6 + 13 * (1 - p) - 6.2) / 2.5)
        if bit:
            s, t = particle(i, LETTERS[bit], i / n, dur, traj, alpha,
                            scale_of=lambda p: 1.0, near_from=0.5, stroke=True)
        else:
            s, t = particle(i, DOT, i / n, dur, traj, alpha,
                            scale_of=lambda p: 1.1 + 0.5 * (1 - p), near_from=0.5, stroke=False)
        shapes += s
        targets += t
    write("widget_ai_summary_loading", "IA, resumen: «Bits que caen».",
          static_layers(13, 0.24, hole_r) + shapes, targets)


if __name__ == "__main__":
    title()
    summary()
