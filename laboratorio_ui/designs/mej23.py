"""MEJ-23: Lanzador Rápido de Aplicaciones"""
VARIANTS = [
    {
        "id": "Search 1",
        "name": "Buscador Universal Spotlight",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center gap-3 mb-3">
          <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>
          <input type="text" placeholder="Buscar apps..." class="flex-1 bg-transparent text-sm text-gray-800 dark:text-white outline-none" value="ter">
        </div>
        <div class="text-xs text-gray-400 mb-2">Apps Recientes</div>
        <div class="grid grid-cols-5 gap-2 mb-3">
          <div class="text-center">
            <div class="w-12 h-12 bg-black rounded-xl flex items-center justify-center text-white text-lg mb-1">$</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Termux</div>
          </div>
          <div class="text-center">
            <div class="w-12 h-12 bg-blue-500 rounded-xl flex items-center justify-center text-white text-lg mb-1">🌐</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Chrome</div>
          </div>
          <div class="text-center">
            <div class="w-12 h-12 bg-green-500 rounded-xl flex items-center justify-center text-white text-lg mb-1">💬</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">WhatsApp</div>
          </div>
          <div class="text-center">
            <div class="w-12 h-12 bg-purple-500 rounded-xl flex items-center justify-center text-white text-lg mb-1">📝</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Acode</div>
          </div>
          <div class="text-center">
            <div class="w-12 h-12 bg-green-400 rounded-xl flex items-center justify-center text-white text-lg mb-1">🎵</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Spotify</div>
          </div>
        </div>
        <div class="text-xs text-gray-400 mb-2">Resultados para "ter"</div>
        <div class="p-3 bg-blue-50 dark:bg-blue-900/30 rounded-xl border-2 border-blue-500">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-black rounded-xl flex items-center justify-center text-white">$</div>
            <div>
              <div class="text-sm font-bold text-gray-800 dark:text-white">Termux</div>
              <div class="text-xs text-gray-500">Terminal de Android</div>
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
        "id": "Recent 2",
        "name": "Fila de Apps Recientes",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Lanzador Rápido</div>
        <div class="grid grid-cols-4 gap-3">
          <div class="text-center">
            <div class="w-14 h-14 bg-black rounded-2xl flex items-center justify-center text-white text-xl mb-1 shadow-lg">$</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Termux</div>
          </div>
          <div class="text-center">
            <div class="w-14 h-14 bg-blue-500 rounded-2xl flex items-center justify-center text-white text-xl mb-1 shadow-lg">🌐</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Chrome</div>
          </div>
          <div class="text-center">
            <div class="w-14 h-14 bg-green-500 rounded-2xl flex items-center justify-center text-white text-xl mb-1 shadow-lg">💬</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">WhatsApp</div>
          </div>
          <div class="text-center">
            <div class="w-14 h-14 bg-purple-500 rounded-2xl flex items-center justify-center text-white text-xl mb-1 shadow-lg">📝</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Acode</div>
          </div>
        </div>
        <div class="mt-3 grid grid-cols-4 gap-3">
          <div class="text-center">
            <div class="w-14 h-14 bg-green-400 rounded-2xl flex items-center justify-center text-white text-xl mb-1 shadow-lg">🎵</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Spotify</div>
          </div>
          <div class="text-center">
            <div class="w-14 h-14 bg-red-500 rounded-2xl flex items-center justify-center text-white text-xl mb-1 shadow-lg">📺</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">YouTube</div>
          </div>
          <div class="text-center">
            <div class="w-14 h-14 bg-gray-800 rounded-2xl flex items-center justify-center text-white text-xl mb-1 shadow-lg">⚙️</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Ajustes</div>
          </div>
          <div class="text-center">
            <div class="w-14 h-14 bg-blue-400 rounded-2xl flex items-center justify-center text-white text-xl mb-1 shadow-lg">📁</div>
            <div class="text-[10px] text-gray-600 dark:text-gray-400">Archivos</div>
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
        "id": "Launch 3",
        "name": "Lanzamiento Directo",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Configuración del Lanzador</div>
        <div class="space-y-2">
          <div class="flex items-center justify-between p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-blue-500 rounded-xl flex items-center justify-center text-white text-lg">🚀</div>
              <div>
                <div class="text-sm font-bold text-gray-800 dark:text-white">Habilitar Lanzador</div>
                <div class="text-xs text-gray-500">Acceso desde teclado y burbuja</div>
              </div>
            </div>
            <div class="w-10 h-5 bg-blue-500 rounded-full flex items-center justify-end px-1">
              <div class="w-4 h-4 bg-white rounded-full"></div>
            </div>
          </div>
          <div class="flex items-center justify-between p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-green-500 rounded-xl flex items-center justify-center text-white text-lg">📊</div>
              <div>
                <div class="text-sm font-bold text-gray-800 dark:text-white">Mostrar Frecuentes</div>
                <div class="text-xs text-gray-500">Top 5 apps más usadas</div>
              </div>
            </div>
            <div class="w-10 h-5 bg-blue-500 rounded-full flex items-center justify-end px-1">
              <div class="w-4 h-4 bg-white rounded-full"></div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3">
        <div class="text-center text-xs text-gray-400">
          <div class="mb-2">📱 Lanzador integrado en teclado</div>
          <div class="text-[10px]">Accede a cualquier app en 1 toque</div>
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
