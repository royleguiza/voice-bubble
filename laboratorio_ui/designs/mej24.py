"""MEJ-24: Banco de Snippets/Plantillas"""
VARIANTS = [
    {
        "id": "Default 1",
        "name": "Vista de Banco de Snippets",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-sm font-bold text-gray-800 dark:text-white">Snippets</div>
          <div class="flex items-center gap-2">
            <div class="px-2 py-1 bg-blue-500 rounded-lg text-white text-xs">+ Nuevo</div>
          </div>
        </div>
        <div class="flex items-center gap-2 mb-3 bg-gray-100 dark:bg-gray-800 rounded-xl p-2">
          <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
          <input type="text" placeholder="Buscar snippets..." class="flex-1 bg-transparent text-sm text-gray-800 dark:text-white outline-none">
        </div>
        <div class="space-y-2">
          <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-gray-800 dark:text-white">Saludo Profesional</div>
                <div class="text-[10px] text-gray-500 truncate mt-1">Hola, espero que estés bien...</div>
              </div>
              <div class="text-xs text-gray-400">↕</div>
            </div>
          </div>
          <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-gray-800 dark:text-white">Despedida Formal</div>
                <div class="text-[10px] text-gray-500 truncate mt-1">Saludos cordiales...</div>
              </div>
              <div class="text-xs text-gray-400">↕</div>
            </div>
          </div>
          <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-gray-800 dark:text-white">Dirección</div>
                <div class="text-[10px] text-gray-500 truncate mt-1">Calle 123, Col. Centro...</div>
              </div>
              <div class="text-xs text-gray-400">↕</div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2">
        <div class="grid grid-cols-10 gap-1 text-center text-xs">
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">q</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">w</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">e</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">r</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">t</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">y</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">u</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">i</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">o</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">p</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Edit 2",
        "name": "Editor de Snippet con Variables",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-sm font-bold text-gray-800 dark:text-white">Editar Snippet</div>
          <div class="flex items-center gap-2">
            <div class="px-2 py-1 bg-green-500 rounded-lg text-white text-xs">💾 Guardar</div>
          </div>
        </div>
        <div class="mb-3">
          <div class="text-xs text-gray-500 mb-1">Nombre</div>
          <input type="text" class="w-full p-2 bg-gray-100 dark:bg-gray-800 rounded-xl text-sm text-gray-800 dark:text-white outline-none border border-gray-200 dark:border-gray-700" value="Saludo Personalizado">
        </div>
        <div class="mb-3">
          <div class="text-xs text-gray-500 mb-1">Contenido</div>
          <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl min-h-[80px]">
            <div class="text-xs text-gray-800 dark:text-white">Hola <span class="px-1 py-0.5 bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 rounded">nombre</span>, espero que estés bien. <span class="px-1 py-0.5 bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 rounded">asunto</span></div>
          </div>
        </div>
        <div class="mb-3">
          <div class="text-xs text-gray-500 mb-1">Variables Detectadas</div>
          <div class="flex flex-wrap gap-2">
            <div class="px-2 py-1 bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 rounded-lg text-xs">nombre</div>
            <div class="px-2 py-1 bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 rounded-lg text-xs">asunto</div>
            <div class="px-2 py-1 bg-gray-200 dark:bg-gray-700 text-gray-500 rounded-lg text-xs">+ Agregar</div>
          </div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2">
        <div class="grid grid-cols-10 gap-1 text-center text-xs">
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">q</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">w</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">e</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">r</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">t</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">y</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">u</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">i</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">o</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">p</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Use 3",
        "name": "Uso con Autocompletado",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-sm text-gray-800 dark:text-white">Hola, ¿cómo puedo ayudarte hoy?</div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-blue-500 p-3 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-2">
          <div class="text-xs font-bold text-blue-600 dark:text-blue-400">Sugerencia de Snippet</div>
          <div class="text-xs text-gray-400">↕</div>
        </div>
        <div class="p-2 bg-blue-50 dark:bg-blue-900/30 rounded-xl mb-2">
          <div class="text-xs text-gray-800 dark:text-white">Saludo Profesional</div>
          <div class="text-[10px] text-gray-500 mt-1">Hola [nombre], espero que estés bien...</div>
        </div>
        <div class="flex gap-2">
          <div class="flex-1 py-1.5 bg-blue-500 rounded-lg text-white text-xs font-bold text-center">↵ Insertar</div>
          <div class="flex-1 py-1.5 bg-gray-200 dark:bg-gray-700 rounded-lg text-gray-800 dark:text-white text-xs font-bold text-center">✎ Editar</div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-2">Snippets Recientes</div>
        <div class="space-y-2">
          <div class="flex items-center gap-2 p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="w-8 h-8 bg-blue-100 dark:bg-blue-900/50 rounded-lg flex items-center justify-center text-blue-500 text-xs">S</div>
            <div class="flex-1">
              <div class="text-xs text-gray-800 dark:text-white">Saludo Profesional</div>
              <div class="text-[10px] text-gray-400">Usado hace 2h</div>
            </div>
          </div>
          <div class="flex items-center gap-2 p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="w-8 h-8 bg-green-100 dark:bg-green-900/50 rounded-lg flex items-center justify-center text-green-500 text-xs">D</div>
            <div class="flex-1">
              <div class="text-xs text-gray-800 dark:text-white">Dirección</div>
              <div class="text-[10px] text-gray-400">Usado hace 1d</div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2 mt-3">
        <div class="grid grid-cols-10 gap-1 text-center text-xs">
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">q</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">w</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">e</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">r</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">t</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">y</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">u</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">i</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">o</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">p</div>
        </div>
      </div>
    </div>"""
    }
]
