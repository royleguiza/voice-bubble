#!/bin/bash
TOKEN="***REVOKADO-SPK01***"
RUN_ID="33559761059"
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
