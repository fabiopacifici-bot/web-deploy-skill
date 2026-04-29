#!/usr/bin/env bash
# deploy-cloudflare-tunnel.sh
# Exposes a running Docker container to a public URL via Cloudflare Quick Tunnel.
# No Cloudflare account needed — quick tunnels are free and instant.
# Usage: bash deploy-cloudflare-tunnel.sh <local-port>
# Example: bash deploy-cloudflare-tunnel.sh 8000

PORT=${1:-8000}

if ! command -v cloudflared &>/dev/null; then
  echo "❌ cloudflared not found."
  echo "   Install: brew install cloudflared | apt install cloudflared"
  echo "   Or: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
  exit 1
fi

echo "🌐 Starting Cloudflare Quick Tunnel → localhost:$PORT"
echo "   A public URL will appear below in ~5 seconds."
echo "   The URL changes on every restart (use named tunnels for persistence)."
echo "   Press Ctrl+C to stop the tunnel."
echo ""

cloudflared tunnel --url "http://localhost:$PORT"
