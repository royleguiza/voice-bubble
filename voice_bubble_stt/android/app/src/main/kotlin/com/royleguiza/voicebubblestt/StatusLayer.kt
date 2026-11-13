package com.royleguiza.voicebubblestt

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.InsetDrawable
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Capa Status (SPK-05, módulo 10 de N): aviso breve no bloqueante, extraído
 * de VoiceKeyboardService. Es una cápsula flotante SUPERPUESTA al teclado
 * (design.md §12 "Avisos"): vive en el [UiHost.noticeHost] (hermano de la
 * raíz del teclado), por lo que jamás cambia su altura, sus mediciones ni
 * sus insets, y fuera de la cápsula los toques llegan a las teclas.
 * Todo lo que necesita del teclado entra por [service], [handler] y
 * [host]; el estado (vista, mensaje, timer) es suyo. PRIVACIDAD: solo
 * muestra mensajes operativos (nunca contenido dictado ni tecleado).
 */
class StatusLayer(
    private val service: InputMethodService,
    private val handler: Handler,
    private val host: UiHost,
) {

    companion object {
        const val NOTICE_DEAD_CONNECTION_ES = "Conexión perdida"
        const val NOTICE_DEAD_CONNECTION_EN = "Connection lost"

        /** Duración visible: informativo, error y con acción (ms). */
        const val DURATION_INFO_MS = 1400L
        const val DURATION_ERROR_MS = 3000L
        const val DURATION_ACTION_MS = 4000L

        /** Animación: entrada, salida y fundido del texto al reemplazarlo (ms). */
        const val ENTER_MS = 160L
        const val EXIT_MS = 180L
        const val SWAP_OUT_MS = 70L
        const val SWAP_IN_MS = 90L

        private const val RISE_DP = 6f
        private const val VISUAL_HEIGHT_DP = 32f
        private const val TOUCH_HEIGHT_DP = 44f
        private const val PAD_H_DP = 14f
        private const val SIDE_MARGIN_DP = 16f
        private const val MULTILINE_RADIUS_DP = 16f
        private const val DOT_DP = 6f
        private const val TEXT_SP = 13f
        private const val BORDER_ALPHA = 0x59
        private const val BORDER_ALPHA_ERROR = 0xB3

        @Volatile
        internal var activeInstance: StatusLayer? = null
            private set
    }

    init {
        activeInstance = this
    }

    /** Lo mínimo que el aviso exige al teclado. */
    interface UiHost {
        fun rootView(): LinearLayout
        fun currentInputView(): View?
        fun dimenPx(resId: Int): Int

        /** Contenedor superpuesto (hermano de la raíz, mismo recuadro). */
        fun noticeHost(): FrameLayout?
    }

    private var capsule: NoticeCapsule? = null
    private var statusMessage: String? = null
    private var dismissStatusRunnable: Runnable? = null
    private var pending: Content? = null

    private class Content(
        val message: String,
        val isError: Boolean,
        val actionLabel: String?,
        val onClick: (() -> Unit)?,
        val openSettings: Boolean,
    )

    private val density = service.resources.displayMetrics.density
    private fun dp(v: Float): Int = (v * density + 0.5f).toInt()

    private fun animate(): Boolean = ValueAnimator.areAnimatorsEnabled()

    /**
     * Aviso breve. Dura 1,4 s (informativo), 3 s (error) o 4 s (con acción
     * o que abre Ajustes). [isError] pinta el punto y el borde en peligro;
     * [actionLabel] muestra la acción (p. ej. "Reintentar") junto al texto.
     */
    fun show(
        message: String,
        openSettingsOnClick: Boolean = false,
        onClick: (() -> Unit)? = null,
        isError: Boolean = false,
        actionLabel: String? = null,
    ) {
        val view = host.rootView()
        view.post {
            // AT-A9: identidad contra la vista vigente; una vista vieja ya
            // reemplazada nunca crea ni borra avisos.
            if (view !== host.currentInputView()) return@post
            // AT-A9: un aviso identico aun vivo conserva su timer original.
            if (message == statusMessage && capsule != null) return@post
            val overlay = host.noticeHost() ?: return@post
            val content = Content(message, isError, actionLabel, onClick, openSettingsOnClick)
            val existing = capsule
            if (existing != null) {
                swap(existing, content)
            } else {
                create(overlay, view, content)
            }
            statusMessage = message
            schedule(content)
        }
    }

    private fun create(overlay: FrameLayout, root: LinearLayout, c: Content) {
        val cap = NoticeCapsule(service)
        cap.maxWidthOf = { parentW -> parentW - 2 * dp(SIDE_MARGIN_DP) }
        applyContent(cap, c)
        val first = root.getChildAt(0)
        val toolbarH = first?.height ?: 0
        val lp = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.CENTER_HORIZONTAL,
        )
        lp.topMargin = root.paddingTop + ((toolbarH - dp(TOUCH_HEIGHT_DP)) / 2).coerceAtLeast(0)
        capsule = cap
        if (animate()) {
            cap.alpha = 0f
            cap.translationY = dp(RISE_DP).toFloat()
        }
        overlay.addView(cap, lp)
        if (animate()) {
            cap.animate().alpha(1f).translationY(0f).setDuration(ENTER_MS)
                .setInterpolator(DecelerateInterpolator()).start()
        }
        cap.announceForAccessibility(c.message)
    }

    /** Aviso nuevo con otro vivo: fundido corto del texto, sin reiniciar la entrada. */
    private fun swap(cap: NoticeCapsule, c: Content) {
        cap.animate().cancel()
        cap.alpha = 1f
        cap.translationY = 0f
        val tv = cap.messageView
        pending = c
        tv.animate().cancel()
        if (!animate()) {
            pending = null
            tv.alpha = 1f
            applyContent(cap, c)
        } else {
            tv.animate().alpha(0f).setDuration(SWAP_OUT_MS).withEndAction {
                pending?.let { applyContent(cap, it) }
                pending = null
                tv.animate().alpha(1f).setDuration(SWAP_IN_MS).start()
            }.start()
        }
        cap.announceForAccessibility(c.message)
    }

    private fun applyContent(cap: NoticeCapsule, c: Content) {
        cap.bind(
            message = c.message,
            isError = c.isError,
            actionLabel = if (c.onClick != null) c.actionLabel else null,
            multilineRadiusPx = dp(MULTILINE_RADIUS_DP).toFloat(),
        )
        // Tocar la cápsula ejecuta su acción si la tiene: los mensajes de
        // reintento dicen "Toca para reintentar" y deben seguir cumpliéndolo.
        cap.setOnClickListener {
            hideAnimated()
            if (c.onClick != null) c.onClick.invoke()
            else if (c.openSettings) service.openAppUi()
        }
        cap.isClickable = true
        cap.actionView.setOnClickListener {
            hideAnimated()
            c.onClick?.invoke()
        }
    }

    private fun schedule(c: Content) {
        dismissStatusRunnable?.let { handler.removeCallbacks(it) }
        val dismiss = Runnable { hideAnimated() }
        dismissStatusRunnable = dismiss
        val timeout = when {
            c.onClick != null || c.openSettings -> DURATION_ACTION_MS
            c.isError -> DURATION_ERROR_MS
            else -> DURATION_INFO_MS
        }
        handler.postDelayed(dismiss, timeout)
    }

    /** Salida con fundido (180 ms); sin animaciones del sistema, desaparece. */
    private fun hideAnimated() {
        val cap = capsule ?: return
        dismissStatusRunnable?.let { handler.removeCallbacks(it) }
        dismissStatusRunnable = null
        statusMessage = null
        capsule = null
        pending = null
        cap.isClickable = false
        cap.actionView.isClickable = false
        if (!animate()) {
            removeNow(cap)
            return
        }
        cap.animate().cancel()
        cap.messageView.animate().cancel()
        cap.animate().alpha(0f).setDuration(EXIT_MS).withEndAction { removeNow(cap) }.start()
    }

    private fun removeNow(cap: View) {
        (cap.parent as? ViewGroup)?.removeView(cap)
    }

    /** Inmediato: rebuild, ocultar ventana y destruir cancelan timers y animaciones. */
    fun hide() {
        dismissStatusRunnable?.let { handler.removeCallbacks(it) }
        dismissStatusRunnable = null
        statusMessage = null
        pending = null
        val cap = capsule
        capsule = null
        cap?.let {
            it.animate().cancel()
            it.messageView.animate().cancel()
            removeNow(it)
        }
    }

    /**
     * Cápsula: fondo `hz_hole` de 32 dp visibles dentro de una fila táctil de
     * 44 dp (inset vertical), borde 1 dp brasa o peligro, punto de error,
     * texto Inter medium 13 sp y acción opcional en brasa semibold.
     */
    private inner class NoticeCapsule(context: Context) : LinearLayout(context) {
        val messageView = TextView(context)
        val actionView = TextView(context)
        private val dot = View(context)
        private val bg = GradientDrawable()
        private val ember = ContextCompat.getColor(context, R.color.hz_ember)
        private val danger = ContextCompat.getColor(context, R.color.kb_danger)
        private val dotGap = dp(8f)
        private val actionGap = dp(12f)
        private var multilineRadius = 0f
        var maxWidthOf: (Int) -> Int = { it }

        init {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            minimumHeight = dp(TOUCH_HEIGHT_DP)
            val vInset = dp((TOUCH_HEIGHT_DP - VISUAL_HEIGHT_DP) / 2f)
            bg.shape = GradientDrawable.RECTANGLE
            bg.setColor(ContextCompat.getColor(context, R.color.hz_hole))
            background = InsetDrawable(bg, 0, vInset, 0, vInset)
            setPadding(dp(PAD_H_DP), vInset + dp(4f), dp(PAD_H_DP), vInset + dp(4f))
            // No roba el foco de escritura; TalkBack lo lee por anuncio.
            isFocusable = false
            isFocusableInTouchMode = false
            importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES

            dot.background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(danger)
            }
            addView(dot, LayoutParams(dp(DOT_DP), dp(DOT_DP)).apply { marginEnd = dotGap })

            messageView.setTextSize(TypedValue.COMPLEX_UNIT_SP, TEXT_SP)
            messageView.setTextColor(ContextCompat.getColor(context, R.color.hz_on_hole))
            messageView.typeface = KbFonts.bodyWeight(context, 500)
            messageView.maxLines = 2
            messageView.ellipsize = TextUtils.TruncateAt.END
            messageView.importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
            messageView.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ ->
                // 1 línea: cápsula completa; 2 líneas: radio 16 dp.
                bg.cornerRadius = if (messageView.lineCount > 1) multilineRadius else 1000f * density
            }
            addView(messageView, LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))

            actionView.setTextSize(TypedValue.COMPLEX_UNIT_SP, TEXT_SP)
            actionView.setTextColor(ember)
            actionView.typeface = KbFonts.body(context, true)
            actionView.gravity = Gravity.CENTER
            actionView.minHeight = dp(TOUCH_HEIGHT_DP)
            actionView.minimumWidth = dp(TOUCH_HEIGHT_DP)
            actionView.setPadding(actionGap, 0, 0, 0)
            actionView.isFocusable = false
            addView(actionView, LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        }

        fun bind(message: String, isError: Boolean, actionLabel: String?, multilineRadiusPx: Float) {
            multilineRadius = multilineRadiusPx
            messageView.text = message
            dot.visibility = if (isError) VISIBLE else GONE
            val border = if (isError) danger else ember
            val a = if (isError) BORDER_ALPHA_ERROR else BORDER_ALPHA
            bg.setStroke(dp(1f), (border and 0x00FFFFFF) or (a shl 24))
            if (actionLabel != null) {
                actionView.text = actionLabel
                actionView.contentDescription = actionLabel
                actionView.visibility = VISIBLE
            } else {
                actionView.visibility = GONE
            }
            requestLayout()
        }

        override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
            val cap = maxWidthOf(MeasureSpec.getSize(widthMeasureSpec)).coerceAtLeast(0)
            var avail = cap - paddingLeft - paddingRight
            if (dot.visibility == VISIBLE) avail -= dot.layoutParams.width + dotGap
            if (actionView.visibility == VISIBLE) {
                actionView.measure(
                    MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
                    MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
                )
                avail -= actionView.measuredWidth
            }
            val maxText = avail.coerceAtLeast(dp(48f))
            if (messageView.maxWidth != maxText) messageView.maxWidth = maxText
            super.onMeasure(
                MeasureSpec.makeMeasureSpec(cap, MeasureSpec.AT_MOST),
                heightMeasureSpec,
            )
        }
    }
}
