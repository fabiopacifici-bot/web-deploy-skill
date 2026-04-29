# Architecture Decision Record — web-deploy-skill

**Progetto:** web-deploy-skill
**Data:** 2026-04-29
**Autore:** Olly (NSA Agency)

## Decisione

Build a language-agnostic deployment skill (`web-deploy`) that any agent (Kernel, OpenClaw, Copilot Agent) can execute to take a Dockerised web app from local to a public URL. Supports multiple deployment targets via a strategy pattern in the SKILL.md instructions.

## Contesto

The Multistack AI Developer course (Week 3) requires students to deploy a real web app to a public URL as the week deliverable. Students come from different backgrounds, have different budgets, and target different platforms. The skill must:

- Work cross-platform (Mac, Windows, Linux) — Docker is the common denominator
- Be executable by Kernel via `exec_shell` (any language, any stack)
- Be usable by Copilot Agent Mode and Claude in VS Code
- Cover multiple deployment targets without requiring expertise in any one
- Be reusable every week (W3 web, W4 desktop, W6 data) — not a one-off

The skill is not a deployment framework. It is a documented procedure with shell commands that an agent reads and executes. The "intelligence" lives in the SKILL.md instructions; the runtime is the agent.

## Piattaforme e strategie supportate

| Strategy | Best for | Free | Complexity |
|---|---|---|---|
| `cloudflare-tunnel` | Docker local → public URL instantly | ✅ | ⭐ |
| `google-cloud-run` | Docker image → scalable serverless | ✅ 2M req/month | ⭐⭐ |
| `render` | Full-stack persistent hosting | ✅ no sleep | ⭐⭐ |
| `netlify` | Static / JAMstack frontends | ✅ | ⭐ |
| `aws-app-runner` | Docker → AWS managed | ⚠️ 12mo free | ⭐⭐⭐ |
| `vercel` | Next.js / Nuxt / static | ✅ | ⭐ |

## Componenti principali

1. `SKILL.md` — main skill file with frontmatter, decision tree, per-strategy instructions
2. `scripts/check-prereqs.sh` — verifies Docker, CLI tools, auth are ready before deploy
3. `scripts/deploy-cloudflare-tunnel.sh` — Cloudflare Tunnel deploy (primary path)
4. `scripts/deploy-gcloud-run.sh` — Google Cloud Run deploy
5. `scripts/deploy-render.sh` — Render deploy via API
6. `scripts/deploy-netlify.sh` — Netlify static deploy
7. `scripts/verify-deploy.sh` — checks the live URL returns 200, reports latency
8. `.specs/plans/` — planning documents
9. `README.md` — human-readable setup guide

## Decisioni architetturali

- **SKILL.md as the entry point, not a CLI tool:** The skill is invoked by an agent reading instructions, not a custom binary. This keeps it agent-agnostic — any agent that can read a file and run shell commands can execute it.
- **Docker as the common denominator:** All strategies assume the app runs in a Docker container. Students have Docker from Week 2. This eliminates platform-specific setup (Node version managers, PHP environments, etc.).
- **Cloudflare Tunnel as the primary path:** Zero new accounts, works with existing Docker setup, public URL in 30 seconds. Perfect for demos and Week 3 deliverables.
- **Google Cloud Run as the secondary path:** Best free tier for Docker-native apps (2M req/month), one command deploy, scales to zero. Better for persistent deployments.
- **Strategy selection by agent:** The skill instructs the agent to ask the user which strategy they want (or infer from context), then execute the corresponding script. No hardcoded single path.
- **verify-deploy.sh always runs last:** Every strategy ends with a URL verification step. The deliverable is a working public URL, not a successful CLI command.

## Vincoli

- NO framework-specific logic inside the skill (no Laravel-specific, no FastAPI-specific)
- NO secrets or API keys in any script — all injected via environment variables or prompted at runtime
- Scripts must be idempotent — running twice should not break the deployment
- Must work on Mac (arm64), Windows (WSL2), Linux without modification
- Cloudflare Tunnel path must work without a Cloudflare account (using the free `cloudflared` quick tunnel)

## Cosa NON è in scope

- Database migrations (handled by the app's own Dockerfile or entrypoint)
- CI/CD pipeline setup (covered separately in Week 4 GitHub Actions)
- SSL certificate management (handled by the platform)
- Custom domain configuration (mentioned but not automated)
- AWS EC2 / VPS management (too complex for Week 3)
- Laravel Forge (paid, Week 9+ final project)
