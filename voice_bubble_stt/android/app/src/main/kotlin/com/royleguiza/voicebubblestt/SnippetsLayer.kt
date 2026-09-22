package com.royleguiza.voicebubblestt

import android.graphics.Typeface
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.inputmethodservice.InputMethodService
import android.text.Editable
import android.text.InputType
import android.text.TextUtils
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * Capa Snippets (SPK-05, módulo 8 de N): chips + búsqueda + editor inline,
 * extraída de VoiceKeyboardService sin cambiar conducta. Todo lo que
 * necesita del teclado entra por [service] (contexto/sistema), [store] y
 * [host]; el estado (query, borradores, modo, subcapa, origen) es suyo,
 * incluidas las filas QWERTY de la subcapa letras (SPK-05 módulo 13);
 * el ruteo de commits/backspace/enter entra por los métodos
 * [routeToQuery], [insertToEditor], [backspaceEditor], [backspaceQuery],
 * [deleteQueryWord] y [handleEnterInEditor].
 * PRIVACIDAD: ni contenido ni nombre ni id se registran en Log.
 */
class SnippetsLayer(
    private val service: InputMethodService,
    private val host: UiHost,
) {

    /** Lo mínimo que los snippets exigen al teclado. */
    interface UiHost {
        fun currentLayer(): Layer
        fun setLayer(next: Layer)
        fun rebuild()
        fun isSpanish(): Boolean
        fun rootView(): LinearLayout
        fun haptic(view: View)
        fun attachPress(key: View, onLongPress: () -> Unit, onTapUp: () -> Unit)
        fun scaledDimen(resId: Int): Int
        fun dimenPx(resId: Int): Int
        fun rowGap(): Int
        fun addContentRow(view: View)
        fun makeIconKey(
            iconRes: Int,
            bgRes: Int,
            weight: Float,
            description: String?,
            tintColorRes: Int,
            useKeyHeight: Boolean = false,
            onClick: () -> Unit,
        ): ImageView
        fun horizontalRow(): LinearLayout
        fun dismissPopup()
        fun takePopup(popup: PopupWindow?)
        fun consumeModifiers()
        fun showCenteredBox(box: LinearLayout, widthPx: Int)
        fun showAnchoredBox(box: LinearLayout, anchor: View)
        // Filas QWERTY de la subcapa (SPK-05 módulo 13): construcción base,
        // commit alfabético, registro visual y gestos del teclado anfitrión.
        fun makeTextKey(
            label: String,
            weight: Float,
            bgRes: Int,
            colorRes: Int,
            textSizePx: Int,
        ): TextView
        fun displayLetter(base: Char): String
        fun attachTap(view: View, onTap: () -> Unit)
        fun commitLetterKey(base: Char)
        fun trackLetterKey(key: TextView, base: Char)
        fun trackShiftKey(key: ImageView)
        fun toggleShiftKey()
        fun showAccentsPopup(anchor: View, base: Char)
        fun deleteBackward()
        fun attachBackspaceKey(key: View, action: () -> Unit)
    }

    private lateinit var store: SnippetStore

    private var mode = SnippetMode.NORMAL
    private var btnEditView: View? = null
    private var btnDeleteView: View? = null
    var isEditorOpen = false
        private set
    private var editing: VbSnippet? = null
    private var activeField: EditText? = null
    private var etNameField: EditText? = null
    private var etContentField: EditText? = null
    private var origin = Layer.LETTERS
    private var seedAttempted = false
    private var query = ""
    private var gridContainer: LinearLayout? = null
    var subLayer = Layer.LETTERS
        private set
    private var draftName = ""
    private var draftContent = ""
    private var draftColor: String? = null
    private var draftActiveIsContent = false
    private var draftCursor = 0
    private var colorSwatchRow: LinearLayout? = null

    private var searchActive = false
    private var searchField: EditText? = null
    private var searchIconView: ImageView? = null

    val isSearchActive: Boolean get() = searchActive

    fun onCreateInputView() {
        store = SnippetStore(service)
    }

    /**
     * Apertura/cierre de la capa snippets. Al abrir: siembra los seeds solo en
     * la primera apertura (idempotencia interna del store), recarga siempre
     * desde prefs (recarga viva: los cambios hechos en la app aparecen al
     * reabrir sin reiniciar nada) y recuerda la capa de origen para volver.
     */
    fun toggle() {
        if (host.currentLayer() == Layer.SNIPPETS) {
            host.setLayer(origin)
            searchActive = false
            searchField = null
            searchIconView = null
            closeEditor()
            return
        }
        origin = host.currentLayer()
        if (!seedAttempted) {
            seedAttempted = true
            store.seedIfFirstOpen()
        }
        store.load()
        query = ""
        subLayer = Layer.LETTERS
        host.setLayer(Layer.SNIPPETS)
        host.rebuild()
    }

    /** Limpieza al salir de la capa (la invoca el rebuild del teclado). */
    fun resetState() {
        query = ""
        gridContainer = null
        searchActive = false
        searchField = null
        searchIconView = null
        mode = SnippetMode.NORMAL
        btnEditView = null
        btnDeleteView = null
        isEditorOpen = false
        editing = null
        activeField = null
        etNameField = null
        etContentField = null
        draftName = ""
        draftContent = ""
        draftColor = null
        draftActiveIsContent = false
        draftCursor = 0
        colorSwatchRow = null
        subLayer = Layer.LETTERS
    }

    fun cycleSubLayerForCode() {
        saveDraftState()
        subLayer = if (subLayer == Layer.CODE) Layer.LETTERS else Layer.CODE
        host.rebuild()
    }

    fun cycleSubLayerForSymbols() {
        saveDraftState()
        subLayer = if (subLayer == Layer.LETTERS) Layer.SYMBOLS else Layer.LETTERS
        host.rebuild()
    }

    fun openEditor(snippet: VbSnippet?) {
        host.dismissPopup()
        isEditorOpen = true
        editing = snippet
        draftName = snippet?.nombre.orEmpty()
        draftContent = snippet?.contenido.orEmpty()
        draftColor = snippet?.color
        draftActiveIsContent = false
        draftCursor = draftName.length
        subLayer = Layer.LETTERS
        searchActive = false
        host.rebuild()
    }

    private fun closeEditor() {
        isEditorOpen = false
        editing = null
        activeField = null
        etNameField = null
        etContentField = null
        draftName = ""
        draftContent = ""
        draftColor = null
        draftActiveIsContent = false
        draftCursor = 0
        subLayer = Layer.LETTERS
        mode = SnippetMode.NORMAL
        colorSwatchRow = null
        host.rebuild()
    }

    fun saveDraftState() {
        etNameField?.let { draftName = it.text.toString() }
        etContentField?.let { draftContent = it.text.toString() }
        draftActiveIsContent = (activeField === etContentField)
        val activeEt = activeField ?: etNameField
        activeEt?.let { draftCursor = it.selectionStart.coerceAtLeast(0) }
    }

    /** Fila de búsqueda/editor inline + grid scrolleable de chips. */
    fun buildContent() {
        val root = host.rootView()
        if (isEditorOpen) {
            host.addContentRow(buildEditorInline())
            return
        }
        host.addContentRow(buildSearchRow())
        val scroll = ScrollView(service).apply {
            isVerticalScrollBarEnabled = false
        }
        val grid = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
        }
        // Contorno uniforme con la barra (borde = entre chips): usa el gap
        // propio de chips para que respiren, no el de teclas.
        val gm = host.dimenPx(R.dimen.kb_snippet_chip_gap) / 2
        grid.setPadding(gm, 0, gm, 0)
        gridContainer = grid
        scroll.addView(grid)
        refreshGrid()
        val lp = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            host.scaledDimen(R.dimen.kb_snippets_grid_height),
        )
        lp.topMargin = gm
        root.addView(scroll, lp)
    }

    /**
     * Filas QWERTY de la subcapa letras (SPK-05 módulo 13): conservan la
     * altura configurada por el usuario sin achicarse artificialmente.
     * Misma conducta que la capa letras del teclado.
     */
    fun buildLetterRows() {
        host.addContentRow(letterRow("qwertyuiop"))
        host.addContentRow(letterRow(if (host.isSpanish()) "asdfghjklñ" else "asdfghjkl;"))
        val row3 = host.horizontalRow()
        val shiftKey = host.makeIconKey(
            R.drawable.ic_shift_off,
            R.drawable.kb_key_alt,
            1.3f,
            if (host.isSpanish()) "mayúsculas" else "shift",
            tintColorRes = R.color.kb_label,
            useKeyHeight = true,
        ) {
            host.toggleShiftKey()
        }
        host.trackShiftKey(shiftKey)
        row3.addView(shiftKey)
        for (c in "zxcvbnm") {
            row3.addView(makeLetterKey(c))
        }
        row3.addView(makeBackspaceKey())
        host.addContentRow(row3)
    }

    private fun letterRow(chars: String): LinearLayout {
        val row = host.horizontalRow()
        for (c in chars) {
            row.addView(makeLetterKey(c))
        }
        return row
    }

    /** Tecla alfabética; mismo estilo y tamaño estándar que la capa letras. */
    private fun makeLetterKey(base: Char): TextView {
        val key = host.makeTextKey(
            host.displayLetter(base),
            1f,
            R.drawable.kb_key_bg,
            R.color.kb_label,
            host.dimenPx(R.dimen.kb_key_text_size),
        )
        if (accentsFor(base).isEmpty()) {
            host.attachTap(key) { commitLetter(base) }
        } else {
            host.attachPress(
                key,
                onLongPress = {
                    host.haptic(key)
                    ensureSearchMode()
                    host.showAccentsPopup(key, base)
                },
                onTapUp = { commitLetter(base) },
            )
        }
        host.trackLetterKey(key, base)
        return key
    }

    /** Backspace: borra del query, del editor activo o del documento. */
    private fun makeBackspaceKey(): ImageView {
        val key = host.makeIconKey(
            R.drawable.ic_backspace,
            R.drawable.kb_key_alt,
            1.3f,
            if (host.isSpanish()) "borrar" else "delete",
            tintColorRes = R.color.kb_label,
            useKeyHeight = true,
        ) {
            ensureSearchMode()
            host.deleteBackward()
        }
        host.attachBackspaceKey(key) {
            ensureSearchMode()
            host.deleteBackward()
        }
        return key
    }

    /** Commit alfabético con activación garantizada del modo búsqueda. */
    private fun commitLetter(base: Char) {
        ensureSearchMode()
        host.commitLetterKey(base)
    }

    private fun buildEditorInline(): LinearLayout {
        val pad = host.dimenPx(R.dimen.kb_popup_padding)
        val m = host.dimenPx(R.dimen.kb_key_gap) / 2
        val isEdit = editing != null

        val container = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.kb_popup_bg)
            setPadding(pad, pad, pad, pad)
        }

        val headerRow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val title = TextView(service).apply {
            text = if (isEdit) (if (host.isSpanish()) "Editar snippet" else "Edit snippet")
            else (if (host.isSpanish()) "Nuevo snippet" else "New snippet")
            setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setTypeface(null, Typeface.BOLD)
        }
        val lpTitle = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        headerRow.addView(title, lpTitle)

        val btnCancel = TextView(service).apply {
            text = if (host.isSpanish()) "Cancelar" else "Cancel"
            gravity = Gravity.CENTER
            setPadding(pad * 2, pad, pad * 2, pad)
            setBackgroundResource(R.drawable.kb_key_bg)
            setTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setOnClickListener {
                host.haptic(this)
                closeEditor()
            }
        }
        val lpCancel = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, host.scaledDimen(R.dimen.kb_snippet_chip_height))
        lpCancel.rightMargin = pad
        headerRow.addView(btnCancel, lpCancel)

        val btnSave = TextView(service).apply {
            text = if (host.isSpanish()) "Guardar" else "Save"
            gravity = Gravity.CENTER
            setPadding(pad * 2, pad, pad * 2, pad)
            setBackgroundResource(R.drawable.kb_key_accent)
            setTextColor(ContextCompat.getColor(service, R.color.kb_label_on_accent))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setTypeface(null, Typeface.BOLD)
            setOnClickListener {
                host.haptic(this)
                val name = etNameField?.text?.toString()?.trim().orEmpty()
                val content = etContentField?.text?.toString()?.trim().orEmpty()
                if (name.isNotEmpty()) {
                    val toSave = if (isEdit && editing != null) {
                        editing!!.copy(nombre = name, contenido = content, color = draftColor)
                    } else {
                        VbSnippet(
                            id = "",
                            nombre = name,
                            contenido = content,
                            orden = 0,
                            color = draftColor,
                        )
                    }
                    store.saveSnippet(toSave)
                    closeEditor()
                }
            }
        }
        val lpSave = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, host.scaledDimen(R.dimen.kb_snippet_chip_height))
        headerRow.addView(btnSave, lpSave)
        container.addView(headerRow)

        val etName = EditText(service).apply {
            hint = if (host.isSpanish()) "Nombre (ej. Git commit)" else "Name"
            setSingleLine(true)
            maxLines = 1
            inputType = InputType.TYPE_CLASS_TEXT
            setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            setHintTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
            setBackgroundResource(R.drawable.kb_key_bg)
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setPadding(pad, pad, pad, pad)
            setText(draftName)
            onFocusChangeListener = View.OnFocusChangeListener { _, hasFocus ->
                if (hasFocus) activeField = this
            }
            setOnClickListener {
                activeField = this
            }
        }
        etNameField = etName
        val lpName = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, host.scaledDimen(R.dimen.kb_snippet_bar_height))
        lpName.topMargin = pad
        container.addView(etName, lpName)

        val etContent = EditText(service).apply {
            hint = if (host.isSpanish()) "Contenido o comando..." else "Content or command..."
            setSingleLine(false)
            maxLines = 2
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            setHintTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
            setBackgroundResource(R.drawable.kb_key_bg)
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setPadding(pad, pad, pad, pad)
            setText(draftContent)
            onFocusChangeListener = View.OnFocusChangeListener { _, hasFocus ->
                if (hasFocus) activeField = this
            }
            setOnClickListener {
                activeField = this
            }
        }
        etContentField = etContent
        val lpContent = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, host.scaledDimen(R.dimen.kb_snippet_bar_height))
        lpContent.topMargin = pad
        container.addView(etContent, lpContent)

        // Selector de color (paleta fija de 6 + sin color): el primer toque
        // alterna y el Guardar persiste draftColor en el snippet.
        val label = TextView(service).apply {
            text = if (host.isSpanish()) "Color" else "Color"
            setTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setPadding(0, pad, 0, pad / 2)
        }
        container.addView(label)
        container.addView(buildColorSwatchRow(pad))

        if (draftActiveIsContent) {
            activeField = etContent
            etContent.post {
                etContent.requestFocus()
                val pos = draftCursor.coerceIn(0, etContent.text.length)
                etContent.setSelection(pos)
            }
        } else {
            activeField = etName
            etName.post {
                etName.requestFocus()
                val pos = draftCursor.coerceIn(0, etName.text.length)
                etName.setSelection(pos)
            }
        }

        val lpContainer = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        lpContainer.setMargins(m, 0, m, 0)
        container.layoutParams = lpContainer
        return container
    }

    /**
     * Fila compacta: 4 cuartos iguales (lupa + nuevo + editar + borrar).
     * La lupa expande el campo (tap o tipeo directo) y comprime el resto
     * con morph; colapsar limpia el query. Al entrar a la capa sin tocar
     * nada queda colapsada.
     */
    /**
     * Barra slim (pedido del dueño): la búsqueda ocupa el 70% con la lupa
     * hardcodeada como placeholder (se oculta al enfocar o tipear); los 3
     * botones comparten el 30% restante en la misma línea y altura, con el
     * mismo gap en todo el contorno. Sin textos explicativos.
     */
    private fun buildSearchRow(): LinearLayout {
        val row = host.horizontalRow()
        val m = host.dimenPx(R.dimen.kb_key_gap_h) / 2
        val h = host.scaledDimen(R.dimen.kb_snippet_bar_height)
        row.setPadding(m, 0, m, 0)

        // Caja de búsqueda (70%): icono lupa + campo transparente.
        val box = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundResource(R.drawable.kb_key_bg)
        }
        val iconDp = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 20f, service.resources.displayMetrics).toInt()
        val iconPad = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 8f, service.resources.displayMetrics).toInt()
        val icon = ImageView(service).apply {
            setImageResource(R.drawable.ic_search)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setColorFilter(ContextCompat.getColor(service, R.color.kb_label_secondary))
            contentDescription = if (host.isSpanish()) "buscar snippets" else "search snippets"
            setOnClickListener {
                searchField?.requestFocus()
                ensureSearchMode()
            }
        }
        box.addView(icon, LinearLayout.LayoutParams(iconDp, iconDp).apply {
            leftMargin = iconPad
        })
        searchIconView = icon

        val et = EditText(service)
        et.hint = if (host.isSpanish()) "Buscar" else "Search"
        et.setSingleLine(true)
        et.maxLines = 1
        et.inputType = InputType.TYPE_CLASS_TEXT
        et.imeOptions = EditorInfo.IME_ACTION_SEARCH
        et.setTextColor(ContextCompat.getColor(service, R.color.kb_label))
        et.setHintTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
        et.setBackgroundResource(0)
        et.setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
        et.setPadding(iconPad, 0, iconPad, 0)
        et.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                query = s?.toString() ?: ""
                updateSearchIcon()
                refreshGrid()
            }
        })
        if (query.isNotEmpty()) {
            et.setText(query)
        }
        searchActive = false
        searchField = et
        et.onFocusChangeListener = View.OnFocusChangeListener { _, hasFocus ->
            searchActive = hasFocus
            applySearchVisual()
            updateSearchIcon()
        }
        et.setOnClickListener { v ->
            if (!v.hasFocus()) v.requestFocus()
            searchActive = true
            applySearchVisual()
            updateSearchIcon()
        }
        box.addView(et, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f))
        val boxLp = LinearLayout.LayoutParams(0, h, 7f)
        boxLp.setMargins(m, 0, m, 0)
        row.addView(box, boxLp)

        // Botones slim (10% c/u): mismo alto, misma línea, mismo gap.
        row.addView(slimToolButton(R.drawable.ic_add, if (host.isSpanish()) "nuevo snippet" else "new snippet", h, m) {
            openEditor(null)
        })
        val btnEdit = slimToolButton(R.drawable.ic_edit, if (host.isSpanish()) "editar snippet" else "edit snippet", h, m) {
            mode = if (mode == SnippetMode.EDIT) SnippetMode.NORMAL else SnippetMode.EDIT
            updateModeVisuals()
            refreshGrid()
        }
        btnEditView = btnEdit
        row.addView(btnEdit)
        val btnDelete = slimToolButton(R.drawable.ic_delete, if (host.isSpanish()) "eliminar snippet" else "delete snippet", h, m) {
            mode = if (mode == SnippetMode.DELETE) SnippetMode.NORMAL else SnippetMode.DELETE
            updateModeVisuals()
            refreshGrid()
        }
        btnDeleteView = btnDelete
        row.addView(btnDelete)

        updateModeVisuals()
        updateSearchIcon()
        return row
    }

    /** Botón slim de la barra: icono centrado, sin texto. */
    private fun slimToolButton(iconRes: Int, description: String?, heightPx: Int, marginPx: Int, onTap: () -> Unit): ImageView {
        val key = ImageView(service)
        key.setImageResource(iconRes)
        key.scaleType = ImageView.ScaleType.CENTER_INSIDE
        key.isClickable = true
        key.isFocusable = true
        key.minimumWidth = 0
        key.minimumHeight = 0
        key.setPadding(0, 0, 0, 0)
        key.setBackgroundResource(R.drawable.kb_key_bg)
        key.setColorFilter(ContextCompat.getColor(service, R.color.kb_label))
        if (description != null) {
            key.contentDescription = description
        }
        val lp = LinearLayout.LayoutParams(0, heightPx, 1f)
        lp.setMargins(marginPx, 0, marginPx, 0)
        key.layoutParams = lp
        host.attachTap(key, onTap)
        return key
    }

    /** La lupa es placeholder: visible solo en reposo (sin foco ni texto). */
    private fun updateSearchIcon() {
        val icon = searchIconView ?: return
        val et = searchField
        val typing = (et?.hasFocus() == true) || !et?.text.isNullOrEmpty()
        icon.visibility = if (typing) View.GONE else View.VISIBLE
    }


    private fun updateModeVisuals() {
        btnEditView?.setBackgroundResource(
            if (mode == SnippetMode.EDIT) R.drawable.kb_key_accent else R.drawable.kb_key_bg,
        )
        (btnEditView as? ImageView)?.setColorFilter(
            if (mode == SnippetMode.EDIT) ContextCompat.getColor(service, R.color.kb_label_on_accent)
            else ContextCompat.getColor(service, R.color.kb_label),
        )
        btnDeleteView?.setBackgroundResource(
            if (mode == SnippetMode.DELETE) R.drawable.kb_key_danger else R.drawable.kb_key_bg,
        )
        (btnDeleteView as? ImageView)?.setColorFilter(
            if (mode == SnippetMode.DELETE) ContextCompat.getColor(service, R.color.kb_label_on_accent)
            else ContextCompat.getColor(service, R.color.kb_label),
        )
    }

    /** Feedback visual del modo busqueda: fondo acentuado cuando esta activo. */
    private fun applySearchVisual() {
        val et = searchField ?: return
        et.setBackgroundResource(
            if (searchActive) R.drawable.kb_key_accent else R.drawable.kb_key_bg,
        )
    }

    /** Repuebla el grid con el filtro actual sobre el cache fresco del store. */
    /**
     * Grilla dinámica (pedido del dueño): máximo 3 columnas; con 4 items
     * 2×2; con 5, 3+2. Chips a altura de tecla Enter, con el mismo gap en
     * todo el contorno (borde, entre chips y con la barra superior).
     */
    private fun refreshGrid() {
        val container = gridContainer ?: return
        container.removeAllViews()
        val q = query.trim()
        val all = store.get()
        val filtered = if (q.isEmpty()) {
            all
        } else {
            all.filter { it.nombre.contains(q, ignoreCase = true) }
        }
        if (filtered.isEmpty()) {
            container.addView(emptyView())
            return
        }
        val gap = host.dimenPx(R.dimen.kb_snippet_chip_gap)
        val cols = if (filtered.size == 4) 2 else minOf(SNIPPET_GRID_COLUMNS, filtered.size)
        var i = 0
        while (i < filtered.size) {
            val inRow = minOf(cols, filtered.size - i)
            val row = host.horizontalRow()
            row.setPadding(gap / 2, 0, gap / 2, 0)
            for (j in 0 until inRow) {
                val chip = makeChip(filtered[i + j])
                val lp = chip.layoutParams as LinearLayout.LayoutParams
                lp.weight = cols.toFloat() / inRow
                row.addView(chip)
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                host.scaledDimen(R.dimen.kb_snippet_chip_height),
            )
            if (container.childCount > 0) {
                lp.topMargin = gap / 2
            }
            container.addView(row, lp)
            i += inRow
        }
    }

    /** Chip con el nombre del snippet: tap inserta, o activa accion segun modo. */
    private fun makeChip(snippet: VbSnippet): TextView {
        val chip = TextView(service)
        chip.text = snippet.nombre
        chip.gravity = Gravity.CENTER
        chip.isClickable = true
        chip.isFocusable = true
        chip.includeFontPadding = false
        chip.maxLines = 1
        chip.ellipsize = TextUtils.TruncateAt.END
        chip.setPadding(
            host.dimenPx(R.dimen.kb_popup_padding), 0,
            host.dimenPx(R.dimen.kb_popup_padding), 0,
        )

        when (mode) {
            SnippetMode.EDIT -> {
                // Lab compacta: borde punteado azul, contenido intacto.
                chip.setBackgroundResource(R.drawable.kb_chip_edit)
                chip.setTextColor(ContextCompat.getColor(service, R.color.kb_label))
                chip.setOnClickListener {
                    host.haptic(chip)
                    openEditor(snippet)
                }
            }
            SnippetMode.DELETE -> {
                // Lab compacta: borde punteado rojo, contenido intacto.
                chip.setBackgroundResource(R.drawable.kb_chip_delete)
                chip.setTextColor(ContextCompat.getColor(service, R.color.kb_label))
                chip.setOnClickListener {
                    host.haptic(chip)
                    showDeleteConfirmation(snippet)
                }
            }
            SnippetMode.NORMAL -> {
                if (snippet.color != null) {
                    chip.background = tintedChipBackground(snippet.color)
                } else {
                    chip.setBackgroundResource(R.drawable.kb_key_bg)
                }
                chip.setTextColor(ContextCompat.getColor(service, R.color.kb_label))
                host.attachPress(
                    chip,
                    onLongPress = {
                        host.haptic(chip)
                        showMenu(chip, snippet)
                    },
                    onTapUp = { insert(snippet) },
                )
            }
        }

        chip.setTextSize(
            TypedValue.COMPLEX_UNIT_PX,
            host.dimenPx(R.dimen.kb_snippet_chip_text_size).toFloat(),
        )
        chip.typeface = Typeface.DEFAULT_BOLD
        chip.contentDescription = snippet.nombre
        // Chips compactos 40dp (pedido del dueño) + gap propio en laterales.
        val lp = LinearLayout.LayoutParams(0, host.scaledDimen(R.dimen.kb_snippet_chip_height), 1f)
        val m = host.dimenPx(R.dimen.kb_snippet_chip_gap) / 2
        lp.setMargins(m, 0, m, 0)
        chip.layoutParams = lp
        return chip
    }

    /** Fondo teñido del chip (fill ~20% + stroke del color de paleta). */
    private fun tintedChipBackground(colorId: String): GradientDrawable {
        val radius = host.dimenPx(R.dimen.kb_key_radius).toFloat()
        val stroke = host.dimenPx(R.dimen.kb_key_stroke_width)
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius
            setColor(ContextCompat.getColor(service, SnippetPalette.fillRes(colorId)))
            setStroke(stroke, ContextCompat.getColor(service, SnippetPalette.strokeRes(colorId)))
        }
    }

    /** Fila de swatches: primera opción = sin color; luego los 6 de paleta. */
    private fun buildColorSwatchRow(pad: Int): LinearLayout {
        val row = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        colorSwatchRow = row
        val size = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, 28f, service.resources.displayMetrics,
        ).toInt()
        val gap = pad / 2

        row.removeAllViews()
        // Sin color (default)
        row.addView(makeSwatch(null, size, gap, selected = draftColor == null,
            description = if (host.isSpanish()) "sin color" else "no color"))
        for (id in SnippetPalette.IDS) {
            row.addView(makeSwatch(id, size, gap, selected = draftColor == id, description = id))
        }
        return row
    }

    private fun makeSwatch(
        colorId: String?,
        size: Int,
        gapPx: Int,
        selected: Boolean,
        description: String,
    ): View {
        val v = View(service)
        v.isClickable = true
        v.isFocusable = true
        v.contentDescription = description
        val bg = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            if (colorId == null) {
                setColor(ContextCompat.getColor(service, R.color.kb_key_bg))
                setStroke(
                    if (selected) 3 else host.dimenPx(R.dimen.kb_key_stroke_width),
                    ContextCompat.getColor(
                        service,
                        if (selected) R.color.kb_key_bg_accent else R.color.kb_key_stroke,
                    ),
                )
            } else {
                setColor(ContextCompat.getColor(service, SnippetPalette.fillRes(colorId)))
                setStroke(
                    if (selected) 3 else host.dimenPx(R.dimen.kb_key_stroke_width),
                    ContextCompat.getColor(
                        service,
                        if (selected) SnippetPalette.strokeRes(colorId) else R.color.kb_key_stroke,
                    ),
                )
            }
        }
        v.background = bg
        val lp = LinearLayout.LayoutParams(size, size)
        lp.rightMargin = gapPx
        v.layoutParams = lp
        v.setOnClickListener {
            host.haptic(it)
            draftColor = colorId
            // Repinta solo los swatches de esta fila.
            val parent = colorSwatchRow ?: return@setOnClickListener
            parent.removeAllViews()
            val pad = host.dimenPx(R.dimen.kb_popup_padding)
            val sz = TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP, 28f, service.resources.displayMetrics,
            ).toInt()
            val g = pad / 2
            parent.addView(makeSwatch(null, sz, g, draftColor == null,
                if (host.isSpanish()) "sin color" else "no color"))
            for (id in SnippetPalette.IDS) {
                parent.addView(makeSwatch(id, sz, g, draftColor == id, id))
            }
        }
        return v
    }

    private fun showDeleteConfirmation(snippet: VbSnippet) {
        host.dismissPopup()
        val pad = host.dimenPx(R.dimen.kb_popup_padding)
        val box = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundResource(R.drawable.kb_popup_bg)
            setPadding(pad * 2, pad * 2, pad * 2, pad * 2)
        }

        val title = TextView(service).apply {
            text = if (host.isSpanish()) "¿Eliminar snippet?" else "Delete snippet?"
            setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size).toFloat())
            setTypeface(null, Typeface.BOLD)
        }
        box.addView(title)

        val desc = TextView(service).apply {
            text = snippet.nombre
            setTextColor(ContextCompat.getColor(service, R.color.kb_recording))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setPadding(0, pad / 2, 0, pad * 2)
        }
        box.addView(desc)

        val actionsRow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }

        val btnCancel = TextView(service).apply {
            text = if (host.isSpanish()) "Cancelar" else "Cancel"
            gravity = Gravity.CENTER
            setPadding(pad * 2, pad, pad * 2, pad)
            setBackgroundResource(R.drawable.kb_key_bg)
            setTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setOnClickListener {
                host.haptic(this)
                host.dismissPopup()
            }
        }
        val lpCancel = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, host.scaledDimen(R.dimen.kb_snippet_chip_height))
        lpCancel.rightMargin = pad
        actionsRow.addView(btnCancel, lpCancel)

        val btnDelete = TextView(service).apply {
            text = if (host.isSpanish()) "Eliminar" else "Delete"
            gravity = Gravity.CENTER
            setPadding(pad * 2, pad, pad * 2, pad)
            setBackgroundResource(R.drawable.kb_key_danger)
            setTextColor(ContextCompat.getColor(service, R.color.kb_label_on_accent))
            setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            setTypeface(null, Typeface.BOLD)
            setOnClickListener {
                host.haptic(this)
                store.deleteSnippet(snippet.id)
                mode = SnippetMode.NORMAL
                updateModeVisuals()
                host.dismissPopup()
                refreshGrid()
            }
        }
        val lpDelete = LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, host.scaledDimen(R.dimen.kb_snippet_chip_height))
        actionsRow.addView(btnDelete, lpDelete)

        box.addView(actionsRow)

        val dm = service.resources.displayMetrics
        val popupWidth = minOf(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 300f, dm).toInt(), dm.widthPixels - pad * 4)
        showCenteredBox(box, popupWidth)
    }

    fun showCenteredBox(box: LinearLayout, widthPx: Int) {
        val popup = PopupWindow(box, widthPx, ViewGroup.LayoutParams.WRAP_CONTENT, true).apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            isOutsideTouchable = true
            animationStyle = R.style.VoiceHistoryPopupAnimation
        }
        host.takePopup(popup)
        popup.showAtLocation(host.rootView(), Gravity.CENTER, 0, 0)
    }

    fun showAnchoredBox(box: LinearLayout, anchor: View) {
        val popup = PopupWindow(
            box,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            true,
        )
        popup.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        popup.isOutsideTouchable = true
        box.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        val loc = IntArray(2)
        anchor.getLocationInWindow(loc)
        val gap = host.dimenPx(R.dimen.kb_key_gap)
        host.takePopup(popup)
        popup.showAtLocation(
            host.rootView(),
            Gravity.NO_GRAVITY,
            loc[0],
            // AT-A12: jamas Y negativo; si no cabe arriba se solapa con el ancla.
            maxOf(gap, loc[1] - box.measuredHeight - gap),
        )
    }

    private fun emptyView(): TextView {
        val pad = host.dimenPx(R.dimen.kb_popup_padding)
        val tv = TextView(service)
        tv.text = if (host.isSpanish()) "Sin snippets todavía." else "No snippets yet."
        tv.gravity = Gravity.CENTER
        tv.setPadding(pad, pad * 2, pad, pad * 2)
        tv.setTextColor(ContextCompat.getColor(service, R.color.kb_label_secondary))
        tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
        return tv
    }

    /**
     * Insercion del contenido completo en el cursor via commitText (soporta
     * multilinea con \n) y regreso a la capa de origen.
     */
    private fun insert(snippet: VbSnippet) {
        host.haptic(host.rootView())
        host.consumeModifiers()
        service.currentInputConnection?.commitText(snippet.contenido, 1)
        searchActive = false
        searchField = null
        host.setLayer(origin)
        host.rebuild()
    }

    /** Menu contextual del chip: insertar, copiar o abrir la app para editar. */
    private fun showMenu(anchor: View, snippet: VbSnippet) {
        host.dismissPopup()
        val pad = host.dimenPx(R.dimen.kb_popup_padding)
        val box = LinearLayout(service)
        box.orientation = LinearLayout.VERTICAL
        box.setBackgroundResource(R.drawable.kb_popup_bg)
        box.setPadding(pad, pad, pad, pad)

        fun addOption(label: String, action: () -> Unit) {
            val tv = TextView(service)
            tv.text = label
            tv.isClickable = true
            tv.isFocusable = true
            tv.setPadding(pad * 2, pad * 2, pad * 2, pad * 2)
            tv.setBackgroundResource(R.drawable.kb_menu_item)
            tv.setTextColor(ContextCompat.getColor(service, R.color.kb_label))
            tv.setTextSize(TypedValue.COMPLEX_UNIT_PX, host.dimenPx(R.dimen.kb_key_text_size_small).toFloat())
            tv.setOnClickListener {
                host.haptic(it)
                host.dismissPopup()
                action()
            }
            box.addView(tv)
        }
        addOption(if (host.isSpanish()) "Insertar" else "Insert") { insert(snippet) }
        addOption(if (host.isSpanish()) "Copiar al portapapeles" else "Copy to clipboard") {
            service.copySnippetToClipboard(snippet.contenido)
        }
        addOption(if (host.isSpanish()) "Abrir app para editar" else "Open app to edit") {
            service.openAppUi()
        }

        showAnchoredBox(box, anchor)
    }

    // ------------------------------------------------------------------
    // Ruteo de escritura: el teclado invoca estos ganchos antes de comitear.
    // ------------------------------------------------------------------

    fun insertToEditor(text: String): Boolean {
        if (!isEditorOpen) return false
        val et = activeField ?: etNameField ?: return false
        val start = et.selectionStart.coerceAtLeast(0)
        val end = et.selectionEnd.coerceAtLeast(0)
        val min = minOf(start, end)
        val max = maxOf(start, end)
        et.text.replace(min, max, text)
        et.setSelection(min + text.length)
        return true
    }

    fun backspaceEditor(): Boolean {
        if (!isEditorOpen) return false
        val et = activeField ?: etNameField ?: return false
        val start = et.selectionStart.coerceAtLeast(0)
        val end = et.selectionEnd.coerceAtLeast(0)
        if (start != end) {
            val min = minOf(start, end)
            val max = maxOf(start, end)
            et.text.delete(min, max)
            et.setSelection(min)
            return true
        }
        if (start > 0) {
            val text = et.text
            val count = if (start >= 2 && Character.isSurrogatePair(text[start - 2], text[start - 1])) 2 else 1
            text.delete(start - count, start)
            et.setSelection(start - count)
            return true
        }
        return true
    }

    /**
     * Modo busqueda activo en la capa snippets: captura los commits del
     * propio teclado y los puebla en el query para filtrar, sin escribir
     * nunca en la app destino (patron estilo Gboard). Devuelve true si el
     * texto fue consumido por el modo busqueda.
     */
    fun routeToQuery(text: String): Boolean {
        if (host.currentLayer() != Layer.SNIPPETS || !searchActive) return false
        val et = searchField ?: return false
        val editable = et.text
        if (editable.length >= SNIPPET_QUERY_MAX_CHARS) return true
        val remaining = SNIPPET_QUERY_MAX_CHARS - editable.length
        var chunk = if (text.length > remaining) text.substring(0, remaining) else text
        // AT-A5: el recorte nunca deja un high surrogate suelto al final.
        if (chunk.isNotEmpty() && Character.isHighSurrogate(chunk.last())) {
            chunk = chunk.dropLast(1)
        }
        editable.append(chunk)
        et.setSelection(editable.length)
        refreshGrid()
        return true
    }

    fun backspaceQuery(): Boolean {
        if (host.currentLayer() != Layer.SNIPPETS || !searchActive) return false
        val et = searchField ?: return false
        val text = et.text
        if (!text.isNullOrEmpty()) {
            // AT-A5: un par surrogate (emoji) se borra entero, no de a medio.
            val count = if (
                text.length >= 2 &&
                Character.isSurrogatePair(text[text.length - 2], text[text.length - 1])
            ) {
                2
            } else {
                1
            }
            text.delete(text.length - count, text.length)
            et.setSelection(text.length)
            refreshGrid()
        }
        return true
    }

    /** Borrado por palabra sobre el query (la capa nunca toca el documento). */
    fun deleteQueryWord() {
        ensureSearchMode()
        val et = searchField ?: return
        val text = et.text ?: return
        val start = queryWordStart(text, text.length)
        if (start < text.length) {
            text.delete(start, text.length)
            et.setSelection(start)
            refreshGrid()
        }
    }

    private fun queryWordStart(text: CharSequence, from: Int): Int {
        var start = from
        if (start == 0) return start
        val eatingWord = text[start - 1].isLetterOrDigit()
        while (start > 0 && text[start - 1].isLetterOrDigit() == eatingWord) start--
        return start
    }

    /** Enter dentro del editor: salta de campo o inserta \n. True si consume. */
    fun handleEnterInEditor(): Boolean {
        if (!isEditorOpen) return false
        if (activeField == etNameField) {
            etContentField?.requestFocus()
            etContentField?.setSelection(etContentField?.text?.length ?: 0)
            activeField = etContentField
        } else if (activeField == etContentField) {
            insertToEditor("\n")
        }
        return true
    }

    /** Apaga el modo busqueda y restaura el fondo inactivo del campo. */
    fun exitSearchMode() {
        searchActive = false
        searchField?.clearFocus()
        applySearchVisual()
        updateSearchIcon()
    }

    /**
     * Enciende el modo busqueda bajo demanda (teclado de la propia capa).
     * Tipeo directo = tocar la lupa: enfoca el campo (la lupa se oculta
     * como placeholder) y el query filtra en vivo.
     */
    fun ensureSearchMode() {
        if (!searchActive) {
            searchActive = true
            applySearchVisual()
        }
        if (searchField?.hasFocus() == false) {
            searchField?.requestFocus()
        }
        updateSearchIcon()
    }
}
