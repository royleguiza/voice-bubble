const { chromium } = require('playwright');
const path = require('path');

(async () => {
    console.log('=== AUDITORIA BURBUJA LAB (PLAYWRIGHT) ===');
    const browser = await chromium.launch({ headless: true });
    const failed = [];
    const check = (name, cond, extra = '') => {
        console.log((cond ? '[PASS] ' : '[FAIL] ') + name + ' ' + extra);
        if (!cond) failed.push(name);
    };

    // ---- Desktop 1440 ----
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 950 } });
    const page = await ctx.newPage();
    const errs = [];
    page.on('pageerror', (e) => errs.push(String(e).split('\n')[0]));
    await page.goto('file://' + path.resolve(__dirname, 'burbuja_lab.html'), { waitUntil: 'load' });
    await page.waitForTimeout(600);

    check('sin errores JS al cargar', errs.length === 0, errs.join(' | '));
    check('burbuja visible', await page.locator('#bubble').isVisible());
    check('contrato de dirección presente', (await page.locator('body').innerHTML()).includes('THESIS:'));

    // Modal sup. der. -> crece izq+abajo
    await page.click('[data-preset="tr"]');
    await page.waitForTimeout(400);
    const bb0 = await page.locator('#bubble').boundingBox();
    // toque largo: pointer down 650ms sin mover
    const cx = bb0.x + bb0.width / 2, cy = bb0.y + bb0.height / 2;
    await page.mouse.move(cx, cy); await page.mouse.down(); await page.waitForTimeout(700); await page.mouse.up();
    await page.waitForTimeout(600);
    const mOpen = await page.locator('#histModal.open').count();
    check('toque largo abre modal (modo toques)', mOpen === 1);
    const mb = await page.locator('#histModal').boundingBox();
    const growsLeft = mb.x < bb0.x, growsDown = (mb.y + mb.height) > (bb0.y + bb0.height);
    check('modal sup.der crece izq.+abajo', growsLeft && growsDown, `bubble@(${Math.round(bb0.x)},${Math.round(bb0.y)}) modal@(${Math.round(mb.x)},${Math.round(mb.y)}) ${Math.round(mb.width)}x${Math.round(mb.height)}`);
    const logTxt = await page.locator('#eventLog').innerText();
    check('log informa dirección izq+abajo', /izq\+abajo/.test(logTxt));
    check('mic abajo-der + rayita presentes', await page.locator('#histMic').isVisible() && await page.locator('#histHandle').isVisible());
    check('sin títulos de texto en modal', ((await page.locator('#histModal').innerText()) || '').toLowerCase().indexOf('historial') === -1);
    await page.screenshot({ path: path.resolve(__dirname, '../.impeccable/review/burbuja-desktop-modal.png') });

    // Colapsar con rayita -> vuelve al origen
    await page.click('#histHandle');
    await page.waitForTimeout(600);
    const bb1 = await page.locator('#bubble').boundingBox();
    const backOk = Math.abs(bb1.x - bb0.x) < 3 && Math.abs(bb1.y - bb0.y) < 3;
    check('rayita contrae al punto de origen', backOk, `origen(${Math.round(bb0.x)},${Math.round(bb0.y)}) fin(${Math.round(bb1.x)},${Math.round(bb1.y)})`);

    // Media izq + teclado -> crece der+arriba
    await page.click('[data-preset="ml"]');
    if ((await page.locator('#kbToggle').getAttribute('aria-checked')) !== 'true') await page.click('#kbToggle');
    await page.waitForTimeout(500);
    const bb2 = await page.locator('#bubble').boundingBox();
    await page.mouse.move(bb2.x + 32, bb2.y + 32); await page.mouse.down(); await page.waitForTimeout(700); await page.mouse.up();
    await page.waitForTimeout(600);
    const mb2 = await page.locator('#histModal').boundingBox();
    check('modal media-izq+teclado crece der.+arriba', (mb2.x + mb2.width) > (bb2.x + bb2.width) && mb2.y < bb2.y, `bubble@(${Math.round(bb2.x)},${Math.round(bb2.y)}) modal@(${Math.round(mb2.x)},${Math.round(mb2.y)})`);
    await page.screenshot({ path: path.resolve(__dirname, '../.impeccable/review/burbuja-desktop-modal-kb.png') });

    // Copiar en card
    await page.locator('.hist-copy').first().click();
    await page.waitForTimeout(300);
    check('botón copiar pasa a done', await page.locator('.hist-copy.done').count() === 1);
    await page.click('#histHandle');
    await page.waitForTimeout(500);

    // Toque largo expande card (modal reabierta)
    await page.click('#btnHistory');
    await page.waitForTimeout(600);
    const card0 = page.locator('.hist-card').first();
    const cb0 = await card0.boundingBox();
    await page.mouse.move(cb0.x + 60, cb0.y + 20); await page.mouse.down(); await page.waitForTimeout(600); await page.mouse.up();
    await page.waitForTimeout(300);
    check('toque largo expande card', await card0.evaluate((e) => e.classList.contains('expanded')));
    // segundo toque largo la colapsa (el clic suelto del long-press no actúa)
    await page.mouse.move(cb0.x + 60, cb0.y + 20); await page.mouse.down(); await page.waitForTimeout(600); await page.mouse.up();
    await page.waitForTimeout(300);
    check('segundo toque largo colapsa card', await card0.evaluate((e) => !e.classList.contains('expanded')));

    // Deslizamiento lateral selecciona dos cards -> aparece copiar-todo abajo-izq
    check('copiar-todo oculto sin selección', await page.locator('#histCopyAll.show').count() === 0);
    const handleCenter = async () => {
      const m = await page.locator('#histModal').boundingBox();
      const h = await page.locator('#histHandle').boundingBox();
      return Math.abs((h.x + h.width / 2) - (m.x + m.width / 2));
    };
    check('rayita centrada sin botón copiar', (await handleCenter()) < 3);
    const cards = page.locator('.hist-card');
    for (const i of [1, 2]) {
      const b = await cards.nth(i).boundingBox();
      const sx = b.x + 60, sy = b.y + 20;
      await page.mouse.move(sx, sy); await page.mouse.down();
      for (let k = 1; k <= 8; k++) { await page.mouse.move(sx + k * 9, sy); await page.waitForTimeout(15); }
      await page.mouse.up(); await page.waitForTimeout(350);
    }
    check('deslizamiento selecciona 2 cards', await page.locator('.hist-card.selected').count() === 2);
    check('copiar-todo visible con 2+', await page.locator('#histCopyAll.show').count() === 1);
    check('rayita sigue centrada con botón copiar', (await handleCenter()) < 3);
    const micB = await page.locator('#histMic').boundingBox();
    const allB = await page.locator('#histCopyAll').boundingBox();
    check('copiar-todo opuesto al mic (izq vs der)', allB.x < micB.x);
    await page.locator('#histCopyAll').click();
    await page.waitForTimeout(300);
    check('copiar-todo confirma en done', await page.locator('#histCopyAll.done').count() === 1);
    await page.waitForTimeout(1200);
    check('tras copiar se limpia selección', await page.locator('.hist-card.selected').count() === 0 && await page.locator('#histCopyAll.show').count() === 0);
    await page.click('#histHandle');
    await page.waitForTimeout(500);

    // Grabación tap-tap
    await page.locator('#bubble').click();
    await page.waitForTimeout(400);
    check('tap inicia grabación', await page.locator('#bubble.is-recording').count() === 1);
    await page.locator('#bubble').click();
    await page.waitForTimeout(400);
    check('segundo tap pasa a transcribir', await page.locator('#bubble.is-transcribing').count() === 1);
    await page.waitForTimeout(1800);

    // ---- Mobile 390 ----
    const ctx2 = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
    const m = await ctx2.newPage();
    const merrs = [];
    m.on('pageerror', (e) => merrs.push(String(e).split('\n')[0]));
    await m.goto('file://' + path.resolve(__dirname, 'burbuja_lab.html'), { waitUntil: 'load' });
    await m.waitForTimeout(600);
    check('móvil: sin errores JS', merrs.length === 0, merrs.join(' | '));
    check('móvil: teléfono cabe (sin scroll-x)', await m.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1));
    await m.screenshot({ path: path.resolve(__dirname, '../.impeccable/review/burbuja-mobile.png') });
    // tap largo táctil abre modal
    const bbm = await m.locator('#bubble').boundingBox();
    await m.touchscreen.tap(bbm.x + 32, bbm.y + 32); // tap = grabar en modo toques
    await m.waitForTimeout(300);
    check('móvil: tap inicia grabación', await m.locator('#bubble.is-recording').count() === 1);

    await browser.close();
    console.log(failed.length ? `\nRESULTADO: ${failed.length} FALLOS` : '\nRESULTADO: TODO PASS');
    process.exit(failed.length ? 1 : 0);
})().catch((e) => { console.error('FATAL', e); process.exit(2); });
