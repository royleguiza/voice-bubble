#!/usr/bin/env node
// T17 · Enmarca las capturas de Play: lee docs/play/capturas/N.png (1–8) y
// escribe docs/play/capturas/marco-N.png (1080 × 1920) con la frase de cada una.
// Uso: NODE_PATH=<dir con playwright> node tools/release/framed_shots.js [es|en|pt]
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');
const PHRASES = {
  es: ['Dictá en *cualquier app*', 'Hablá y *aparece el texto*', 'Tus *notas* por voz', 'Dictá y leé *sin abrir la app*',
       'Tus respuestas *a un toque*', 'Hecho para *programar*', 'Hablá en tu idioma, *mandalo en el suyo*', 'Listo en *unos minutos*'],
  en: ['Dictate in *any app*', 'Speak and *the text appears*', 'Your *voice notes*', 'Dictate and read *without opening the app*',
       'Your replies *in one tap*', 'Made for *coding*', 'Speak your language, *send it in theirs*', 'Ready in *a few minutes*'],
  pt: ['Dite em *qualquer app*', 'Fale e *o texto aparece*', 'Suas *notas* por voz', 'Dite e leia *sem abrir o app*',
       'Suas respostas *com um toque*', 'Feito para *programar*', 'Fale no seu idioma, *envie no dele*', 'Pronto em *poucos minutos*'],
};
(async () => {
  const lang = process.argv[2] || 'es';
  const dir = path.join(__dirname, '../../docs/play');
  const exe = process.env.CHROME || undefined;
  const b = await chromium.launch(exe ? { executablePath: exe } : {});
  const p = await b.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
  for (let i = 1; i <= 8; i++) {
    const shot = path.join(dir, 'capturas', `${i}.png`);
    if (!fs.existsSync(shot)) continue;
    const url = 'file://' + path.join(dir, 'capturas.html') + `?img=capturas/${i}.png&t=` + encodeURIComponent(PHRASES[lang][i - 1]);
    await p.goto(url);
    await p.waitForTimeout(300);
    await p.locator('#frame').screenshot({ path: path.join(dir, 'capturas', `marco-${lang}-${i}.png`) });
  }
  await b.close();
})();
