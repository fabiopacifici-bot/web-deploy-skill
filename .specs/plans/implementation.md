# Implementation Plan — web-deploy-skill

**Date:** 2026-04-29
**Status:** Ready to build
**Branch:** main (new repo)

---

## Checklist

- [ ] 1. Init repo structure
- [ ] 2. Write `scripts/check-prereqs.sh`
- [ ] 3. Write `scripts/deploy-cloudflare-tunnel.sh`
- [ ] 4. Write `scripts/deploy-gcloud-run.sh`
- [ ] 5. Write `scripts/deploy-render.sh`
- [ ] 6. Write `scripts/deploy-netlify.sh`
- [ ] 7. Write `scripts/verify-deploy.sh`
- [ ] 8. Write `SKILL.md` (main entry point)
- [ ] 9. Write `README.md`
- [ ] 10. Init git, first commit
- [ ] 11. Push to fabiopacifici-bot/web-deploy-skill (private)
- [ ] 12. Clone into workspace/skills/web-deploy/

---

## File Structure

```
web-deploy-skill/
├── ADR.md
├── README.md
├── SKILL.md                          ← agent entry point
├── .specs/
│   └── plans/
│       └── implementation.md         ← this file
└── scripts/
    ├── check-prereqs.sh
    ├── deploy-cloudflare-tunnel.sh
    ├── deploy-gcloud-run.sh
    ├── deploy-render.sh
    ├── deploy-netlify.sh
    └── verify-deploy.sh
```

---

## Step 1 — check-prereqs.sh

Checks all required tools are installed before attempting deploy.

```bash
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
    echo "✅ $1 found"
  fi
}

# Always required
check docker "Install Docker Desktop from https://docker.com"
check git "Install Git from https://git-scm.com"

# Strategy-specific
case $STRATEGY in
  cloudflare-tunnel)
    check cloudflared "brew install cloudflared / apt install cloudflared / winget install Cloudflare.cloudflared"
    ;;
  gcloud-run)
    check gcloud "Install from https://cloud.google.com/sdk/docs/install"
    check docker "Already checked"
    ;;
  render)
    check curl "Should be pre-installed"
    ;;
  netlify)
    check netlify "npm install -g netlify-cli"
    ;;
  vercel)
    check vercel "npm install -g vercel"
    ;;
esac

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "⚠️  Fix $ERRORS missing tool(s) before deploying."
  exit 1
fi

echo ""
echo "✅ All prerequisites met for strategy: $STRATEGY"
```

---

## Step 2 — deploy-cloudflare-tunnel.sh

No account needed. Uses `cloudflared` quick tunnel.

```bash
#!/usr/bin/env bash
# deploy-cloudflare-tunnel.sh
# Exposes a running Docker container to a public URL via Cloudflare Quick Tunnel
# Usage: bash deploy-cloudflare-tunnel.sh <local-port>
# Example: bash deploy-cloudflare-tunnel.sh 8000

PORT=${1:-8000}

echo "🌐 Starting Cloudflare Quick Tunnel on port $PORT..."
echo "   (Ctrl+C to stop — URL is temporary, changes on restart)"
echo ""

cloudflared tunnel --url http://localhost:$PORT
```

---

## Step 3 — deploy-gcloud-run.sh

Google Cloud Run — requires gcloud CLI and a project.

```bash
#!/usr/bin/env bash
# deploy-gcloud-run.sh
# Deploy a Docker image to Google Cloud Run
# Usage: bash deploy-gcloud-run.sh <image-name> <service-name> <region>
# Example: bash deploy-gcloud-run.sh my-app my-app-service europe-west1

IMAGE=${1:?"Usage: $0 <image-name> <service-name> <region>"}
SERVICE=${2:?"Usage: $0 <image-name> <service-name> <region>"}
REGION=${3:-europe-west1}
PROJECT=$(gcloud config get-value project 2>/dev/null)

if [ -z "$PROJECT" ]; then
  echo "❌ No active gcloud project. Run: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

echo "📦 Building and pushing Docker image..."
IMAGE_URI="gcr.io/$PROJECT/$IMAGE"
docker build -t "$IMAGE_URI" .
docker push "$IMAGE_URI"

echo "🚀 Deploying to Cloud Run..."
gcloud run deploy "$SERVICE" \
  --image "$IMAGE_URI" \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --port 8080

URL=$(gcloud run services describe "$SERVICE" \
  --region "$REGION" \
  --format 'value(status.url)')

echo ""
echo "✅ Deployed: $URL"
bash "$(dirname $0)/verify-deploy.sh" "$URL"
```

---

## Step 4 — deploy-render.sh

Trigger a Render deploy via API (requires Render API key + service ID).

```bash
#!/usr/bin/env bash
# deploy-render.sh
# Trigger a Render.com deployment via API
# Required env vars: RENDER_API_KEY, RENDER_SERVICE_ID

if [ -z "$RENDER_API_KEY" ] || [ -z "$RENDER_SERVICE_ID" ]; then
  echo "❌ Set RENDER_API_KEY and RENDER_SERVICE_ID environment variables"
  echo "   Get them from: https://dashboard.render.com/u/settings#api-keys"
  exit 1
fi

echo "🚀 Triggering Render deploy for service $RENDER_SERVICE_ID..."

RESPONSE=$(curl -s -X POST \
  "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys" \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Content-Type: application/json")

DEPLOY_ID=$(echo $RESPONSE | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)

if [ -z "$DEPLOY_ID" ]; then
  echo "❌ Deploy failed. Response: $RESPONSE"
  exit 1
fi

echo "✅ Deploy triggered. ID: $DEPLOY_ID"
echo "   Monitor at: https://dashboard.render.com/web/$RENDER_SERVICE_ID/deploys/$DEPLOY_ID"
```

---

## Step 5 — deploy-netlify.sh

Static site deploy.

```bash
#!/usr/bin/env bash
# deploy-netlify.sh
# Deploy a static site to Netlify
# Usage: bash deploy-netlify.sh <build-dir>
# Example: bash deploy-netlify.sh dist

BUILD_DIR=${1:-dist}

if [ ! -d "$BUILD_DIR" ]; then
  echo "❌ Build directory '$BUILD_DIR' not found. Run your build command first."
  exit 1
fi

echo "🚀 Deploying to Netlify from $BUILD_DIR..."
netlify deploy --dir="$BUILD_DIR" --prod

URL=$(netlify status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('siteData',{}).get('ssl_url',''))" 2>/dev/null)
[ -n "$URL" ] && bash "$(dirname $0)/verify-deploy.sh" "$URL"
```

---

## Step 6 — verify-deploy.sh

```bash
#!/usr/bin/env bash
# verify-deploy.sh — check a URL returns 200
# Usage: bash verify-deploy.sh <url>

URL=${1:?"Usage: $0 <url>"}
MAX_RETRIES=5
WAIT=10

echo "🔍 Verifying deployment at $URL..."

for i in $(seq 1 $MAX_RETRIES); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$URL" 2>/dev/null)
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "301" ] || [ "$STATUS" = "302" ]; then
    LATENCY=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 "$URL" 2>/dev/null)
    echo "✅ Live — HTTP $STATUS — ${LATENCY}s response time"
    echo "🌐 URL: $URL"
    exit 0
  fi
  echo "⏳ Attempt $i/$MAX_RETRIES — HTTP $STATUS — waiting ${WAIT}s..."
  sleep $WAIT
done

echo "❌ Deployment not responding after $((MAX_RETRIES * WAIT))s. Check logs."
exit 1
```

---

## Step 7 — SKILL.md

Main agent entry point. Agent reads this, asks user which strategy, executes the right script.

Key sections:
- Frontmatter: name, description, commands
- Decision tree: which strategy when
- Per-strategy instructions with exact commands
- verify always runs at end

---

## Step 8 — README.md

Human-readable docs covering:
- What this skill does
- Quick start (3 commands)
- Strategy comparison table
- How to add it to Kernel
- How to use with Copilot Agent

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|---|---|---|
| cloudflared not installed | Medium | check-prereqs catches it, install instructions in error |
| gcloud auth expired | Medium | script checks project config, error message includes fix |
| Docker not running | Low | check-prereqs catches it |
| Render API key missing | Low | clear error + link to dashboard |
| URL not live after deploy | Low | verify-deploy retries 5x with 10s wait |

---

## Success Criteria

- Student runs `/skill web-deploy` in Kernel (or Copilot Agent) and gets a public URL
- Works on Mac, Windows (WSL2), Linux without modification
- Cloudflare Tunnel path works in under 2 minutes from zero
- Google Cloud Run path works in under 5 minutes
- verify-deploy confirms the URL is live before reporting success
