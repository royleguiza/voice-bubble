// @ts-check
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  try {
    console.log('🔍 Analizando laboratorio_ui/index.html...');
    await page.goto('file:///home/roy/projects/apps/voice-bubble/laboratorio_ui/index.html', { 
      waitUntil: 'domcontentloaded',
      timeout: 10000 
    });
    await page.waitForTimeout(3000); // Esperar a que se cargue el JavaScript y Vue
    
    // Verificar que la página carga correctamente
    const title = await page.title();
    console.log(`✅ Título de la página: ${title}`);
    
    // Verificar que hay features en el JavaScript
    const featuresInfo = await page.evaluate(() => {
      // Intentar acceder a featuresData de diferentes maneras
      let features = [];
      
      // Primero intentar acceder directamente
      if (typeof featuresData !== 'undefined') {
        features = featuresData;
      } else if (window.featuresData) {
        features = window.featuresData;
      } else {
        // Si no está disponible, intentar obtenerlo del HTML
        const scripts = document.querySelectorAll('script');
        for (const script of scripts) {
          const scriptContent = script.textContent;
          if (scriptContent.includes('featuresData')) {
            // Extraer el array JSON del script
            const startIdx = scriptContent.indexOf('[');
            const endIdx = scriptContent.lastIndexOf(']');
            if (startIdx !== -1 && endIdx !== -1) {
              const jsonString = scriptContent.substring(startIdx, endIdx + 1);
              try {
                features = JSON.parse(jsonString);
                break;
              } catch (e) {
                console.log('Error parsing JSON:', e.message);
              }
            }
          }
        }
      }
      
      return {
        count: features.length,
        ids: features.map(f => f.id)
      };
    });
    
    console.log(`✅ Número de features encontradas: ${featuresInfo.count}`);
    console.log(`📋 IDs encontrados: ${featuresInfo.ids.join(', ')}`);
    
    // Verificar que todas las MEJ están representadas
    const expectedMejs = [
      'MEJ-01', 'MEJ-02', 'MEJ-03', 'MEJ-04', 'MEJ-05', 'MEJ-06', 'MEJ-07', 'MEJ-08',
      'MEJ-09', 'MEJ-10', 'MEJ-11', 'MEJ-12', 'MEJ-13', 'MEJ-14', 'MEJ-15', 'MEJ-16',
      'MEJ-17', 'MEJ-18', 'MEJ-19', 'MEJ-20', 'MEJ-21', 'MEJ-22', 'MEJ-23', 'MEJ-24'
    ];
    
    const htmlFeatures = featuresInfo.ids;
    
    console.log('\n📋 Verificando coherencia con MEJORAS-SEPTIEMBRE.md:');
    for (const mej of expectedMejs) {
      const found = htmlFeatures.includes(mej);
      console.log(`${found ? '✅' : '❌'} ${mej}: ${found ? 'Encontrada' : 'FALTANTE'}`);
    }
    
    // Verificar que NO se utilizan emoticones problemáticos
    console.log('\n🔍 Verificando emoticones en la UI:');
    const emoticons = await page.evaluate(() => {
      const emoticonsToCheck = ['🎤', '📋', '☰', '😀', '📝', '🔢', '⚡', '🔊', '🎯'];
      const bodyText = document.body.innerText;
      const found = [];
      
      emoticonsToCheck.forEach(emoticon => {
        if (bodyText.includes(emoticon)) {
          found.push(emoticon);
        }
      });
      
      return found;
    });
    
    if (emoticons.length === 0) {
      console.log('✅ No se encontraron emoticones problemáticos en la UI');
    } else {
      console.log(`❌ Emoticones encontrados: ${emoticons.join(', ')}`);
    }
    
    // Verificar que el diseño sigue el patrón Liquid Glass
    console.log('\n🔍 Verificando diseño Liquid Glass:');
    const hasGlassClasses = await page.evaluate(() => {
      const glassClasses = ['glass-header', 'backdrop-blur', 'bg-white/80', 'bg-black/60'];
      const html = document.documentElement.outerHTML;
      
      return glassClasses.some(cls => html.includes(cls));
    });
    
    console.log(`${hasGlassClasses ? '✅' : '⚠️'} Diseño Liquid Glass: ${hasGlassClasses ? 'Detectado' : 'No detectado'}`);
    
    // Verificar que las variantes muestran diferentes diseños
    console.log('\n🔍 Verificando variantes de diseño:');
    const variantInfo = await page.evaluate(() => {
      if (!window.featuresData || !window.featuresData[0]) return null;
      
      const feature = window.featuresData[0];
      return {
        id: feature.id,
        name: feature.name,
        variantsCount: feature.variants.length,
        firstVariantHtmlLength: feature.variants[0]?.html?.length || 0,
        secondVariantHtmlLength: feature.variants[1]?.html?.length || 0
      };
    });
    
    if (variantInfo) {
      console.log(`✅ Feature: ${variantInfo.id} - ${variantInfo.name}`);
      console.log(`   Variantes: ${variantInfo.variantsCount}`);
      console.log(`   Primera variante HTML: ${variantInfo.firstVariantHtmlLength} caracteres`);
      console.log(`   Segunda variante HTML: ${variantInfo.secondVariantHtmlLength} caracteres`);
      
      // Verificar que las variantes son diferentes
      const areDifferent = await page.evaluate(() => {
        if (!window.featuresData || !window.featuresData[0]) return false;
        const feature = window.featuresData[0];
        return feature.variants[0]?.html !== feature.variants[1]?.html;
      });
      
      console.log(`${areDifferent ? '✅' : '⚠️'} Variantes diferentes: ${areDifferent ? 'Sí' : 'No'}`);
    }
    
    // Verificar accesibilidad básica
    console.log('\n🔍 Verificando accesibilidad básica:');
    const accessibilityInfo = await page.evaluate(() => {
      const ariaLabels = document.querySelectorAll('[aria-label]').length;
      const tabButtons = document.querySelectorAll('button[role="tab"]').length;
      const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6').length;
      
      return {
        ariaLabels,
        tabButtons,
        headings
      };
    });
    
    console.log(`✅ Elementos con aria-label: ${accessibilityInfo.ariaLabels}`);
    console.log(`✅ Botones de tab con rol: ${accessibilityInfo.tabButtons}`);
    console.log(`✅ Encabezados: ${accessibilityInfo.headings}`);
    
    // Resumen final
    console.log('\n📊 RESUMEN DEL ANÁLISIS:');
    console.log(`   Features encontradas: ${featuresInfo.count}`);
    console.log(`   MEJ esperadas: ${expectedMejs.length}`);
    console.log(`   MEJ encontradas: ${htmlFeatures.filter(f => expectedMejs.includes(f)).length}`);
    console.log(`   Emoticones problemáticos: ${emoticons.length}`);
    console.log(`   Diseño Liquid Glass: ${hasGlassClasses ? 'Sí' : 'No'}`);
    
    // Verificar coherencia con MEJORAS-SEPTIEMBRE.md
    const missingMejs = expectedMejs.filter(mej => !htmlFeatures.includes(mej));
    if (missingMejs.length === 0) {
      console.log('\n✅ COHERENCIA VERIFICADA: Todas las MEJ del documento están en el HTML');
    } else {
      console.log(`\n❌ FALTAN MEJ: ${missingMejs.join(', ')}`);
    }
    
  } catch (error) {
    console.error('❌ Error durante el análisis:', error.message);
  } finally {
    await browser.close();
  }
})();