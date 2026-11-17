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
print('PROBLEMAS',bad)
sys.exit(1 if bad else 0)
