"""MEJ-07: Control Altura/Elevación"""
VARIANTS = [
    {
        "id": "Height 1",
        "name": "Selector de Altura de Teclas",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Altura de Teclas</div>
        <div class="space-y-2">
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <span class="text-xs text-gray-600 dark:text-gray-400">Muy Compacto</span>
            <span class="text-xs text-gray-400">85%</span>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <span class="text-xs text-gray-600 dark:text-gray-400">Compacto</span>
            <span class="text-xs text-gray-400">92%</span>
          </div>
          <div class="flex items-center justify-between p-2 bg-blue-100 dark:bg-blue-900/30 rounded-xl border-2 border-blue-500">
            <span class="text-xs text-blue-600 dark:text-blue-400 font-bold">Estándar</span>
            <span class="text-xs text-blue-500 font-bold">100%</span>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <span class="text-xs text-gray-600 dark:text-gray-400">Alto</span>
            <span class="text-xs text-gray-400">108%</span>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <span class="text-xs text-gray-600 dark:text-gray-400">Extra Alto</span>
            <span class="text-xs text-gray-400">120%</span>
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
          <div class="flex-[5] py-2 bg-white dark:bg-gray-700 rounded-lg text-gray-800 dark:text-white text-xs">espacio</div>
          <div class="flex-1 py-2 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Elev 2",
        "name": "Control de Elevación Inferior",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Elevación Inferior</div>
        <div class="space-y-2">
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <span class="text-xs text-gray-600 dark:text-gray-400">Pegado al borde</span>
            <span class="text-xs text-gray-400">0 dp</span>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <span class="text-xs text-gray-600 dark:text-gray-400">Elevación Baja</span>
            <span class="text-xs text-gray-400">12 dp</span>
          </div>
          <div class="flex items-center justify-between p-2 bg-blue-100 dark:bg-blue-900/30 rounded-xl border-2 border-blue-500">
            <span class="text-xs text-blue-600 dark:text-blue-400 font-bold">Elevación Media</span>
            <span class="text-xs text-blue-500 font-bold">24 dp</span>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <span class="text-xs text-gray-600 dark:text-gray-400">Elevación Alta</span>
            <span class="text-xs text-gray-400">36 dp</span>
          </div>
        </div>
        <div class="mt-3">
          <div class="text-xs text-gray-500 mb-2">Personalizado</div>
          <div class="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full">
            <div class="w-2/3 h-full bg-blue-500 rounded-full"></div>
          </div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3">
        <div class="text-xs text-gray-500 mb-2">Vista Lateral (Elevación 24dp)</div>
        <div class="flex items-end justify-center gap-4 h-20">
          <div class="text-center">
            <div class="w-32 bg-gray-200 dark:bg-gray-700 rounded-lg p-1 mb-2">
              <div class="grid grid-cols-5 gap-0.5 text-center text-[8px]">
                <div class="py-1 bg-white dark:bg-gray-600 rounded">q</div>
                <div class="py-1 bg-white dark:bg-gray-600 rounded">w</div>
                <div class="py-1 bg-white dark:bg-gray-600 rounded">e</div>
                <div class="py-1 bg-white dark:bg-gray-600 rounded">r</div>
                <div class="py-1 bg-white dark:bg-gray-600 rounded">t</div>
              </div>
            </div>
            <div class="h-6 bg-gray-300 dark:bg-gray-600 rounded-lg"></div>
          </div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Compare 3",
        "name": "Comparación de Alturas",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Comparación de Alturas</div>
        <div class="space-y-3">
          <div class="flex items-center gap-3">
            <div class="w-16 text-xs text-gray-500">85%</div>
            <div class="flex-1 h-8 bg-gray-100 dark:bg-gray-800 rounded-lg flex items-center justify-center">
              <div class="px-2 py-0.5 bg-white dark:bg-gray-700 rounded text-[10px] text-gray-800 dark:text-white">q w e r t</div>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <div class="w-16 text-xs text-gray-500">100%</div>
            <div class="flex-1 h-10 bg-gray-100 dark:bg-gray-800 rounded-lg flex items-center justify-center">
              <div class="px-2 py-1 bg-white dark:bg-gray-700 rounded text-xs text-gray-800 dark:text-white">q w e r t</div>
            </div>
          </div>
          <div class="flex items-center gap-3">
            <div class="w-16 text-xs text-blue-500 font-bold">120%</div>
            <div class="flex-1 h-12 bg-blue-50 dark:bg-blue-900/20 rounded-lg flex items-center justify-center border border-blue-300 dark:border-blue-700">
              <div class="px-2 py-1.5 bg-white dark:bg-gray-700 rounded text-sm text-gray-800 dark:text-white font-bold">q w e r t</div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2">
        <div class="grid grid-cols-10 gap-1 text-center text-xs">
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">q</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">w</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">e</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">r</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">t</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">y</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">u</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">i</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">o</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">p</div>
        </div>
        <div class="flex gap-1 mt-1">
          <div class="flex-1 py-3 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white text-xs">⇧</div>
          <div class="flex-[5] py-3 bg-white dark:bg-gray-700 rounded-lg text-gray-800 dark:text-white text-xs">espacio</div>
          <div class="flex-1 py-3 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
        </div>
      </div>
    </div>"""
    }
]
