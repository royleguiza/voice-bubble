import re
import html
import os

MARKDOWN_PATH = "/home/roy/projects/apps/voice-bubble/MEJORAS-SEPTIEMBRE.md"
OUTPUT_HTML_PATH = "/home/roy/projects/apps/voice-bubble/laboratorio_ui/mejoras-septiembre.html"
INDEX_HTML_PATH = "/home/roy/projects/apps/voice-bubble/laboratorio_ui/index.html"
BACKUP_INDEX_PATH = "/home/roy/projects/apps/voice-bubble/laboratorio_ui/laboratorio_componentes_previo.html"

with open(MARKDOWN_PATH, "r", encoding="utf-8") as f:
    raw_md = f.read()

def inline_format(text):
    # Code spans `code`
    text = re.sub(r'`([^`]+)`', lambda m: f'<code class="code-pill">{html.escape(m.group(1))}</code>', text)
    # Bold **text**
    text = re.sub(r'\*\*([^*]+)\*\*', lambda m: f'<strong>{m.group(1)}</strong>', text)
    # Italics *text*
    text = re.sub(r'(?<!\*)\*([^*]+)\*(?!\*)', lambda m: f'<em>{m.group(1)}</em>', text)
    # Links [text](url)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', lambda m: f'<a href="{m.group(2)}" target="_blank" rel="noopener" class="md-link">{m.group(1)}</a>', text)
    return text

def parse_markdown_table(table_text):
    lines = [l.strip() for l in table_text.strip().splitlines() if l.strip()]
    if len(lines) < 2:
        return ""
    
    header_cols = [c.strip() for c in lines[0].strip('|').split('|')]
    data_lines = lines[2:] if len(lines) > 2 and '---' in lines[1] else lines[1:]
    
    html_out = ['<div class="table-wrapper"><table class="glass-table"><thead><tr>']
    for h in header_cols:
        html_out.append(f'<th>{inline_format(h)}</th>')
    html_out.append('</tr></thead><tbody>')
    
    for row in data_lines:
        cols = [c.strip() for c in row.strip('|').split('|')]
        html_out.append('<tr>')
        for i, c in enumerate(cols):
            val = inline_format(c)
            if 'Aprobada' in c:
                val = '<span class="status-badge badge-approved">✓ Aprobada</span>'
            elif 'Descartada' in c:
                val = '<span class="status-badge badge-discarded">✕ Descartada</span>'
            elif 'En Análisis' in c or 'En Estudio' in c:
                val = '<span class="status-badge badge-review">⏳ En Análisis</span>'
            html_out.append(f'<td>{val}</td>')
        html_out.append('</tr>')
        
    html_out.append('</tbody></table></div>')
    return '\n'.join(html_out)

def categorize_mej(code, title, content):
    lower = (code + " " + title + " " + content).lower()
    categories = []
    if any(w in lower for w in ['teclado', 'tecla', 'espaciador', 'numpad', 'layout', 'mayúscula', 'símbolo', 'pulsación']):
        categories.append('teclado')
    if any(w in lower for w in ['burbuja', 'flotante', 'isla', 'notch', 'morph']):
        categories.append('burbuja')
    if any(w in lower for w in ['portapapeles', 'clipboard', 'clip', 'pegado']):
        categories.append('clipboard')
    if any(w in lower for w in ['código', 'termux', 'terminal', 'cli', 'neovim']):
        categories.append('codigo')
    if any(w in lower for w in ['gesto', 'trackpad', 'puntero', 'mouse', 'deslizamiento', 'hold']):
        categories.append('gestos')
    if any(w in lower for w in ['widget', 'multimedia', 'audio', 'música', 'reproductor', 'whatsapp']):
        categories.append('multimedia')
    if any(w in lower for w in ['tema', 'paleta', 'color', 'glass', 'diseño', 'modal']):
        categories.append('ui')
    if not categories:
        categories.append('teclado')
    return categories

def parse_mej_body_to_html(body_text):
    lines = body_text.strip().splitlines()
    html_lines = []
    in_list = False
    in_sublist = False
    
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        
        # Check sub-bullet (e.g. "  - **Ajustes**: ...")
        if re.match(r'^\s{2,}[-*]\s+', line):
            if not in_sublist:
                html_lines.append('<ul class="sublist">')
                in_sublist = True
            content = re.sub(r'^\s{2,}[-*]\s+', '', line)
            html_lines.append(f'<li>{inline_format(content)}</li>')
            continue
        else:
            if in_sublist:
                html_lines.append('</ul>')
                in_sublist = False
                
        # Check main bullet (e.g. "* **Origen / Necesidad**: ...")
        if re.match(r'^[-*]\s+', stripped):
            content = re.sub(r'^[-*]\s+', '', stripped)
            
            # Detect subsection headers
            sec_class = "bullet-item"
            icon = "•"
            if "Origen / Necesidad" in content:
                sec_class = "bullet-section bullet-origin"
                icon = "🎯"
            elif "Comportamiento Esperado" in content:
                sec_class = "bullet-section bullet-behavior"
                icon = "⚡"
            elif "Impacto Técnico" in content:
                sec_class = "bullet-section bullet-tech"
                icon = "🛠️"
            elif "Estado" in content:
                sec_class = "bullet-section bullet-status"
                icon = "📊"
                
            html_lines.append(f'<div class="{sec_class}"><span class="bullet-icon">{icon}</span><div class="bullet-content">{inline_format(content)}</div></div>')
            continue
            
        # Code block
        if stripped.startswith('```'):
            continue
            
        # Normal paragraph
        html_lines.append(f'<p>{inline_format(stripped)}</p>')
        
    if in_sublist:
        html_lines.append('</ul>')
        
    return '\n'.join(html_lines)

# Split sections
sec1_match = re.search(r'## 1\. Planes Listos para Ejecución.*?(?=## 2\.)', raw_md, re.DOTALL)
sec1_text = sec1_match.group(0) if sec1_match else ""

sec2_match = re.search(r'## 2\. Registro de Nuevas Ideas y Propuestas.*?(?=## 3\.)', raw_md, re.DOTALL)
sec2_text = sec2_match.group(0) if sec2_match else ""

sec3_match = re.search(r'## 3\. Registro de Decisiones y Descartes.*', raw_md, re.DOTALL)
sec3_text = sec3_match.group(0) if sec3_match else ""

# Parse Section 2 Items (MEJ-03 to MEJ-24)
items = []
pattern = r'###\s+(2\.\d+)\s+\[(MEJ-\d+)\]\s+(.*?)\n(.*?)(?=\n###|\n##|$)'
for m in re.finditer(pattern, sec2_text, re.DOTALL):
    num_prefix = m.group(1)
    code = m.group(2)
    title = m.group(3).strip()
    body = m.group(4).strip()
    cats = categorize_mej(code, title, body)
    
    # Status
    status = "En Diseño"
    if "Aprobada" in body:
        status = "Aprobada"
    elif "Descartada" in body:
        status = "Descartada"
        
    items.append({
        'num': num_prefix,
        'code': code,
        'title': title,
        'body_html': parse_mej_body_to_html(body),
        'raw_body': body,
        'cats': cats,
        'status': status
    })

# Parse Section 3 table
table_match = re.search(r'\| Fecha \|.*', sec3_text, re.DOTALL)
sec3_table_html = parse_markdown_table(table_match.group(0)) if table_match else ""

# Generate HTML
html_template = f"""<!DOCTYPE html>
<html lang="es" data-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0">
    <title>VoiceBubble STT — Plan de Mejoras Septiembre 2026</title>
    
    <!-- Google Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
    
    <style>
        :root[data-theme="dark"] {{
            --bg-canvas: #09090b;
            --bg-surface: rgba(18, 18, 23, 0.78);
            --bg-surface-elevated: rgba(26, 26, 33, 0.88);
            --bg-card-hover: rgba(32, 32, 42, 0.95);
            --border-subtle: rgba(255, 255, 255, 0.08);
            --border-strong: rgba(255, 255, 255, 0.16);
            --border-focus: #38bdf8;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --text-tertiary: #64748b;
            --accent: #38bdf8;
            --accent-glow: rgba(56, 189, 248, 0.25);
            --accent-bg: rgba(56, 189, 248, 0.12);
            --accent-secondary: #818cf8;
            --badge-green-bg: rgba(34, 197, 94, 0.16);
            --badge-green-border: rgba(34, 197, 94, 0.35);
            --badge-green-text: #4ade80;
            --shadow-glass: 0 10px 30px -10px rgba(0, 0, 0, 0.5);
            --shadow-card: 0 4px 20px -2px rgba(0, 0, 0, 0.35);
        }}

        :root[data-theme="light"] {{
            --bg-canvas: #f8fafc;
            --bg-surface: rgba(255, 255, 255, 0.88);
            --bg-surface-elevated: rgba(241, 245, 249, 0.95);
            --bg-card-hover: rgba(255, 255, 255, 1);
            --border-subtle: rgba(0, 0, 0, 0.08);
            --border-strong: rgba(0, 0, 0, 0.15);
            --border-focus: #0284c7;
            --text-primary: #0f172a;
            --text-secondary: #475569;
            --text-tertiary: #94a3b8;
            --accent: #0284c7;
            --accent-glow: rgba(2, 132, 199, 0.2);
            --accent-bg: rgba(2, 132, 199, 0.1);
            --accent-secondary: #6366f1;
            --badge-green-bg: rgba(22, 163, 74, 0.12);
            --badge-green-border: rgba(22, 163, 74, 0.3);
            --badge-green-text: #15803d;
            --shadow-glass: 0 10px 30px -10px rgba(0, 0, 0, 0.08);
            --shadow-card: 0 4px 16px -2px rgba(0, 0, 0, 0.06);
        }}

        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            -webkit-tap-highlight-color: transparent;
        }}

        body {{
            font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background-color: var(--bg-canvas);
            color: var(--text-primary);
            line-height: 1.65;
            padding-bottom: env(safe-area-inset-bottom, 24px);
            min-height: 100vh;
            overflow-x: hidden;
            transition: background-color 0.25s ease, color 0.25s ease;
        }}

        /* Sticky Glass Header */
        .app-header {{
            position: sticky;
            top: 0;
            z-index: 100;
            background: var(--bg-surface);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border-bottom: 1px solid var(--border-subtle);
            padding: 12px 16px;
            padding-top: calc(12px + env(safe-area-inset-top, 0px));
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
        }}

        .brand-cluster {{
            display: flex;
            align-items: center;
            gap: 10px;
            text-decoration: none;
            color: inherit;
        }}

        .brand-icon {{
            width: 38px;
            height: 38px;
            border-radius: 12px;
            background: linear-gradient(135deg, #38bdf8 0%, #6366f1 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            box-shadow: 0 4px 12px rgba(56, 189, 248, 0.35);
        }}

        .brand-text h1 {{
            font-size: 15px;
            font-weight: 700;
            letter-spacing: -0.3px;
            line-height: 1.2;
        }}

        .brand-text span {{
            font-size: 11px;
            color: var(--accent);
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }}

        .header-actions {{
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .btn-icon {{
            width: 38px;
            height: 38px;
            border-radius: 10px;
            border: 1px solid var(--border-subtle);
            background: var(--bg-surface-elevated);
            color: var(--text-primary);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            cursor: pointer;
            transition: all 0.2s ease;
        }}

        .btn-icon:hover, .btn-icon:active {{
            background: var(--bg-card-hover);
            border-color: var(--accent);
            transform: scale(0.96);
        }}

        /* Sticky Search & Filter Bar */
        .sticky-search-panel {{
            position: sticky;
            top: 62px;
            z-index: 90;
            background: var(--bg-surface);
            backdrop-filter: blur(18px);
            -webkit-backdrop-filter: blur(18px);
            border-bottom: 1px solid var(--border-subtle);
            padding: 10px 16px 12px;
            display: flex;
            flex-direction: column;
            gap: 10px;
        }}

        .search-box-wrap {{
            position: relative;
            display: flex;
            align-items: center;
            width: 100%;
        }}

        .search-icon {{
            position: absolute;
            left: 14px;
            color: var(--text-tertiary);
            font-size: 15px;
            pointer-events: none;
        }}

        .search-input {{
            width: 100%;
            height: 42px;
            background: var(--bg-surface-elevated);
            border: 1px solid var(--border-subtle);
            border-radius: 12px;
            padding: 0 38px 0 40px;
            color: var(--text-primary);
            font-size: 14px;
            font-family: inherit;
            outline: none;
            transition: all 0.2s ease;
        }}

        .search-input:focus {{
            border-color: var(--border-focus);
            box-shadow: 0 0 0 3px var(--accent-glow);
            background: var(--bg-card-hover);
        }}

        .search-clear-btn {{
            position: absolute;
            right: 12px;
            background: none;
            border: none;
            color: var(--text-tertiary);
            font-size: 16px;
            cursor: pointer;
            display: none;
        }}

        .filter-chips {{
            display: flex;
            gap: 8px;
            overflow-x: auto;
            scrollbar-width: none;
            -webkit-overflow-scrolling: touch;
            padding-bottom: 2px;
        }}

        .filter-chips::-webkit-scrollbar {{
            display: none;
        }}

        .chip {{
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            white-space: nowrap;
            background: var(--bg-surface-elevated);
            border: 1px solid var(--border-subtle);
            color: var(--text-secondary);
            cursor: pointer;
            transition: all 0.2s ease;
        }}

        .chip.active {{
            background: var(--accent);
            color: #09090b;
            border-color: var(--accent);
            box-shadow: 0 2px 10px var(--accent-glow);
        }}

        /* Main Container */
        .main-content {{
            max-width: 860px;
            margin: 0 auto;
            padding: 16px;
            display: flex;
            flex-direction: column;
            gap: 20px;
        }}

        /* Hero / Overview Card */
        .hero-banner {{
            background: linear-gradient(135deg, rgba(56, 189, 248, 0.12) 0%, rgba(99, 102, 241, 0.12) 100%);
            border: 1px solid var(--border-strong);
            border-radius: 20px;
            padding: 20px;
            position: relative;
            overflow: hidden;
            box-shadow: var(--shadow-glass);
        }}

        .hero-banner::before {{
            content: '';
            position: absolute;
            top: -40px;
            right: -40px;
            width: 140px;
            height: 140px;
            background: radial-gradient(circle, var(--accent-glow) 0%, transparent 70%);
            border-radius: 50%;
            pointer-events: none;
        }}

        .hero-pill {{
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 4px 12px;
            background: var(--accent-bg);
            border: 1px solid var(--accent-glow);
            border-radius: 30px;
            color: var(--accent);
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 12px;
        }}

        .hero-title {{
            font-size: 22px;
            font-weight: 800;
            letter-spacing: -0.5px;
            margin-bottom: 8px;
            line-height: 1.25;
        }}

        .hero-desc {{
            font-size: 13px;
            color: var(--text-secondary);
            line-height: 1.6;
        }}

        /* Stats Grid */
        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
            margin-top: 16px;
        }}

        .stat-box {{
            background: var(--bg-surface);
            border: 1px solid var(--border-subtle);
            border-radius: 14px;
            padding: 12px 10px;
            text-align: center;
        }}

        .stat-num {{
            font-size: 20px;
            font-weight: 800;
            color: var(--accent);
            font-family: 'JetBrains Mono', monospace;
        }}

        .stat-label {{
            font-size: 10px;
            font-weight: 600;
            color: var(--text-tertiary);
            text-transform: uppercase;
            letter-spacing: 0.3px;
            margin-top: 2px;
        }}

        /* Section Headings */
        .section-header-wrap {{
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-top: 10px;
            margin-bottom: 4px;
        }}

        .section-title {{
            font-size: 18px;
            font-weight: 800;
            letter-spacing: -0.3px;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .section-tag {{
            font-size: 11px;
            padding: 2px 8px;
            border-radius: 6px;
            background: var(--bg-surface-elevated);
            color: var(--text-secondary);
            font-family: 'JetBrains Mono', monospace;
        }}

        /* Section 1 Card */
        .execution-card {{
            background: var(--bg-surface);
            border: 1px solid var(--border-subtle);
            border-radius: 16px;
            padding: 16px;
            box-shadow: var(--shadow-card);
        }}

        .execution-item {{
            padding: 12px;
            border-radius: 12px;
            background: var(--bg-surface-elevated);
            border: 1px solid var(--border-subtle);
            margin-top: 10px;
        }}

        .execution-item h4 {{
            font-size: 14px;
            font-weight: 700;
            margin-bottom: 6px;
            display: flex;
            align-items: center;
            gap: 8px;
        }}

        .execution-item ul {{
            list-style: none;
            padding-left: 0;
            font-size: 12.5px;
            color: var(--text-secondary);
        }}

        .execution-item li {{
            margin-top: 4px;
            position: relative;
            padding-left: 14px;
        }}

        .execution-item li::before {{
            content: '•';
            position: absolute;
            left: 2px;
            color: var(--accent);
        }}

        /* Improvement Cards (MEJ-XX) */
        .mej-card {{
            background: var(--bg-surface);
            border: 1px solid var(--border-subtle);
            border-radius: 18px;
            overflow: hidden;
            box-shadow: var(--shadow-card);
            transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
        }}

        .mej-card:hover {{
            border-color: var(--border-strong);
            background: var(--bg-card-hover);
        }}

        .mej-header {{
            padding: 16px;
            cursor: pointer;
            display: flex;
            flex-direction: column;
            gap: 8px;
            user-select: none;
        }}

        .mej-meta-row {{
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 8px;
        }}

        .mej-code-badge {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            font-weight: 700;
            color: var(--accent);
            background: var(--accent-bg);
            border: 1px solid var(--accent-glow);
            padding: 3px 10px;
            border-radius: 8px;
        }}

        .status-badge {{
            font-size: 11px;
            font-weight: 700;
            padding: 3px 10px;
            border-radius: 20px;
            display: inline-flex;
            align-items: center;
            gap: 4px;
            white-space: nowrap;
        }}

        .badge-approved {{
            background: var(--badge-green-bg);
            border: 1px solid var(--badge-green-border);
            color: var(--badge-green-text);
        }}

        .badge-design {{
            background: rgba(56, 189, 248, 0.15);
            border: 1px solid rgba(56, 189, 248, 0.3);
            color: #38bdf8;
        }}

        .badge-discarded {{
            background: rgba(239, 68, 68, 0.15);
            border: 1px solid rgba(239, 68, 68, 0.3);
            color: #f87171;
        }}

        .mej-title {{
            font-size: 15px;
            font-weight: 700;
            line-height: 1.35;
            letter-spacing: -0.2px;
            color: var(--text-primary);
        }}

        .mej-card-tags {{
            display: flex;
            gap: 6px;
            flex-wrap: wrap;
            margin-top: 2px;
        }}

        .tag-pill {{
            font-size: 10px;
            font-weight: 600;
            padding: 2px 8px;
            border-radius: 6px;
            background: var(--bg-surface-elevated);
            color: var(--text-tertiary);
            text-transform: capitalize;
        }}

        .mej-body {{
            padding: 0 16px 16px;
            border-top: 1px solid var(--border-subtle);
            background: rgba(0, 0, 0, 0.08);
            display: flex;
            flex-direction: column;
            gap: 12px;
            font-size: 13.5px;
        }}

        .mej-body.collapsed {{
            display: none;
        }}

        .toggle-icon {{
            font-size: 12px;
            color: var(--text-tertiary);
            transition: transform 0.2s ease;
        }}

        .toggle-icon.expanded {{
            transform: rotate(180deg);
        }}

        /* Bullets in MEJ body */
        .bullet-section {{
            display: flex;
            gap: 10px;
            margin-top: 10px;
        }}

        .bullet-icon {{
            font-size: 16px;
            flex-shrink: 0;
            margin-top: 1px;
        }}

        .bullet-content {{
            flex: 1;
            line-height: 1.6;
        }}

        .bullet-content strong {{
            color: var(--text-primary);
        }}

        .sublist {{
            list-style: none;
            padding-left: 12px;
            margin-top: 8px;
            display: flex;
            flex-direction: column;
            gap: 6px;
            border-left: 2px solid var(--border-subtle);
        }}

        .sublist li {{
            position: relative;
            padding-left: 12px;
            font-size: 13px;
            color: var(--text-secondary);
        }}

        .sublist li::before {{
            content: '›';
            position: absolute;
            left: 0;
            color: var(--accent);
            font-weight: bold;
        }}

        /* Inline code & links */
        .code-pill {{
            font-family: 'JetBrains Mono', monospace;
            font-size: 12px;
            padding: 2px 6px;
            border-radius: 6px;
            background: var(--bg-surface-elevated);
            border: 1px solid var(--border-subtle);
            color: var(--accent);
        }}

        .md-link {{
            color: var(--accent);
            text-decoration: none;
            border-bottom: 1px dotted var(--accent);
        }}

        .md-link:hover {{
            text-decoration: underline;
        }}

        /* Tables */
        .table-wrapper {{
            overflow-x: auto;
            -webkit-overflow-scrolling: touch;
            border: 1px solid var(--border-subtle);
            border-radius: 14px;
            background: var(--bg-surface);
            box-shadow: var(--shadow-card);
            margin-top: 10px;
        }}

        .glass-table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 12.5px;
            text-align: left;
            min-width: 600px;
        }}

        .glass-table th {{
            background: var(--bg-surface-elevated);
            color: var(--text-secondary);
            font-weight: 700;
            padding: 10px 14px;
            border-bottom: 1px solid var(--border-subtle);
            white-space: nowrap;
        }}

        .glass-table td {{
            padding: 10px 14px;
            border-bottom: 1px solid var(--border-subtle);
            color: var(--text-secondary);
            vertical-align: middle;
        }}

        .glass-table tr:last-child td {{
            border-bottom: none;
        }}

        .glass-table tr:hover td {{
            background: var(--bg-card-hover);
        }}

        /* Table of Contents Offcanvas Drawer */
        .toc-drawer-overlay {{
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.6);
            backdrop-filter: blur(4px);
            z-index: 200;
            opacity: 0;
            pointer-events: none;
            transition: opacity 0.25s ease;
        }}

        .toc-drawer-overlay.active {{
            opacity: 1;
            pointer-events: auto;
        }}

        .toc-drawer {{
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            max-height: 80vh;
            background: var(--bg-surface);
            border-top: 1px solid var(--border-strong);
            border-radius: 24px 24px 0 0;
            z-index: 210;
            transform: translateY(100%);
            transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
            display: flex;
            flex-direction: column;
            box-shadow: 0 -10px 40px rgba(0, 0, 0, 0.5);
            padding-bottom: env(safe-area-inset-bottom, 20px);
        }}

        .toc-drawer.active {{
            transform: translateY(0);
        }}

        .toc-drawer-handle {{
            width: 44px;
            height: 5px;
            background: var(--text-tertiary);
            border-radius: 10px;
            margin: 12px auto 6px;
            opacity: 0.6;
        }}

        .toc-drawer-header {{
            padding: 12px 20px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid var(--border-subtle);
        }}

        .toc-drawer-header h3 {{
            font-size: 16px;
            font-weight: 700;
        }}

        .toc-list {{
            overflow-y: auto;
            padding: 12px 20px;
            display: flex;
            flex-direction: column;
            gap: 8px;
        }}

        .toc-item {{
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 10px 14px;
            border-radius: 12px;
            background: var(--bg-surface-elevated);
            border: 1px solid var(--border-subtle);
            text-decoration: none;
            color: var(--text-primary);
            font-size: 13px;
            transition: all 0.2s ease;
        }}

        .toc-item:active {{
            background: var(--bg-card-hover);
            border-color: var(--accent);
        }}

        .toc-code {{
            font-family: 'JetBrains Mono', monospace;
            font-weight: 700;
            color: var(--accent);
            margin-right: 8px;
        }}

        /* Floating Action Button (Back to Top) */
        .fab-top {{
            position: fixed;
            bottom: 24px;
            right: 20px;
            width: 46px;
            height: 46px;
            border-radius: 50%;
            background: var(--accent);
            color: #09090b;
            border: none;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 20px;
            font-weight: bold;
            box-shadow: 0 4px 20px var(--accent-glow);
            cursor: pointer;
            z-index: 80;
            opacity: 0;
            pointer-events: none;
            transition: all 0.25s ease;
        }}

        .fab-top.visible {{
            opacity: 1;
            pointer-events: auto;
            transform: translateY(0);
        }}

        /* Alert / Callout Glass */
        .alert-callout {{
            background: rgba(56, 189, 248, 0.08);
            border: 1px solid var(--accent-glow);
            border-radius: 14px;
            padding: 14px;
            font-size: 12.5px;
            color: var(--text-secondary);
            line-height: 1.5;
            display: flex;
            gap: 10px;
        }}

        .no-results {{
            text-align: center;
            padding: 40px 20px;
            color: var(--text-tertiary);
            font-size: 14px;
            display: none;
        }}
    </style>
</head>
<body>

    <!-- Sticky Glass Header -->
    <header class="app-header">
        <a href="#" class="brand-cluster">
            <div class="brand-icon">🎙️</div>
            <div class="brand-text">
                <h1>VoiceBubble STT</h1>
                <span>Mejoras Septiembre 2026</span>
            </div>
        </a>
        <div class="header-actions">
            <button class="btn-icon" id="btn-toc" title="Índice de Mejoras" aria-label="Índice">📑</button>
            <button class="btn-icon" id="btn-theme" title="Alternar Modo Oscuro/Claro" aria-label="Tema">🌓</button>
        </div>
    </header>

    <!-- Sticky Search and Filter Bar -->
    <div class="sticky-search-panel">
        <div class="search-box-wrap">
            <span class="search-icon">🔍</span>
            <input type="text" id="search-input" class="search-input" placeholder="Buscar entre las 24 mejoras (ej: teclado, termux, notch)..." autocomplete="off">
            <button class="search-clear-btn" id="search-clear">✕</button>
        </div>
        <div class="filter-chips" id="filter-chips">
            <button class="chip active" data-cat="all">Todas ({len(items) + 2})</button>
            <button class="chip" data-cat="teclado">⌨️ Teclado</button>
            <button class="chip" data-cat="burbuja">🫧 Burbuja / Isla</button>
            <button class="chip" data-cat="clipboard">📋 Portapapeles</button>
            <button class="chip" data-cat="codigo">💻 Código / Termux</button>
            <button class="chip" data-cat="gestos">👆 Gestos / Puntero</button>
            <button class="chip" data-cat="multimedia">🎵 Multimedia</button>
            <button class="chip" data-cat="ui">🎨 UI & Temas</button>
        </div>
    </div>

    <!-- Main Container -->
    <main class="main-content">

        <!-- Hero Overview -->
        <section class="hero-banner">
            <div class="hero-pill">⚡ Documento Oficial • Ciclo Septiembre</div>
            <h2 class="hero-title">Plan y Registro de Mejoras 2026</h2>
            <p class="hero-desc">
                Especificación técnica de features y arquitectura móvil para <strong>VoiceBubble STT</strong>.
                Sin parches temporales, con foco en ergonomía, estabilidad y diseño Apple Liquid Glass.
            </p>
            <div class="stats-grid">
                <div class="stat-box">
                    <div class="stat-num">{len(items) + 2}</div>
                    <div class="stat-label">Mejoras Totales</div>
                </div>
                <div class="stat-box">
                    <div class="stat-num">2</div>
                    <div class="stat-label">Listas Ejecución</div>
                </div>
                <div class="stat-box">
                    <div class="stat-num">22</div>
                    <div class="stat-label">Nuevas Ideas</div>
                </div>
            </div>
        </section>

        <!-- Rules Alert -->
        <div class="alert-callout">
            <span style="font-size: 18px;">📌</span>
            <div>
                <strong>Regla Operativa:</strong> CERO cambios de código en <code>app_source/</code> o <code>voice_bubble_stt/</code> hasta la fase de ejecución. Solo documentación, diseño de arquitectura y especificación de features aprobadas.
            </div>
        </div>

        <!-- Section 1: Ready for Execution -->
        <div class="section-header-wrap" id="section-1">
            <h3 class="section-title">1. Planes Listos para Ejecución</h3>
            <span class="section-tag">2 FEATURES</span>
        </div>

        <div class="execution-card">
            <p style="font-size: 13px; color: var(--text-secondary); margin-bottom: 8px;">
                Planes analizados y aprobados previamente por el dueño:
            </p>

            <div class="execution-item" data-cats="clipboard teclado" data-search="bandeja portapapeles clipboard tray mej-01 clips cursor">
                <h4>
                    <span class="mej-code-badge">MEJ-01</span>
                    Bandeja de Portapapeles (Clipboard Tray)
                    <span class="status-badge badge-approved" style="margin-left: auto;">✓ Aprobada</span>
                </h4>
                <ul>
                    <li>Captura de clips copiados fuera de la app (opt-in).</li>
                    <li>Tecla <code>📋</code> en barra inferior o superior para insertar clips en cursor.</li>
                    <li>Documento técnico: <a href="plan-clipboard.md" target="_blank" class="md-link">plan-clipboard.md</a></li>
                </ul>
            </div>

            <div class="execution-item" data-cats="teclado gestos" data-search="ciclar mayusculas minusculas shift mej-02 texto seleccionado">
                <h4>
                    <span class="mej-code-badge">MEJ-02</span>
                    Ciclar Mayúsculas/Minúsculas con ⇧
                    <span class="status-badge badge-approved" style="margin-left: auto;">✓ Aprobada</span>
                </h4>
                <ul>
                    <li>Ciclo <code>minúsculas</code> → <code>Mayúscula Inicial</code> → <code>MAYÚSCULAS</code> en texto seleccionado.</li>
                    <li>Comportamiento dinámico dependiente del estado del cursor y selección.</li>
                    <li>Documento técnico: <a href="plan-ciclar-mayusculas.md" target="_blank" class="md-link">plan-ciclar-mayusculas.md</a></li>
                </ul>
            </div>
        </div>

        <!-- Section 2: New Proposals -->
        <div class="section-header-wrap" id="section-2">
            <h3 class="section-title">2. Registro de Nuevas Ideas y Propuestas</h3>
            <span class="section-tag">MEJ-03 AL MEJ-24</span>
        </div>

        <div id="mej-items-container" style="display: flex; flex-direction: column; gap: 14px;">
"""

for item in items:
    cat_str = " ".join(item['cats'])
    status_badge_class = "badge-approved" if item['status'] == "Aprobada" else "badge-design"
    status_badge_text = "✓ Aprobada" if item['status'] == "Aprobada" else "⚡ En Diseño"
    search_terms = f"{item['code']} {item['title']} {item['raw_body']}".lower().replace('"', '')

    tags_html = "".join([f'<span class="tag-pill">{c}</span>' for c in item['cats']])

    html_template += f"""
            <article class="mej-card" id="{item['code'].lower()}" data-cats="{cat_str}" data-search="{search_terms}">
                <div class="mej-header" onclick="toggleCard('{item['code'].lower()}')">
                    <div class="mej-meta-row">
                        <span class="mej-code-badge">{item['code']}</span>
                        <div style="display: flex; align-items: center; gap: 8px;">
                            <span class="status-badge {status_badge_class}">{status_badge_text}</span>
                            <span class="toggle-icon expanded" id="icon-{item['code'].lower()}">▼</span>
                        </div>
                    </div>
                    <h4 class="mej-title">{item['num']} {item['title']}</h4>
                    <div class="mej-card-tags">
                        {tags_html}
                    </div>
                </div>
                <div class="mej-body" id="body-{item['code'].lower()}">
                    {item['body_html']}
                </div>
            </article>
    """

html_template += f"""
        </div>

        <div id="no-results-msg" class="no-results">
            🔍 No se encontraron mejoras que coincidan con la búsqueda.
        </div>

        <!-- Section 3: Decisions Table -->
        <div class="section-header-wrap" id="section-3" style="margin-top: 20px;">
            <h3 class="section-title">3. Registro de Decisiones y Descartes</h3>
            <span class="section-tag">TABLA RESUMEN</span>
        </div>

        {sec3_table_html}

        <footer style="text-align: center; padding: 40px 0 20px; font-size: 12px; color: var(--text-tertiary);">
            <p>VoiceBubble STT • Laboratorio UI & Diseño 2026</p>
            <p style="margin-top: 4px;">Optimizada para navegación fluida en dispositivos móviles.</p>
        </footer>

    </main>

    <!-- Table of Contents Bottom Sheet / Drawer -->
    <div class="toc-drawer-overlay" id="toc-overlay"></div>
    <div class="toc-drawer" id="toc-drawer">
        <div class="toc-drawer-handle"></div>
        <div class="toc-drawer-header">
            <h3>📑 Índice de Mejoras (24)</h3>
            <button class="btn-icon" id="toc-close" style="width: 32px; height: 32px;">✕</button>
        </div>
        <div class="toc-list">
            <a href="#section-1" class="toc-item" onclick="closeToc()">
                <span><strong>1. Planes Listos para Ejecución</strong></span>
                <span class="status-badge badge-approved">2</span>
            </a>
"""

for item in items:
    html_template += f"""
            <a href="#{item['code'].lower()}" class="toc-item" onclick="closeToc()">
                <div>
                    <span class="toc-code">{item['code']}</span>
                    <span>{item['title']}</span>
                </div>
                <span style="font-size: 11px; color: var(--text-tertiary); margin-left: 8px;">›</span>
            </a>
    """

html_template += f"""
            <a href="#section-3" class="toc-item" onclick="closeToc()">
                <span><strong>3. Registro de Decisiones y Descartes</strong></span>
                <span class="status-badge badge-review">Tabla</span>
            </a>
        </div>
    </div>

    <!-- Floating Action Button: Back to Top -->
    <button class="fab-top" id="fab-top" title="Subir al inicio">↑</button>

    <!-- Interactive Client-side Script -->
    <script>
        // Toggle Theme
        const btnTheme = document.getElementById('btn-theme');
        btnTheme.addEventListener('click', () => {{
            const currentTheme = document.documentElement.getAttribute('data-theme');
            const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
            document.documentElement.setAttribute('data-theme', newTheme);
            localStorage.setItem('vb_theme', newTheme);
        }});
        
        // Restore saved theme
        const savedTheme = localStorage.getItem('vb_theme');
        if (savedTheme) {{
            document.documentElement.setAttribute('data-theme', savedTheme);
        }}

        // Card Collapse / Expand
        function toggleCard(id) {{
            const body = document.getElementById('body-' + id);
            const icon = document.getElementById('icon-' + id);
            if (!body || !icon) return;
            const isCollapsed = body.classList.toggle('collapsed');
            icon.classList.toggle('expanded', !isCollapsed);
        }}

        // Table of Contents Drawer
        const tocDrawer = document.getElementById('toc-drawer');
        const tocOverlay = document.getElementById('toc-overlay');
        const btnToc = document.getElementById('btn-toc');
        const tocClose = document.getElementById('toc-close');

        function openToc() {{
            tocDrawer.classList.add('active');
            tocOverlay.classList.add('active');
            document.body.style.overflow = 'hidden';
        }}

        function closeToc() {{
            tocDrawer.classList.remove('active');
            tocOverlay.classList.remove('active');
            document.body.style.overflow = '';
        }}

        btnToc.addEventListener('click', openToc);
        tocClose.addEventListener('click', closeToc);
        tocOverlay.addEventListener('click', closeToc);

        // Search & Filter Logic
        const searchInput = document.getElementById('search-input');
        const searchClear = document.getElementById('search-clear');
        const filterChips = document.querySelectorAll('.chip');
        const cards = document.querySelectorAll('.mej-card, .execution-item');
        const noResultsMsg = document.getElementById('no-results-msg');

        let activeCategory = 'all';

        function applyFilters() {{
            const query = searchInput.value.trim().toLowerCase();
            let visibleCount = 0;

            searchClear.style.display = query ? 'block' : 'none';

            cards.forEach(card => {{
                const cardCats = (card.getAttribute('data-cats') || '').split(' ');
                const cardSearch = card.getAttribute('data-search') || '';

                const matchesCat = (activeCategory === 'all') || cardCats.includes(activeCategory);
                const matchesQuery = !query || cardSearch.includes(query);

                if (matchesCat && matchesQuery) {{
                    card.style.display = '';
                    visibleCount++;
                }} else {{
                    card.style.display = 'none';
                }}
            }});

            noResultsMsg.style.display = visibleCount === 0 ? 'block' : 'none';
        }}

        searchInput.addEventListener('input', applyFilters);

        searchClear.addEventListener('click', () => {{
            searchInput.value = '';
            applyFilters();
            searchInput.focus();
        }});

        filterChips.forEach(chip => {{
            chip.addEventListener('click', () => {{
                filterChips.forEach(c => c.classList.remove('active'));
                chip.classList.add('active');
                activeCategory = chip.getAttribute('data-cat');
                applyFilters();
            }});
        }});

        // Floating Action Button
        const fabTop = document.getElementById('fab-top');
        window.addEventListener('scroll', () => {{
            if (window.scrollY > 300) {{
                fabTop.classList.add('visible');
            }} else {{
                fabTop.classList.remove('visible');
            }}
        }}, {{ passive: true }});

        fabTop.addEventListener('click', () => {{
            window.scrollTo({{ top: 0, behavior: 'smooth' }});
        }});
    </script>
</body>
</html>
"""

# Write to file
with open(OUTPUT_HTML_PATH, "w", encoding="utf-8") as f:
    f.write(html_template)
print(f"Generated {OUTPUT_HTML_PATH} ({len(html_template)} bytes)")

# Backup index.html if not already backed up
if os.path.exists(INDEX_HTML_PATH) and not os.path.exists(BACKUP_INDEX_PATH):
    import shutil
    shutil.copyfile(INDEX_HTML_PATH, BACKUP_INDEX_PATH)
    print(f"Backed up original index.html to {BACKUP_INDEX_PATH}")

# Overwrite index.html so accessing root / directly displays Mejoras Septiembre
with open(INDEX_HTML_PATH, "w", encoding="utf-8") as f:
    f.write(html_template)
print(f"Updated {INDEX_HTML_PATH}")

