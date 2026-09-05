# Túnel Temporal Público — Guía para Agentes IA

> **Objetivo:** Exponer `laboratorio_ui/index.html` (o cualquier carpeta estática) a internet de forma **momentánea** para que una persona en **otra red y sin Tailscale** pueda abrirlo en su navegador.
> **Contexto de esta PC (Debian 12 bookworm, 2026-08-31):** `192.168.1.21` detrás de NAT (`192.168.1.1`), sin IP pública ni port-forwarding. `python3 -m http.server` solo es visible en LAN y vía Tailscale `100.78.99.51` (`debian`). El `nohup ... &` muere al cerrar la shell persistente de OpenCode tras 120s (timeout del tool). **Solución robusta:** `systemd-run --user` para servicios transient que sobreviven al cierre de la shell.

## Resumen para agentes

**Stack probado el 2026-08-31:**
- `http.server` en `127.0.0.1:8000` sirviendo `laboratorio_ui/` vía `systemd-run --user`
- `cloudflared tunnel --url http://127.0.0.1:8000 --no-autoupdate` vía `systemd-run --user` → URL `https://<random>.trycloudflare.com` (Quick Tunnel, sin cuenta, QUIC, **efímera**: muere al parar el servicio, no reutilizar entre demos). Verificado una vez con `curl -I https://<ejemplo-efímero>.trycloudflare.com/` → `200` el 2026-08-31.

**Por qué cloudflared y no solo http.server:** El router bloquea inbound. Cloudflared hace **túnel saliente** (outbound) hacia Cloudflare y publica una URL aleatoria. Cualquiera con el link lo ve, sin instalar Tailscale ni estar en la misma red. Al parar el servicio la URL muere.

## Procedimiento exacto (copiar/pegar)

### 1. Prerrequisitos en esta Debian
```bash
uname -m          # x86_64 → cloudflared-linux-amd64
which curl wget ssh
ls /tmp/cloudflared || curl -L --output /tmp/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x /tmp/cloudflared
/tmp/cloudflared --version  # 2026.8.3 ok
```

### 2. Levantar el servidor HTTP local (transient, sobrevive al timeout del tool)
```bash
# Mata previos si existen
systemctl --user stop lab-http cf-tunnel 2>/dev/null; systemctl --user reset-failed 2>/dev/null

# Arranca HTTP en 127.0.0.1:8000 sirviendo laboratorio_ui
systemd-run --user --unit=lab-http python3 -m http.server 8000 --bind 127.0.0.1 --directory /home/roy/projects/apps/voice-bubble/laboratorio_ui

sleep 2
systemctl --user status lab-http --no-pager | head -n 20
ss -tln | grep 8000
curl -s -I http://127.0.0.1:8000/ | head -n 5  # debe dar 200
```

### 3. Crear el túnel público
```bash
systemd-run --user --unit=cf-tunnel /tmp/cloudflared tunnel --url http://127.0.0.1:8000 --no-autoupdate
sleep 8
journalctl --user -u cf-tunnel -n 100 --no-pager | tail -n 40
# Buscar línea:
# |  https://<random>.trycloudflare.com  |
journalctl --user -u cf-tunnel -n 100 --no-pager | grep -oE "https://[a-z0-9-]+\.trycloudflare\.com" | head -n 1
# Probar desde la misma Debian (simula externo vía Cloudflare):
curl -s -I https://<URL> | head -n 5  # debe dar 200, no 502
curl -s https://<URL>/ | head -n 5     # debe contener "<title>VoiceBubble"
```

**Si da 502 `Unable to reach origin`:** es porque `lab-http` murió (nohup no sobrevive). Repetir paso 2 con `systemd-run` y reintentar. No usar `nohup ... &` en esta máquina.

### 4. Compartir con el usuario externo
Dar la URL exacta que muestre el log en ese momento. Ejemplo **efímero** del 2026-08-31 (ya muerto, no reutilizar):
```
https://colony-enb-const-sub.trycloudflare.com  ← ejemplo vencido, cada túnel genera una URL nueva aleatoria
```
Instrucciones para la otra computadora (sin Tailscale, sin misma red):
> Abre Chrome/Firefox y pega tal cual `https://<random>.trycloudflare.com/` y dale Enter. No necesita instalar nada, no necesita VPN, funciona con datos móviles o cualquier WiFi. Verá el laboratorio con menú de 24 MEJ y 81 teléfonos.

### 5. Apagar (obligatorio tras la demo)
```bash
systemctl --user stop lab-http cf-tunnel
systemctl --user reset-failed
ss -tln | grep 8000 || echo "puerto 8000 cerrado OK"
journalctl --user -u cf-tunnel -n 20 --no-pager | tail
```

## Alternativas si cloudflared falla

- **SSH reverse (sin binario):** `ssh -R 80:localhost:8000 nokey@localhost.run` o `serveo.net`. Da URL pública pero a veces inestable. Requiere `ssh` saliente.
- **localtunnel (Node):** `npx localtunnel --port 8000` (usa `~/.nvm` Node 24.20.0 ya instalado). Útil si Cloudflare está bloqueado.
- **GitHub static (persistente, no túnel):** `https://raw.githubusercontent.com/royleguiza/voice-bubble/main/laboratorio_ui/index.html` ya es público sin túnel, pero requiere push con `[skip ci]` y no es live.

## Notas para agentes futuros

- **Siempre usar `systemd-run --user` en esta PC** para procesos largos (http.server, cloudflared). El `nohup` muere por el timeout de 120s del tool `bash` en OpenCode.
- **Tailscale ya está activo:** `debian 100.78.99.51`, `moto-g05 100.66.223.82 direct`. Para usuarios con Tailscale basta `http://100.78.99.51:8000/`, no hace falta túnel público. Usar túnel solo para externos sin Tailscale.
- **Seguridad:** URL aleatoria, efímera, sin auth. No exponer si el contenido tiene secretos. Cerrar con `systemctl --user stop` al terminar.
- **Logs:** `journalctl --user -u lab-http -n 50` y `journalctl --user -u cf-tunnel -n 50` + `/tmp/lab_http.log` si se usó nohup.
- **Política de push vigente**: ver `AGENTS.md` (ventana de docs con `paths-ignore` + `[skip ci]`; ningún push de código sin autorización del dueño). El túnel no toca CI, es `systemd` local, seguro.
