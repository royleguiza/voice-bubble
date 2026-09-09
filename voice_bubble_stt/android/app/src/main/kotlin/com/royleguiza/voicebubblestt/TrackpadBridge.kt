package com.royleguiza.voicebubblestt

import android.inputmethodservice.InputMethodService
import android.os.Build
import android.provider.Settings
import android.transition.ChangeBounds
import android.transition.Fade
import android.transition.TransitionManager
import android.transition.TransitionSet
import android.view.HapticFeedbackConstants
import android.view.KeyEvent
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.widget.LinearLayout
import android.widget.Toast

/**
 * Puente del trackpad (SPK-05, módulo 6 de N): capa TRACKPAD con cursor
 * de mouse virtual, extraída de VoiceKeyboardService sin cambiar conducta.
 * Todo lo que necesita del teclado entra por [service] (contexto/sistema),
 * [kbPrefs] (caché de preferencias) y [host]; el overlay ([manager]) y su
 * ciclo de vida son suyos. El modo 2D de la barra espaciadora (MEJ-25) se
 * queda en VKS: está acoplado a gestos/shift/snippets/commit.
 */
class TrackpadBridge(
    private val service: InputMethodService,
    private val kbPrefs: KeyboardPrefs,
    private val host: UiHost,
) {

    /** Lo mínimo que el trackpad exige al teclado. */
    interface UiHost {
        fun currentLayer(): Layer
        fun setLayer(next: Layer)
        fun lastLetters(): Layer
        fun setLastLetters(l: Layer)
        fun isPasswordField(): Boolean
        fun rootView(): LinearLayout
        fun keyHeightPx(): Int
        fun rowGapPx(): Int
        fun beginTransition()
        fun rebuild()
        fun haptic(view: View)
    }

    private var manager: PointerOverlayManager? = null

    fun playTransition() {
        if (!service.reducedMotion()) {
            try {
                val transition = TransitionSet().apply {
                    ordering = TransitionSet.ORDERING_TOGETHER
                    addTransition(ChangeBounds().apply {
                        duration = 180L
                        interpolator = DecelerateInterpolator()
                    })
                    addTransition(Fade().apply {
                        duration = 140L
                    })
                }
                TransitionManager.beginDelayedTransition(host.rootView(), transition)
            } catch (_: Exception) {}
        }
    }

    fun targetHeightPx(): Int {
        val totalKeyRows = if (kbPrefs.terminalRowVisiblePref) 5 else 4
        return totalKeyRows * host.keyHeightPx() + (totalKeyRows - 1) * host.rowGapPx()
    }

    fun toggle() {
        if (host.isPasswordField()) return
        host.beginTransition()
        if (host.currentLayer() == Layer.TRACKPAD) {
            host.setLayer(host.lastLetters())
            manager?.hide()
            host.rebuild()
        } else {
            val cur = host.currentLayer()
            host.setLastLetters(if (cur != Layer.SNIPPETS && cur != Layer.TRACKPAD) cur else Layer.LETTERS)
            host.setLayer(Layer.TRACKPAD)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(service)) {
                Toast.makeText(service, "Concede el permiso de superposición para ver el cursor", Toast.LENGTH_SHORT).show()
            }
            val m = getOrCreate()
            val location = IntArray(2)
            host.rootView().getLocationOnScreen(location)
            if (location[1] > 0) {
                m.updateKeyboardTop(location[1].toFloat())
            }
            m.show()
            host.rebuild()
            host.rootView().post {
                val loc = IntArray(2)
                host.rootView().getLocationOnScreen(loc)
                if (loc[1] > 0) {
                    m.updateKeyboardTop(loc[1].toFloat())
                }
            }
        }
    }

    fun buildLayer(): View {
        val m = getOrCreate()
        val targetHeight = targetHeightPx()
        return VirtualTrackpadView(
            context = service,
            scrollPosition = kbPrefs.trackpadScrollPosition,
            tapToClick = kbPrefs.trackpadTapToClick,
            secondaryClickMode = kbPrefs.trackpadSecondaryClick,
            scrollDirection = kbPrefs.trackpadScrollDirection,
            autoReturnSeconds = kbPrefs.trackpadAutoReturn,
            trackpadHeightPx = targetHeight,
            buttonLayout = kbPrefs.trackpadButtonLayout,
            listener = object : VirtualTrackpadView.TrackpadListener {
                override fun onPointerMove(dx: Float, dy: Float) {
                    m.moveBy(dx, dy)
                }

                override fun onLeftClick() {
                    val (px, py) = m.getPosition()
                    m.triggerClickFeedback()
                    dispatchTap(px, py)
                }

                override fun onRightClick() {
                    val (px, py) = m.getPosition()
                    m.triggerClickFeedback()
                    dispatchLongPress(px, py)
                }

                override fun onScroll(deltaY: Float) {
                    val (px, py) = m.getPosition()
                    dispatchScroll(px, py, deltaY)
                }

                override fun onAutoReturn() {
                    if (host.currentLayer() == Layer.TRACKPAD) {
                        toggle()
                    }
                }

                override fun performHaptic(isFirm: Boolean) {
                    when (kbPrefs.trackpadHaptic) {
                        "none" -> {}
                        "firm" -> host.haptic(host.rootView())
                        else -> { // "subtle"
                            if (kbPrefs.hapticsEnabled) {
                                host.rootView().performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            }
                        }
                    }
                }
            }
        )
    }

    fun hide() {
        manager?.hide()
    }

    fun destroy() {
        manager?.destroy()
        manager = null
    }

    private fun getOrCreate(): PointerOverlayManager {
        val existing = manager
        if (existing != null) {
            existing.sensitivity = kbPrefs.trackpadSensitivity
            existing.accelCurve = kbPrefs.trackpadAccelCurve
            existing.pointerStyle = kbPrefs.trackpadPointerStyle
            return existing
        }
        val created = PointerOverlayManager(service)
        created.sensitivity = kbPrefs.trackpadSensitivity
        created.accelCurve = kbPrefs.trackpadAccelCurve
        created.pointerStyle = kbPrefs.trackpadPointerStyle
        manager = created
        return created
    }

    private fun dispatchTap(x: Float, y: Float) {
        if (VoiceBubbleAccessibilityService.isConnected()) {
            VoiceBubbleAccessibilityService.dispatchTap(x, y)
            return
        }
        service.currentInputConnection ?: return
        service.sendDownUpKeyEvents(KeyEvent.KEYCODE_DPAD_CENTER)
    }

    private fun dispatchLongPress(x: Float, y: Float) {
        if (VoiceBubbleAccessibilityService.isConnected()) {
            VoiceBubbleAccessibilityService.dispatchLongPress(x, y)
            return
        }
        service.currentInputConnection ?: return
        service.sendDownUpKeyEvents(KeyEvent.KEYCODE_MENU)
    }

    private fun dispatchScroll(x: Float, y: Float, deltaY: Float) {
        if (VoiceBubbleAccessibilityService.isConnected()) {
            VoiceBubbleAccessibilityService.dispatchScroll(x, y, deltaY)
            return
        }
        service.currentInputConnection ?: return
        if (deltaY > 0) {
            service.sendDownUpKeyEvents(KeyEvent.KEYCODE_DPAD_DOWN)
        } else if (deltaY < 0) {
            service.sendDownUpKeyEvents(KeyEvent.KEYCODE_DPAD_UP)
        }
    }
}
