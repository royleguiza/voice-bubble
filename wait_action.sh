#!/bin/bash
# El token JAMÁS se hardcodea aquí: se lee del entorno (ver AGENTS.md §9.4).
: "${GITHUB_TOKEN:?Define GITHUB_TOKEN en el entorno (export GITHUB_TOKEN=...) — nunca lo pegues en archivos.}"
TOKEN="$GITHUB_TOKEN"
RUN_ID="33560253236"
REPO="royleguiza/voice-bubble"

while true; do
  RES=$(curl -s -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID")
  STATUS=$(echo "$RES" | grep -o '"status": "[^"]*' | cut -d'"' -f4)
  CONCLUSION=$(echo "$RES" | grep -o '"conclusion": "[^"]*' | cut -d'"' -f4)
  
  if [ "$STATUS" == "completed" ]; then
    echo "COMPLETED: $CONCLUSION"
    break
  fi
  sleep 15
done
