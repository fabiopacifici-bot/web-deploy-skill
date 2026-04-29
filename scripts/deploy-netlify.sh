#!/usr/bin/env bash
# deploy-netlify.sh
# Deploy a static site to Netlify
# Usage: bash deploy-netlify.sh [build-dir]
# Example: bash deploy-netlify.sh dist
# Example: bash deploy-netlify.sh public
# Default build dir: dist

BUILD_DIR=${1:-dist}

if ! command -v netlify &>/dev/null; then
  echo "❌ netlify CLI not found."
  echo "   Install: npm install -g netlify-cli"
  exit 1
fi

if [ ! -d "$BUILD_DIR" ]; then
  echo "❌ Build directory '$BUILD_DIR' not found."
  echo "   Run your build command first (e.g. npm run build, hugo, etc.)"
  echo "   Then retry: bash deploy-netlify.sh $BUILD_DIR"
  exit 1
fi

echo "🚀 Deploying to Netlify from ./$BUILD_DIR ..."
netlify deploy --dir="$BUILD_DIR" --prod

echo ""
echo "✅ Netlify deploy complete."

# Try to get the deployed URL
SITE_URL=$(netlify status --json 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('siteData', {}).get('ssl_url') or d.get('siteData', {}).get('url', ''))
except:
    print('')
" 2>/dev/null)

if [ -n "$SITE_URL" ]; then
  bash "$(dirname "$0")/verify-deploy.sh" "$SITE_URL"
fi
