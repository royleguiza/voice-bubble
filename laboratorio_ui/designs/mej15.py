"""MEJ-15: Temas Visuales y Paleta Arcoíris"""
VARIANTS = [
    {
        "id": "Themes 1",
        "name": "Selector de Temas Globales",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Temas Visuales</div>
        <div class="grid grid-cols-2 gap-2">
          <div class="p-3 bg-gradient-to-br from-gray-100 to-gray-200 rounded-xl border-2 border-blue-500">
            <div class="text-xs font-bold text-gray-800">Liquid Glass</div>
            <div class="text-[10px] text-gray-500">Default</div>
          </div>
          <div class="p-3 bg-black rounded-xl">
            <div class="text-xs font-bold text-white">OLED Negro</div>
            <div class="text-[10px] text-gray-400">AMOLED</div>
          </div>
          <div class="p-3 bg-gradient-to-br from-cyan-500 to-purple-500 rounded-xl">
            <div class="text-xs font-bold text-white">Neón Cyberpunk</div>
            <div class="text-[10px] text-cyan-200">Futurista</div>
          </div>
          <div class="p-3 bg-black rounded-xl border border-green-500">
            <div class="text-xs font-bold text-green-400">Terminal Matrix</div>
            <div class="text-[10px] text-green-300">Hacker</div>
          </div>
        </div>
      </div>
      <div class="bg-[#1a1a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-700 p-2">
        <div class="grid grid-cols-10 gap-1 text-center text-xs">
          <div class="py-2 bg-red-500 rounded-lg font-bold text-white shadow-sm">q</div>
          <div class="py-2 bg-orange-500 rounded-lg font-bold text-white shadow-sm">w</div>
          <div class="py-2 bg-yellow-500 rounded-lg font-bold text-white shadow-sm">e</div>
          <div class="py-2 bg-green-500 rounded-lg font-bold text-white shadow-sm">r</div>
          <div class="py-2 bg-blue-500 rounded-lg font-bold text-white shadow-sm">t</div>
          <div class="py-2 bg-indigo-500 rounded-lg font-bold text-white shadow-sm">y</div>
          <div class="py-2 bg-purple-500 rounded-lg font-bold text-white shadow-sm">u</div>
          <div class="py-2 bg-pink-500 rounded-lg font-bold text-white shadow-sm">i</div>
          <div class="py-2 bg-red-400 rounded-lg font-bold text-white shadow-sm">o</div>
          <div class="py-2 bg-orange-400 rounded-lg font-bold text-white shadow-sm">p</div>
        </div>
        <div class="flex gap-1 mt-1">
          <div class="flex-1 py-2 bg-gradient-to-r from-red-500 to-orange-500 rounded-lg font-bold text-white text-xs">⇧</div>
          <div class="flex-[5] py-2 bg-gradient-to-r from-green-500 to-blue-500 rounded-lg text-white text-xs">espacio</div>
          <div class="flex-1 py-2 bg-gradient-to-r from-indigo-500 to-purple-500 rounded-lg font-bold text-white text-xs">↵</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Pick 2",
        "name": "Selector de Color Tecla por Tecla",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Personalizar Tecla</div>
        <div class="mb-3">
          <div class="text-xs text-gray-500 mb-2">Seleccionar Tecla</div>
          <div class="flex gap-1 flex-wrap">
            <div class="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-lg flex items-center justify-center text-xs text-gray-800 dark:text-white">q</div>
            <div class="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-lg flex items-center justify-center text-xs text-gray-800 dark:text-white">w</div>
            <div class="w-8 h-8 bg-blue-500 rounded-lg flex items-center justify-center text-xs text-white font-bold border-2 border-blue-300">e</div>
            <div class="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-lg flex items-center justify-center text-xs text-gray-800 dark:text-white">r</div>
            <div class="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-lg flex items-center justify-center text-xs text-gray-800 dark:text-white">t</div>
          </div>
        </div>
        <div class="mb-3">
          <div class="text-xs text-gray-500 mb-2">Color de Fondo</div>
          <div class="flex gap-2">
            <div class="w-8 h-8 bg-red-500 rounded-full border-2 border-white shadow"></div>
            <div class="w-8 h-8 bg-orange-500 rounded-full border-2 border-white shadow"></div>
            <div class="w-8 h-8 bg-yellow-500 rounded-full border-2 border-white shadow"></div>
            <div class="w-8 h-8 bg-green-500 rounded-full border-2 border-white shadow"></div>
            <div class="w-8 h-8 bg-blue-500 rounded-full border-2 border-blue-300 shadow"></div>
            <div class="w-8 h-8 bg-purple-500 rounded-full border-2 border-white shadow"></div>
          </div>
        </div>
        <div>
          <div class="text-xs text-gray-500 mb-2">Color de Texto</div>
          <div class="flex gap-2">
            <div class="w-6 h-6 bg-white rounded-full border-2 border-gray-300 shadow"></div>
            <div class="w-6 h-6 bg-black rounded-full border-2 border-gray-300 shadow"></div>
            <div class="w-6 h-6 bg-gray-400 rounded-full border-2 border-gray-300 shadow"></div>
          </div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 flex items-center justify-center">
        <div class="w-16 h-16 bg-blue-500 rounded-2xl flex items-center justify-center text-white text-2xl font-bold shadow-lg shadow-blue-500/30 border-2 border-blue-300">e</div>
      </div>
    </div>"""
    },
    {
        "id": "Neon 3",
        "name": "Vista Previa Neón y Matrix",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-[#0a0a0a]/95 backdrop-blur-xl rounded-2xl border border-cyan-500/50 p-4 mb-3 shadow-lg shadow-cyan-500/20">
        <div class="text-sm font-bold text-cyan-400 mb-3">Tema Neón Cyberpunk</div>
        <div class="grid grid-cols-5 gap-1 text-center text-xs">
          <div class="py-2 bg-transparent rounded-lg font-bold text-cyan-400 border border-cyan-500/50 shadow-[0_0_10px_rgba(0,255,255,0.3)]">q</div>
          <div class="py-2 bg-transparent rounded-lg font-bold text-cyan-400 border border-cyan-500/50 shadow-[0_0_10px_rgba(0,255,255,0.3)]">w</div>
          <div class="py-2 bg-transparent rounded-lg font-bold text-cyan-400 border border-cyan-500/50 shadow-[0_0_10px_rgba(0,255,255,0.3)]">e</div>
          <div class="py-2 bg-transparent rounded-lg font-bold text-cyan-400 border border-cyan-500/50 shadow-[0_0_10px_rgba(0,255,255,0.3)]">r</div>
          <div class="py-2 bg-transparent rounded-lg font-bold text-cyan-400 border border-cyan-500/50 shadow-[0_0_10px_rgba(0,255,255,0.3)]">t</div>
        </div>
        <div class="flex gap-1 mt-1">
          <div class="flex-1 py-2 bg-transparent rounded-lg font-bold text-pink-400 border border-pink-500/50 shadow-[0_0_10px_rgba(255,0,255,0.3)] text-xs">⇧</div>
          <div class="flex-[5] py-2 bg-transparent rounded-lg text-cyan-400 text-xs border border-cyan-500/50 shadow-[0_0_10px_rgba(0,255,255,0.3)]">espacio</div>
          <div class="flex-1 py-2 bg-transparent rounded-lg font-bold text-purple-400 border border-purple-500/50 shadow-[0_0_10px_rgba(128,0,255,0.3)] text-xs">↵</div>
        </div>
      </div>
      <div class="bg-[#000a00]/95 backdrop-blur-xl rounded-2xl border border-green-500/50 p-4 shadow-lg shadow-green-500/20">
        <div class="text-sm font-bold text-green-400 mb-3">Tema Terminal Matrix</div>
        <div class="grid grid-cols-5 gap-1 text-center text-xs">
          <div class="py-2 bg-transparent rounded-lg font-bold text-green-400 border border-green-500/30">q</div>
          <div class="py-2 bg-transparent rounded-lg font-bold text-green-400 border border-green-500/30">w</div>
          <div class="py-2 bg-transparent rounded-lg font-bold text-green-400 border border-green-500/30">e</div>
          <div class="py-2 bg-transparent rounded-lg font-bold text-green-400 border border-green-500/30">r</div>
          <div class="py-2 bg-transparent rounded-lg font-bold text-green-400 border border-green-500/30">t</div>
        </div>
        <div class="flex gap-1 mt-1">
          <div class="flex-1 py-2 bg-transparent rounded-lg font-bold text-green-300 border border-green-500/30 text-xs">⇧</div>
          <div class="flex-[5] py-2 bg-transparent rounded-lg text-green-400 text-xs border border-green-500/30">espacio</div>
          <div class="flex-1 py-2 bg-transparent rounded-lg font-bold text-green-300 border border-green-500/30 text-xs">↵</div>
        </div>
      </div>
    </div>"""
    }
]
