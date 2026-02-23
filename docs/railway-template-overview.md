# Railway Template Overview

Deploy ZeroClaw to [Railway](https://railway.com) in one click.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/8Q-7oo?referralCode=gGZ7iz&utm_medium=integration&utm_source=template&utm_campaign=generic)

---

## 1. Summary

- **Purpose:** Provide a one-click deployment path for ZeroClaw on Railway.
- **Audience:** Operators and developers who want a managed cloud deployment without maintaining their own infrastructure.
- **Scope:** Template architecture, environment variables, build pipeline, and post-deploy configuration.
- **Non-goals:** Self-hosted Docker Compose setups (see [network-deployment.md](network-deployment.md)), local development, Raspberry Pi deployment.

## 2. What the Template Deploys

| Component | Detail |
|---|---|
| **Service** | ZeroClaw gateway (HTTP/WebSocket API) |
| **Image** | Multi-stage Dockerfile, `release` target |
| **Base image** | `gcr.io/distroless/cc-debian13:nonroot` |
| **Binary size** | ~8.8 MB (stripped, LTO, `opt-level = "z"`) |
| **Runtime memory** | < 5 MB baseline |
| **User** | Non-root (UID 65534) |
| **Health check** | `GET /health` (10 s timeout) |
| **Restart policy** | On failure, max 3 retries |

## 3. Prerequisites

- A [Railway account](https://railway.com)
- An LLM provider API key (OpenRouter, OpenAI, Anthropic, Gemini, Groq, etc.)

## 4. One-Click Deploy

1. Click the **Deploy on Railway** button above (or in the project README).
2. Railway prompts for environment variables — at minimum set **`API_KEY`**.
3. Railway builds the Dockerfile `release` stage and starts the gateway.
4. Once the health check passes, your instance is live at the Railway-assigned URL.

## 5. Environment Variables

### Required

| Variable | Description |
|---|---|
| `API_KEY` | LLM provider API key. Can also use provider-specific keys (`OPENROUTER_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, etc.) |

### Optional

| Variable | Default | Description |
|---|---|---|
| `PROVIDER` | `openrouter` | LLM provider name (`openrouter`, `openai`, `anthropic`, `gemini`, `groq`, `mistral`, `deepseek`, `ollama`, etc.) |
| `ZEROCLAW_MODEL` | `anthropic/claude-sonnet-4-20250514` | Model identifier in provider-specific format |
| `ZEROCLAW_TEMPERATURE` | `0.7` | Sampling temperature (0.0–2.0) |
| `ZEROCLAW_ALLOW_PUBLIC_BIND` | `true` | Allow binding to public interfaces (must be `true` on Railway) |
| `ZEROCLAW_GATEWAY_HOST` | `0.0.0.0` | Gateway bind address |

### Port Handling

Railway injects a `PORT` environment variable automatically. ZeroClaw reads it via the fallback chain:

```
ZEROCLAW_GATEWAY_PORT → PORT → config.toml default (42617)
```

No manual port configuration is needed on Railway.

## 6. Template Files

### `railway.toml`

Build and deploy configuration consumed by Railway at deploy time.

```toml
[build]
dockerfilePath = "Dockerfile"
buildTarget = "release"

[deploy]
startCommand = "zeroclaw gateway"
healthcheckPath = "/health"
healthcheckTimeout = 10
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

### `railway.json`

Template definition for the Railway marketplace. Declares environment variables with descriptions, defaults, and required flags so the deploy UI prompts users correctly.

## 7. Build Pipeline

The Dockerfile `release` stage runs a two-phase build:

1. **Dependency cache** — copies `Cargo.toml`/`Cargo.lock`, builds dependencies with dummy source files, then removes them. This layer is cached across rebuilds.
2. **Source build** — copies actual source, compiles `--release --locked`, strips the binary.
3. **Runtime** — copies the ~8.8 MB binary into a distroless image with no shell, no package manager, and non-root execution.

Railway's Docker builder handles all of this automatically from the Dockerfile.

## 8. Post-Deploy Configuration

### Connecting Channels

The gateway deployment exposes the HTTP/WebSocket API. To connect chat channels (Telegram, Discord, Slack, etc.), switch the start command to `daemon` mode:

1. In Railway service settings, change the start command to:
   ```
   zeroclaw daemon
   ```
2. Add the relevant channel environment variables (e.g., `TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`).
3. Redeploy.

See [channels-reference.md](channels-reference.md) for per-channel setup.

### Persistent Storage

ZeroClaw stores workspace data under `/zeroclaw-data/`. On Railway, add a [volume](https://docs.railway.com/reference/volumes) mounted at `/zeroclaw-data` to persist configuration, memory, and conversation state across redeploys.

### Custom Domain

Railway provides a generated URL by default. To use a custom domain, configure it in Railway's service settings under **Networking > Custom Domains**.

## 9. Troubleshooting

- **Health check fails immediately**
  - Cause: Missing `API_KEY` or invalid provider configuration.
  - Fix: Verify `API_KEY` is set and matches the selected `PROVIDER`.

- **Port binding error**
  - Cause: `ZEROCLAW_ALLOW_PUBLIC_BIND` not set.
  - Fix: Ensure it is `true` (set by default in the template).

- **Build timeout**
  - Cause: First build compiles all Rust dependencies from scratch (~5–10 min).
  - Fix: Subsequent builds use cached layers and are much faster. No action needed.

- **503 after deploy**
  - Cause: Gateway not yet ready or health check path mismatch.
  - Fix: Wait for the health check to pass. Verify the Railway service logs show `gateway listening`.

## 10. Resource Recommendations

| Tier | CPU | Memory | Use Case |
|---|---|---|---|
| **Starter** | 0.5 vCPU | 512 MB | Personal use, low traffic |
| **Standard** | 1 vCPU | 1 GB | Moderate traffic, multiple channels |
| **Production** | 2 vCPU | 2 GB | High traffic, concurrent users |

ZeroClaw's baseline footprint (< 5 MB RAM, < 10 ms cold start) means even the smallest Railway plan works well for personal use.

## 11. Related Docs

- [Config reference](config-reference.md)
- [Providers reference](providers-reference.md)
- [Channels reference](channels-reference.md)
- [Network deployment](network-deployment.md)
- [Operations runbook](operations-runbook.md)
- [Troubleshooting](troubleshooting.md)
