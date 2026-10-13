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

### Agent child steps

Flutter emits bounded INFO `[sidechain]` JSON records with `stage=grouping` or
`stage=child_screen`. Match `session_id` and the selected `tool_use_id` to the
CLI's child-step records; these identifiers are log/trace fields, never metric
labels. Records include resident/grouped/flat unmatched counts and any reported
`child_steps_version` / `child_steps_revision`. Missing capability metadata is
unknown, including on older working bridges. `resident_only` and `truncated`
prevent a bounded snapshot from being mistaken for complete history.

Jaeger operations are `app.sidechain.grouping`, `app.sidechain.child_screen`,
and `prime_agent.child_steps.poll` on the CLI. Native polls report finite stage
and reason codes for read failures and skipped work, plus roster, transcript,
forwarded, duplicate, and deferred counts. Look at those operation spans rather
than interpreting an agent lifetime span as spawn latency.

Prometheus exports CLI counters `happy_prime_agent_child_polls_total` and
`happy_prime_agent_child_steps_total`. Flutter records
`app.sidechain.incoming_linked_rows`, `app.sidechain.ingress_truncated`,
`app.sidechain.grouping_reports`, and `app.sidechain.child_screen_reports`.
Incoming rows count ingestion occurrences, including repeated fetches; reports
count emitted diagnostic snapshots. They are not a durable message balance.
CLI forwarded counts mean durable queue admission, rather than a server ACK.
Discover the exported metric spelling before querying it.

```logql
{service_name="happy-flutter"} |= "[sidechain]" |= "<session-id>"
{service_name="happy-agent"} |= "child_steps" |= "<session-id>"
```

These signals require the updated app/CLI to be running on the reporting device
and owning host. A successful build does not establish that runtime acceptance.
Updating Flutter alone does not replace the owning host's Happy bridge or an
existing session process. CLI snapshots identify their source commit in
`cli_version` (for example, `0.0.0-next+abcdef1`); legacy constant
`v0.0.0-next` cannot distinguish installed builds. Compare the running bridge's
capability/revision with the intended source and inspect the daemon's managed
update status. Missing capability alone is not proof of an older executable.

### Server-side Loki

The Rust daemon and Go server are also indexed in Loki:

- `service_name="happy"` — Go server
- `service_name="happy-daemon"` — happy-cli daemon

When chasing a Flutter-visible bug (e.g. `CryptoSecretBox.decrypt failed`, `fetchMessages dropped`, `machine offline`), cross-check the Flutter trace_id against the server-side logs for the same window — many "client" errors originate server-side.
