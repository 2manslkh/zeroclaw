# syntax=docker/dockerfile:1.7

# ── Stage 1: Build ────────────────────────────────────────────
FROM rust:1.93-slim@sha256:9663b80a1621253d30b146454f903de48f0af925c967be48c84745537cd35d8b AS builder
WORKDIR /app

RUN --mount=type=cache,id=zeroclaw-apt-cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,id=zeroclaw-apt-lib,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y pkg-config && rm -rf /var/lib/apt/lists/*

# Cache deps first
COPY Cargo.toml Cargo.lock./
COPY crates/robot-kit/Cargo.toml crates/robot-kit/Cargo.toml
RUN mkdir -p src benches crates/robot-kit/src \
 && echo "fn main() {}" > src/main.rs \
 && echo "fn main() {}" > benches/agent_benchmarks.rs \
 && echo "pub fn placeholder() {}" > crates/robot-kit/src/lib.rs
RUN --mount=type=cache,id=zeroclaw-cargo-registry,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,id=zeroclaw-cargo-git,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,id=zeroclaw-target,target=/app/target,sharing=locked \
    cargo build --release --locked
RUN rm -rf src benches crates/robot-kit/src

# Build real binary
COPY src/ src/
COPY benches/ benches/
COPY crates/ crates/
COPY firmware/ firmware/
COPY web/ web/
RUN mkdir -p web/dist && \
    if [! -f web/dist/index.html ]; then \
      printf '%s\n' \
        '<!doctype html>' \
        '<html lang="en"><head><meta charset="utf-8"/>' \
        '<meta name="viewport" content="width=device-width,initial-scale=1"/>' \
        '<title>ZeroClaw Dashboard</title></head>' \
        '<body><h1>ZeroClaw Dashboard Unavailable</h1>' \
        '<p>Build the web UI to populate <code>web/dist</code>.</p></body></html>' \
        > web/dist/index.html; \
    fi
RUN --mount=type=cache,id=zeroclaw-cargo-registry,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,id=zeroclaw-cargo-git,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,id=zeroclaw-target,target=/app/target,sharing=locked \
    cargo build --release --locked && cp target/release/zeroclaw /app/zeroclaw && strip /app/zeroclaw

# Prepare data dirs (no baked config) + dual-process entry wrapper (bash for job control)
RUN mkdir -p /zeroclaw-data/.zeroclaw /zeroclaw-data/workspace \
 && printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -Eeuo pipefail' \
    '# Always clear any stale config so flags/env take precedence' \
    'rm -f /zeroclaw-data/.zeroclaw/config.toml' \
    'export ZEROCLAW_WORKSPACE=/zeroclaw-data/workspace' \
    'export HOME=/zeroclaw-data' \
    '# Bind gateway to Railway-provided PORT and all interfaces' \
    'export ZEROCLAW_GATEWAY_PORT="${PORT:-42617}"' \
    'export ZEROCLAW_GATEWAY_HOST="${ZEROCLAW_GATEWAY_HOST:-0.0.0.0}"' \
    '' \
    'PROVIDER="${ZEROCLAW_PROVIDER:-openrouter}"' \
    'MODEL="${ZEROCLAW_MODEL:-openrouter/hunter-alpha}"' \
    'API_KEY="${ZEROCLAW_API_KEY:-}"' \
    'if [ -z "$API_KEY" ]; then echo "ERROR: ZEROCLAW_API_KEY is empty"; exit 1; fi' \
    '' \
    'echo "[entry] starting gateway on ${ZEROCLAW_GATEWAY_HOST}:${ZEROCLAW_GATEWAY_PORT}"' \
    'zeroclaw --provider "$PROVIDER" --api-key "$API_KEY" --model "$MODEL" gateway &' \
    'GATEWAY_PID=$!' \
    'sleep 1' \
    '' \
    'echo "[entry] starting daemon (channels) in foreground"' \
    'zeroclaw --provider "$PROVIDER" --api-key "$API_KEY" --model "$MODEL" daemon &' \
    'DAEMON_PID=$!' \
    '' \
    'term() { echo "[entry] stopping..."; kill -TERM "$GATEWAY_PID" "$DAEMON_PID" 2>/dev/null || true; wait; }' \
    'trap term INT TERM' \
    '' \
    'wait -n "$GATEWAY_PID" "$DAEMON_PID"' \
    'exit_code=$?' \
    'echo "[entry] a process exited with $exit_code; shutting down the other"' \
    'kill -TERM "$GATEWAY_PID" "$DAEMON_PID" 2>/dev/null || true' \
    'wait || true' \
    'exit $exit_code' \
    > /entrypoint.sh && chmod +x /entrypoint.sh

# ── Stage 2: Runtime (Debian slim with nonroot user) ─────────
FROM debian:trixie-slim@sha256:f6e2cfac5cf956ea044b4bd75e6397b4372ad88fe00908045e9a0d21712ae3ba AS release
RUN apt-get update && apt-get install -y ca-certificates curl tini bash procps && rm -rf /var/lib/apt/lists/* \
 && useradd -u 65532 -m -s /usr/sbin/nologin nonroot

COPY --from=builder /app/zeroclaw /usr/local/bin/zeroclaw
COPY --from=builder /zeroclaw-data /zeroclaw-data
COPY --from=builder /entrypoint.sh /entrypoint.sh

ENV ZEROCLAW_WORKSPACE=/zeroclaw-data/workspace \
    HOME=/zeroclaw-data \
    # Railway injects PORT; bind to it. Local fallback 42617.
    ZEROCLAW_GATEWAY_PORT=${PORT:-42617}

WORKDIR /zeroclaw-data
USER 65532:65532
EXPOSE 42617
ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
# Entrypoint now launches BOTH: gateway (bg) + daemon (fg). No CMD needed.
