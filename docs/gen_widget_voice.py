#!/usr/bin/env python3
"""Genera las animaciones de la píldora del widget (AnimatedVectorDrawable).

RemoteViews no admite vistas propias ni dibujo por cuadro, así que la animación
A de HorizonView (teclado) y HorizonPainter (app) se reproduce con AVD en bucle
dentro de ProgressBar indeterminados. Este script es la fuente de:

  res/drawable/widget_voice_{low,mid,high}.xml  grabando (3 niveles de volumen)
  res/drawable/widget_voice_think.xml           pensando (rayitas)
  res/drawable/widget_voice_spin.xml            arco que gira sobre el agujero

Paridad con HorizonView.drawAccretion/step:
- grabando: 45 % glifos mono '0' '1' '{' '}', resto guiones y puntos; nacen en
  la ✕ (bajo su halo) y viajan al agujero; tamaño k = 0.45 + 0.55·d, color
  on_hole lejos (d > .45), ember en el medio y hot cerca (d < .18); alfa
  min(1, .25 + .9·d) con fundido de entrada al salir del halo.
- pensando: renglones blancos de 2 px y largo 5–21 px que nacen al borde del
  agujero y se frenan hacia la ✕, con fundido de entrada y de salida.

Uso: python3 docs/gen_widget_voice.py   (desde la raíz del repo)
"""
import os
import random

D = os.path.join(os.path.dirname(__file__), "..",
                 "voice_bubble_stt/android/app/src/main/res/drawable")
VW, VH = 300, 44
CY = 22
HOLE_END = 31      # borde del anillo del agujero (capa fija encima)
BORN_X = 280       # centro de la ✕
GLYPH_STROKE = 1.1

DOT = "M-1.5,0a1.5,1.5 0 1,0 3,0a1.5,1.5 0 1,0 -3,0z"
DASH = "M0,-0.8h8v1.6h-8z"
# Glifos mono de ~8 de alto centrados en (0,0), dibujados con trazo.
GLYPHS = {
    "0": "M0,-4C-1.7,-4 -2.4,-2.4 -2.4,0C-2.4,2.4 -1.7,4 0,4C1.7,4 2.4,2.4 2.4,0C2.4,-2.4 1.7,-4 0,-4Z",
    "1": "M-1.8,-2.6L0.4,-4V4M-2,4H2.4",
    "{": "M1.8,-4.2C0.2,-4.2 -0.3,-3.6 -0.3,-2.4V-1C-0.3,-0.3 -0.8,0 -1.8,0C-0.8,0 -0.3,0.3 -0.3,1V2.4C-0.3,3.6 0.2,4.2 1.8,4.2",
    "}": "M-1.8,-4.2C-0.2,-4.2 0.3,-3.6 0.3,-2.4V-1C0.3,-0.3 0.8,0 1.8,0C0.8,0 0.3,0.3 0.3,1V2.4C0.3,3.6 -0.2,4.2 -1.8,4.2",
}

HEAD = """<?xml version="1.0" encoding="utf-8"?>
<!-- GENERADO por docs/gen_widget_voice.py: no editar a mano. %s -->
<animated-vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt">
    <aapt:attr name="android:drawable">
        <vector android:width="%ddp" android:height="%ddp"
            android:viewportWidth="%d" android:viewportHeight="%d">
"""


def f(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def kf(prop, vtype, frames):
    rows = "".join(
        '                        <keyframe android:fraction="%s" android:value="%s" />\n' % (f(a), b)
        for a, b in frames)
    return ('                    <propertyValuesHolder android:propertyName="%s" android:valueType="%s">\n'
            '%s                    </propertyValuesHolder>\n') % (prop, vtype, rows)


def target(name, dur, off, interp, holders):
    return ("""    <target android:name="%s">
        <aapt:attr name="android:animation">
            <objectAnimator android:duration="%d" android:startOffset="%d"
                    android:repeatCount="infinite" android:repeatMode="restart"
                    android:interpolator="@android:interpolator/%s">
%s                </objectAnimator>
        </aapt:attr>
    </target>
""") % (name, dur, off, interp, "".join(holders))


def write(name, label, shapes, targets, vw=VW, vh=VH):
    out = HEAD % (label, vw, vh, vw, vh) + shapes + "        </vector>\n    </aapt:attr>\n" + targets
    out += "</animated-vector>\n"
    with open(os.path.join(D, "widget_voice_%s.xml" % name), "w") as fh:
        fh.write(out)


def recording(name, n, dur, seed):
    rng = random.Random(seed)
    shapes = targets = ""
    # Posición lineal en el tiempo: los keyframes de color/tamaño/alfa caen
    # sobre la misma fracción que d = 1 - fracción.
    for i in range(n):
        r = rng.random()
        if r < 0.45:
            kind, path = "glyph", GLYPHS[rng.choice("01{}")]
        elif r < 0.72:
            kind, path = "fill", DASH
        else:
            kind, path = "fill", DOT
        ps = rng.uniform(0.55, 1.45)
        d_ms = int(dur / ps)
        y0 = rng.uniform(CY - 13, CY + 13)
        if kind == "glyph":
            shapes += ('            <group android:name="g%d" android:translateX="%d" android:translateY="%s">\n'
                       '                <path android:name="p%d" android:strokeColor="@color/hz_on_hole" android:strokeAlpha="0"\n'
                       '                    android:strokeWidth="%s" android:strokeLineCap="round" android:strokeLineJoin="round"\n'
                       '                    android:pathData="%s" />\n            </group>\n') % (
                i, BORN_X, f(y0), i, f(GLYPH_STROKE), path)
            cprop, aprop = "strokeColor", "strokeAlpha"
        else:
            shapes += ('            <group android:name="g%d" android:translateX="%d" android:translateY="%s">\n'
                       '                <path android:name="p%d" android:fillColor="@color/hz_on_hole" android:fillAlpha="0"\n'
                       '                    android:pathData="%s" />\n            </group>\n') % (i, BORN_X, f(y0), i, path)
            cprop, aprop = "fillColor", "fillAlpha"
        off = rng.randint(0, d_ms)
        targets += target("g%d" % i, d_ms, off, "linear", [
            kf("translateX", "floatType", [(0, BORN_X), (1, HOLE_END)]),
            kf("translateY", "floatType", [(0, f(y0)), (0.5, f(y0 + (CY - y0) * 0.2)),
                                           (0.8, f(y0 + (CY - y0) * 0.55)), (1, CY)]),
            kf("scaleX", "floatType", [(0, 1), (1, 0.45)]),
            kf("scaleY", "floatType", [(0, 1), (1, 0.45)]),
        ])
        targets += target("p%d" % i, d_ms, off, "linear", [
            kf(cprop, "colorType", [(0, "@color/hz_on_hole"), (0.54, "@color/hz_on_hole"),
                                    (0.56, "@color/hz_ember"), (0.81, "@color/hz_ember"),
                                    (0.83, "@color/hz_hot"), (1, "@color/hz_hot")]),
            kf(aprop, "floatType", [(0, 0), (0.08, 1), (0.3, 1), (1, 0.3)]),
        ])
    write(name, "Grabando, nivel %s: glifos, guiones y puntos de la ✕ al agujero." % name, shapes, targets)


def thinking(n=22, seed=9):
    rng = random.Random(seed)
    shapes = targets = ""
    x0 = HOLE_END + 2
    for i in range(n):
        y = CY + (rng.random() - 0.5) * VH * 0.36
        ln = rng.uniform(5, 21)
        ps = rng.uniform(0.6, 1.2)
        d_ms = int(4200 / ps)
        shapes += ('            <group android:name="g%d" android:translateX="%d">\n'
                   '                <path android:name="p%d" android:strokeColor="@color/hz_on_hole" android:strokeAlpha="0"\n'
                   '                    android:strokeWidth="2" android:pathData="M0,%sh%s" />\n            </group>\n') % (
            i, x0, i, f(y), f(ln))
        off = rng.randint(0, d_ms)
        targets += target("g%d" % i, d_ms, off, "decelerate_quad", [
            kf("translateX", "floatType", [(0, x0), (1, BORN_X - 4)]),
        ])
        targets += target("p%d" % i, d_ms, off, "decelerate_quad", [
            kf("strokeAlpha", "floatType", [(0, 0), (0.06, 1), (0.85, 1), (1, 0)]),
        ])
    write("think", "Pensando: rayitas del agujero hacia la ✕.", shapes, targets)


def spin():
    shapes = ('            <group android:name="spin" android:pivotX="22" android:pivotY="22">\n'
              '                <path android:name="arc" android:strokeColor="@color/hz_hot" android:strokeWidth="3"\n'
              '                    android:strokeLineCap="round" android:pathData="M22,7A15,15 0 0,1 34.99,29.5" />\n'
              '            </group>\n')
    targets = target("spin", 1100, 0, "linear", [kf("rotation", "floatType", [(0, 0), (1, 360)])])
    write("spin", "Pensando: arco que gira sobre el agujero (capa fija de 44dp).", shapes, targets, 44, 44)


if __name__ == "__main__":
    # Duración base a velocidad media (ps = 1); cada partícula se divide por su
    # velocidad propia, igual que ps en HorizonView. Cantidad = concurrentes.
    recording("low", 20, 3600, 1)
    recording("mid", 30, 2300, 2)
    recording("high", 40, 1400, 3)
    thinking()
    spin()
