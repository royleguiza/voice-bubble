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
        (statusDot.background as GradientDrawable).setColor(color(if (enabled) R.color.ok else R.color.warn))
        statusText.text = if (enabled) "Activo. Los clics del puntero ya funcionan." else "Desactivado"
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
