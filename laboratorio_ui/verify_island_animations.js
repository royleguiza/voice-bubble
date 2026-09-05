const { chromium } = require('playwright');
const path = require('path');

(async () => {
    console.log('=== AUDITORÍA Y CONTROL DE ANIMACIONES DE LA PÍLDORA FLOTANTE (PLAYWRIGHT) ===');
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
        viewport: { width: 1280, height: 900 }
    });
    const page = await context.newPage();

    const filePath = 'file://' + path.resolve(__dirname, 'trackpad_lab.html');
    await page.goto(filePath, { waitUntil: 'load' });

    const auditResults = {
        passed: [],
        failed: [],
        measurements: {}
    };

    function check(name, condition, details = '') {
        if (condition) {
            console.log(`[PASS] ${name} ${details}`);
            auditResults.passed.push({ name, details });
        } else {
            console.error(`[FAIL] ${name} ${details}`);
            auditResults.failed.push({ name, details });
        }
    }

    // 1. ANÁLISIS DE CSS Y TRANSICIONES DE LA PÍLDORA EN REPOSO
    console.log('\n--- 1. Especificaciones de la Píldora en Reposo ---');
    const pill = page.locator('#dynamicIsland');
    const pillStyles = await pill.evaluate(el => {
        const style = window.getComputedStyle(el);
        const box = el.getBoundingClientRect();
        return {
            width: style.width,
            height: style.height,
            boxW: Math.round(box.width),
            boxH: Math.round(box.height),
            borderRadius: style.borderRadius,
            transitionDuration: style.transitionDuration,
            transitionTimingFunction: style.transitionTimingFunction,
            transitionProperty: style.transitionProperty,
            display: style.display,
            alignItems: style.alignItems,
            justifyContent: style.justifyContent
        };
    });

    auditResults.measurements.pillRestStyles = pillStyles;

    check('Dimensiones base de píldora compacta (184px x 36px)', 
        pillStyles.boxW === 184 && pillStyles.boxH === 36,
        `Recibido: ${pillStyles.boxW}px x ${pillStyles.boxH}px`);

    check('Border-radius píldora compacta (18px = pill shape)',
        pillStyles.borderRadius === '18px',
        `Recibido: ${pillStyles.borderRadius}`);

    check('Curva de aceleración definida (cubic-bezier 0.16, 1, 0.3, 1)',
        pillStyles.transitionTimingFunction.includes('cubic-bezier(0.16, 1, 0.3, 1)'),
        `Timing function: ${pillStyles.transitionTimingFunction}`);

    check('Duración de transición fluida de 420ms (0.42s)',
        pillStyles.transitionDuration.includes('0.42s'),
        `Duración: ${pillStyles.transitionDuration}`);

    // 2. ELEMENTOS Y SLOTS DE LA PÍLDORA
    console.log('\n--- 2. Elementos Internos de la Píldora (Slots & Punch Central) ---');
    const slotLeft = page.locator('#islandSlotLeft');
    const slotRight = page.locator('#islandSlotRight');
    const camCutout = page.locator('#islandCamCutout');
    const trackpadBtn = page.locator('#islandTrackpadBtn');
    const micBtn = page.locator('#islandMicBtn');

    const leftBtnTag = await slotLeft.locator('button').first().getAttribute('id');
    const rightBtnTag = await slotRight.locator('button').first().getAttribute('id');
    const trackpadColor = await trackpadBtn.evaluate(el => window.getComputedStyle(el).color);
    const micColor = await micBtn.evaluate(el => window.getComputedStyle(el).color);

    check('Ranura izquierda contiene botón de Trackpad (#islandTrackpadBtn)', leftBtnTag === 'islandTrackpadBtn');
    check('Ranura derecha contiene botón de Micrófono (#islandMicBtn)', rightBtnTag === 'islandMicBtn');
    check('Color distintivo Trackpad (#58a6ff / rgb(88, 166, 255))', trackpadColor.includes('88, 166, 255'));
    check('Color distintivo Micrófono (#ff453a / rgb(255, 69, 58))', micColor.includes('255, 69, 58'));

    // 3. TRANSICIÓN A MODO GRABACIÓN (MORPHING EXPANSION)
    console.log('\n--- 3. Animación de Expansión a Modo Grabación ---');
    await micBtn.click();
    await page.waitForTimeout(700);

    const recStyles = await pill.evaluate(el => {
        const s = window.getComputedStyle(el);
        const box = el.getBoundingClientRect();
        return {
            boxW: Math.round(box.width),
            boxH: Math.round(box.height),
            borderRadius: s.borderRadius
        };
    });
    check('Píldora expande a 330px x 48px con r=24px',
        recStyles.boxW === 330 && recStyles.boxH === 48 && recStyles.borderRadius === '24px',
        `Recibido: ${recStyles.boxW}px x ${recStyles.boxH}px, r=${recStyles.borderRadius}`);

    // 4. ANIMACIÓN Y ESTRUCTURA DEL WAVEFORM VISUALIZER
    console.log('\n--- 4. Visualizador de Onda Reactivo (9 Wave Bars) ---');
    const waveBars = page.locator('.waveform-visualizer .wave-bar');
    const waveCount = await waveBars.count();
    check('El visualizador de onda contiene exactamente 9 barras reactivas', waveCount === 9, `Recibido: ${waveCount}`);

    const waveAnimations = await waveBars.evaluateAll(bars => {
        return bars.map((b, idx) => {
            const s = window.getComputedStyle(b);
            return {
                idx,
                speaking: b.classList.contains('speaking'),
                animationName: s.animationName,
                animationDuration: s.animationDuration,
                animationDelay: s.animationDelay,
                backgroundColor: s.backgroundColor,
                width: s.width
            };
        });
    });

    const allSpeaking = waveAnimations.every(w => w.speaking && w.animationName === 'audioWaveform');
    const distinctDelays = new Set(waveAnimations.map(w => w.animationDelay)).size;
    check('Todas las barras ejecutan animación @keyframes audioWaveform de 0.7s', allSpeaking,
        `Animación: ${waveAnimations[0]?.animationName} (${waveAnimations[0]?.animationDuration})`);
    check('Delays desfasados (staggered delay) para efecto de onda orgánico', distinctDelays >= 7,
        `Delays encontrados: ${distinctDelays} variaciones`);

    const hasFinishBtn = await page.locator('.rec-action-btn.finish').isVisible();
    const hasCancelBtn = await page.locator('.rec-action-btn.cancel').isVisible();
    const hasTimer = await page.locator('#recTimerText').isVisible();
    check('Botón de finalización [✓] visible en modo grabación', hasFinishBtn);
    check('Botón de cancelación [✕] visible en modo grabación', hasCancelBtn);
    check('Cronómetro M:SS visible en modo grabación', hasTimer);

    // Cancelar grabación
    await page.click('.rec-action-btn.cancel');
    await page.waitForTimeout(500);

    // 5. EXPANDIR HISTORIAL: GLIDE DE SLOTS A LAS ESQUINAS INFERIORES Y FADE DEL CENTRO
    console.log('\n--- 5. Morphing a Historial: Desplazamiento de Ranuras a Esquinas ---');
    await page.click('#islandCamCutout');
    await page.waitForTimeout(500);

    const historyState = await page.evaluate(() => {
        const island = document.getElementById('dynamicIsland');
        const slotL = document.getElementById('islandSlotLeft');
        const slotR = document.getElementById('islandSlotRight');
        const cam = document.getElementById('islandCamCutout');
        const iBox = island.getBoundingClientRect();
        const iStyle = window.getComputedStyle(island);
        const lStyle = window.getComputedStyle(slotL);
        const rStyle = window.getComputedStyle(slotR);
        const cStyle = window.getComputedStyle(cam);

        return {
            boxW: Math.round(iBox.width),
            boxH: Math.round(iBox.height),
            islandRadius: iStyle.borderRadius,
            slotLeftDisplay: lStyle.display,
            slotLeftTop: lStyle.top,
            slotLeftPos: lStyle.position,
            slotRightDisplay: rStyle.display,
            slotRightTop: rStyle.top,
            slotRightPos: rStyle.position,
            camOpacity: cStyle.opacity,
            camPointerEvents: cStyle.pointerEvents
        };
    });

    check('Modal de historial expande a ~340px x 230px con r=28px',
        historyState.boxW === 340 && historyState.boxH === 230 && historyState.islandRadius === '28px',
        `Recibido: ${historyState.boxW}px x ${historyState.boxH}px`);

    check('Ranura izquierda NO se destruye ni oculta con none',
        historyState.slotLeftDisplay !== 'none',
        `display: ${historyState.slotLeftDisplay}`);

    check('Ranura derecha NO se destruye ni oculta con none',
        historyState.slotRightDisplay !== 'none',
        `display: ${historyState.slotRightDisplay}`);

    check('Las ranuras se deslizan a la base de la tarjeta (top ~ 184px = 100% - 46px)',
        parseInt(historyState.slotLeftTop) > 170 && parseInt(historyState.slotRightTop) > 170,
        `Posición top: L=${historyState.slotLeftTop}, R=${historyState.slotRightTop}`);

    check('Orificio central de cámara se desvanece con opacidad 0 y pointer-events none',
        historyState.camOpacity === '0' && historyState.camPointerEvents === 'none',
        `opacity: ${historyState.camOpacity}`);

    const dragHandle = page.locator('#historyDragHandle');
    const hasDragHandle = await dragHandle.isVisible();
    check('Rayita drag handle inferior visible para control gestual', hasDragHandle);

    await page.evaluate(() => toggleHistoryExtend50());
    await page.waitForTimeout(500);
    const extBoxH = await pill.evaluate(el => Math.round(el.getBoundingClientRect().height));
    check('Modo extendido al 50% alcanza 380px de altura vertical', extBoxH === 380, `Recibido: ${extBoxH}px`);

    await page.click('#historyBottomBarArea');
    await page.waitForTimeout(500);

    const isCollapsed = await pill.evaluate(el => {
        const box = el.getBoundingClientRect();
        return Math.round(box.height) === 36 && Math.round(box.width) === 184;
    });
    check('Píldora colapsa limpiamente de regreso a 184px x 36px', isCollapsed);

    // 6. ADAPTABILIDAD A LOS BORDES DE LA PANTALLA (BOUNDARY-AWARE EXPANSION)
    console.log('\n--- 6. Expansión Inteligente según Posición de Cámara (Bordes) ---');
    await page.click('#presetLeft');
    await page.waitForTimeout(100);
    await page.click('#islandMicBtn');
    await page.waitForTimeout(400);

    const leftBoundaryStyle = await pill.evaluate(el => ({
        left: el.style.left,
        right: el.style.right,
        transform: el.style.transform
    }));
    check('Preset Perforada Izquierda expande anclado al margen izquierdo (left: 10px, no overflow)',
        leftBoundaryStyle.left === '10px' && leftBoundaryStyle.transform === 'none',
        `left: ${leftBoundaryStyle.left}, transform: ${leftBoundaryStyle.transform}`);

    await page.click('.rec-action-btn.cancel');
    await page.waitForTimeout(400);

    console.log('\n============================================================');
    console.log(` AUDITORÍA PLAYWRIGHT: ${auditResults.passed.length} pasados, ${auditResults.failed.length} fallidos.`);
    console.log('============================================================\n');

    await browser.close();
    process.exit(auditResults.failed.length > 0 ? 1 : 0);
})();
