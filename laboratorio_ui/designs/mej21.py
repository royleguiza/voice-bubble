"""MEJ-21: Bloc de Notas de Voz"""
VARIANTS = [
    {
        "id": "Draft 1",
        "name": "Borrador Flotante Aislado",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-sm font-bold text-gray-800 dark:text-white">📝 Bloc de Notas</div>
          <div class="flex items-center gap-2">
            <div class="px-2 py-1 bg-blue-500 rounded-lg text-white text-xs">🎤 Dictar</div>
            <div class="w-6 h-6 bg-gray-200 dark:bg-gray-700 rounded-full flex items-center justify-center text-gray-500 text-xs">✕</div>
          </div>
        </div>
        <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl min-h-[100px] mb-3">
          <div class="text-xs text-gray-800 dark:text-white">Reunión 3pm: discutir roadmap Q4 del proyecto VoiceBubble. Prioridades: teclado nativo, burbuja flotante, y transcripción en tiempo real.</div>
          <div class="text-xs text-gray-400 mt-2">|</div>
        </div>
        <div class="flex gap-2">
          <div class="flex-1 py-2 bg-blue-500 rounded-xl text-white text-xs font-bold text-center">💾 Guardar</div>
          <div class="flex-1 py-2 bg-gray-200 dark:bg-gray-700 rounded-xl text-gray-800 dark:text-white text-xs font-bold text-center">📋 Copiar</div>
          <div class="flex-1 py-2 bg-green-500 rounded-xl text-white text-xs font-bold text-center">↵ Insertar</div>
          <div class="w-10 py-2 bg-red-100 dark:bg-red-900/30 rounded-xl text-red-500 text-xs font-bold text-center">🗑️</div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-2">Notas Guardadas (3/10)</div>
        <div class="space-y-2">
          <div class="p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="text-xs text-gray-800 dark:text-white">Lista de compras: leche, pan, huevos</div>
            <div class="text-[10px] text-gray-400">Guardado hace 2h</div>
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
        "id": "Dictate 2",
        "name": "Dictado Directo a la Nota",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-blue-500 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-sm font-bold text-gray-800 dark:text-white">📝 Dictando...</div>
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div>
            <div class="text-xs text-red-500 font-bold">0:05</div>
          </div>
        </div>
        <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl min-h-[100px] mb-3">
          <div class="text-xs text-gray-800 dark:text-white">Necesito comprar leche para el café de mañana...</div>
          <div class="text-xs text-blue-400 mt-2 animate-pulse">|</div>
        </div>
        <div class="flex gap-2">
          <div class="flex-1 py-2 bg-red-500 rounded-xl text-white text-xs font-bold text-center">⏹ Detener</div>
          <div class="flex-1 py-2 bg-gray-200 dark:bg-gray-700 rounded-xl text-gray-800 dark:text-white text-xs font-bold text-center">💾 Guardar</div>
          <div class="flex-1 py-2 bg-gray-200 dark:bg-gray-700 rounded-xl text-gray-800 dark:text-white text-xs font-bold text-center">📋 Copiar</div>
        </div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-2">Notas Guardadas (2/10)</div>
        <div class="space-y-2">
          <div class="p-2 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="text-xs text-gray-800 dark:text-white">Reunión 3pm: roadmap Q4</div>
            <div class="text-[10px] text-gray-400">Guardado hace 1h</div>
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
        "id": "Sandbox 3",
        "name": "Aislamiento Total del Sandbox",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-3 mb-3">
        <div class="text-xs text-gray-800 dark:text-white">Hola, estoy en el chat de Telegram escribiendo...</div>
      </div>
      <div class="bg-yellow-100 dark:bg-yellow-900/30 rounded-xl p-2 mb-3 border border-yellow-300 dark:border-yellow-700">
        <div class="flex items-center gap-2">
          <div class="w-6 h-6 bg-yellow-500 rounded-full flex items-center justify-center">
            <span class="text-white text-xs">⚠</span>
          </div>
          <div class="text-xs text-yellow-600 dark:text-yellow-400 font-bold">Sandbox Aislado - No se envía al chat</div>
        </div>
      </div>
      <div class="bg-white/95 dark:bg-[#1c2333]/95 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3 shadow-2xl">
        <div class="flex items-center justify-between mb-3">
          <div class="text-sm font-bold text-gray-800 dark:text-white">📝 Borrador</div>
          <div class="flex items-center gap-2">
            <div class="px-2 py-1 bg-blue-500 rounded-lg text-white text-xs">🎤 Dictar</div>
          </div>
        </div>
        <div class="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl min-h-[80px] mb-3">
          <div class="text-xs text-gray-800 dark:text-white">Ideas para el proyecto: implementar teclado nativo con soporte para snippets y dictado por voz.</div>
        </div>
        <div class="flex gap-2">
          <div class="flex-1 py-2 bg-blue-500 rounded-xl text-white text-xs font-bold text-center">💾 Guardar</div>
          <div class="flex-1 py-2 bg-green-500 rounded-xl text-white text-xs font-bold text-center">↵ Insertar</div>
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
