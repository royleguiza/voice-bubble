"""MEJ-06: Gesto Barra Espaciadora"""
VARIANTS = [
    {
        "id": "Menu 1",
        "name": "Menú Rápido de 3 Opciones",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-xl">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3 text-center">Menú Rápido de Espacio</div>
        <div class="flex gap-2">
          <div class="flex-1 p-3 bg-blue-500 rounded-xl text-center shadow-lg shadow-blue-500/30">
            <div class="text-lg mb-1">&lt;/&gt;</div>
            <div class="text-xs text-white font-bold">Código</div>
          </div>
          <div class="flex-1 p-3 bg-purple-500 rounded-xl text-center shadow-lg shadow-purple-500/30">
            <div class="text-lg mb-1">📋</div>
            <div class="text-xs text-white font-bold">Portapapeles</div>
          </div>
          <div class="flex-1 p-3 bg-green-500 rounded-xl text-center shadow-lg shadow-green-500/30">
            <div class="text-lg mb-1">☰</div>
            <div class="text-xs text-white font-bold">Snippets</div>
          </div>
        </div>
        <div class="text-center text-xs text-gray-400 mt-2">Deslizar hacia arriba y soltar</div>
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
        <div class="flex gap-1 mt-1">
          <div class="flex-1 py-2 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white text-xs">⇧</div>
          <div class="flex-[5] py-2 bg-white dark:bg-gray-700 rounded-lg text-gray-800 dark:text-white text-xs relative">
            espacio
            <svg class="w-4 h-4 text-blue-500 absolute right-2 top-1/2 -translate-y-1/2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/></svg>
          </div>
          <div class="flex-1 py-2 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Swipe 2",
        "name": "Gesto de Activación",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Gesto de Activación</div>
        <div class="flex items-center justify-center gap-4">
          <div class="text-center">
            <div class="w-16 h-16 bg-gray-200 dark:bg-gray-700 rounded-2xl flex items-center justify-center mb-1">
              <div class="text-2xl">👆</div>
            </div>
            <div class="text-xs text-gray-500">Toque largo</div>
            <div class="text-xs text-gray-400">~300ms</div>
          </div>
          <svg class="w-8 h-8 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6"/></svg>
          <div class="text-center">
            <div class="w-16 h-16 bg-blue-500 rounded-2xl flex items-center justify-center mb-1 shadow-lg shadow-blue-500/30">
              <div class="text-2xl">📋</div>
            </div>
            <div class="text-xs text-blue-500 font-bold">Menú Rápido</div>
            <div class="text-xs text-blue-400">3 opciones</div>
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
        <div class="flex gap-1 mt-1">
          <div class="flex-1 py-2 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white text-xs">⇧</div>
          <div class="flex-[5] py-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg text-blue-600 dark:text-blue-400 text-xs font-bold border-2 border-blue-500">espacio ↑</div>
          <div class="flex-1 py-2 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Custom 3",
        "name": "Personalización de Slots",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Personalizar Menú</div>
        <div class="space-y-3">
          <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="text-xs text-gray-500 mb-2">Slot Izquierdo</div>
            <div class="flex items-center gap-2">
              <div class="px-3 py-2 bg-blue-500 rounded-lg text-white text-xs font-bold">&lt;/&gt; Código</div>
              <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
            </div>
          </div>
          <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="text-xs text-gray-500 mb-2">Slot Centro</div>
            <div class="flex items-center gap-2">
              <div class="px-3 py-2 bg-purple-500 rounded-lg text-white text-xs font-bold">📋 Portapapeles</div>
              <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
            </div>
          </div>
          <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="text-xs text-gray-500 mb-2">Slot Derecho</div>
            <div class="flex items-center gap-2">
              <div class="px-3 py-2 bg-green-500 rounded-lg text-white text-xs font-bold">☰ Snippets</div>
              <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2">
        <div class="flex gap-1 text-center text-xs">
          <div class="flex-1 py-2 bg-blue-500 rounded-lg text-white font-bold">&lt;/&gt;</div>
          <div class="flex-1 py-2 bg-purple-500 rounded-lg text-white font-bold">📋</div>
          <div class="flex-1 py-2 bg-green-500 rounded-lg text-white font-bold">☰</div>
        </div>
      </div>
    </div>"""
    }
]
