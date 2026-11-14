package com.royleguiza.voicebubble.puntero

import android.app.Activity
import android.content.Intent
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * Única pantalla del complemento: dice si está activo y lleva a activarlo.
 * Construida en código (sin dependencias) con el lenguaje de VoiceBubble.
 */
class MainActivity : Activity() {

    private lateinit var statusDot: View
    private lateinit var statusText: TextView
    private lateinit var primary: Button
    private lateinit var steps: TextView
    private lateinit var testResult: TextView
    private lateinit var counters: TextView
    private var testWaiting = false

    private val d get() = resources.displayMetrics.density
    private fun color(id: Int) = getColor(id)
    private fun dp(v: Float) = (v * d).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24f), dp(56f), dp(24f), dp(32f))
        }

        column.addView(ImageView(this).apply {
            setImageDrawable(packageManager.getApplicationIcon(applicationInfo))
            contentDescription = null
        }, LinearLayout.LayoutParams(dp(72f), dp(72f)).apply { bottomMargin = dp(20f) })

        column.addView(text(getString(R.string.app_name), 30f, R.color.label, bold = true))
        column.addView(
            text(
                "Hace los clics del trackpad de VoiceBubble en cualquier app, con cualquier teclado. " +
                    "No lee lo que hay en la pantalla ni guarda nada.",
                17f, R.color.secondary,
            ),
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(8f)
                bottomMargin = dp(28f)
            },
        )

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18f), dp(16f), dp(18f), dp(16f))
            background = GradientDrawable().apply {
                cornerRadius = 26f * d
                setColor(color(R.color.surface))
            }
        }
        statusDot = View(this).apply {
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL }
        }
        card.addView(statusDot, LinearLayout.LayoutParams(dp(10f), dp(10f)).apply { marginEnd = dp(12f) })
        statusText = text("", 17f, R.color.label, bold = true)
        card.addView(statusText)
        column.addView(card)

        primary = Button(this).apply {
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = Typeface.DEFAULT_BOLD
            stateListAnimator = null
            setOnClickListener {
                open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
        }
        column.addView(primary, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(54f)).apply {
            topMargin = dp(16f)
        })

        steps = text("", 15f, R.color.secondary)
        column.addView(steps, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(16f)
        })

        // Prueba de clic: el servicio toca el botón «Blanco» de esta pantalla.
        // Si Android lo ejecuta, el botón se entera; si no, se ve por qué.
        column.addView(text("Probar el clic", 20f, R.color.label, bold = true),
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(32f)
            })
        column.addView(text("Tocá «Probar»: VoiceBubble Puntero va a tocar el botón «Blanco» solo, como haría con el trackpad.",
            15f, R.color.secondary),
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(6f)
            })
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val target = pill("Blanco", R.color.surface, R.color.label)
        target.setOnClickListener {
            if (testWaiting) {
                testWaiting = false
                testResult.text = "✓ Android hizo el clic. El puntero puede tocar en otras apps."
                testResult.setTextColor(color(R.color.ok))
            }
        }
        val run = pill("Probar", R.color.accent, R.color.on_accent)
        run.setOnClickListener { runTest(target) }
        row.addView(run, LinearLayout.LayoutParams(0, dp(52f), 1f).apply { marginEnd = dp(12f) })
        row.addView(target, LinearLayout.LayoutParams(0, dp(52f), 1f))
        column.addView(row, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52f)).apply {
            topMargin = dp(14f)
        })
        testResult = text("", 15f, R.color.secondary)
        column.addView(testResult, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(10f)
        })
        counters = text("", 13f, R.color.secondary)
        column.addView(counters, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(6f)
        })

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            column.addView(
                text(
                    "Si Android dice «Ajuste restringido»: abrí la información de la app, tocá ⋮ " +
                        "arriba a la derecha y elegí «Permitir ajustes restringidos». Después volvé a Accesibilidad.",
                    15f, R.color.secondary,
                ),
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    topMargin = dp(20f)
                },
            )
            column.addView(Button(this).apply {
                text = "Abrir información de la app"
                isAllCaps = false
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTextColor(color(R.color.accent))
                background = null
                stateListAnimator = null
                gravity = Gravity.START or Gravity.CENTER_VERTICAL
                setPadding(0, 0, 0, 0)
                setOnClickListener {
                    open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(Uri.parse("package:$packageName")))
                }
            }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(48f)))
        }

        setContentView(ScrollView(this).apply {
            isFillViewport = true
            addView(column)
        })
    }

    override fun onResume() {
        super.onResume()
        render(isEnabled())
        renderCounters()
    }

    private fun renderCounters() {
        counters.text = "Desde que se activó: ${PunteroService.received} clics pedidos por VoiceBubble · " +
            "${PunteroService.done} hechos · ${PunteroService.cancelled} interrumpidos · " +
            "${PunteroService.rejected} rechazados."
    }

    private fun runTest(target: View) {
        testResult.setTextColor(color(R.color.secondary))
        if (!PunteroService.isConnected) {
            testResult.text = "✗ El servicio no está en marcha. Activalo en Accesibilidad (si ya está activo, apagalo y volvé a prenderlo)."
            testResult.setTextColor(color(R.color.warn))
            return
        }
        val loc = IntArray(2)
        target.getLocationOnScreen(loc)
        val x = loc[0] + target.width / 2f
        val y = loc[1] + target.height / 2f
        testWaiting = true
        testResult.text = "Probando…"
        val sent = PunteroService.testTap(x, y) { completed ->
            runOnUiThread {
                if (!completed && testWaiting) {
                    testWaiting = false
                    testResult.text = "✗ Android canceló el gesto. Apagá y volvé a prender VoiceBubble Puntero en Accesibilidad."
                    testResult.setTextColor(color(R.color.warn))
                }
            }
        }
        if (!sent) {
            testWaiting = false
            testResult.text = "✗ Android rechazó el gesto. Apagá y volvé a prender VoiceBubble Puntero en Accesibilidad."
            testResult.setTextColor(color(R.color.warn))
            return
        }
        target.postDelayed({
            if (testWaiting) {
                testWaiting = false
                testResult.text = "✗ Android dijo que hizo el gesto, pero el botón no recibió el toque."
                testResult.setTextColor(color(R.color.warn))
            }
            renderCounters()
        }, 1500L)
    }

    private fun pill(label: String, bgId: Int, fgId: Int) = Button(this).apply {
        text = label
        isAllCaps = false
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        typeface = Typeface.DEFAULT_BOLD
        stateListAnimator = null
        setTextColor(color(fgId))
        background = GradientDrawable().apply {
            cornerRadius = 26f * d
            setColor(color(bgId))
        }
    }

    private fun isEnabled(): Boolean {
        val setting = try {
            Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
        } catch (_: Exception) {
            null
        }
        return PointerProtocol.isServiceEnabled(setting)
    }

    private fun render(enabled: Boolean) {
        (statusDot.background as GradientDrawable).setColor(color(if (enabled && PunteroService.isConnected) R.color.ok else R.color.warn))
        statusText.text = when {
            enabled && PunteroService.isConnected -> "Activo. Los clics del puntero ya funcionan."
            enabled -> "Activado en Accesibilidad, pero Android no lo inició. Apagalo y volvé a prenderlo."
            else -> "Desactivado"
        }
        primary.text = if (enabled) "Abrir Accesibilidad" else "Activar en Accesibilidad"
        primary.setTextColor(color(if (enabled) R.color.accent else R.color.on_accent))
        primary.background = GradientDrawable().apply {
            cornerRadius = 16f * d
            setColor(color(if (enabled) R.color.surface else R.color.accent))
        }
        steps.text = if (enabled) {
            "Abrí el trackpad desde la barra de VoiceBubble: tocar es clic, mantener es clic largo."
        } else {
            "En Accesibilidad, elegí «VoiceBubble Puntero» y activalo."
        }
    }

    private fun text(value: String, sp: Float, colorId: Int, bold: Boolean = false) = TextView(this).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        setTextColor(color(colorId))
        setLineSpacing(0f, 1.25f)
        if (bold) typeface = Typeface.DEFAULT_BOLD
    }

    private fun open(intent: Intent) {
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {}
    }
}
