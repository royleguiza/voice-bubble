#!/usr/bin/env python3
"""
Injects real MEJ designs into laboratorio_ui/index.html.
Reads all design modules from designs/ directory and patches the featuresData JSON.
"""
import os
import sys
import json
import re
import importlib.util

DESIGNS_DIR = os.path.join(os.path.dirname(__file__), 'designs')
HTML_FILE = os.path.join(os.path.dirname(__file__), 'index.html')

def load_designs():
    """Load all MEJ design modules and return a dict of {mej_id: variants}."""
    designs = {}
    for filename in sorted(os.listdir(DESIGNS_DIR)):
        if not filename.startswith('mej') or not filename.endswith('.py'):
            continue
        filepath = os.path.join(DESIGNS_DIR, filename)
        spec = importlib.util.spec_from_file_location(filename[:-3], filepath)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        
        # Extract MEJ number from filename
        mej_num = filename.replace('mej', '').replace('.py', '')
        mej_id = f'MEJ-{mej_num.zfill(2)}'
        
        if hasattr(module, 'VARIANTS'):
            designs[mej_id] = module.VARIANTS
            print(f"  Loaded {mej_id}: {len(module.VARIANTS)} variants")
        else:
            print(f"  WARNING: {filename} has no VARIANTS")
    
    return designs

def build_variant_json(variant):
    """Build the JSON object for a single variant."""
    return {
        "id": variant['id'],
        "name": variant['name'],
        "html": variant['html']
    }

def main():
    print("=== MEJ Design Injector ===\n")
    
    # Check if HTML file exists
    if not os.path.exists(HTML_FILE):
        print(f"ERROR: {HTML_FILE} not found")
        sys.exit(1)
    
    # Read current HTML
    with open(HTML_FILE, 'r', encoding='utf-8') as f:
        html_content = f.read()
    print(f"Read {len(html_content)} bytes from index.html\n")
    
    # Load all designs
    print("Loading design modules...")
    designs = load_designs()
    print(f"\nLoaded {len(designs)} MEJ designs\n")
    
    if not designs:
        print("ERROR: No designs loaded")
        sys.exit(1)
    
    # Find featuresData in HTML
    match = re.search(r'featuresData\s*=\s*', html_content)
    if not match:
        print("ERROR: Could not find featuresData in HTML")
        sys.exit(1)
    
    json_start = match.end()
    
    # Find the end of the JSON array by counting brackets
    bracket_count = 0
    json_end = json_start
    in_string = False
    escape_next = False
    
    for i in range(json_start, len(html_content)):
        c = html_content[i]
        
        if escape_next:
            escape_next = False
            continue
        
        if c == '\\' and in_string:
            escape_next = True
            continue
        
        if c == '"' and not escape_next:
            in_string = not in_string
            continue
        
        if not in_string:
            if c == '[':
                bracket_count += 1
            elif c == ']':
                bracket_count -= 1
                if bracket_count == 0:
                    json_end = i + 1
                    break
    
    json_str = html_content[json_start:json_end]
    
    # Parse the existing JSON
    print("Parsing existing featuresData JSON...")
    try:
        data = json.loads(json_str)
        print(f"  Found {len(data)} MEJ entries\n")
    except json.JSONDecodeError as e:
        print(f"  JSON parse error: {e}")
        sys.exit(1)
    
    # Replace entries with real designs
    print("Injecting real designs...")
    injected = set()
    for entry in data:
        mej_id = entry['id']
        if mej_id in designs:
            variants = designs[mej_id]
            entry['variants'] = [build_variant_json(v) for v in variants]
            injected.add(mej_id)
            print(f"  Injected {mej_id}: {len(variants)} variants")
    
    # Check for missing MEJ
    for mej_id in designs:
        if mej_id not in injected:
            print(f"  WARNING: {mej_id} was not found in existing HTML data")
    
    # Serialize back to JSON
    new_json = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    
    # Replace in HTML
    new_html = html_content[:json_start] + new_json + html_content[json_end:]
    
    # Validate the result
    print("\nValidating JSON...")
    match2 = re.search(r'featuresData\s*=\s*', new_html)
    if match2:
        bracket_count2 = 0
        json_end2 = match2.end()
        in_string2 = False
        escape_next2 = False
        
        for i in range(match2.end(), len(new_html)):
            c = new_html[i]
            
            if escape_next2:
                escape_next2 = False
                continue
            
            if c == '\\' and in_string2:
                escape_next2 = True
                continue
            
            if c == '"' and not escape_next2:
                in_string2 = not in_string2
                continue
            
            if not in_string2:
                if c == '[':
                    bracket_count2 += 1
                elif c == ']':
                    bracket_count2 -= 1
                    if bracket_count2 == 0:
                        json_end2 = i + 1
                        break
        
        try:
            validated = json.loads(new_html[match2.end():json_end2])
            print(f"  JSON valid: {len(validated)} MEJ entries")
            for entry in validated:
                print(f"    {entry['id']}: {len(entry['variants'])} variants")
        except json.JSONDecodeError as e:
            print(f"  JSON validation failed: {e}")
            sys.exit(1)
    
    # Write updated HTML
    with open(HTML_FILE, 'w', encoding='utf-8') as f:
        f.write(new_html)
    
    print(f"\nDone! Updated {HTML_FILE}")

if __name__ == '__main__':
    main()
