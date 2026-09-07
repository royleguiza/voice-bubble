#!/bin/bash
set -euo pipefail
# wait_action.sh — espera un run de Actions sin guardar secretos (SPK-01).
# Uso: GITHUB_TOKEN=... ./wait_action.sh <RUN_ID> [REPO]
# El token SOLO vive en el entorno o en `gh auth`. Jamás en archivos.
: "${GITHUB_TOKEN:?Define GITHUB_TOKEN en el entorno (export GITHUB_TOKEN=...) — nunca lo pegues en archivos.}"
RUN_ID="${1:-33560253236}"
REPO="${2:-royleguiza/voice-bubble}"
TOKEN="$GITHUB_TOKEN"

while true; do
  RES=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID")
  STATUS=$(echo "$RES" | grep -o '"status": "[^"]*' | cut -d'"' -f4)
  CONCLUSION=$(echo "$RES" | grep -o '"conclusion": "[^"]*' | cut -d'"' -f4)
  
  if [ "$STATUS" == "completed" ]; then
    echo "COMPLETED: $CONCLUSION"
    break
  fi
  sleep 15
done
