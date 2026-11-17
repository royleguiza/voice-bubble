"""Etapa 4 (C2): values (en), values-es y values-pt de la app y del complemento
tienen las mismas claves y los mismos marcadores %n$x por clave."""
import re,sys,xml.etree.ElementTree as ET
import os
R=os.path.dirname(os.path.abspath(__file__))+'/'
bad=0
for mod in ('voice_bubble_stt/android/app','puntero_android/app'):
    d={}
    for v in ('values','values-es','values-pt'):
        t=ET.parse(R+mod+'/src/main/res/%s/strings.xml'%v).getroot()
        m={}
        for e in t:
            if e.tag=='string': m[e.get('name')]=sorted(re.findall(r'%\d\$\w',''.join(e.itertext())))
            elif e.tag=='plurals':
                for it in e: m[e.get('name')+'/'+it.get('quantity')]=sorted(re.findall(r'%\d\$?\w',''.join(it.itertext())))
        d[v]=m
    for v in d:
        if d[v].keys()!=d['values'].keys(): print(mod,v,'claves difieren',set(d[v])^set(d['values'])); bad+=1
        for k in d['values']:
            if k in d[v] and d[v][k]!=d['values'][k] and not (k.endswith('/one') ): print(mod,v,k,d[v][k],d['values'][k]); bad+=1
    print(mod,{v:len(d[v]) for v in d})
# Widget: un @string en un diseño de RemoteViews lo resuelve el launcher con
# el idioma del teléfono, no el de la app. Todo texto de widget_*.xml tiene
# que ponerse también desde WidgetTexts.kt (con el mismo id y la misma clave).
import glob
src=R+'voice_bubble_stt/android/app/src/main/'
wt=open(src+'kotlin/com/royleguiza/voicebubblestt/WidgetTexts.kt').read()
pairs=set(re.findall(r'R\.id\.(\w+),\s*(?:\w+\s*\+\s*)?context\.getString\(R\.string\.(\w+)\)',wt))
pairs|={(i,k) for k,ids in re.findall(r'val \w+ = context\.getString\(R\.string\.(\w+)\)((?:\s*views\.set\w+\(R\.id\.\w+, \w+\))+)',wt) for i in re.findall(r'R\.id\.(\w+)',ids)}
nw=0
for f in sorted(glob.glob(src+'res/layout/widget_*.xml')):
    for e in ET.parse(f).getroot().iter():
        i=(e.get('{http://schemas.android.com/apk/res/android}id') or '').replace('@+id/','')
        for a in ('text','contentDescription'):
            v=e.get('{http://schemas.android.com/apk/res/android}'+a) or ''
            if v.startswith('@string/'):
                nw+=1
                if (i,v[8:]) not in pairs: print('widget sin WidgetTexts:',os.path.basename(f),i,v); bad+=1
print('widget: textos de diseño cubiertos',nw)
for k in ('WidgetTexts.notes(context, views)','WidgetTexts.detail(context, views)','WidgetTexts.noteItem(context, views)','WidgetTexts.pendingItem(context, views)'):
    if not any(k in open(x).read() for x in glob.glob(src+'kotlin/com/royleguiza/voicebubblestt/Widget*.kt') if not x.endswith('WidgetTexts.kt')):
        print('falta llamada',k); bad+=1
print('PROBLEMAS',bad)
sys.exit(1 if bad else 0)
