---
name: glitchtip-triage
description: Triage happy_flutter production issues in GlitchTip — list unresolved issues, pull event details, cross-check Loki, detect stale-build false alarms, and update ROADMAP. Use when the user says "triage glitchtip", "check production issues", "latest crashes", or asks for a GlitchTip audit.
---

# GlitchTip Triage

Recurring audit workflow for happy_flutter production issues. Organization `default`, project `happy_flutter`.

## 1. List issues

```text
mcp__glitchtip__.list_issues(
  organization_slug: "default",
  project_slug: "happy_flutter",
  query: "is:unresolved",
  sort: "-last_seen",
  limit: 15
)
```

Omit `query` to include resolved issues (useful for verifying a fix stuck).

## 2. Per-issue detail

For each actionable issue, call `mcp__glitchtip__.get_latest_event(issue_id: <id>)` and inspect tags, **release/build number**, environment, device, breadcrumbs, stack.

If the GlitchTip MCP times out or the event body is missing, fall back to the direct API with `curl` (this happened during the June 2026 partition outage — metadata survived, bodies were DLQ'd).

## 3. Stale-build check (do this BEFORE diagnosing)

Many "still broken" reports are unreleased fixes, not new defects. Heuristic:

1. Read the build number from the event's `release` tag (e.g. `1.0.0+192001`).
2. Compare against the latest git tag: `git tag --sort=-creatordate | head -5`.
3. If a fix commit exists on main, check whether it predates the reporting build:
   `git merge-base --is-ancestor <fix-sha> <release-tag>` — if the fix is NOT an ancestor of the build the user runs, the report is stale, not a regression.

Releases are automatic on every commit to `main`, so "fix on main" means "ships with next build" — a device can still lag behind.

## 4. Cross-check Loki

Every event carries `trace_id` / `app_launch_id`. Correlate:

```logql
{service_name="happy-flutter"} | trace_id="<hex>"
```

Also check server-side for the same window — many "client" errors originate server-side:
- `{service_name="happy-server"}` (Go server)
- `{service_name="happy-daemon"}` (Rust/Go daemon)

See the `loki-trace` skill for query caveats (token cap, chunked results).

## 5. Report + update ROADMAP

- Summarize per issue: severity, count, root-cause hypothesis, whether a fix exists on main, whether the reporting build predates the fix.
- Update the **Production Bugs** table in `ROADMAP.md` with new issues or status changes.
- **Never resolve or ignore GlitchTip issues** unless the user explicitly asks, or the task is to close verified-fixed issues.
