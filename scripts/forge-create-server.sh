#!/usr/bin/env bash
# forge-create-server.sh — provision a new server via Laravel Forge API
# Usage: bash scripts/forge-create-server.sh <name> <provider> <region> <size> [php_version]
# Example: bash scripts/forge-create-server.sh my-server hetzner eu-central 1 php84
#
# Supported providers: ocean2 (DigitalOcean), akamai (Linode), vultr2, aws, hetzner, custom
# PHP versions: php84, php83, php82, php81, php80, php74
#
# Get valid regions/sizes: curl -s -H "Authorization: Bearer $TOKEN" https://forge.laravel.com/api/v1/regions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

NAME="${1:?"Usage: $0 <name> <provider> <region> <size> [php_version]"}"
PROVIDER="${2:?"Usage: $0 <name> <provider> <region> <size> [php_version]"}"
REGION="${3:?"Usage: $0 <name> <provider> <region> <size> [php_version]"}"
SIZE="${4:?"Usage: $0 <name> <provider> <region> <size> [php_version]"}"
PHP="${5:-php84}"

FORGE_TOKEN=$(require_cred forge api_token "Get it at: https://forge.laravel.com/user-profile/api")

echo "🚀 Creating Forge server: $NAME"
echo "   Provider: $PROVIDER | Region: $REGION | Size: $SIZE | PHP: $PHP"
echo ""

RESPONSE=$(curl -s -X POST https://forge.laravel.com/api/v1/servers \
  -H "Authorization: Bearer $FORGE_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{
    \"name\": \"$NAME\",
    \"provider\": \"$PROVIDER\",
    \"region\": \"$REGION\",
    \"size\": \"$SIZE\",
    \"php_version\": \"$PHP\",
    \"database\": \"forge\",
    \"database_type\": \"postgres17\"
  }")

# Check for errors
ERROR=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',''))" 2>/dev/null)
if [ -n "$ERROR" ]; then
  echo "❌ Forge API error: $ERROR"
  echo "   Full response: $RESPONSE"
  exit 1
fi

# Parse response
SERVER_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['server']['id'])" 2>/dev/null)
SERVER_IP=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['server'].get('ip_address','pending'))" 2>/dev/null)
PROVISION_CMD=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('provision_command',''))" 2>/dev/null)

# Save to local DB
save_server "$SERVER_ID" "$NAME" "$SERVER_IP" "$PROVIDER" "provisioning"

echo "✅ Server created — ID: $SERVER_ID"
echo "   IP: $SERVER_IP (may be pending)"
echo "   Status: provisioning (~10 minutes)"
echo ""

if [ -n "$PROVISION_CMD" ]; then
  echo "⚙️  Custom VPS provision command:"
  echo "   $PROVISION_CMD"
  echo ""
fi

echo "ℹ️  Monitor progress:"
echo "   bash scripts/forge-server-status.sh $SERVER_ID"
echo "   Or: https://forge.laravel.com/servers/$SERVER_ID"
