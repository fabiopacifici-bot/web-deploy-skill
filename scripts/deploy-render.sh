#!/usr/bin/env bash
# deploy-render.sh
# Trigger a Render.com deployment via API
# Usage: bash deploy-render.sh
# Required env vars:
#   RENDER_API_KEY    — from https://dashboard.render.com/u/settings#api-keys
#   RENDER_SERVICE_ID — from your service URL: https://dashboard.render.com/web/srv-XXXXXXX

if [ -z "$RENDER_API_KEY" ]; then
  echo "❌ RENDER_API_KEY not set."
  echo "   Get it from: https://dashboard.render.com/u/settings#api-keys"
  echo "   Then: export RENDER_API_KEY=rnd_xxxxxxxx"
  exit 1
fi

if [ -z "$RENDER_SERVICE_ID" ]; then
  echo "❌ RENDER_SERVICE_ID not set."
  echo "   Find it in your service URL: https://dashboard.render.com/web/srv-XXXXXXX"
  echo "   Then: export RENDER_SERVICE_ID=srv-xxxxxxxx"
  exit 1
fi

echo "🚀 Triggering Render deploy for service $RENDER_SERVICE_ID..."

RESPONSE=$(curl -s -X POST \
  "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys" \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"clearCache": "do_not_clear"}')

DEPLOY_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

if [ -z "$DEPLOY_ID" ]; then
  echo "❌ Deploy failed. Response: $RESPONSE"
  exit 1
fi

echo "✅ Deploy triggered — ID: $DEPLOY_ID"
echo "📊 Monitor: https://dashboard.render.com/web/$RENDER_SERVICE_ID/deploys/$DEPLOY_ID"
echo ""
echo "ℹ️  Render deploys take ~2-5 minutes. Run verify-deploy.sh with your service URL when ready."
