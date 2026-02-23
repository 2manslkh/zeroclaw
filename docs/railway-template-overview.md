# Deploy and Host ZeroClaw on Railway

ZeroClaw is a Rust-first autonomous agent runtime optimized for performance, security, and extensibility. It provides an HTTP/WebSocket gateway for LLM-powered agents, supports multiple model providers (OpenRouter, OpenAI, Anthropic, Gemini, Groq, and more), and connects to chat channels like Telegram, Discord, and Slack — all from a single lightweight binary under 9 MB.

## About Hosting ZeroClaw

Deploying ZeroClaw involves building a statically compiled Rust binary inside a multi-stage Docker pipeline. The release image uses a distroless base (`gcr.io/distroless/cc-debian13:nonroot`) with no shell or package manager, running as a non-root user for minimal attack surface. Railway handles the Docker build automatically — you provide an LLM provider API key, and the template configures port binding, health checks, and restart policies. The resulting service exposes an HTTP/WebSocket API gateway with a baseline memory footprint under 5 MB and sub-10 ms cold starts.

## Common Use Cases

- **Personal AI agent** — Deploy a private LLM-powered assistant accessible via API or chat channels for personal productivity.
- **Multi-channel bot** — Run a single ZeroClaw instance connected to Telegram, Discord, and Slack simultaneously for community or team support.
- **LLM API gateway** — Expose a unified HTTP/WebSocket endpoint that routes requests to any supported model provider with built-in resilience and observability.

## Dependencies for ZeroClaw Hosting

- A [Railway account](https://railway.com)
- An LLM provider API key (OpenRouter, OpenAI, Anthropic, Gemini, Groq, Mistral, DeepSeek, etc.)

### Deployment Dependencies

- [ZeroClaw GitHub repository](https://github.com/zeroclaw-labs/zeroclaw)
- [Railway template](https://railway.com/deploy/8Q-7oo?referralCode=gGZ7iz&utm_medium=integration&utm_source=template&utm_campaign=generic)
- [Providers reference](providers-reference.md) — supported LLM providers and configuration
- [Channels reference](channels-reference.md) — per-channel setup for Telegram, Discord, Slack, etc.
- [Config reference](config-reference.md) — full configuration options

### Implementation Details

The `railway.toml` configures the build and deploy pipeline:

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

Key environment variables:

| Variable | Default | Description |
|---|---|---|
| `API_KEY` | *(required)* | LLM provider API key |
| `PROVIDER` | `openrouter` | LLM provider name |
| `ZEROCLAW_MODEL` | `anthropic/claude-sonnet-4-20250514` | Model identifier |
| `ZEROCLAW_TEMPERATURE` | `0.7` | Sampling temperature (0.0–2.0) |

Railway injects `PORT` automatically. ZeroClaw reads it via the fallback chain: `ZEROCLAW_GATEWAY_PORT` → `PORT` → config default (42617).

To connect chat channels, change the start command to `zeroclaw daemon` and add the relevant channel tokens (e.g., `TELEGRAM_BOT_TOKEN`, `DISCORD_BOT_TOKEN`).

## Why Deploy ZeroClaw on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying ZeroClaw on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
