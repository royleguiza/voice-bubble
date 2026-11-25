"""T20 · Normaliza los marcadores del applicationId para las guardas.

Desde T20 los manifiestos y PointerProtocol arman el permiso de firma, las
acciones del protocolo y los paquetes con el applicationId de cada app
(`${applicationId}`, `${hostPackage}`, `$COMPANION_PACKAGE`, `$HOST_PACKAGE`)
para que «Orison Dev» conviva con la de Play. Las guardas viejas comparan
textos literales: acá se reemplazan por los valores de la versión de Play.
"""
import re

HOST = "com.royleguiza.orison"
COMPANION = HOST + ".puntero"


def normalize(rel_path, text):
    p = rel_path.replace("\\", "/")
    if p.endswith("AndroidManifest.xml"):
        app_id = COMPANION if "puntero_android" in p else HOST
        text = text.replace("${applicationId}", app_id).replace("${hostPackage}", HOST)
    if p.endswith("PointerProtocol.kt"):
        text = re.sub(r'const val COMPANION_PACKAGE = [^\n]*', f'const val COMPANION_PACKAGE = "{COMPANION}"', text)
        text = re.sub(r'const val HOST_PACKAGE = [^\n]*', f'const val HOST_PACKAGE = "{HOST}"', text)
        text = text.replace('"$COMPANION_PACKAGE.', f'"{COMPANION}.').replace('"$HOST_PACKAGE.', f'"{HOST}.')
    return text
