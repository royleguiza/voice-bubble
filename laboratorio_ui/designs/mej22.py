"""MEJ-22: Controlador de Audios de Chats"""
VARIANTS = [
    {
        "id": "Strip 1",
        "name": "Barra de Control de Audio",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="flex items-center gap-3 mb-2">
          <div class="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center text-white text-xs font-bold">W</div>
          <div class="flex-1">
            <div class="text-sm font-bold text-gray-800 dark:text-white">WhatsApp</div>
            <div class="text-xs text-gray-500">Audio de María</div>
          </div>
          <div class="text-xs text-gray-400">0:45 / 2:10</div>
        </div>
        <div class="flex items-center gap-2 mb-2">
          <div class="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400 text-xs">⏪</div>
          <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white text-sm shadow-lg shadow-blue-500/30">⏸</div>
          <div class="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400 text-xs">⏩</div>
        </div>
        <div class="flex items-center gap-2">
          <div class="text-[10px] text-gray-400">0:45</div>
          <div class="flex-1 h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full">
            <div class="w-[35%] h-full bg-blue-500 rounded-full relative">
              <div class="absolute right-0 top-1/2 -translate-y-1/2 w-3 h-3 bg-blue-500 rounded-full border-2 border-white shadow"></div>
            </div>
          </div>
          <div class="text-[10px] text-gray-400">2:10</div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-sm text-gray-800 dark:text-white">¿Qué tal la reunión?</div>
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
        "id": "Volume 2",
        "name": "Control de Volumen Rápido",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-xs font-bold text-gray-800 dark:text-white">Control de Audio</div>
          <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500 text-xs">✕</div>
        </div>
        <div class="flex items-center gap-3 mb-3">
          <div class="w-12 h-12 bg-gradient-to-br from-green-500 to-green-600 rounded-xl flex items-center justify-center text-white text-lg shadow-lg shadow-green-500/30">🎤</div>
          <div class="flex-1">
            <div class="text-sm font-bold text-gray-800 dark:text-white">Audio de María</div>
            <div class="text-xs text-gray-500">WhatsApp • 2:10</div>
          </div>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <div class="text-[10px] text-gray-400">0:45</div>
          <div class="flex-1 h-2 bg-gray-200 dark:bg-gray-700 rounded-full">
            <div class="w-[35%] h-full bg-blue-500 rounded-full"></div>
          </div>
          <div class="text-[10px] text-gray-400">2:10</div>
        </div>
        <div class="flex items-center justify-center gap-4 mb-3">
          <div class="w-10 h-10 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400">⏪</div>
          <div class="w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center text-white text-lg shadow-lg shadow-blue-500/30">⏸</div>
          <div class="w-10 h-10 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400">⏩</div>
        </div>
        <div class="flex items-center gap-2">
          <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"/></svg>
          <div class="flex-1 h-1 bg-gray-200 dark:bg-gray-700 rounded-full">
            <div class="w-3/4 h-full bg-gray-400 rounded-full"></div>
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
        "id": "Persist 3",
        "name": "Persistencia Durante Scroll",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="flex items-center gap-2 mb-2">
          <div class="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center text-white text-xs font-bold">W</div>
          <div class="text-sm font-bold text-gray-800 dark:text-white">WhatsApp</div>
          <div class="ml-auto text-xs text-gray-400">0:45 / 2:10</div>
        </div>
        <div class="flex items-center gap-2">
          <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400 text-[10px]">⏪</div>
          <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center text-white text-xs shadow-lg shadow-blue-500/30">⏸</div>
          <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-600 dark:text-gray-400 text-[10px]">⏩</div>
          <div class="flex-1 h-1 bg-gray-200 dark:bg-gray-700 rounded-full">
            <div class="w-[35%] h-full bg-blue-500 rounded-full"></div>
          </div>
        </div>
      </div>
      <div class="flex-1 space-y-2 overflow-y-auto">
        <div class="bg-gray-100 dark:bg-gray-800 rounded-2xl p-3 ml-auto max-w-[80%]">
          <div class="text-sm text-gray-800 dark:text-white">Hola, ¿cómo estás?</div>
          <div class="text-[10px] text-gray-400 text-right">10:30</div>
        </div>
        <div class="bg-gray-100 dark:bg-gray-800 rounded-2xl p-3 max-w-[80%]">
          <div class="text-sm text-gray-800 dark:text-white">Muy bien, trabajando en el proyecto</div>
          <div class="text-[10px] text-gray-400">10:32</div>
        </div>
        <div class="bg-gray-100 dark:bg-gray-800 rounded-2xl p-3 ml-auto max-w-[80%]">
          <div class="text-sm text-gray-800 dark:text-white">¿Ya terminaste el teclado?</div>
          <div class="text-[10px] text-gray-400 text-right">10:35</div>
        </div>
        <div class="bg-gray-100 dark:bg-gray-800 rounded-2xl p-3 max-w-[80%]">
          <div class="text-sm text-gray-800 dark:text-white">Sí, falta pulir algunos detalles</div>
          <div class="text-[10px] text-gray-400">10:38</div>
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
