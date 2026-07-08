#!/usr/bin/env bash
# deploy-laravel-cloud.sh
# Deploy a Laravel app to Laravel Cloud (free tier, 1 app free)
# Deploys directly from Git — no Docker build needed.
# Usage: bash deploy-laravel-cloud.sh [app-name] [environment]

set -euo pipefail

APP_NAME="${1:-}"
ENVIRONMENT="${2:-production}"

echo "=== Laravel Cloud Deploy ==="
echo ""

# Step 1: Install cloud CLI if missing
if ! command -v cloud &>/dev/null; then
  echo "Installing Laravel Cloud CLI..."
  if ! composer global require laravel/cloud-cli; then
    echo "FAILED to install cloud CLI"
    echo "Make sure composer global bin dir is in your PATH:"
    echo '  export PATH="$HOME/.config/composer/vendor/bin:$PATH"'
    exit 1
  fi
fi

export PATH="$HOME/.config/composer/vendor/bin:$HOME/.composer/vendor/bin:$PATH"

# Step 2: Check auth
if ! cloud auth -n 2>/dev/null; then
  echo "Opening browser for Laravel Cloud authentication..."
  if ! cloud auth -n; then
    echo "Auth failed. Run manually: cloud auth"
    exit 1
  fi
fi
echo "Authenticated"
echo ""

# Step 3: Deploy
if [ -f .cloud/config.json ]; then
  echo "Repo already configured, triggering deploy..."
  if [ -n "$APP_NAME" ]; then
    cloud deploy "$APP_NAME" "$ENVIRONMENT" -n
  else
    cloud deploy "$ENVIRONMENT" -n
  fi
else
  echo "First-time deploy — running cloud ship..."
  cloud ship -n
fi

echo ""
echo "Monitoring deployment..."
cloud deploy:monitor -n

echo ""
echo "=== Deploy complete ==="
echo "Open https://console.laravel.cloud to see your app"
