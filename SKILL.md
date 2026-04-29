---
name: web-deploy
description: Deploy a web app from a Docker container to a public URL. Supports Cloudflare Tunnel (instant, no account), Google Cloud Run (free, scalable), Render, Netlify, and AWS App Runner. Language-agnostic — works with any stack that runs in Docker.
version: 1.0.0
user-invokable: true
commands:
  - /deploy
  - /web-deploy
  - /go-live
metadata:
  scripts_dir: scripts/
  adr: ADR.md
---

# web-deploy Skill

Deploy a Dockerised web app to a public URL.

## Decision Tree — Which Strategy?

| Situation | Strategy | Time to live |
|---|---|---|
| Docker running locally, just want a public URL now | `cloudflare-tunnel` | ~30 seconds |
| Want real persistent hosting, free, no credit card | `gcloud-run` | ~5 minutes |
| App already on Render, trigger a redeploy | `render` | ~3 minutes |
| Static site / JAMstack (no backend) | `netlify` | ~1 minute |
| Next.js / Nuxt on Vercel | `vercel` | ~1 minute |
| Learning AWS, want App Runner | `aws-app-runner` | ~10 minutes |

**If the user hasn't specified a strategy:** ask them which situation matches and recommend accordingly.

---

## Agent Instructions

### Step 0 — Identify strategy

If strategy not specified, ask:
> "Which deploy target do you want? Options: cloudflare-tunnel (instant demo), gcloud-run (free persistent), render, netlify, vercel, aws-app-runner"

If user says "fastest" or "just want to show it now" → use `cloudflare-tunnel`.
If user says "free hosting" or "real URL" → use `gcloud-run` or `render`.
If user says "static site" or "frontend only" → use `netlify` or `vercel`.

---

### Step 1 — Check prerequisites

Always run this first:

```bash
bash <SKILL_DIR>/scripts/check-prereqs.sh <strategy>
```

If prerequisites fail, report what's missing with install instructions. Do not proceed until fixed.

---

### Step 2 — Ensure Docker container is running

The app must be running in Docker before deploying (except Render/Netlify which deploy from Git).

Check:
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}"
```

If no containers are running:
```bash
docker compose up -d
# or
docker run -d -p 8000:8000 <image-name>
```

Ask user for the local port if unclear.

---

### Step 3 — Deploy

#### Strategy: `cloudflare-tunnel`

```bash
bash <SKILL_DIR>/scripts/deploy-cloudflare-tunnel.sh <local-port>
```

Wait for the URL to appear in output (looks like `https://xxxx-xxxx.trycloudflare.com`).
Report the URL to the user. Note: URL is temporary and changes on restart.

#### Strategy: `gcloud-run`

```bash
bash <SKILL_DIR>/scripts/deploy-gcloud-run.sh <image-name> <service-name> <region>
```

Default region: `europe-west1`
The script builds, pushes, and deploys. verify-deploy runs automatically.

Before running, ensure user is authenticated:
```bash
gcloud auth list
```
If not authenticated:
```bash
gcloud auth login
gcloud config set project <project-id>
gcloud auth configure-docker
```

#### Strategy: `render`

Requires: `RENDER_API_KEY` and `RENDER_SERVICE_ID` environment variables.

```bash
export RENDER_API_KEY=<key>
export RENDER_SERVICE_ID=<service-id>
bash <SKILL_DIR>/scripts/deploy-render.sh
```

After triggering, wait 3-5 minutes then verify:
```bash
bash <SKILL_DIR>/scripts/verify-deploy.sh <render-service-url>
```

#### Strategy: `netlify`

```bash
bash <SKILL_DIR>/scripts/deploy-netlify.sh <build-dir>
```

Common build dirs: `dist`, `public`, `build`, `out`, `.next`
If not authenticated: `netlify login` first.

#### Strategy: `vercel`

```bash
vercel --prod
```

Follow prompts. Vercel auto-detects the framework.

#### Strategy: `aws-app-runner`

Requires AWS CLI authenticated and ECR access:

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-1.amazonaws.com

# Build and push
docker build -t <image-name> .
docker tag <image-name>:latest <account-id>.dkr.ecr.eu-west-1.amazonaws.com/<image-name>:latest
docker push <account-id>.dkr.ecr.eu-west-1.amazonaws.com/<image-name>:latest

# Deploy via App Runner (via AWS console or apprunner CLI)
```

---

### Step 4 — Verify (always)

For all strategies except cloudflare-tunnel (which shows the URL in real-time):

```bash
bash <SKILL_DIR>/scripts/verify-deploy.sh <url>
```

Report to user:
- ✅ URL is live, HTTP status, response time
- 🌐 The public URL
- 💡 Any notes (e.g. "Cloudflare Tunnel URL changes on restart")

---

### Step 5 — Report

Tell the user:
```
✅ Deployed successfully

🌐 URL: <public-url>
📦 Strategy: <strategy>
⏱️ Response time: <latency>s

<any relevant notes>
```

---

## SKILL_DIR resolution

The skill scripts are in the same directory as this SKILL.md file.
Resolve the absolute path:

```bash
SKILL_DIR="$(dirname "$(realpath "$0")")/scripts"
# or if called by an agent with a known skill path:
SKILL_DIR="~/.kernel/ecosystem/skills/web-deploy/scripts"
```

---

## Platform Reference

| Platform | Free tier | Cold start | Database | Best for |
|---|---|---|---|---|
| Cloudflare Tunnel | ✅ Free forever | None (local) | — | Local demo, quick share |
| Google Cloud Run | ✅ 2M req/month | ~1s | Use Cloud SQL | Docker apps, APIs |
| Render | ✅ No sleep | None | Postgres free | Full-stack persistent |
| Netlify | ✅ Free forever | None | — | Static / JAMstack |
| Vercel | ✅ Free forever | None | — | Next.js / Nuxt |
| AWS App Runner | ⚠️ 12mo free | ~3s | Use RDS | AWS ecosystem |
| Railway | ⚠️ $5/mo after trial | None | Postgres | Full-stack |
| Laravel Forge | ❌ Paid | None | Any | Laravel production |
