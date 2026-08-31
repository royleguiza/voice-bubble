"""MEJ-12: Micro-Teclado Flotante"""
VARIANTS = [
    {
        "id": "Strip 1",
        "name": "Command Strip Compacto",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-[#1e1e2e]/95 backdrop-blur-xl rounded-2xl border border-gray-700 p-3 mb-3 flex-1">
        <div class="font-mono text-xs text-green-400">$ <span class="text-white">git status</span></div>
        <div class="font-mono text-xs text-gray-300">On branch main</div>
        <div class="font-mono text-xs text-gray-300">Your branch is up to date</div>
        <div class="font-mono text-xs text-gray-300">nothing to commit</div>
        <div class="font-mono text-xs text-green-400">$ <span class="text-white">npm run build</span></div>
        <div class="font-mono text-xs text-gray-300">Building project...</div>
        <div class="font-mono text-xs text-green-400">✓ Build complete</div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-2 shadow-xl">
        <div class="flex items-center gap-1">
          <div class="px-3 py-2 bg-blue-500 rounded-xl text-white text-xs font-bold flex items-center gap-1">
            <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/></svg>
            Mic
          </div>
          <div class="px-3 py-2 bg-gray-200 dark:bg-gray-700 rounded-xl text-gray-800 dark:text-white text-xs">⌫</div>
          <div class="flex-1 px-3 py-2 bg-gray-200 dark:bg-gray-700 rounded-xl text-gray-800 dark:text-white text-xs">espacio</div>
          <div class="px-3 py-2 bg-blue-500 rounded-xl text-white text-xs font-bold">↵</div>
          <div class="px-3 py-2 bg-gray-200 dark:bg-gray-700 rounded-xl text-gray-800 dark:text-white text-xs">⇥</div>
          <div class="px-2 py-2 bg-gray-300 dark:bg-gray-600 rounded-xl text-gray-800 dark:text-white text-xs">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/></svg>
          </div>
        </div>
        <div class="text-center text-[10px] text-gray-400 mt-1">Micro-Teclado Flotante (44dp)</div>
      </div>
    </div>"""
    },
    {
        "id": "Float 2",
        "name": "Barr Flotante en Chat",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="flex items-center gap-3 mb-2">
          <div class="w-8 h-8 rounded-full bg-green-500 flex items-center justify-center text-white text-xs font-bold">T</div>
          <div class="text-sm font-bold text-gray-800 dark:text-white">Telegram</div>
        </div>
        <div class="text-sm text-gray-800 dark:text-white">¿Ya viste el nuevo repo?</div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-full border border-gray-200 dark:border-gray-700 p-1.5 shadow-xl mx-4 mb-3">
        <div class="flex items-center gap-1">
          <div class="px-2 py-1.5 bg-blue-500 rounded-full text-white text-[10px] font-bold">🎤</div>
          <div class="px-2 py-1.5 bg-gray-200 dark:bg-gray-700 rounded-full text-gray-800 dark:text-white text-[10px]">⌫</div>
          <div class="flex-1 px-2 py-1.5 bg-gray-200 dark:bg-gray-700 rounded-full text-gray-800 dark:text-white text-[10px] text-center">espacio</div>
          <div class="px-2 py-1.5 bg-blue-500 rounded-full text-white text-[10px] font-bold">↵</div>
        </div>
      </div>
      <div class="flex-1 px-4 space-y-2">
        <div class="bg-gray-100 dark:bg-gray-800 rounded-2xl p-3">
          <div class="text-sm text-gray-800 dark:text-white">Sí, lo estoy viendo ahora</div>
        </div>
        <div class="bg-blue-500 rounded-2xl p-3 ml-auto max-w-[80%]">
          <div class="text-sm text-white">Perfecto, voy a hacer el merge</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Compare 3",
        "name": "Comparación de Tamaños",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Conmutación Teclado ↔ Burbuja</div>
        <div class="space-y-2">
          <div class="flex items-center justify-between p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="text-xs text-gray-600 dark:text-gray-400">Minimizar a Burbuja</div>
            <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>
          </div>
          <div class="flex items-center justify-between p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="text-xs text-gray-600 dark:text-gray-400">Expandir a Teclado Completo</div>
            <svg class="w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/></svg>
          </div>
        </div>
        <div class="mt-3 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-300 dark:border-blue-700">
          <div class="text-xs text-blue-600 dark:text-blue-400">💡 El micro-teclado deja ver el 95% de la pantalla</div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Comparación de Alturas</div>
        <div class="space-y-3">
          <div>
            <div class="text-xs text-gray-500 mb-1">Teclado Completo</div>
            <div class="h-20 bg-gray-200 dark:bg-gray-700 rounded-lg flex items-center justify-center">
              <div class="text-xs text-gray-400">40% de pantalla</div>
            </div>
          </div>
          <div>
            <div class="text-xs text-blue-500 font-bold mb-1">Micro-Teclado</div>
            <div class="h-4 bg-blue-100 dark:bg-blue-900/30 rounded-lg flex items-center justify-center border border-blue-300 dark:border-blue-700">
              <div class="text-[10px] text-blue-500">5% de pantalla</div>
            </div>
          </div>
        </div>
      </div>
    </div>"""
    }
]
