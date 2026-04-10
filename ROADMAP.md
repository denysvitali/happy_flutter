# Roadmap

This roadmap tracks upcoming features and improvements for **happy_flutter**.

**Last Updated**: 2026-04-10

## P0: Core Messaging & Session Reliability

The app lives or dies on one invariant:

`one user tap -> one stable localId -> one optimistic row -> one persisted message -> one retry identity -> one final merged message`

The current test count is not enough if this contract can break without failing CI. Before adding more feature work, the core send path needs explicit contract coverage.

### Immediate Test Priorities

| Task | Status | Description |
|------|--------|-------------|
| Canonical message identity contract tests | In Progress | Add a dedicated suite that asserts a single `localId` survives optimistic UI, REST send, socket forwarding, outbox retry, server ack, and merge. |
| Repeated identical send tests | In Progress | Cover `continue`/same-text repeated sends and prove they produce distinct `localId`s and distinct logical messages. |
| Optimistic replacement invariants | Done | Added contract coverage asserting that server-acked messages replace the exact optimistic placeholder by `localId`, never by text similarity or list position, including repeated identical user text. |
| Retry identity invariants | Done | Added contract coverage proving explicit retry preserves the original `localId` and logical message, while a fresh user resend creates a new `localId` and a second logical message. |
| Out-of-order delivery tests | In Progress | Added coverage for REST success before a later socket echo and REST success before a later fetch overlap. Remaining gaps: socket echo before fetch and broader duplicate-broadcast sequencing. |
| Core messaging state-machine tests | Not Started | Model `draft -> sending -> sent/pending/failed -> merged` explicitly and test valid/invalid transitions. |
| User-visible core E2E scenarios | Not Started | Add E2E coverage for rapid follow-ups, background/resume mid-send, disconnected socket with successful REST persistence, and follow-up sends while the agent is still thinking. |
| Invariant telemetry | Not Started | Emit counters/logs for unmatched optimistic rows, duplicate `localId`s, unknown acked `localId`s, and retry-created duplicates. |

### Production Bugs (from GlitchTip, Apr 2026)

| Issue | Severity | Count | Status | Description |
|-------|----------|-------|--------|-------------|
| InvalidateSync disposed crash | Fatal | 55 | Fix on main (1ba4ebc), **needs release** | App suspend races with in-flight `invalidateAndAwait()`; `dispose()` now completes normally instead of throwing `StateError`. Production build 113001 predates fix. |
| Null check operator (chat load) | Fatal | 9 | Open | `TypeError: Null check operator used on a null value` during `chat.screen.load`. Obfuscated stack — needs debug build repro. |
| Null check operator (general) | Error | 12 | Open | Same TypeError, different call site. Active since Apr 2, last seen Apr 9. |
| Back button error rate | Error | 3/8 (37.5%) | Open | `StandardComponentType.backButton` click action failing intermittently. |
| CryptoSecretBox.decrypt failed | Warning | 27 | Open | Decryption failures — possible key mismatch on legacy NaCl messages or corrupt ciphertext. |
| Stale profile in ChatScreen | Warning | 9 | Open | Saved profile ID no longer exists in settings after profile deletion; should clear stale reference. |
| Machine offline on session create | Warning | 33 | Open | No pre-check guard — user can tap "create session" on an offline machine. UX should disable or warn. |
| fetchMessages dropped (output filter) | Warning | ~180 | Open | Large batches of messages dropped during fetch for output data/filter reasons. Needs investigation. |

### Performance (from GlitchTip)

| Metric | Value | Target | Notes |
|--------|-------|--------|-------|
| App cold start (`root /`) | avg 4.6s, p95 9.3s | < 3s avg | Includes deferred init (1.9s avg). Profile on real device to find bottlenecks. |
| fetchMessages p95 | up to 54s (outlier sessions) | < 5s | Sessions with very large message histories. Consider pagination limits or incremental fetch. |
| Deferred init | avg 1.9s | < 1s | `app.deferredInit` transaction — audit what's being loaded eagerly. |

### Engineering Rule

For core chat flows, no layer may invent a second message identity when a canonical `localId` already exists. UI, sync, retry, and merge code must all use the same identifier.

## Project Context

- **Flutter Version**: 3.38.7 (Dart 3.10+)

---

## Priority Levels

- **P0**: Critical - Blocking features or security issues
- **P1**: High - Core functionality users expect
- **P2**: Medium - Enhanced user experience
- **P3**: Low - Nice to have, polish features

---

## P1: High Priority

*All P1 items completed.*

---

## P2: Enhanced Features

### 3. Offline & Performance

| Task | Status | Description |
|------|--------|-------------|
| Persist messages to MMKV | Done | `MessageCacheService` caches last 200 messages per session in MMKV. Loaded on app start via `_restoreAllCachedMessages()`. Debounced writes (500ms) via `_scheduleSaveMessages()`. |
| Offline message outbox | Done | `MessageOutbox` service persists failed sends to MMKV with exponential backoff retry (1s→2s→4s→max 30s, max 3 retries). Restored on startup via `restoreAndFlush()`. |

### 4. Optimistic Mutations

| Task | Status | Description |
|------|--------|-------------|
| Optimistic mutation layer | Not Started | All state mutations are pessimistic (wait for server round-trip + WebSocket echo). An `OptimisticMutation<T>` primitive that patches provider state immediately and rolls back on failure would make every action feel instant. |

### 5. Sidebar Navigation

| Task | Status | Description |
|------|--------|-------------|
| Collapsible sidebar | Not Started | Tab bar exists but no sidebar for tablet/desktop layouts. Referenced in multiple RN components. |

---

## P3: Polish Features

### 6. Native Platform Integrations

| Task | Status | Description |
|------|--------|-------------|
| WebRTC/LiveKit | Partial | `video_call_service.dart` exists with stubs |
| Push notifications | Partial | Service exists, notification test screen in dev tools |
| Biometric auth | Not Started | Face ID, Touch ID, fingerprint |
| Audio recording | Not Started | Voice input for chat |

**References**:
- React Native: `@livekit/react-native-webrtc`, `expo-camera`, `expo-notifications`, `expo-local-authentication`

### 7. CI/CD Enhancements

| Task | Status | Description |
|------|--------|-------------|
| Test coverage reporting | Done | CI runs `flutter test --coverage` with Codecov upload on every push. |

---

## Progress Tracking

| Category | Status | Notes |
|----------|--------|-------|
| Authentication | Done | QR auth, device linking, account restore, backup key |
| Encryption | Done | AES-256-GCM (new), NaCl/libsodium (legacy), key derivation |
| Chat | Done | Full markdown, syntax highlighting, code blocks, TTS |
| Chat Input | Done | Draft auto-save, @file autocomplete, /command autocomplete, permission mode selector, profile selector, abort |
| Storage | Done | MMKV with migration, drafts, permission modes, FlutterSecureStorage for secrets |
| State | Done | 16 providers, all notifiers implemented |
| WebSocket | Done | Socket.IO with reconnect, inline message fast path, 100ms debounce |
| API | Done | All endpoints with 250+ tests |
| Sessions | Done | Date headers ("Today", "Yesterday"), session cards, status indicators |
| Session Creation | Done | Optimistic placeholder, 60s `_sessionSpawnedAt` registry, 3-attempt recovery in `sendMessage` |
| Settings | Done | Theme, language, voice, features, profiles, usage, developer, server, machines, changelog, Claude Connect (16 screens) |
| Tool Rendering | Done | 19 tool-specific views, KnownTools registry (30+ variants), PermissionFooter, elapsed time, auto-collapse, tool error display |
| Logging | Done | `LoggerService` (5000-entry circular buffer), `DevLogsScreen` (filter/search/copy/clear), Sentry forwarding, `RemoteLogger`, `ErrorBoundary`, `ErrorSnackbarManager` |
| UI Components | Done | Shimmer loading, command palette, diff view, tab bar, avatars, status bar theming |
| Dev Tools | Done | Dev logs, encryption debug, network inspector, notification test, session debug |
| i18n | Partial | Framework in place (`flutter: generate: true`), 10 locale ARB files (en, es, fr, de, ca, it, ja, pl, pt, ru, zh, zh_Hans), 4 generated. More languages may need translation coverage. |
| CI/CD | Done | 7-job pipeline (analyze, test + coverage, golden, build-debug, build-release, build-web, deploy-web), caching, `v*` tag releases with obfuscation, Codecov |
| Native | Partial | TTS, video call stubs, push stubs — WebRTC/biometric/audio not started |

---

## Next Steps

1. **Immediate**: Cut a production release to ship the InvalidateSync dispose fix (1ba4ebc) — 55 fatal crashes/day
2. **This sprint**: Investigate and fix the two Null check operator fatals (chat.screen.load + general)
3. **This sprint**: Fix back button 37.5% error rate
4. **This sprint**: Guard session creation against offline machines (UX warning/disable)
5. **This sprint**: Clean up stale profile references in ChatScreen
6. **Next sprint**: Optimistic mutation layer for instant UI feedback
7. **Next sprint**: Profile and reduce cold start time (avg 4.6s → target < 3s)
8. **This quarter**: Sidebar navigation for tablet/desktop

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Ship InvalidateSync fix to production | Very Low | Tag a release — eliminates 55 fatal crashes/day |
| Guard offline machine in NewSessionDialog | Low | Disable create button or show warning when machine offline — eliminates 33 warnings/day |
| Clear stale profile references | Low | On profile deletion, clear sessionId→profileId mappings — eliminates 9 warnings/day |
| Streaming cursor in assistant bubble | Low | Makes AI response feel continuous vs discrete jumps |
