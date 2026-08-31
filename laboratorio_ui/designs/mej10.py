"""MEJ-10: Gestos Duales en Burbuja"""
VARIANTS = [
    {
        "id": "Tap 1",
        "name": "Toque vs Mantener",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="flex-1 flex flex-col items-center justify-center relative">
        <div class="absolute right-4 top-1/4">
          <div class="w-14 h-14 bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-full border border-gray-200 dark:border-gray-700 shadow-xl flex items-center justify-center">
            <svg class="w-6 h-6 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/></svg>
          </div>
          <div class="text-center text-[10px] text-gray-400 mt-1">Toque = Grabar</div>
          <div class="text-center text-[10px] text-gray-400">Mantener = Historial</div>
        </div>
        <div class="w-full px-4">
          <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3">
            <div class="text-sm text-gray-800 dark:text-white">Hola, ¿cómo puedo ayudarte hoy?</div>
            <div class="text-xs text-gray-400 mt-1">WhatsApp</div>
          </div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "History 2",
        "name": "Historial Flotante desde Burbuja",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="flex-1 flex flex-col items-center justify-center relative">
        <div class="absolute right-4 top-1/4">
          <div class="w-14 h-14 bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-full border border-gray-200 dark:border-gray-700 shadow-xl flex items-center justify-center mb-2">
            <svg class="w-6 h-6 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/></svg>
          </div>
        </div>
        <div class="absolute right-20 top-16 w-56 bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 shadow-2xl">
          <div class="text-xs font-bold text-gray-800 dark:text-white mb-2">Historial</div>
          <div class="space-y-2">
            <div class="p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
              <div class="text-xs text-gray-800 dark:text-white">Hola, ¿cómo estás?</div>
              <div class="text-[10px] text-gray-400">Hace 2 min</div>
            </div>
            <div class="p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
              <div class="text-xs text-gray-800 dark:text-white">Reunión a las 3pm</div>
              <div class="text-[10px] text-gray-400">Hace 15 min</div>
            </div>
            <div class="p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
              <div class="text-xs text-gray-800 dark:text-white">Comprar leche</div>
              <div class="text-[10px] text-gray-400">Hoy 10:30</div>
            </div>
          </div>
        </div>
        <div class="w-full px-4 mt-20">
          <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3">
            <div class="text-sm text-gray-800 dark:text-white">Hola, ¿cómo puedo ayudarte hoy?</div>
          </div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Mode 3",
        "name": "Selector de Modo de Burbuja",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Modo de Burbuja</div>
        <div class="space-y-2">
          <div class="p-3 bg-blue-100 dark:bg-blue-900/30 rounded-xl border-2 border-blue-500">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-blue-600 dark:text-blue-400">Toque Simple</div>
                <div class="text-[10px] text-blue-400">Tap = Grabar, Hold = Historial</div>
              </div>
              <div class="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center">
                <svg class="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>
              </div>
            </div>
          </div>
          <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-gray-600 dark:text-gray-400">Mantener Presionado</div>
                <div class="text-[10px] text-gray-400">Hold = Grabar, Tap = Historial</div>
              </div>
              <div class="w-6 h-6 bg-gray-300 dark:bg-gray-600 rounded-full"></div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4">
        <div class="flex items-center justify-center gap-8">
          <div class="text-center">
            <div class="w-16 h-16 bg-blue-100 dark:bg-blue-900/30 rounded-2xl flex items-center justify-center mb-1">
              <div class="text-2xl">👆</div>
            </div>
            <div class="text-xs text-blue-500 font-bold">Toque</div>
            <div class="text-[10px] text-gray-400">~100ms</div>
          </div>
          <div class="text-center">
            <div class="w-16 h-16 bg-purple-100 dark:bg-purple-900/30 rounded-2xl flex items-center justify-center mb-1">
              <div class="text-2xl">👇</div>
            </div>
            <div class="text-xs text-purple-500 font-bold">Mantener</div>
            <div class="text-[10px] text-gray-400">~400ms</div>
          </div>
        </div>
      </div>
    </div>"""
    }
]
