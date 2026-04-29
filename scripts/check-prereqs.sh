#!/usr/bin/env bash
# check-prereqs.sh — verify required tools for chosen deploy strategy
# Usage: bash check-prereqs.sh <strategy>
# strategies: cloudflare-tunnel | gcloud-run | render | netlify | vercel

STRATEGY=${1:-cloudflare-tunnel}
ERRORS=0

check() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌ Missing: $1 — $2"
    ERRORS=$((ERRORS+1))
  else
    echo "✅ $1 found ($(command -v $1))"
  fi
}

echo "🔍 Checking prerequisites for strategy: $STRATEGY"
echo ""

# Always required
check docker "Install Docker Desktop from https://docker.com"
check git "Install Git from https://git-scm.com"

# Strategy-specific
case $STRATEGY in
  cloudflare-tunnel)
    check cloudflared "Install: brew install cloudflared | apt install cloudflared | winget install Cloudflare.cloudflared | https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
    ;;
  gcloud-run)
    check gcloud "Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    ;;
  render)
    check curl "Should be pre-installed on all platforms"
    echo "ℹ️  Render deploy requires RENDER_API_KEY and RENDER_SERVICE_ID env vars"
    ;;
  netlify)
    check netlify "Install: npm install -g netlify-cli"
    ;;
  vercel)
    check vercel "Install: npm install -g vercel"
    ;;
  aws-app-runner)
    check aws "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    check docker "Already checked"
    ;;
  *)
    echo "⚠️  Unknown strategy: $STRATEGY"
    echo "   Valid options: cloudflare-tunnel | gcloud-run | render | netlify | vercel | aws-app-runner"
    exit 1
    ;;
esac

echo ""
if [ $ERRORS -gt 0 ]; then
  echo "⚠️  Fix $ERRORS missing tool(s) above before deploying."
  exit 1
fi

echo "✅ All prerequisites met for strategy: $STRATEGY"
