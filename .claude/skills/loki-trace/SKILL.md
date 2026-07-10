---
name: loki-trace
description: Trace a happy_flutter issue across client and server logs in Loki using trace_id / app_launch_id correlation. Use when the user says "check the logs", "trace this error", "why did this fail in prod", or when a GlitchTip event needs server-side correlation.
---

# Cross-Service Loki Tracing

Three log streams share one Loki. Correlate by `trace_id` (per-trace) or `app_launch_id` (per-launch, Flutter only).

| Service label | What |
|---------------|------|
| `service_name="happy-flutter"` | Flutter app (note the **dash**, not underscore) |
| `service_name="happy-server"` | Go server |
| `service_name="happy-daemon"` | happy-cli daemon |

## Standard queries

```logql
# Client errors, last window
{service_name="happy-flutter"} | detected_level=~"ERROR|WARN"

# Follow one trace (from a GlitchTip event's trace_id tag)
{service_name="happy-flutter"} | trace_id="<hex>"

# One app launch end-to-end
{service_name="happy-flutter"} | app_launch_id="<uuid>"

# Ingestion pipeline failures (stage vocab: raw → normalized → processed → grouped → merged → notified)
{service_name="happy-flutter"} |~ "stage=\\w+ outcome=(error|dropped)"
```

## Cross-check pattern

Many "client" errors (`CryptoSecretBox.decrypt failed`, `fetchMessages dropped`, `machine offline`) originate server-side. For the same time window as the client error, query `happy-server` and `happy-daemon` with the same `trace_id` (or just the window if the ID isn't propagated).

## Tool caveats

- `mcp__loki__loki_query` has a ~10k-token cap. Large results are saved to `~/.claude/projects/.../tool-results/mcp-loki-loki_query-*.txt` — read in chunks with the Read tool (offset/limit), don't cat the whole file.
- Bound every query: use `limit`, tight time ranges, and `filter` to cut noise BEFORE widening.
- If the Loki MCP times out (seen during the GlitchTip partition outage), `curl` the Loki HTTP API directly.
- Levels: only `LogLevel.warning` and above are forwarded outside dev mode — a missing debug line in Loki is expected, not evidence.

## Escalation

- Client-side crash context → GlitchTip (`glitchtip-triage` skill).
- Metrics-shaped questions (latency, rates) → Prometheus: `mcp__prometheus__prometheus_search` with natural language first, then PromQL (`app.*` metrics, e.g. `app_cold_start_seconds_bucket`, `app_fetch_messages_seconds_bucket`).
- Distributed traces → Jaeger (`mcp__jaeger__search_traces`) with the same trace_id.
