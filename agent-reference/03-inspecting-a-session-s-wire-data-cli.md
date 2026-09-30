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

