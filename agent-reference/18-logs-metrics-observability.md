## Logs & Metrics — Observability

Mobile client telemetry flows three ways: **Loki** for log streams, **Prometheus** for app/server metrics, **GlitchTip** for crash+issue tracking. The Flutter app ships OTel-flavored logs (`scope_name="happy_flutter"`, `scope_version=1.11.x`) via `LoggerService` → OTel collector → Loki.

### Loki (logs)

Service label is `service_name="happy-flutter"` (note the dash, not underscore). Logs carry per-launch identifiers `app_launch_id`, `trace_id`, `span_id` so you can correlate a user report with the exact launch and trace.

**Useful selectors:**

```logql
# All happy-flutter logs (last 1h)
{service_name="happy-flutter"}

# Errors only (compact output, no payload)
{service_name="happy-flutter"} | detected_level="ERROR"

# Warnings + errors
{service_name="happy-flutter"} | detected_level=~"ERROR|WARN"

# Filter by trace_id from a GlitchTip issue
{service_name="happy-flutter"} | trace_id="<hex>"

# Filter by launch
{service_name="happy-flutter"} | app_launch_id="<uuid>"

# Pipeline stage outcomes (raw/normalized/processed/grouped/merged/notified)
{service_name="happy-flutter"} |~ "stage=\\w+ outcome=(error|dropped)"
```

**Pipeline stage vocab:** `raw → normalized → processed → grouped → merged → notified`. Search by `stage=<name>` to follow a single socket payload through the ingestion pipeline.

**Volume policy (DEBUG):** successful `stage=notified outcome=ok` lines are logged once per 5-minute window; the rest of the window is folded into one INFO `outcome=summary suppressed=<n> sessions=<n>` line so the DEBUG sampler cannot discard the count. Every non-`ok` outcome is still logged verbatim, so `outcome=(error|dropped)` greps are unaffected. On top of that, `LoggerService` caps DEBUG **OTel export** at 60/min (120 burst) and samples 1-in-25 beyond it, reporting shed counts as `[logger] dropped … from OTel export`. The local 5000-entry ring buffer behind DevLogsScreen keeps full fidelity.

**Caveat:** `mcp__loki__loki_query` has a token cap (~10k tokens per call); on large queries the result is saved to `~/.claude/projects/.../tool-results/mcp-loki-loki_query-*.txt` and must be read in chunks. Use `head`/`tail`/`limit` to bound the response, and `filter` to reduce noise.

**`mcp__loki` not loaded?** Retry once, say out loud it's broken, then query Loki direct: `http://loki.monitoring.svc.cluster.local:3100` — same LogQL selectors via `/loki/api/v1/query_range`. Don't silently stall or work around it for turns.

### Prometheus (metrics)

App telemetry uses OTel metrics too. Useful base names: `app.*` (e.g. `app.deferredInit` duration, `app.chat.sync.await` stall). Server-side `happy-server` and `happy-daemon` metrics share the Prometheus instance.

Native exports batch logs and spans every 10s and metrics every 60s; the
paused lifecycle event force-flushes pending data. Network counters include
`happy_flutter.http.attempts` (result/cache/attempt),
`happy_flutter.network.link_changes`, and `happy_flutter.socket.dials`.
Developer → Network Inspector retains 500 metadata-only HTTP attempts even in
release builds. A `???` HTTP status can be a DNS, timeout, deadline, or
intentional suspension cancellation; check its cause before treating it as a
server response. Message GET diagnostics retain only numeric `afterSeq` and
`limit` query values, so repeated pagination can be distinguished from
duplicate requests without retaining arbitrary query data. Native header wait
includes DNS, TCP, TLS, and server time. Power Diagnostics counts suspension
cancellations separately from HTTP failures and slow completed requests.

Example:

```promql
# Cold start duration (seconds, last 1h)
histogram_quantile(0.95, sum(rate(app_cold_start_seconds_bucket[5m])) by (le))

# fetchMessages p95
histogram_quantile(0.95, sum(rate(app_fetch_messages_seconds_bucket[5m])) by (le))
```

`mcp__prometheus__prometheus_search` accepts natural-language queries ("cold start time", "fetch messages latency") to discover metric names before writing PromQL.

### GlitchTip (crashes + issues)

Use for **fatal** bugs and issue triage — see the *Production Issues / GlitchTip* section above for the `mcp__glitchtip__` invocation recipe (organization `default`, project `happy_flutter`).

### Server-side Loki

The Rust daemon and Go server are also indexed in Loki:

- `service_name="happy-server"` — Go server
- `service_name="happy-daemon"` — happy-cli daemon

When chasing a Flutter-visible bug (e.g. `CryptoSecretBox.decrypt failed`, `fetchMessages dropped`, `machine offline`), cross-check the Flutter trace_id against the server-side logs for the same window — many "client" errors originate server-side.
