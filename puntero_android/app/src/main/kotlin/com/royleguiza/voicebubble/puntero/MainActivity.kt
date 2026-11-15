package com.royleguiza.voicebubble.puntero

import android.app.Activity
import android.content.Intent
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
 * Construida en código (sin dependencias) con Horizonte, el diseño de
 * VoiceBubble: tokens hz_* día/noche, Sora en títulos e Inter en el texto.
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
    private val sora by lazy { Fonts.sora(this) }
    private val inter by lazy { Fonts.inter(this) }
    private val interMedium by lazy { Fonts.interMedium(this) }

    /** Tarjeta Horizonte: superficie surf con borde line de 1 dp. */
    private fun surface(radiusDp: Float, fillId: Int = R.color.hz_surf) = GradientDrawable().apply {
        cornerRadius = radiusDp * d
        setColor(color(fillId))
        setStroke(maxOf(1, dp(1f)), color(R.color.hz_line))
    }

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

        column.addView(text(getString(R.string.app_name), 30f, R.color.hz_fg, heading = true))
        column.addView(
            text(
                "Hace los clics del trackpad de VoiceBubble en cualquier app, con cualquier teclado. " +
                    "No lee lo que hay en la pantalla ni guarda nada.",
                17f, R.color.hz_fg2,
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
            background = surface(26f)
        }
        statusDot = View(this).apply {
            background = GradientDrawable().apply { shape = GradientDrawable.OVAL }
        }
        card.addView(statusDot, LinearLayout.LayoutParams(dp(10f), dp(10f)).apply { marginEnd = dp(12f) })
        statusText = text("", 17f, R.color.hz_fg, medium = true)
        card.addView(statusText)
        column.addView(card)

        primary = Button(this).apply {
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
            typeface = interMedium
            stateListAnimator = null
            setOnClickListener {
                open(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            }
        }
        column.addView(primary, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(54f)).apply {
            topMargin = dp(16f)
        })

        steps = text("", 15f, R.color.hz_fg2)
        column.addView(steps, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(16f)
        })

        // Prueba de clic: el servicio toca el botón «Blanco» de esta pantalla.
        // Si Android lo ejecuta, el botón se entera; si no, se ve por qué.
        column.addView(text("Probar el clic", 20f, R.color.hz_fg, heading = true),
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(32f)
            })
        column.addView(text("Tocá «Probar»: VoiceBubble Puntero va a tocar el botón «Blanco» solo, como haría con el trackpad.",
            15f, R.color.hz_fg2),
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(6f)
            })
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val target = pill("Blanco", R.color.hz_surf, R.color.hz_fg, outlined = true)
        target.setOnClickListener {
            if (testWaiting) {
                testWaiting = false
                testResult.text = "✓ Android hizo el clic. El puntero puede tocar en otras apps."
                testResult.setTextColor(color(R.color.hz_ok))
            }
        }
        val run = pill("Probar", R.color.hz_ember, R.color.hz_on_ember)
        run.setOnClickListener { runTest(target) }
        row.addView(run, LinearLayout.LayoutParams(0, dp(52f), 1f).apply { marginEnd = dp(12f) })
        row.addView(target, LinearLayout.LayoutParams(0, dp(52f), 1f))
        column.addView(row, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52f)).apply {
            topMargin = dp(14f)
        })
        testResult = text("", 15f, R.color.hz_fg2)
        column.addView(testResult, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(10f)
        })
        counters = text("", 13f, R.color.hz_fg2)
        column.addView(counters, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(6f)
        })

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            column.addView(
                text(
                    "Si Android dice «Ajuste restringido»: abrí la información de la app, tocá ⋮ " +
                        "arriba a la derecha y elegí «Permitir ajustes restringidos». Después volvé a Accesibilidad.",
                    15f, R.color.hz_fg2,
                ),
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    topMargin = dp(20f)
                },
            )
            column.addView(Button(this).apply {
                text = "Abrir información de la app"
                isAllCaps = false
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
                setTextColor(color(R.color.hz_ember_t))
                typeface = interMedium
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
        testResult.setTextColor(color(R.color.hz_fg2))
        if (!PunteroService.isConnected) {
            testResult.text = "✗ El servicio no está en marcha. Activalo en Accesibilidad (si ya está activo, apagalo y volvé a prenderlo)."
            testResult.setTextColor(color(R.color.hz_danger))
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
                    testResult.setTextColor(color(R.color.hz_danger))
                }
            }
        }
        if (!sent) {
            testWaiting = false
            testResult.text = "✗ Android rechazó el gesto. Apagá y volvé a prender VoiceBubble Puntero en Accesibilidad."
            testResult.setTextColor(color(R.color.hz_danger))
            return
        }
        target.postDelayed({
            if (testWaiting) {
                testWaiting = false
                testResult.text = "✗ Android dijo que hizo el gesto, pero el botón no recibió el toque."
                testResult.setTextColor(color(R.color.hz_danger))
            }
            renderCounters()
        }, 1500L)
    }

    private fun pill(label: String, bgId: Int, fgId: Int, outlined: Boolean = false) = Button(this).apply {
        text = label
        isAllCaps = false
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        typeface = interMedium
        stateListAnimator = null
        setTextColor(color(fgId))
        background = if (outlined) {
            surface(26f, bgId)
        } else {
            GradientDrawable().apply {
                cornerRadius = 26f * d
                setColor(color(bgId))
            }
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
        (statusDot.background as GradientDrawable).setColor(color(if (enabled && PunteroService.isConnected) R.color.hz_ok else R.color.hz_danger))
        statusText.text = when {
            enabled && PunteroService.isConnected -> "Activo. Los clics del puntero ya funcionan."
            enabled -> "Activado en Accesibilidad, pero Android no lo inició. Apagalo y volvé a prenderlo."
            else -> "Desactivado"
        }
        primary.text = if (enabled) "Abrir Accesibilidad" else "Activar en Accesibilidad"
        // Primario en brasa con texto on-ember; ya activo, pasa a tarjeta.
        primary.setTextColor(color(if (enabled) R.color.hz_ember_t else R.color.hz_on_ember))
        primary.background = if (enabled) {
            surface(16f)
        } else {
            GradientDrawable().apply {
                cornerRadius = 16f * d
                setColor(color(R.color.hz_ember))
            }
        }
        steps.text = if (enabled) {
            "Abrí el trackpad desde la barra de VoiceBubble: tocar es clic, mantener es clic largo."
        } else {
            "En Accesibilidad, elegí «VoiceBubble Puntero» y activalo."
        }
    }

    /** Texto Horizonte: [heading] = Sora (títulos), [medium] = Inter medium, si no Inter regular. */
    private fun text(
        value: String,
        sp: Float,
        colorId: Int,
        heading: Boolean = false,
        medium: Boolean = false,
    ) = TextView(this).apply {
        text = value
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
        setTextColor(color(colorId))
        setLineSpacing(0f, 1.25f)
        typeface = when {
            heading -> sora
            medium -> interMedium
            else -> inter
        }
    }

    private fun open(intent: Intent) {
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {}
    }
}
