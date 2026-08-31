"""MEJ-02: Ciclar Mayúsculas"""
VARIANTS = [
    {
        "id": "Shift 1",
        "name": "Indicador de Estado Shift",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 shadow-xl flex-1 flex flex-col overflow-hidden">
        <div class="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
          <h3 class="font-bold text-gray-800 dark:text-white">Chat</h3>
          <div class="flex items-center gap-2">
            <div class="px-2 py-1 bg-blue-500 rounded-lg text-white text-xs font-bold">⇧ MAYÚS</div>
            <div class="text-xs text-gray-400">1/3</div>
          </div>
        </div>
        <div class="flex-1 p-4 space-y-3">
          <div class="bg-gray-100 dark:bg-gray-800 rounded-2xl rounded-tl-sm p-3 max-w-[80%]">
            <div class="text-sm text-gray-800 dark:text-white">Hola, ¿cómo estás?</div>
          </div>
          <div class="bg-blue-500 rounded-2xl rounded-tr-sm p-3 max-w-[80%] ml-auto">
            <div class="text-sm text-white">Muy bien, gracias</div>
          </div>
        </div>
        <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-t-2xl border-t border-gray-300 dark:border-gray-600 p-2">
          <div class="grid grid-cols-10 gap-1 text-center text-xs">
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">Q</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">W</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">E</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">R</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">T</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">Y</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">U</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">I</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">O</div>
            <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">P</div>
          </div>
          <div class="flex gap-1 mt-1">
            <div class="flex-1 py-2 bg-blue-500 rounded-lg font-bold text-white text-xs shadow-lg shadow-blue-500/30">⇧</div>
            <div class="flex-[5] py-2 bg-white dark:bg-gray-700 rounded-lg text-gray-800 dark:text-white text-xs">espacio</div>
            <div class="flex-1 py-2 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
          </div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Shift 2",
        "name": "Ciclado Visual de Estados",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Estados de Shift</div>
        <div class="flex gap-2">
          <div class="flex-1 p-3 bg-gray-100 dark:bg-gray-800 rounded-xl text-center">
            <div class="text-2xl mb-1">🔡</div>
            <div class="text-xs text-gray-500">minúsculas</div>
            <div class="text-[10px] text-gray-400">Toque 1</div>
          </div>
          <div class="flex-1 p-3 bg-blue-100 dark:bg-blue-900/30 rounded-xl text-center border-2 border-blue-500">
            <div class="text-2xl mb-1">🔠</div>
            <div class="text-xs text-blue-600 dark:text-blue-400 font-bold">MAYÚSCULA</div>
            <div class="text-[10px] text-blue-400">Toque 2</div>
          </div>
          <div class="flex-1 p-3 bg-gray-100 dark:bg-gray-800 rounded-xl text-center">
            <div class="text-2xl mb-1">🔡</div>
            <div class="text-xs text-gray-500">minúsculas</div>
            <div class="text-[10px] text-gray-400">Toque 3</div>
          </div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-sm text-gray-800 dark:text-white">Hola mundo|</div>
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
          <div class="flex-[5] py-2 bg-white dark:bg-gray-700 rounded-lg text-gray-800 dark:text-white text-xs">espacio</div>
          <div class="flex-1 py-2 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Shift 3",
        "name": "Animación de Ciclado",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Animación de Ciclado</div>
        <div class="flex items-center justify-center gap-4">
          <div class="w-16 h-16 bg-gray-200 dark:bg-gray-700 rounded-2xl flex items-center justify-center">
            <div class="text-2xl">⇧</div>
          </div>
          <svg class="w-8 h-8 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6"/></svg>
          <div class="w-16 h-16 bg-blue-500 rounded-2xl flex items-center justify-center shadow-lg shadow-blue-500/30">
            <div class="text-2xl text-white font-bold">A</div>
          </div>
        </div>
        <div class="text-center text-xs text-gray-500 mt-3">Toque rápido = ciclo • Mantener = fijo</div>
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
          <div class="flex-1 py-2 bg-blue-500 rounded-lg font-bold text-white text-xs shadow-lg shadow-blue-500/30">⇧</div>
          <div class="flex-[5] py-2 bg-white dark:bg-gray-700 rounded-lg text-gray-800 dark:text-white text-xs">espacio</div>
          <div class="flex-1 py-2 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
        </div>
      </div>
    </div>"""
    }
]
