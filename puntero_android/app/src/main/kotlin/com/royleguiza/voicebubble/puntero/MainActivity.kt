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
import android.widget.SeekBar
import android.widget.Switch
import android.widget.TextView
import kotlin.math.roundToInt

/**
 * Única pantalla del complemento: dice si está activo y lleva a activarlo, y
 * (fase 3) permite usarlo sin VoiceBubble: pestaña propia en el borde, lado,
 * ajustes mínimos del trackpad y volver a poner el trackpad en su lugar.
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

    private val prefs by lazy { DockPrefs(this) }
    private lateinit var tabSwitch: Switch
    private lateinit var tabNote: TextView
    private lateinit var ownSettings: LinearLayout
    private lateinit var hostNote: TextView
    private val sideButtons = mutableListOf<Pair<String, Button>>()
    private val styleButtons = mutableListOf<Pair<String, Button>>()
    private val modeButtons = mutableListOf<Pair<String, Button>>()
    private lateinit var sensValue: TextView
    private lateinit var sensBar: SeekBar

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
                getString(R.string.ptr_main_intro),
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

        buildStandalone(column)

        // Prueba de clic: el servicio toca el botón «Blanco» de esta pantalla.
        // Si Android lo ejecuta, el botón se entera; si no, se ve por qué.
        column.addView(text(getString(R.string.ptr_main_test_title), 20f, R.color.hz_fg, heading = true),
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(32f)
            })
        column.addView(text(getString(R.string.ptr_main_test_hint),
            15f, R.color.hz_fg2),
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(6f)
            })
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val target = pill(getString(R.string.ptr_main_target), R.color.hz_surf, R.color.hz_fg, outlined = true)
        target.setOnClickListener {
            if (testWaiting) {
                testWaiting = false
                testResult.text = getString(R.string.ptr_main_test_ok)
                testResult.setTextColor(color(R.color.hz_ok))
            }
        }
        val run = pill(getString(R.string.ptr_main_test_button), R.color.hz_ember, R.color.hz_on_ember)
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
                    getString(R.string.ptr_main_restricted_hint),
                    15f, R.color.hz_fg2,
                ),
                LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                    topMargin = dp(20f)
                },
            )
            column.addView(Button(this).apply {
                text = getString(R.string.ptr_main_app_info)
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
        renderStandalone()
    }

    // ------------------------------------------------------- sin VoiceBubble (fase 3)

    private fun lp(topDp: Float = 0f) =
        LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(topDp)
        }

    private fun buildStandalone(column: LinearLayout) {
        column.addView(text(getString(R.string.ptr_main_tab_title), 20f, R.color.hz_fg, heading = true), lp(32f))
        column.addView(
            text(getString(R.string.ptr_main_tab_hint), 15f, R.color.hz_fg2),
            lp(6f),
        )

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(18f), dp(10f), dp(12f), dp(10f))
            background = surface(26f)
        }
        card.addView(text(getString(R.string.ptr_main_edge_tab), 17f, R.color.hz_fg, medium = true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        tabSwitch = Switch(this).apply {
            contentDescription = getString(R.string.ptr_main_edge_tab)
            val states = arrayOf(intArrayOf(android.R.attr.state_checked), intArrayOf())
            thumbTintList = android.content.res.ColorStateList(states, intArrayOf(color(R.color.hz_on_ember), color(R.color.hz_surf)))
            trackTintList = android.content.res.ColorStateList(states, intArrayOf(color(R.color.hz_ember), color(R.color.hz_line)))
            setOnCheckedChangeListener { _, on ->
                if (on == prefs.ownTab()) return@setOnCheckedChangeListener
                prefs.setOwnTab(on)
                PunteroService.refreshOwnSettings()
                renderStandalone()
            }
        }
        card.addView(tabSwitch)
        column.addView(card, lp(14f))
        tabNote = text("", 14f, R.color.hz_fg2)
        column.addView(tabNote, lp(8f))

        column.addView(text(getString(R.string.ptr_main_tab_side), 15f, R.color.hz_fg, medium = true), lp(18f))
        column.addView(choiceRow(sideButtons, listOf("left" to getString(R.string.ptr_main_left), "right" to getString(R.string.ptr_main_right))) { side ->
            prefs.saveSide(if (side == "left") DockGeometry.Side.LEFT else DockGeometry.Side.RIGHT)
            PunteroService.refreshOwnSettings(rebuild = true)
            renderStandalone()
        }, lp(8f))

        column.addView(text(getString(R.string.ptr_main_trackpad_title), 20f, R.color.hz_fg, heading = true), lp(28f))
        column.addView(
            text(
                getString(R.string.ptr_main_window_hint),
                15f, R.color.hz_fg2,
            ),
            lp(6f),
        )
        hostNote = text(
            getString(R.string.ptr_main_host_note),
            15f, R.color.hz_fg2,
        )
        column.addView(hostNote, lp(12f))

        ownSettings = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        ownSettings.addView(text(getString(R.string.ptr_main_shape), 15f, R.color.hz_fg, medium = true), lp(12f))
        ownSettings.addView(choiceRow(modeButtons, listOf(PointerProtocol.MODE_WINDOW to getString(R.string.ptr_main_shape_window), PointerProtocol.MODE_PANEL to getString(R.string.ptr_main_shape_panel))) { mode ->
            saveOwn(mode = mode)
        }, lp(8f))
        ownSettings.addView(text(getString(R.string.ptr_main_style), 15f, R.color.hz_fg, medium = true), lp(18f))
        ownSettings.addView(choiceRow(styleButtons, listOf(
            PointerProtocol.STYLE_ARROW to getString(R.string.ptr_main_style_arrow),
            PointerProtocol.STYLE_DOT to getString(R.string.ptr_main_style_dot),
            PointerProtocol.STYLE_CROSS to getString(R.string.ptr_main_style_cross),
        )) { style -> saveOwn(style = style) }, lp(8f))
        val sensRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        sensRow.addView(text(getString(R.string.ptr_main_sensitivity), 15f, R.color.hz_fg, medium = true), LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
        sensValue = text("", 15f, R.color.hz_fg2)
        sensRow.addView(sensValue)
        ownSettings.addView(sensRow, lp(18f))
        val steps = ((PointerProtocol.MAX_SENSITIVITY - PointerProtocol.MIN_SENSITIVITY) * 10).roundToInt()
        sensBar = SeekBar(this).apply {
            max = steps
            contentDescription = getString(R.string.ptr_main_sensitivity_desc)
            progressTintList = android.content.res.ColorStateList.valueOf(color(R.color.hz_ember))
            thumbTintList = android.content.res.ColorStateList.valueOf(color(R.color.hz_ember))
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(bar: SeekBar, progress: Int, fromUser: Boolean) {
                    val v = sensFromProgress(progress)
                    sensValue.text = String.format("%.1f×", v)
                    if (fromUser) saveOwn(sensitivity = v)
                }
                override fun onStartTrackingTouch(bar: SeekBar) {}
                override fun onStopTrackingTouch(bar: SeekBar) {}
            })
        }
        ownSettings.addView(sensBar, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(48f)))
        column.addView(ownSettings, lp(0f))

        column.addView(Button(this).apply {
            text = getString(R.string.ptr_main_reset_placement)
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(color(R.color.hz_ember_t))
            typeface = interMedium
            background = null
            stateListAnimator = null
            gravity = Gravity.START or Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 0)
            setOnClickListener {
                prefs.clearTrackpadPlacement()
                text = getString(R.string.ptr_main_reset_done)
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, dp(48f)).apply { topMargin = dp(8f) })
    }

    private fun sensFromProgress(progress: Int): Float =
        (PointerProtocol.MIN_SENSITIVITY + progress / 10f).coerceIn(PointerProtocol.MIN_SENSITIVITY, PointerProtocol.MAX_SENSITIVITY)

    private fun saveOwn(sensitivity: Float? = null, style: String? = null, mode: String? = null) {
        val cur = prefs.ownTrackpad()
        prefs.saveOwnTrackpad(sensitivity ?: cur.sensitivity, style ?: cur.style, mode ?: cur.mode)
        PunteroService.refreshOwnSettings()
        renderStandalone()
    }

    /** Fila de opciones (una sola elegida): píldoras Horizonte, la elegida en brasa. */
    private fun choiceRow(
        into: MutableList<Pair<String, Button>>,
        options: List<Pair<String, String>>,
        onPick: (String) -> Unit,
    ): LinearLayout {
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        options.forEachIndexed { i, (value, label) ->
            val b = pill(label, R.color.hz_surf, R.color.hz_fg, outlined = true)
            b.setOnClickListener { onPick(value) }
            into += value to b
            row.addView(b, LinearLayout.LayoutParams(0, dp(48f), 1f).apply {
                if (i > 0) marginStart = dp(10f)
            })
        }
        return row
    }

    private fun markChoice(buttons: List<Pair<String, Button>>, selected: String) {
        for ((value, b) in buttons) {
            val on = value == selected
            b.isSelected = on
            b.setTextColor(color(if (on) R.color.hz_on_ember else R.color.hz_fg))
            b.background = if (on) {
                GradientDrawable().apply {
                    cornerRadius = 26f * d
                    setColor(color(R.color.hz_ember))
                }
            } else {
                surface(26f)
            }
        }
    }

    private fun renderStandalone() {
        val own = prefs.ownTab()
        if (tabSwitch.isChecked != own) tabSwitch.isChecked = own
        val hostDock = PunteroService.hostDockEnabled(this)
        tabNote.text = when {
            own && hostDock -> getString(R.string.ptr_main_tab_note_host)
            own -> getString(R.string.ptr_main_tab_note_own)
            else -> getString(R.string.ptr_main_tab_note_off)
        }
        markChoice(sideButtons, if (prefs.side() == DockGeometry.Side.LEFT) "left" else "right")
        val hostInstalled = HostLink.isHostInstalled(this)
        hostNote.visibility = if (hostInstalled) View.VISIBLE else View.GONE
        ownSettings.visibility = if (hostInstalled) View.GONE else View.VISIBLE
        val tp = prefs.ownTrackpad()
        markChoice(modeButtons, tp.mode)
        markChoice(styleButtons, tp.style)
        val progress = ((tp.sensitivity - PointerProtocol.MIN_SENSITIVITY) * 10).roundToInt()
        if (sensBar.progress != progress) sensBar.progress = progress
        sensValue.text = String.format("%.1f×", tp.sensitivity)
    }

    private fun renderCounters() {
        counters.text = getString(R.string.ptr_main_counters, PunteroService.received, PunteroService.done, PunteroService.cancelled, PunteroService.rejected)
    }

    private fun runTest(target: View) {
        testResult.setTextColor(color(R.color.hz_fg2))
        if (!PunteroService.isConnected) {
            testResult.text = getString(R.string.ptr_main_err_service_down)
            testResult.setTextColor(color(R.color.hz_danger))
            return
        }
        val loc = IntArray(2)
        target.getLocationOnScreen(loc)
        val x = loc[0] + target.width / 2f
        val y = loc[1] + target.height / 2f
        testWaiting = true
        testResult.text = getString(R.string.ptr_main_testing)
        val sent = PunteroService.testTap(x, y) { completed ->
            runOnUiThread {
                if (!completed && testWaiting) {
                    testWaiting = false
                    testResult.text = getString(R.string.ptr_main_err_cancelled)
                    testResult.setTextColor(color(R.color.hz_danger))
                }
            }
        }
        if (!sent) {
            testWaiting = false
            testResult.text = getString(R.string.ptr_main_err_rejected)
            testResult.setTextColor(color(R.color.hz_danger))
            return
        }
        target.postDelayed({
            if (testWaiting) {
                testWaiting = false
                testResult.text = getString(R.string.ptr_main_err_no_touch)
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
            enabled && PunteroService.isConnected -> getString(R.string.ptr_main_status_active)
            enabled -> getString(R.string.ptr_main_status_not_started)
            else -> getString(R.string.ptr_main_status_off)
        }
        primary.text = if (enabled) getString(R.string.ptr_main_open_accessibility) else getString(R.string.ptr_main_enable_accessibility)
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
            getString(R.string.ptr_main_steps_enabled)
        } else {
            getString(R.string.ptr_main_steps_disabled)
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
