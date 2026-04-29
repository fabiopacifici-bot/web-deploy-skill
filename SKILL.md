---
name: web-deploy
description: Deploy a web app from a Docker container to a public URL. Supports Cloudflare Tunnel (instant, no account), Google Cloud Run (free, scalable), Render, Netlify, and AWS App Runner. Full server management via Laravel Forge API. Domain registration and DNS management via Cloudflare API. Credentials stored securely in local SQLite vault.
version: 2.0.0
user-invokable: true
commands:
  - /deploy
  - /web-deploy
  - /go-live
  - /forge
  - /domain
metadata:
  scripts_dir: scripts/
  adr: ADR.md
  credential_db: ~/.web-deploy/config.db
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
| Need a managed PHP/Laravel server (production) | `forge` | ~10 minutes |
| Need to add a domain to Cloudflare | `cloudflare-domain` | ~2 minutes |
| Need to add/update a DNS record | `cloudflare-dns` | ~30 seconds |

**If the user hasn't specified a strategy:** ask them which situation matches and recommend accordingly.

---

## First-time Setup (credential vault)

All API credentials are stored securely in a local SQLite DB (`~/.web-deploy/config.db`, chmod 600). Run once before using Forge or Cloudflare strategies:

```bash
bash <SKILL_DIR>/scripts/setup.sh
```

This interactively prompts for:
- Laravel Forge API token
- Cloudflare API token + Account ID
- Google Cloud project ID
- Render API key

Credentials are never stored in environment variables or SKILL.md — always read from the local vault at runtime.

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

### Strategy: `forge` — Laravel Forge server + site

**Step A — Create server (if needed):**
```bash
bash <SKILL_DIR>/scripts/forge-create-server.sh <name> <provider> <region> <size> [php_version]
# Example: bash scripts/forge-create-server.sh prod-server hetzner eu-central 1 php84
# Providers: ocean2 (DigitalOcean) | akamai (Linode) | vultr2 | aws | hetzner | custom
# Wait ~10 minutes for provisioning
```

**Step B — Deploy site from Git:**
```bash
bash <SKILL_DIR>/scripts/forge-deploy-site.sh <server_id> <domain> <github_user/repo> [branch]
# Example: bash scripts/forge-deploy-site.sh 12345 myapp.com myorg/myrepo main
# This: creates site, links GitHub repo, requests SSL, triggers first deploy
```

**Then verify:**
```bash
bash <SKILL_DIR>/scripts/verify-deploy.sh https://<domain>
```

---

### Strategy: `cloudflare-domain` — add domain to Cloudflare

```bash
bash <SKILL_DIR>/scripts/cloudflare-add-domain.sh <domain>
# Example: bash scripts/cloudflare-add-domain.sh myapp.com
```

Returns nameservers to set at the domain registrar. After DNS propagation, add records:

```bash
# Point domain to a server IP
bash <SKILL_DIR>/scripts/cloudflare-add-dns.sh myapp.com A 1.2.3.4

# Point domain to a PaaS CNAME (Render, Cloud Run, etc.)
bash <SKILL_DIR>/scripts/cloudflare-add-dns.sh myapp.com CNAME my-app.onrender.com @ true
```

---

### Strategy: `cloudflare-dns` — add/update a DNS record

```bash
bash <SKILL_DIR>/scripts/cloudflare-add-dns.sh <domain> <type> <content> [name] [proxied]
# Examples:
bash scripts/cloudflare-add-dns.sh myapp.com A 1.2.3.4           # A record, proxied
bash scripts/cloudflare-add-dns.sh myapp.com CNAME app.render.com # CNAME @ proxied
bash scripts/cloudflare-add-dns.sh myapp.com CNAME app.render.com www true
```

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
| **Laravel Forge** | ❌ Paid ($12/mo) | None | Any | **Laravel production, managed server** |
| **Cloudflare** | ✅ Free DNS/CDN/WAF | None | — | **Domain + DNS + WAF for any stack** |

## Credential Vault Reference

All sensitive values read from `~/.web-deploy/config.db` at runtime:

| Service | Key | Where to get it |
|---|---|---|
| `forge` | `api_token` | https://forge.laravel.com/user-profile/api |
| `cloudflare` | `api_token` | https://dash.cloudflare.com/profile/api-tokens |
| `cloudflare` | `account_id` | Cloudflare dashboard right sidebar |
| `gcloud` | `project_id` | https://console.cloud.google.com |
| `gcloud` | `region` | e.g. `europe-west1` |
| `render` | `api_key` | https://dashboard.render.com/u/settings#api-keys |
| Laravel Forge | ❌ Paid | None | Any | Laravel production |
