const { chromium } = require('playwright');
const path = require('path');

(async () => {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    const consoleErrors = [];
    page.on('console', msg => {
        if (msg.type() === 'error') {
            consoleErrors.push(msg.text());
        }
    });
    page.on('pageerror', err => {
        consoleErrors.push(err.toString());
    });

    const filePath = 'file://' + path.resolve(__dirname, 'trackpad_lab.html');
    console.log('Navigating to:', filePath);
    await page.goto(filePath, { waitUntil: 'load' });

    let failures = [];

    function assert(condition, message) {
        if (!condition) {
            console.error('FAIL:', message);
            failures.push(message);
        } else {
            console.log('PASS:', message);
        }
    }

    // Test 1: No initial console or page errors
    assert(consoleErrors.length === 0, `Initial console errors: ${JSON.stringify(consoleErrors)}`);

    // Test 2: Theme toggle
    const themeBtn = page.locator('#themeToggleBtn');
    await themeBtn.click();
    let rootTheme = await page.getAttribute('html', 'data-theme');
    assert(rootTheme === 'light', `Theme toggled to light (got ${rootTheme})`);

    await themeBtn.click();
    rootTheme = await page.getAttribute('html', 'data-theme');
    assert(rootTheme === 'dark', `Theme toggled back to dark (got ${rootTheme})`);

    // Test 3: Dynamic Island Presence & Tuning Presets
    const island = page.locator('#dynamicIsland');
    let isIslandVisible = await island.isVisible();
    assert(isIslandVisible, 'Dynamic Island is visible on screen');

    await page.click('#presetLeft');
    let islandX = await page.evaluate(() => state.posX);
    assert(islandX === -108, `Preset Left set X to -108 (got ${islandX})`);

    await page.click('#presetReset');
    islandX = await page.evaluate(() => state.posX);
    assert(islandX === 0, `Preset Reset restored X to 0 (got ${islandX})`);

    // Test 4: Modular Slot Swapping
    const leftSlotBtnIdBefore = await page.locator('#islandSlotLeft button').getAttribute('id');
    assert(leftSlotBtnIdBefore === 'islandTrackpadBtn', 'Left slot initially contains Trackpad button');

    await page.click('button:has-text("⇄ Invertir")');
    const leftSlotBtnIdAfter = await page.locator('#islandSlotLeft button').getAttribute('id');
    assert(leftSlotBtnIdAfter === 'islandMicBtn', 'Left slot contains Mic button after swap');

    // Invert back
    await page.click('button:has-text("⇄ Invertir")');
    const leftSlotBtnIdRestored = await page.locator('#islandSlotLeft button').getAttribute('id');
    assert(leftSlotBtnIdRestored === 'islandTrackpadBtn', 'Left slot restored to Trackpad button');

    // Test 4b: Trackpad logo is arrow cursor
    const trackpadSvgPolygon = await page.locator('#islandTrackpadBtn polygon').getAttribute('points');
    assert(trackpadSvgPolygon === '3 3 10.07 19.97 12.58 12.58 19.97 10.07 3 3', 'Trackpad logo is arrow cursor polygon');

    // Test 4c: No internal dot circle inside island pill
    const camDotCount = await page.locator('#islandCamCutout .island-camera-dot').count();
    const isDotVisible = camDotCount > 0 ? await page.locator('#islandCamCutout .island-camera-dot').isVisible() : false;
    assert(!isDotVisible, 'No internal dot circle inside island pill');

    // Test 4d: Island Themes (Dark: pure black, Light: white, Glass: liquid glass)
    await page.click('#btnIslandThemeDark');
    await page.waitForTimeout(300);
    let darkBg = await island.evaluate(el => window.getComputedStyle(el).backgroundColor);
    assert(darkBg === 'rgb(0, 0, 0)', `Island dark theme is pure black #000000 (got ${darkBg})`);

    await page.click('#btnIslandThemeLight');
    await page.waitForTimeout(300);
    let lightBg = await island.evaluate(el => window.getComputedStyle(el).backgroundColor);
    assert(lightBg === 'rgb(255, 255, 255)', `Island light theme is white #ffffff (got ${lightBg})`);
    let timerColor = await page.locator('#recTimerText').evaluate(el => window.getComputedStyle(el).color);
    assert(timerColor === 'rgb(31, 36, 48)', `Island light theme timer text has accessible contrast (got ${timerColor})`);
    let snippetColor = await page.locator('.history-snippet-text').first().evaluate(el => window.getComputedStyle(el).color);
    assert(snippetColor === 'rgb(28, 28, 30)', `Island light theme snippet text has accessible contrast (got ${snippetColor})`);

    await page.click('#btnIslandThemeGlass');
    await page.waitForTimeout(300);
    let hasGlassClass = await island.evaluate(el => el.classList.contains('mode-liquid-glass') || el.classList.contains('island-theme-glass'));
    assert(hasGlassClass, 'Island theme switched to liquid glass');

    // Test 5: Mic Recording & Audio Waveform Flow
    const micBtn = page.locator('#islandMicBtn');
    await micBtn.click();
    let isRecVisible = await page.locator('#islandRecordingView').isVisible();
    assert(isRecVisible, 'Recording view expanded upon clicking Mic');

    // Finish recording
    const finishRecBtn = page.locator('.rec-action-btn.finish');
    await finishRecBtn.click();
    let isStatusVisible = await page.locator('#islandStatusView').isVisible();
    assert(isStatusVisible, 'Status processing view displayed upon finishing recording');

    // Wait for auto completion cycle (1.2s + 1.2s = 2.4s in lab)
    await page.waitForTimeout(2800);
    isRecVisible = await page.locator('#islandRecordingView').isVisible();
    isStatusVisible = await page.locator('#islandStatusView').isVisible();
    assert(!isRecVisible && !isStatusVisible, 'Island collapsed back to pill after transcription completion');

    // Test 6: Morphing History Modal
    const camCutout = page.locator('#islandCamCutout');
    await camCutout.click();
    let isHistoryVisible = await page.locator('#islandHistoryContent').isVisible();
    assert(isHistoryVisible, 'Morphing History Modal expanded upon clicking center camera cutout');

    // Test adaptive scenarios: 1 item, 2 items, 5 items
    await page.click('#btnScenario1');
    let cardCount = await page.locator('.history-card-row').count();
    assert(cardCount === 1, 'Adaptive scenario 1 shows exactly 1 item full-width');

    await page.click('#btnScenario2');
    cardCount = await page.locator('.history-card-row').count();
    assert(cardCount === 2, 'Adaptive scenario 2 shows exactly 2 items');

    await page.click('#btnScenario5');
    cardCount = await page.locator('.history-card-row').count();
    assert(cardCount >= 3, 'Adaptive scenario 5 shows 3+ scrollable items');

    // Test Copy button on history card
    const firstCopyBtn = page.locator('.history-card-copy-btn').first();
    await firstCopyBtn.click();
    let isCopied = await firstCopyBtn.evaluate(el => el.classList.contains('copied'));
    assert(isCopied, 'Copy button shows green checkmark copied state');

    // Close history modal via bottom handle
    const bottomHandle = page.locator('#historyBottomBarArea');
    await bottomHandle.click();
    isHistoryVisible = await page.locator('#islandHistoryContent').isVisible();
    assert(!isHistoryVisible, 'History modal closed after clicking bottom drag handle');

    // Test 7: Floating Trackpad Overlay Activation
    const toggleTrackpadBtn = page.locator('#toggleTrackpadBtn');
    await toggleTrackpadBtn.click();
    const trackpadOverlay = page.locator('#floatingTrackpadOverlay');
    let isTrackpadVisible = await trackpadOverlay.isVisible();
    assert(isTrackpadVisible, 'Floating trackpad overlay is visible');

    // Test 8: Button Layouts (Top 50/50 vs Wings)
    const btnLayoutWings = page.locator('#tpLayoutWingsBtn');
    await btnLayoutWings.click();
    let hasWingsLayout = await trackpadOverlay.evaluate(el => el.classList.contains('tp-layout-wings'));
    assert(hasWingsLayout, 'Trackpad overlay switched to tp-layout-wings');

    const btnLayoutTop = page.locator('#tpLayoutTopBtn');
    await btnLayoutTop.click();
    let hasTopLayout = await trackpadOverlay.evaluate(el => el.classList.contains('tp-layout-top'));
    assert(hasTopLayout, 'Trackpad overlay switched to tp-layout-top');

    // Verify 50/50 split buttons have mouse icons and zero visible text
    const splitLeftText = (await page.locator('#btnSplitLeft').innerText()).trim();
    const splitRightText = (await page.locator('#btnSplitRight').innerText()).trim();
    const splitLeftIcon = await page.locator('#btnSplitLeft svg').count();
    const splitRightIcon = await page.locator('#btnSplitRight svg').count();
    assert(splitLeftText === '' && splitRightText === '', 'Top split buttons have zero visible text labels');
    assert(splitLeftIcon === 1 && splitRightIcon === 1, 'Top split buttons display mouse vector icons');

    // Test 9: Scroll Strip Modes (Right, Left, None)
    await page.click('#tpScrollLeftBtn');
    let hasScrollLeft = await trackpadOverlay.evaluate(el => el.classList.contains('tp-scroll-left'));
    assert(hasScrollLeft, 'Trackpad overlay has tp-scroll-left');

    await page.click('#tpScrollNoneBtn');
    let hasScrollNone = await trackpadOverlay.evaluate(el => el.classList.contains('tp-scroll-none'));
    assert(hasScrollNone, 'Trackpad overlay has tp-scroll-none (100% width pad)');

    await page.click('#tpScrollRightBtn');
    let hasScrollRight = await trackpadOverlay.evaluate(el => el.classList.contains('tp-scroll-right'));
    assert(hasScrollRight, 'Trackpad overlay restored to tp-scroll-right');

    // Test 10: Trackpad Themes (Liquid Glass, Dark, Light)
    await page.click('#tpThemeDarkBtn');
    let hasThemeDark = await trackpadOverlay.evaluate(el => el.classList.contains('tp-theme-dark'));
    assert(hasThemeDark, 'Trackpad theme set to tp-theme-dark');

    await page.click('#tpThemeLightBtn');
    let hasThemeLight = await trackpadOverlay.evaluate(el => el.classList.contains('tp-theme-light'));
    assert(hasThemeLight, 'Trackpad theme set to tp-theme-light');

    await page.click('#tpThemeGlassBtn');
    let hasThemeGlass = await trackpadOverlay.evaluate(el => el.classList.contains('tp-theme-glass'));
    assert(hasThemeGlass, 'Trackpad theme restored to tp-theme-glass');

    // Test 11: Height Extension via Rayita
    await page.click('#tpHeightExtBtn');
    let isExtended = await trackpadOverlay.evaluate(el => el.classList.contains('tp-extended'));
    assert(isExtended, 'Trackpad overlay extended to 380px');

    await page.click('#tpHeightStdBtn');
    isExtended = await trackpadOverlay.evaluate(el => el.classList.contains('tp-extended'));
    assert(!isExtended, 'Trackpad overlay restored to standard 240px');

    // Test 12: Virtual Pointer Movement on Touchpad
    const pad = page.locator('#centralTouchpad');
    const padBox = await pad.boundingBox();
    const ptrBefore = await page.evaluate(() => ({ x: state.pointerX, y: state.pointerY }));
    
    // Perform mouse drag on central touchpad
    await page.mouse.move(padBox.x + padBox.width / 2, padBox.y + padBox.height / 2);
    await page.mouse.down();
    await page.mouse.move(padBox.x + padBox.width / 2 + 40, padBox.y + padBox.height / 2 - 30);
    await page.mouse.up();

    const ptrAfter = await page.evaluate(() => ({ x: state.pointerX, y: state.pointerY }));
    assert(ptrBefore.x !== ptrAfter.x || ptrBefore.y !== ptrAfter.y,
        `Virtual pointer moved on trackpad drag (before: ${JSON.stringify(ptrBefore)}, after: ${JSON.stringify(ptrAfter)})`);

    // Test 13: Close Trackpad via Drag Handle Click
    const handleArea = page.locator('#trackpadTopBarArea');
    await handleArea.click();
    await page.waitForTimeout(300);
    isTrackpadVisible = await trackpadOverlay.isVisible();
    assert(!isTrackpadVisible, 'Trackpad overlay closed upon tapping top rayita handle');

    console.log('\n=== TEST SUMMARY ===');
    console.log(`Total failures: ${failures.length}`);
    if (failures.length > 0) {
        console.error('Failures list:', failures);
    }
    if (consoleErrors.length > 0) {
        console.error('Console errors during run:', consoleErrors);
    }

    await browser.close();
    process.exit(failures.length > 0 ? 1 : 0);
})();
