# web-deploy-skill

Deploy any Dockerised web app to a public URL in one skill invocation.

## What it does

- Supports 6 deployment targets: Cloudflare Tunnel, Google Cloud Run, Render, Netlify, Vercel, AWS App Runner
- Language-agnostic — any stack that runs in Docker
- Executable by any agent: Kernel, OpenClaw, Copilot Agent Mode, Claude
- Built for the Multistack AI Developer course (Week 3+)

## Quick start

**Fastest (no account needed):**
```bash
bash scripts/check-prereqs.sh cloudflare-tunnel
docker run -d -p 8000:8000 my-app
bash scripts/deploy-cloudflare-tunnel.sh 8000
```

**Free persistent hosting:**
```bash
gcloud auth login
bash scripts/deploy-gcloud-run.sh my-app my-app-service europe-west1
```

## Add to Kernel

```bash
# Clone into Kernel's ecosystem
git clone https://github.com/fabiopacifici-bot/web-deploy-skill ~/.kernel/ecosystem/skills/web-deploy

# Restart Kernel to pick up the new skill
curl -s -X POST http://localhost:8769/message -H "Content-Type: application/json" -d '{"message": "/restart"}'
```

Then use from Kernel:
```
/skill web-deploy
```

Or tell Kernel: `"deploy my app to a public URL using cloudflare tunnel on port 8000"`

## Use with Copilot Agent / Claude

Drag `SKILL.md` into the agent context and say:
> "Execute the web-deploy skill for my app running on port 8000 using cloudflare-tunnel strategy"

## Strategies

| Strategy | Command | Free | Account needed |
|---|---|---|---|
| `cloudflare-tunnel` | `bash scripts/deploy-cloudflare-tunnel.sh <port>` | ✅ | No |
| `gcloud-run` | `bash scripts/deploy-gcloud-run.sh <image> <service>` | ✅ | Google account |
| `render` | `bash scripts/deploy-render.sh` | ✅ | Render account |
| `netlify` | `bash scripts/deploy-netlify.sh <dir>` | ✅ | Netlify account |
| `vercel` | `vercel --prod` | ✅ | Vercel account |
| `aws-app-runner` | see SKILL.md | ⚠️ 12mo | AWS account |

## Structure

```
web-deploy-skill/
├── ADR.md                              ← Architecture decisions
├── SKILL.md                            ← Agent entry point
├── README.md                           ← This file
├── .specs/plans/implementation.md      ← Build plan
└── scripts/
    ├── check-prereqs.sh
    ├── deploy-cloudflare-tunnel.sh
    ├── deploy-gcloud-run.sh
    ├── deploy-render.sh
    ├── deploy-netlify.sh
    └── verify-deploy.sh
```
