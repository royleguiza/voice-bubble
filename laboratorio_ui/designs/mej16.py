"""MEJ-16: Historial de Transcripciones"""
VARIANTS = [
    {
        "id": "Modal 1",
        "name": "Modal Glass con Tarjetas",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-sm font-bold text-gray-800 dark:text-white">Historial de Dictados</div>
          <div class="flex items-center gap-2">
            <div class="text-xs text-gray-500">5/20</div>
            <div class="px-2 py-1 bg-red-100 dark:bg-red-900/30 rounded-lg text-red-500 text-xs">Vaciar</div>
            <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500">×</div>
          </div>
        </div>
        <div class="p-2 bg-gray-100 dark:bg-gray-800 rounded-xl mb-3 flex items-center gap-2">
          <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
          <input type="text" placeholder="Buscar transcripción..." class="flex-1 bg-transparent text-xs text-gray-800 dark:text-white outline-none">
        </div>
        <div class="space-y-2 max-h-48 overflow-y-auto">
          <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="text-xs text-gray-800 dark:text-white">Hola, necesito que me ayudes con el proyecto...</div>
                <div class="flex items-center gap-2 mt-1">
                  <span class="text-[10px] text-gray-400">Hace 3 min</span>
                  <span class="text-[10px] text-blue-400">🎤 Teclado</span>
                </div>
              </div>
              <div class="flex gap-1">
                <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500 text-xs">📋</div>
                <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500 text-xs">📌</div>
              </div>
            </div>
          </div>
          <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl border border-gray-200 dark:border-gray-700">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="text-xs text-gray-800 dark:text-white">Reunión con el equipo a las 3 de la tarde...</div>
                <div class="flex items-center gap-2 mt-1">
                  <span class="text-[10px] text-gray-400">Hoy 11:20</span>
                  <span class="text-[10px] text-purple-400">🫧 Burbuja</span>
                </div>
              </div>
              <div class="flex gap-1">
                <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500 text-xs">📋</div>
                <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500 text-xs">📌</div>
              </div>
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
        "id": "Expand 2",
        "name": "Transcripción Expandida",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-sm font-bold text-gray-800 dark:text-white">Transcripción Completa</div>
          <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500">×</div>
        </div>
        <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl mb-3">
          <div class="text-xs text-gray-800 dark:text-white leading-relaxed">Hola, necesito que me ayudes con el proyecto de la app. Tenemos que implementar el sistema de burbuja flotante y el teclado nativo. El deadline es el viernes y necesitamos tener al menos el prototipo funcional.</div>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <span class="text-[10px] text-gray-400">Hace 3 min</span>
          <span class="text-[10px] text-blue-400">🎤 Teclado</span>
          <span class="text-[10px] text-gray-400">45 palabras</span>
        </div>
        <div class="flex gap-2">
          <div class="flex-1 py-2 bg-blue-500 rounded-xl text-white text-xs font-bold text-center">📋 Copiar</div>
          <div class="flex-1 py-2 bg-gray-200 dark:bg-gray-700 rounded-xl text-gray-800 dark:text-white text-xs font-bold text-center">↵ Insertar</div>
          <div class="w-10 py-2 bg-red-100 dark:bg-red-900/30 rounded-xl text-red-500 text-xs font-bold text-center">🗑️</div>
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
        "id": "Multi 3",
        "name": "Selección Múltiple",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-sm font-bold text-gray-800 dark:text-white">Selección Múltiple</div>
          <div class="text-xs text-blue-500">3 seleccionados</div>
        </div>
        <div class="space-y-2">
          <div class="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl border-2 border-blue-500">
            <div class="flex items-center gap-2">
              <div class="w-5 h-5 bg-blue-500 rounded-full flex items-center justify-center">
                <svg class="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>
              </div>
              <div class="text-xs text-gray-800 dark:text-white">Hola, necesito ayuda...</div>
            </div>
          </div>
          <div class="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl border-2 border-blue-500">
            <div class="flex items-center gap-2">
              <div class="w-5 h-5 bg-blue-500 rounded-full flex items-center justify-center">
                <svg class="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>
              </div>
              <div class="text-xs text-gray-800 dark:text-white">Reunión con el equipo...</div>
            </div>
          </div>
          <div class="p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl border-2 border-blue-500">
            <div class="flex items-center gap-2">
              <div class="w-5 h-5 bg-blue-500 rounded-full flex items-center justify-center">
                <svg class="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>
              </div>
              <div class="text-xs text-gray-800 dark:text-white">Comprar leche y pan...</div>
            </div>
          </div>
        </div>
        <div class="flex gap-2 mt-3">
          <div class="flex-1 py-2 bg-blue-500 rounded-xl text-white text-xs font-bold text-center">📋 Copiar Todo</div>
          <div class="flex-1 py-2 bg-gray-200 dark:bg-gray-700 rounded-xl text-gray-800 dark:text-white text-xs font-bold text-center">↵ Insertar</div>
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
    }
]
