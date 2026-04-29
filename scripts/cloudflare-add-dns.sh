#!/usr/bin/env bash
# cloudflare-add-dns.sh — add or update a DNS record for a domain in Cloudflare
# Usage: bash scripts/cloudflare-add-dns.sh <domain> <type> <content> [name] [proxied]
# Examples:
#   bash scripts/cloudflare-add-dns.sh myapp.com A 1.2.3.4
#   bash scripts/cloudflare-add-dns.sh myapp.com CNAME my-app.onrender.com www
#   bash scripts/cloudflare-add-dns.sh myapp.com CNAME my-app.a.run.app @ true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

DOMAIN="${1:?"Usage: $0 <domain> <type> <content> [name] [proxied]"}"
TYPE="${2:?"Usage: $0 <domain> <type> <content> [name] [proxied]"}"
CONTENT="${3:?"Usage: $0 <domain> <type> <content> [name] [proxied]"}"
NAME="${4:-@}"
PROXIED="${5:-true}"

CF_TOKEN=$(require_cred cloudflare api_token "Get it at: https://dash.cloudflare.com/profile/api-tokens")

# Get zone_id from local DB or fetch from API
ZONE_ID=$(get_zone_id "$DOMAIN")

if [ -z "$ZONE_ID" ]; then
  echo "🔍 Zone not in local DB, fetching from Cloudflare..."
  ZONE_RESPONSE=$(curl -s "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "Authorization: Bearer $CF_TOKEN")
  ZONE_ID=$(echo "$ZONE_RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
results = d.get('result', [])
print(results[0]['id'] if results else '')
" 2>/dev/null)

  if [ -z "$ZONE_ID" ]; then
    echo "❌ Zone not found for $DOMAIN"
    echo "   Run first: bash scripts/cloudflare-add-domain.sh $DOMAIN"
    exit 1
  fi
  # Cache it
  CF_ACCOUNT=$(get_cred cloudflare account_id)
  save_domain "$DOMAIN" "$ZONE_ID" "$CF_ACCOUNT"
fi

echo "📝 Adding DNS record: $TYPE $NAME → $CONTENT (proxied: $PROXIED)"

RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"$TYPE\",
    \"name\": \"$NAME\",
    \"content\": \"$CONTENT\",
    \"ttl\": 1,
    \"proxied\": $PROXIED,
    \"comment\": \"Added by web-deploy-skill\"
  }")

SUCCESS=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null)
RECORD_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result',{}).get('id',''))" 2>/dev/null)
ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; errs=json.load(sys.stdin).get('errors',[]); print(errs[0].get('message','') if errs else '')" 2>/dev/null)

if [ "$SUCCESS" != "True" ]; then
  echo "❌ Failed to add DNS record: $ERROR"
  exit 1
fi

echo "✅ DNS record added — ID: $RECORD_ID"
echo "   $TYPE $NAME.$DOMAIN → $CONTENT"
[ "$PROXIED" = "true" ] && echo "   Proxied through Cloudflare CDN + WAF ✅"
echo ""
echo "⏳ DNS propagation: usually < 1 minute within Cloudflare"
