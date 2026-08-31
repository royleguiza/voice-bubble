"""MEJ-04: Layouts Código/Termux"""
VARIANTS = [
    {
        "id": "Termux 1",
        "name": "Preset Termux / CLI",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-[#1e1e2e]/95 backdrop-blur-xl rounded-2xl border border-gray-700 p-3 mb-3">
        <div class="flex items-center gap-2 mb-2">
          <div class="w-3 h-3 rounded-full bg-red-500"></div>
          <div class="w-3 h-3 rounded-full bg-yellow-500"></div>
          <div class="w-3 h-3 rounded-full bg-green-500"></div>
          <span class="text-xs text-gray-400 ml-2">Termux</span>
        </div>
        <div class="font-mono text-xs text-green-400">$ <span class="text-white">ls -la</span></div>
        <div class="font-mono text-xs text-gray-300">total 48</div>
        <div class="font-mono text-xs text-gray-300">drwxr-xr-x 12 roy users 4096</div>
      </div>
      <div class="bg-[#1e1e2e]/90 backdrop-blur-xl rounded-2xl border border-gray-700 p-2 flex-1">
        <div class="flex items-center justify-between mb-2 px-2">
          <span class="text-xs font-bold text-cyan-400">TERMUX LAYOUT</span>
          <span class="text-xs text-gray-500">Ctrl Alt Tab</span>
        </div>
        <div class="grid grid-cols-7 gap-1 text-center text-xs">
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">Ctrl</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">Alt</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">Tab</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">Esc</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">~</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">|</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">-</div>
        </div>
        <div class="grid grid-cols-5 gap-1 mt-1 text-center text-xs">
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">←</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">↑</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">↓</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-cyan-400 border border-cyan-800">→</div>
          <div class="py-2 bg-blue-500 rounded-lg font-bold text-white">↵</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "WebJS 2",
        "name": "Preset Web / JavaScript",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-[#1e1e2e]/95 backdrop-blur-xl rounded-2xl border border-gray-700 p-3 mb-3">
        <div class="font-mono text-xs">
          <div class="text-purple-400">import</div>
          <div class="text-blue-300">{'{'}<span class="text-white"> useState </span>{'}'}</div>
          <div class="text-purple-400">from</div>
          <div class="text-green-400">'react'</div>
          <div class="text-gray-500 mt-2">// Component</div>
          <div class="text-blue-300">const</div>
          <div class="text-yellow-300">App</div>
          <div class="text-white">= () =&gt; {'{'}</div>
        </div>
      </div>
      <div class="bg-[#1e1e2e]/90 backdrop-blur-xl rounded-2xl border border-gray-700 p-2 flex-1">
        <div class="flex items-center justify-between mb-2 px-2">
          <span class="text-xs font-bold text-yellow-400">WEB / JS PRESET</span>
          <span class="text-xs text-gray-500">=&gt; === &amp;&amp; ||</span>
        </div>
        <div class="grid grid-cols-6 gap-1 text-center text-xs">
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">=&gt;</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">===</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">&amp;&amp;</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">||</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">{'{'}</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">{'}'}</div>
        </div>
        <div class="grid grid-cols-6 gap-1 mt-1 text-center text-xs">
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">$</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">?</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">!</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">;</div>
          <div class="py-2 bg-[#2a2a3e] rounded-lg font-mono text-yellow-400 border border-yellow-800">:</div>
          <div class="py-2 bg-blue-500 rounded-lg font-bold text-white">↵</div>
        </div>
      </div>
    </div>"""
    },
    {
        "id": "Presets 3",
        "name": "Selector de Presets",
        "html": """<div class="absolute inset-0 bg-gradient-to-b from-gray-100 to-gray-200 dark:from-[#0a0f18] dark:to-[#111827] p-4 flex flex-col">
      <div class="flex justify-between items-center px-2 py-1 text-xs text-gray-600 dark:text-gray-400 mb-3">
        <span class="font-semibold">9:41</span>
        <div class="flex gap-1"><div class="w-4 h-2 bg-current rounded-sm"></div><div class="w-3 h-2 bg-current rounded-sm"></div></div>
      </div>
      <div class="bg-white/90 dark:bg-[#1c2333]/90 backdrop-blur-xl rounded-2xl border border-gray-200 dark:border-gray-700 p-4 mb-3">
        <div class="text-sm font-bold text-gray-800 dark:text-white mb-3">Configurar Preset</div>
        <div class="space-y-2">
          <div class="flex items-center justify-between p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-blue-500 rounded-xl flex items-center justify-center text-white text-lg">&lt;/&gt;</div>
              <div>
                <div class="text-sm font-bold text-gray-800 dark:text-white">Código Estándar</div>
                <div class="text-xs text-gray-500">{'{ } [ ] ( ) < > ; :'}</div>
              </div>
            </div>
            <div class="w-6 h-6 bg-blue-500 rounded-full flex items-center justify-center">
              <svg class="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>
            </div>
          </div>
          <div class="flex items-center justify-between p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-cyan-500 rounded-xl flex items-center justify-center text-white text-lg">$</div>
              <div>
                <div class="text-sm font-bold text-gray-800 dark:text-white">Termux / CLI</div>
                <div class="text-xs text-gray-500">Ctrl Alt Tab Esc ~ |</div>
              </div>
            </div>
            <div class="w-6 h-6 bg-gray-300 dark:bg-gray-600 rounded-full"></div>
          </div>
          <div class="flex items-center justify-between p-3 bg-gray-100 dark:bg-gray-800 rounded-xl">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 bg-yellow-500 rounded-xl flex items-center justify-center text-white text-lg">{ }</div>
              <div>
                <div class="text-sm font-bold text-gray-800 dark:text-white">Web / JavaScript</div>
                <div class="text-xs text-gray-500">=&gt; === &amp;&amp; || $ ?</div>
              </div>
            </div>
            <div class="w-6 h-6 bg-gray-300 dark:bg-gray-600 rounded-full"></div>
          </div>
        </div>
      </div>
      <div class="bg-gray-200/90 dark:bg-[#2a2a2e]/90 backdrop-blur-xl rounded-2xl border border-gray-300 dark:border-gray-600 p-2">
        <div class="grid grid-cols-7 gap-1 text-center text-xs">
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-mono text-gray-800 dark:text-white shadow-sm">q</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-mono text-gray-800 dark:text-white shadow-sm">w</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-mono text-gray-800 dark:text-white shadow-sm">e</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-mono text-gray-800 dark:text-white shadow-sm">r</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-mono text-gray-800 dark:text-white shadow-sm">t</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-mono text-gray-800 dark:text-white shadow-sm">y</div>
          <div class="py-2 bg-white dark:bg-gray-700 rounded-lg font-mono text-gray-800 dark:text-white shadow-sm">u</div>
        </div>
      </div>
    </div>"""
    }
]
