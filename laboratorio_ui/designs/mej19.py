"""MEJ-19: Numpad Dedicado"""
VARIANTS = [
    {
        "id": "Numpad 1",
        "name": "Numpad Calculadora / Contable",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Transferencia Bancaria</div>
        <div class="space-y-3">
          <div>
            <div class="text-xs text-gray-500 mb-1">Monto</div>
            <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl border-2 border-blue-500">
              <div class="text-lg font-bold text-gray-800 dark:text-white">$ 1,250.00</div>
            </div>
          </div>
          <div>
            <div class="text-xs text-gray-500 mb-1">Cuenta Destino</div>
            <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
              <div class="text-sm text-gray-800 dark:text-white">**** **** **** 4928</div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2">
        <div class="grid grid-cols-4 gap-1 text-center text-xs">
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">7</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">8</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">9</div>
          <div class="py-3 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">⌫</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">4</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">5</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">6</div>
          <div class="py-3 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">/</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">1</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">2</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">3</div>
          <div class="py-3 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">*</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">,</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">0</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">00</div>
          <div class="py-3 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm">+</div>
        </div>
        <div class="flex gap-1 mt-1">
          <div class="flex-1 py-3 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
          <div class="flex-1 py-3 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white text-xs">-</div>
          <div class="flex-1 py-3 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white text-xs">ABC</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Auto 2",
        "name": "Auto-Detección de Campo Numérico",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Auto-Detección Inteligente</div>
        <div class="space-y-2">
          <div class="p-3 bg-blue-50 dark:bg-blue-900/30 rounded-xl border-2 border-blue-500">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-blue-500 rounded-xl flex items-center justify-center text-white text-lg">#</div>
              <div>
                <div class="text-sm font-bold text-blue-600 dark:text-blue-400">Campo Numérico</div>
                <div class="text-xs text-blue-400">TYPE_CLASS_NUMBER</div>
              </div>
            </div>
          </div>
          <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-gray-300 dark:bg-gray-600 rounded-xl flex items-center justify-center text-gray-600 dark:text-gray-400 text-lg">📞</div>
              <div>
                <div class="text-sm font-bold text-gray-600 dark:text-gray-400">Campo Teléfono</div>
                <div class="text-xs text-gray-400">TYPE_CLASS_PHONE</div>
              </div>
            </div>
          </div>
        </div>
        <div class="mt-3 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-xl border border-blue-300 dark:border-blue-700">
          <div class="text-xs text-blue-600 dark:text-blue-400">💡 Al enfocar un campo numérico, el Numpad se abre automáticamente</div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2">
        <div class="grid grid-cols-3 gap-1 text-center text-xs">
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">7</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">8</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">9</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">4</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">5</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">6</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">1</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">2</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">3</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">.</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">0</div>
          <div class="py-3 bg-blue-500 rounded-lg font-bold text-white shadow-sm text-lg">↵</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Phone 3",
        "name": "Estilo Teléfono / Marcador",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-xs font-bold text-gray-500 dark:text-gray-400 mb-3">Configurar Numpad</div>
        <div class="space-y-2">
          <div class="p-3 bg-blue-100 dark:bg-blue-900/30 rounded-xl border-2 border-blue-500">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-blue-600 dark:text-blue-400">Calculadora / Contable</div>
                <div class="text-[10px] text-blue-400">7-8-9 arriba, 1-2-3 abajo</div>
              </div>
              <div class="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center">
                <svg class="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>
              </div>
            </div>
          </div>
          <div class="p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center justify-between">
              <div>
                <div class="text-xs font-bold text-gray-600 dark:text-gray-400">Teléfono / Marcador</div>
                <div class="text-[10px] text-gray-400">1-2-3 arriba, 7-8-9 abajo</div>
              </div>
              <div class="w-6 h-6 bg-gray-300 dark:bg-gray-600 rounded-full"></div>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2">
        <div class="grid grid-cols-3 gap-1 text-center text-xs">
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">1</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">2</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">3</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">4</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">5</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">6</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">7</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">8</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">9</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">*</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">0</div>
          <div class="py-3 bg-white dark:bg-gray-700 rounded-lg font-bold text-gray-800 dark:text-white shadow-sm text-lg">#</div>
        </div>
        <div class="flex gap-1 mt-1">
          <div class="flex-1 py-3 bg-blue-500 rounded-lg font-bold text-white text-xs">↵</div>
          <div class="flex-1 py-3 bg-gray-300 dark:bg-gray-600 rounded-lg font-bold text-gray-800 dark:text-white text-xs">ABC</div>
        </div>
      </div>
    </div>"""
    }
]
