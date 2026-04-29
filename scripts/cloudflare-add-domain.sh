#!/usr/bin/env bash
# cloudflare-add-domain.sh — add a domain zone to Cloudflare and configure it
# Usage: bash scripts/cloudflare-add-domain.sh <domain>
# Example: bash scripts/cloudflare-add-domain.sh myapp.com
#
# What it does:
#   1. Creates a zone for the domain in Cloudflare
#   2. Enables full SSL mode
#   3. Enables Always Use HTTPS
#   4. Returns the nameservers to set at your registrar

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

DOMAIN="${1:?"Usage: $0 <domain>"}"

CF_TOKEN=$(require_cred cloudflare api_token "Get it at: https://dash.cloudflare.com/profile/api-tokens")
CF_ACCOUNT=$(require_cred cloudflare account_id "Find it in your Cloudflare dashboard sidebar")

echo "🌐 Adding domain to Cloudflare: $DOMAIN"

# Step 1 — Create zone
ZONE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$DOMAIN\",
    \"account\": {\"id\": \"$CF_ACCOUNT\"},
    \"jump_start\": true
  }")

SUCCESS=$(echo "$ZONE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null)
ZONE_ID=$(echo "$ZONE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result',{}).get('id',''))" 2>/dev/null)
ERROR=$(echo "$ZONE_RESPONSE" | python3 -c "import sys,json; errs=json.load(sys.stdin).get('errors',[]); print(errs[0].get('message','') if errs else '')" 2>/dev/null)

if [ "$SUCCESS" != "True" ] || [ -z "$ZONE_ID" ]; then
  echo "❌ Failed to create zone: $ERROR"
  echo "   Full response: $ZONE_RESPONSE"
  exit 1
fi

# Save zone to local DB
save_domain "$DOMAIN" "$ZONE_ID" "$CF_ACCOUNT"
echo "✅ Zone created — ID: $ZONE_ID"

# Step 2 — Enable Full SSL
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "full"}' > /dev/null
echo "✅ SSL mode: Full"

# Step 3 — Always Use HTTPS
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/always_use_https" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"value": "on"}' > /dev/null
echo "✅ Always Use HTTPS: enabled"

# Step 4 — Get nameservers
NS=$(echo "$ZONE_RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ns = d.get('result', {}).get('name_servers', [])
for n in ns:
    print('  ' + n)
" 2>/dev/null)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ $DOMAIN added to Cloudflare"
echo ""
echo "📋 Set these nameservers at your domain registrar:"
echo "$NS"
echo ""
echo "⏳ DNS propagation: 5-30 minutes after updating nameservers"
echo ""
echo "Next: add DNS records with:"
echo "   bash scripts/cloudflare-add-dns.sh $DOMAIN A <ip-address>"
echo "   bash scripts/cloudflare-add-dns.sh $DOMAIN CNAME <target>"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
