#!/usr/bin/env bash
# forge-deploy-site.sh — create a site on a Forge server and deploy from Git
# Usage: bash scripts/forge-deploy-site.sh <server_id> <domain> <repo> [branch]
# Example: bash scripts/forge-deploy-site.sh 12345 myapp.com myorg/myrepo main
#
# Prerequisites: server must be ready (is_ready: true)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

SERVER_ID="${1:?"Usage: $0 <server_id> <domain> <repo> [branch]"}"
DOMAIN="${2:?"Usage: $0 <server_id> <domain> <repo> [branch]"}"
REPO="${3:?"Usage: $0 <server_id> <domain> <repo> [branch]"}"
BRANCH="${4:-main}"

FORGE_TOKEN=$(require_cred forge api_token "Get it at: https://forge.laravel.com/user-profile/api")

echo "🌐 Creating site: $DOMAIN on server $SERVER_ID"

# Step 1 — Create site
SITE_RESPONSE=$(curl -s -X POST "https://forge.laravel.com/api/v1/servers/$SERVER_ID/sites" \
  -H "Authorization: Bearer $FORGE_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{
    \"domain\": \"$DOMAIN\",
    \"project_type\": \"php\",
    \"directory\": \"/public\"
  }")

SITE_ID=$(echo "$SITE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['site']['id'])" 2>/dev/null)
SITE_ERROR=$(echo "$SITE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)

if [ -z "$SITE_ID" ]; then
  echo "❌ Failed to create site: $SITE_ERROR"
  echo "   Response: $SITE_RESPONSE"
  exit 1
fi

echo "✅ Site created — ID: $SITE_ID"

# Step 2 — Install Git repository
echo "📦 Installing Git repo: $REPO ($BRANCH)..."

GIT_RESPONSE=$(curl -s -X POST "https://forge.laravel.com/api/v1/servers/$SERVER_ID/sites/$SITE_ID/git" \
  -H "Authorization: Bearer $FORGE_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{
    \"provider\": \"github\",
    \"repository\": \"$REPO\",
    \"branch\": \"$BRANCH\",
    \"composer\": true
  }")

GIT_ERROR=$(echo "$GIT_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('message',''))" 2>/dev/null)
if [ -n "$GIT_ERROR" ] && [ "$GIT_ERROR" != "None" ]; then
  echo "⚠️  Git install warning: $GIT_ERROR"
fi

echo "✅ Git repo linked"

# Step 3 — Enable Let's Encrypt SSL
echo "🔒 Requesting SSL certificate..."

SSL_RESPONSE=$(curl -s -X POST "https://forge.laravel.com/api/v1/servers/$SERVER_ID/sites/$SITE_ID/certificates/letsencrypt" \
  -H "Authorization: Bearer $FORGE_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"domains\": [\"$DOMAIN\"]}")

SSL_ID=$(echo "$SSL_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('certificate',{}).get('id',''))" 2>/dev/null)
[ -n "$SSL_ID" ] && echo "✅ SSL certificate requested (ID: $SSL_ID)" || echo "⚠️  SSL request may need manual follow-up"

# Step 4 — Trigger first deploy
echo "🚀 Triggering deployment..."

DEPLOY_RESPONSE=$(curl -s -X POST "https://forge.laravel.com/api/v1/servers/$SERVER_ID/sites/$SITE_ID/deployment/deploy" \
  -H "Authorization: Bearer $FORGE_TOKEN" \
  -H "Accept: application/json")

echo ""
echo "✅ Deployment triggered"
echo "   Domain: https://$DOMAIN"
echo "   Forge dashboard: https://forge.laravel.com/servers/$SERVER_ID/sites/$SITE_ID"
echo ""
echo "⏳ Deployment takes 1-3 minutes. Verify with:"
echo "   bash scripts/verify-deploy.sh https://$DOMAIN"
