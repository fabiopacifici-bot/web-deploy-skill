#!/usr/bin/env bash
# setup.sh — interactive first-time credential setup
# Stores all credentials in ~/.web-deploy/config.db (SQLite, local, chmod 600)
# Usage: bash scripts/setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "🔧 web-deploy-skill — First-time setup"
echo "   Credentials stored locally at: $DB_PATH"
echo "   File permissions: 600 (only you can read it)"
echo ""

prompt_cred() {
  local service="$1" key="$2" label="$3" hint="$4" required="$5"
  local existing
  existing=$(get_cred "$service" "$key")

  if [ -n "$existing" ]; then
    echo "✅ $label: already set (use --reset to overwrite)"
    return
  fi

  [ -n "$hint" ] && echo "   ℹ️  $hint"
  read -rsp "   $label: " val
  echo ""

  if [ -z "$val" ]; then
    if [ "$required" = "required" ]; then
      echo "   ⚠️  Skipped (required for $service features)"
    else
      echo "   ⏭️  Skipped"
    fi
    return
  fi

  set_cred "$service" "$key" "$val"
  echo "   ✅ Saved"
}

# ── Laravel Forge ──────────────────────────────────────────────────────────────
echo "━━━ Laravel Forge ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Get your API token: https://forge.laravel.com/user-profile/api"
prompt_cred "forge" "api_token" "Forge API Token" "" "optional"
echo ""

# ── Cloudflare ─────────────────────────────────────────────────────────────────
echo "━━━ Cloudflare ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Get your API token: https://dash.cloudflare.com/profile/api-tokens"
echo "   Required permissions: Zone:DNS:Edit, Zone:Zone:Read, Zone:Zone Settings:Edit"
prompt_cred "cloudflare" "api_token" "Cloudflare API Token" "" "optional"
echo "   Get your Account ID: Cloudflare dashboard → right sidebar"
prompt_cred "cloudflare" "account_id" "Cloudflare Account ID" "" "optional"
echo ""

# ── Google Cloud ───────────────────────────────────────────────────────────────
echo "━━━ Google Cloud ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Get project ID: https://console.cloud.google.com"
prompt_cred "gcloud" "project_id" "GCloud Project ID" "" "optional"
prompt_cred "gcloud" "region" "Default Region (e.g. europe-west1)" "" "optional"
echo ""

# ── Render ─────────────────────────────────────────────────────────────────────
echo "━━━ Render ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Get API key: https://dashboard.render.com/u/settings#api-keys"
prompt_cred "render" "api_key" "Render API Key" "" "optional"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup complete. Run 'bash scripts/setup.sh' again to add more."
echo ""
echo "Configured services:"
sqlite3 "$DB_PATH" "SELECT DISTINCT service FROM credentials ORDER BY service;" | while read -r svc; do
  echo "  ✅ $svc"
done
