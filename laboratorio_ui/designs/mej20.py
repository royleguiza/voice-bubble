"""MEJ-20: Widget Multimedia y Música"""
VARIANTS = [
    {
        "id": "Mini 1",
        "name": "Mini Reproductor Liquid Glass",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="flex items-center gap-3">
          <div class="w-12 h-12 bg-gradient-to-br from-purple-500 to-pink-500 rounded-xl flex items-center justify-center text-white text-lg shadow-lg shadow-purple-500/30">♪</div>
          <div class="flex-1 overflow-hidden">
            <div class="text-xs font-bold text-gray-800 dark:text-white truncate">Bohemian Rhapsody</div>
            <div class="text-[10px] text-gray-500 truncate">Queen</div>
          </div>
          <div class="flex items-center gap-1">
            <div class="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400 text-xs">⏮</div>
            <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white text-sm shadow-lg shadow-blue-500/30">⏸</div>
            <div class="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400 text-xs">⏭</div>
          </div>
        </div>
        <div class="mt-2 flex items-center gap-2">
          <div class="text-[10px] text-gray-400">1:23</div>
          <div class="flex-1 h-1 bg-gray-200 dark:bg-gray-700 rounded-full">
            <div class="w-1/3 h-full bg-blue-500 rounded-full"></div>
          </div>
          <div class="text-[10px] text-gray-400">4:55</div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-sm text-gray-800 dark:text-white">Hola, ¿cómo puedo ayudarte hoy?</div>
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
        "name": "Tarjeta Expandida con Volumen",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-xs font-bold text-gray-800 dark:text-white">Reproductor</div>
          <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500 text-xs">✕</div>
        </div>
        <div class="flex items-center gap-3 mb-3">
          <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-pink-500 rounded-xl flex items-center justify-center text-white text-2xl shadow-lg shadow-purple-500/30">♪</div>
          <div class="flex-1">
            <div class="text-sm font-bold text-gray-800 dark:text-white">Bohemian Rhapsody</div>
            <div class="text-xs text-gray-500">Queen</div>
          </div>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <div class="text-[10px] text-gray-400">1:23</div>
          <div class="flex-1 h-2 bg-gray-200 dark:bg-gray-700 rounded-full">
            <div class="w-1/3 h-full bg-blue-500 rounded-full"></div>
          </div>
          <div class="text-[10px] text-gray-400">4:55</div>
        </div>
        <div class="flex items-center justify-center gap-4 mb-3">
          <div class="w-10 h-10 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400">⏮</div>
          <div class="w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center text-white text-lg shadow-lg shadow-blue-500/30">⏸</div>
          <div class="w-10 h-10 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400">⏭</div>
        </div>
        <div class="flex items-center gap-2">
          <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"/></svg>
          <div class="flex-1 h-1 bg-gray-200 dark:bg-gray-700 rounded-full">
            <div class="w-2/3 h-full bg-gray-400 rounded-full"></div>
          </div>
          <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"/></svg>
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
        "id": "Hide 3",
        "name": "Auto-Ocultamiento Sin Reproducción",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Widget Multimedia</div>
        <div class="space-y-2">
          <div class="p-3 bg-blue-50 dark:bg-blue-900/30 rounded-xl border-2 border-blue-500">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-blue-600 dark:text-blue-400">Habilitar Widget de Música</div>
                <div class="text-[10px] text-blue-400">Auto-oculta sin reproducción</div>
              </div>
              <div class="w-10 h-5 bg-blue-500 rounded-full flex items-center justify-end px-1">
                <div class="w-4 h-4 bg-white rounded-full"></div>
              </div>
            </div>
          </div>
          <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-gray-600 dark:text-gray-400">Mostrar Carátula</div>
                <div class="text-[10px] text-gray-400">Mini artwork del álbum</div>
              </div>
              <div class="w-10 h-5 bg-blue-500 rounded-full flex items-center justify-end px-1">
                <div class="w-4 h-4 bg-white rounded-full"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-center text-xs text-gray-400">
          <div class="mb-2">🎵 No hay reproducción activa</div>
          <div class="text-[10px]">El widget se oculta automáticamente</div>
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
