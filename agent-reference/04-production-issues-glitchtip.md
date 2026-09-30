## Production Issues / GlitchTip

- **Use GlitchTip for app issue checks** when asked about app crashes,
  production errors, regressions, or latest issues.
- **Scope:** organization `default`, project `happy_flutter`.
- If GlitchTip tools are not loaded, run `tool_search` for
  `glitchtip latest issues`.
- To list active app issues:

```text
mcp__glitchtip__.list_issues(
  organization_slug: "default",
  project_slug: "happy_flutter",
  query: "is:unresolved",
  sort: "-last_seen",
  limit: 15
)
```

- To list latest events including resolved issues, omit `query`:

```text
mcp__glitchtip__.list_issues(
  organization_slug: "default",
  project_slug: "happy_flutter",
  sort: "-last_seen",
  limit: 10
)
```

- For actionable issues, call
  `mcp__glitchtip__.get_latest_event(issue_id: <id>)` and inspect tags,
  release, environment, device, breadcrumbs, and stack data.
- Do not resolve or ignore GlitchTip issues unless the user asks for that
  action, or the task is explicitly to close verified fixed issues.

