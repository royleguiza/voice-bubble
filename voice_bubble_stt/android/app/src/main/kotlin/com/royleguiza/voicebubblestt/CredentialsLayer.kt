package com.royleguiza.voicebubblestt

import android.graphics.Typeface
import android.inputmethodservice.InputMethodService
import android.os.DeadObjectException
import android.os.Handler
import android.os.RemoteException
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Capa Claves (SPK-05, módulo 3 de N): lista y relleno de credenciales,
 * extraída de VoiceKeyboardService sin cambiar conducta. Todo lo que la
 * capa necesita del teclado entra por [service] (solo lectura/pegado del
 * sistema), [store], [handler] y [host]; la capa es dueña de su origen
 * ([origin]) y jamás toca el estado de VKS directamente.
 */
class CredentialsLayer(
    private val service: InputMethodService,
    private val store: CredentialStore,
    private val handler: Handler,
    private val host: UiHost,
) {

    /** Lo mínimo que la capa exige al teclado. */
    interface UiHost {
        fun currentLayer(): Layer
        fun showLayer(next: Layer)
        fun tapFeedback()
        fun isSpanish(): Boolean
        fun isPasswordField(): Boolean
        fun isServiceAlive(): Boolean
        fun attachTap(view: View, onTap: () -> Unit)
        fun scaledDimen(resId: Int): Int
        fun rowGap(): Int
    }

    private var origin = Layer.LETTERS

    fun toggle() {
        if (host.currentLayer() == Layer.CREDENTIALS) {
            host.showLayer(origin)
            return
        }
        origin = host.currentLayer()
        host.showLayer(Layer.CREDENTIALS)
    }

    /** Lista compacta de credenciales: avatar + nombre (+usuario) + pegar. */
    fun buildRows(parent: LinearLayout) {
        val entries = store.loadIndex()
        val showUser = store.getShowUser()
        if (entries.isEmpty()) {
            val empty = TextView(service).apply {
                text = if (host.isSpanish()) "Sin claves. Guárdalas en Ajustes → Claves." else "No credentials. Save them in Settings → Claves."
                gravity = Gravity.CENTER
                setTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 13f)
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                host.scaledDimen(R.dimen.kb_snippets_grid_height),
            )
            lp.topMargin = host.rowGap()
            parent.addView(empty, lp)
            return
        }
        val scroll = ScrollView(service).apply {
            isVerticalScrollBarEnabled = true
        }
        val list = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
        }
        for (entry in entries) {
            list.addView(buildRow(entry, showUser))
        }
        scroll.addView(list)
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            host.scaledDimen(R.dimen.kb_snippets_grid_height),
        )
        lp.topMargin = host.rowGap()
        parent.addView(scroll, lp)
    }

    private fun buildRow(entry: VbCredentialEntry, showUser: Boolean): View {
        val pad = service.dimen(R.dimen.kb_popup_padding)
        val row = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundResource(R.drawable.kb_menu_item)
            setPadding(pad, pad / 2, pad, pad / 2)
            isClickable = true
            isFocusable = true
        }
        val avatar = TextView(service).apply {
            text = entry.nombre.firstOrNull()?.uppercaseChar()?.toString() ?: "•"
            gravity = Gravity.CENTER
            setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 15f)
            setTypeface(null, Typeface.BOLD)
        }
        val avatarSize = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 34f, service.resources.displayMetrics,
        ).toInt()
        row.addView(avatar, LinearLayout.LayoutParams(avatarSize, avatarSize))

        val meta = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val name = TextView(service).apply {
            text = entry.nombre
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_DIP, 14f)
            setTypeface(null, Typeface.BOLD)
        }
        meta.addView(name)
        if (showUser) {
            val user = TextView(service).apply {
                text = entry.usuario
                maxLines = 1
                ellipsize = TextUtils.TruncateAt.END
                setTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
                setTextSize(TypedValue.COMPLEX_UNIT_DIP, 12f)
            }
            meta.addView(user)
        }
        val metaLp = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        val metaMargin = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 10f, service.resources.displayMetrics,
        ).toInt()
        metaLp.marginStart = metaMargin
        row.addView(meta, metaLp)

        val paste = ImageView(service).apply {
            setImageResource(R.drawable.ic_paste)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            isClickable = true
            isFocusable = true
            setBackgroundResource(R.drawable.kb_key_accent)
            setColorFilter(ContextCompat.getColor(service, R.color.kb_label_on_accent))
            contentDescription = if (host.isSpanish()) "pegar ${entry.nombre}" else "paste ${entry.nombre}"
        }
        val touchMin = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 44f, service.resources.displayMetrics,
        ).toInt()
        row.addView(paste, LinearLayout.LayoutParams(touchMin, touchMin))
        val fill = { fill(entry) }
        host.attachTap(paste, fill)
        row.setOnClickListener { fill() }
        val rowLp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
        rowLp.topMargin = service.dimen(R.dimen.kb_key_gap) / 2
        row.layoutParams = rowLp
        return row
    }

    private fun commitOrWarn(text: CharSequence): Boolean {
        return com.royleguiza.voicebubblestt.commitOrWarn(service, text, host.isSpanish()) {
            warnDeadConnection(service, host.isSpanish())
        }
    }

    /**
     * Relleno usuario+contraseña ante el toque explícito (único uso de la
     * password en memoria: nunca se muestra, nunca se loguea).
     *
     * Seguridad C-07 (Relleno de claves seguro):
     * 1. Foco ya en campo de contraseña: solo pega la clave directamente.
     * 2. Foco en otro campo (usuario):
     *    - Captura editor y conexión iniciales antes del TAB.
     *    - Comitea el usuario con [commitOrWarn].
     *    - Envía TAB para avanzar el foco al siguiente campo.
     *    - En el callback diferido (250 ms):
     *      * Verifica que el servicio siga vivo.
     *      * Compara conexión y editor actuales contra los iniciales.
     *      * Si el TAB no avanzó (misma conexión o mismo fieldId), ABORTA
     *        para no pegar la contraseña en el campo de texto visible.
     *      * Si el paquete de la app cambió, ABORTA para evitar inyección en otra app.
     *      * Si el nuevo campo de destino no es un campo de contraseña
     *        ([isPasswordInput] == false o [host.isPasswordField] == false),
     *        significa que el usuario tocó otro campo visible durante la espera
     *        o la app cambió de contexto: ABORTA inmediatamente sin pegar nada.
     *    - Cero registro de logs y cero filtración de secretos.
     */
    private fun fill(entry: VbCredentialEntry) {
        host.tapFeedback()
        val password = store.getPassword(entry.id)
        if (password.isNullOrEmpty()) return
        if (host.isPasswordField()) {
            commitOrWarn(password)
        } else {
            val initialEditor = service.currentInputEditorInfo
            val initialIc = service.currentInputConnection
            if (initialEditor == null || initialIc == null) return

            if (!commitOrWarn(entry.usuario)) return

            try {
                service.sendDownUpKeyEvents(KeyEvent.KEYCODE_TAB)
            } catch (_: DeadObjectException) {
                warnDeadConnection(service, host.isSpanish())
                return
            } catch (_: RemoteException) {
                warnDeadConnection(service, host.isSpanish())
                return
            } catch (_: IllegalStateException) {
                warnDeadConnection(service, host.isSpanish())
                return
            } catch (_: Exception) {
                warnDeadConnection(service, host.isSpanish())
                return
            }

            handler.postDelayed({
                if (!host.isServiceAlive()) return@postDelayed
                val currentEditor = service.currentInputEditorInfo ?: return@postDelayed
                val currentIc = service.currentInputConnection ?: return@postDelayed

                // C-07: Si el TAB no avanzó (sigue en la misma conexión o mismo fieldId), abortar
                val didNotAdvance = (currentIc === initialIc) ||
                    (initialEditor.fieldId != View.NO_ID && currentEditor.fieldId == initialEditor.fieldId && currentEditor.inputType == initialEditor.inputType)
                if (didNotAdvance) return@postDelayed

                // C-07: Si cambió de aplicación o paquete en el diferido, abortar
                if (currentEditor.packageName != initialEditor.packageName) return@postDelayed

                // C-07: Si cambió de campo en el diferido hacia un campo no-password, abortar
                if (!isPasswordInput(currentEditor) || !host.isPasswordField()) return@postDelayed

                commitOrWarn(password)
            }, 250L)
        }
        host.showLayer(origin)
    }
}
