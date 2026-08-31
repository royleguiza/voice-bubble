"""MEJ-17: Sistema Modular de Micro-Widgets"""
VARIANTS = [
    {
        "id": "Strip 1",
        "name": "Franja de Widgets Modular",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-2 mb-3">
        <div class="flex gap-2 overflow-x-auto">
          <div class="flex-shrink-0 w-24 p-2 bg-yellow-100 dark:bg-yellow-900/30 rounded-xl border border-yellow-300 dark:border-yellow-700">
            <div class="text-xs font-bold text-yellow-600 dark:text-yellow-400 mb-1">📝 Notas</div>
            <div class="text-[10px] text-gray-500">Idea rápida...</div>
          </div>
          <div class="flex-shrink-0 w-24 p-2 bg-blue-100 dark:bg-blue-900/30 rounded-xl border border-blue-300 dark:border-blue-700">
            <div class="text-xs font-bold text-blue-600 dark:text-blue-400 mb-1">📋 Clips</div>
            <div class="text-[10px] text-gray-500">Último: hola</div>
          </div>
          <div class="flex-shrink-0 w-24 p-2 bg-green-100 dark:bg-green-900/30 rounded-xl border border-green-300 dark:border-green-700">
            <div class="text-xs font-bold text-green-600 dark:text-green-400 mb-1">⚡ Cmds</div>
            <div class="text-[10px] text-gray-500">git status</div>
          </div>
          <div class="flex-shrink-0 w-24 p-2 bg-purple-100 dark:bg-purple-900/30 rounded-xl border border-purple-300 dark:border-purple-700">
            <div class="text-xs font-bold text-purple-600 dark:text-purple-400 mb-1">🔢 Calc</div>
            <div class="text-[10px] text-gray-500">150 * 1.21</div>
          </div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="flex items-center justify-between mb-2">
          <div class="text-xs font-bold text-gray-800 dark:text-white">📝 Notas Rápidas</div>
          <div class="flex gap-1">
            <div class="px-2 py-1 bg-gray-200 dark:bg-gray-700 rounded-lg text-gray-600 dark:text-gray-400 text-[10px]">📋 Copiar</div>
            <div class="px-2 py-1 bg-gray-200 dark:bg-gray-700 rounded-lg text-gray-600 dark:text-gray-400 text-[10px]">↵ Insertar</div>
          </div>
        </div>
        <div class="p-2 bg-gray-50 dark:bg-gray-800 rounded-xl min-h-[60px]">
          <div class="text-xs text-gray-800 dark:text-white">Reunión 3pm: discutir roadmap Q4</div>
          <div class="text-xs text-gray-400 mt-1">Prioridad: alta</div>
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
        "id": "Cmds 2",
        "name": "Widget de Comandos y Calculadora",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-xs font-bold text-gray-800 dark:text-white mb-2">⚡ Comandos Rápidos</div>
        <div class="flex flex-wrap gap-1">
          <div class="px-2 py-1 bg-gray-100 dark:bg-gray-800 rounded-lg text-[10px] text-gray-800 dark:text-white border border-gray-200 dark:border-gray-700">git status</div>
          <div class="px-2 py-1 bg-gray-100 dark:bg-gray-800 rounded-lg text-[10px] text-gray-800 dark:text-white border border-gray-200 dark:border-gray-700">git push</div>
          <div class="px-2 py-1 bg-gray-100 dark:bg-gray-800 rounded-lg text-[10px] text-gray-800 dark:text-white border border-gray-200 dark:border-gray-700">npm install</div>
          <div class="px-2 py-1 bg-gray-100 dark:bg-gray-800 rounded-lg text-[10px] text-gray-800 dark:text-white border border-gray-200 dark:border-gray-700">docker ps</div>
          <div class="px-2 py-1 bg-gray-100 dark:bg-gray-800 rounded-lg text-[10px] text-gray-800 dark:text-white border border-gray-200 dark:border-gray-700">ssh server</div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-xs font-bold text-gray-800 dark:text-white mb-2">🔢 Calculadora Rápida</div>
        <div class="p-2 bg-gray-50 dark:bg-gray-800 rounded-xl">
          <div class="text-xs text-gray-500 mb-1">150 * 1.21</div>
          <div class="text-lg font-bold text-gray-800 dark:text-white">= 181.5</div>
        </div>
        <div class="flex gap-1 mt-2">
          <div class="flex-1 py-1 bg-blue-500 rounded-lg text-white text-[10px] font-bold text-center">📋 Copiar</div>
          <div class="flex-1 py-1 bg-gray-200 dark:bg-gray-700 rounded-lg text-gray-800 dark:text-white text-[10px] font-bold text-center">↵ Insertar</div>
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
        "id": "Config 3",
        "name": "Configuración de Widgets",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Configurar Widgets</div>
        <div class="space-y-2">
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 bg-yellow-500 rounded-lg flex items-center justify-center text-white text-sm">📝</div>
              <div class="text-xs text-gray-800 dark:text-white">Notas Rápidas</div>
            </div>
            <div class="w-10 h-5 bg-blue-500 rounded-full flex items-center justify-end px-1">
              <div class="w-4 h-4 bg-white rounded-full"></div>
            </div>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 bg-blue-500 rounded-lg flex items-center justify-center text-white text-sm">📋</div>
              <div class="text-xs text-gray-800 dark:text-white">Portapapeles en Vivo</div>
            </div>
            <div class="w-10 h-5 bg-blue-500 rounded-full flex items-center justify-end px-1">
              <div class="w-4 h-4 bg-white rounded-full"></div>
            </div>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center text-white text-sm">⚡</div>
              <div class="text-xs text-gray-800 dark:text-white">Comandos</div>
            </div>
            <div class="w-10 h-5 bg-blue-500 rounded-full flex items-center justify-end px-1">
              <div class="w-4 h-4 bg-white rounded-full"></div>
            </div>
          </div>
          <div class="flex items-center justify-between p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-2">
              <div class="w-8 h-8 bg-purple-500 rounded-lg flex items-center justify-center text-white text-sm">🔢</div>
              <div class="text-xs text-gray-800 dark:text-white">Calculadora</div>
            </div>
            <div class="w-10 h-5 bg-gray-300 dark:bg-gray-600 rounded-full flex items-center px-1">
              <div class="w-4 h-4 bg-white rounded-full"></div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-2">
        <div class="flex gap-1 overflow-x-auto">
          <div class="flex-shrink-0 w-20 p-2 bg-yellow-100 dark:bg-yellow-900/30 rounded-xl text-center">
            <div class="text-xs">📝</div>
          </div>
          <div class="flex-shrink-0 w-20 p-2 bg-blue-100 dark:bg-blue-900/30 rounded-xl text-center">
            <div class="text-xs">📋</div>
          </div>
          <div class="flex-shrink-0 w-20 p-2 bg-green-100 dark:bg-green-900/30 rounded-xl text-center">
            <div class="text-xs">⚡</div>
          </div>
        </div>
      </div>
    </div>"""
    }
]
