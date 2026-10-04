## Inspecting a Session's Wire Data (CLI)

- **Session ids are opaque hex strings** (e.g. `c948d14cf2c6fc0573379cbb1`). They are *not* git SHAs and are distinct from the `claudeSessionId` (UUID) and `machineId` (UUID) shown in the metadata. If a pasted hex id fails `git rev-parse` / `git cat-file`, treat it as a session id, not a commit.
- Use the **`happy` CLI** (the binary on PATH is `happy` — not `haply`) to decrypt and dump a session's metadata, messages, sidechains, and process state. This is the fastest way to see the raw wire shape behind a UI rendering bug (a workflow run's `workflowProgress` / sidechain `children`, encrypted message bodies, tool-call input/result):

```bash
happy debug session <session-id>                                       # human-readable; 20 oldest messages
happy debug session <session-id> --tail                                 # most recent messages
happy debug session <session-id> --messages 500                         # widen the window (cap it — full transcripts are large)
happy debug session <session-id> --json --no-process --no-diagnostics   # raw JSON bodies for jq/rg
happy debug session <session-id> --all --remote                         # everything, incl. owning daemon/machine
```

  Useful flags: `--last-message`, `--no-messages`, `--no-process`, `--no-diagnostics`, `--remote`. Sibling verbs under `happy debug`: `bundle` (redacted tarball for bug reports), `doctor`, `logs`, `status`, `config`, `repair-sessions`.

For native Codex children, inspect `agentMetadata` on the Agent input, child
payloads, and terminal result. It carries reported role, model, reasoning effort,
and thread status. Each present map replaces the previous snapshot, including
`{}` to clear stale values; absence means no snapshot update. Later child
metadata can fill an initially empty anchor. Thread status is separate from
task completion: `idle` or `notLoaded` does not prove a successful task.
Thread-reported model settings are not per-turn billing telemetry. Missing child
values must not fall back to the coordinator's model or permission mode.
Effective sandbox and approval policy are shown only when reported for that
child; otherwise the details view says they are not reported. A read-only role
describes its assignment and does not by itself establish enforced permissions.
