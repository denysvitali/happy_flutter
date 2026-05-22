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

### Production Bugs (from GlitchTip, May 2026)

| Issue | Severity | Count | Status | Description |
|-------|----------|-------|--------|-------------|
| InvalidateSync disposed crash | Fatal | 55 | Shipped in v1.0.0-154901 (1ba4ebc) | App suspend races with in-flight `invalidateAndAwait()`; `dispose()` now completes normally instead of throwing `StateError`. |
| Null check operator (chat load) | Fatal | 9 | Shipped in v1.0.0-154901 (51f1189) | `session!.permissionMode!` and `selectedProfile!.defaultModelMode` force-unwraps in `_loadInitialSettings` when async gap allowed session/profile to become null. Fixed with safe pattern-matching (`case final x?`). Residual GlitchTip events (HAPPY_FLUTTER-17O/3C0/382) are historical aggregate; no new shape identified in audit 2026-05-22. |
| Null check operator (general) | Error | 12 | Shipped in v1.0.0-154901 (51f1189) | Same root cause as above. |
| Isolate unsendable Future | Error | 3 | Shipped in v1.0.0-152XXX+ (7b69d1b, 84ff0c2) | `Isolate.run` closure was capturing `this` in offline TTS / AES decrypt isolates; switched to top-level worker with sendable POD args. |
| ttsUseOffline unknown settings key | Fatal | 1 | Shipped in v1.0.0-XXXX (e051f35); telemetry b7cee41 on main | Settings dispatcher dropped unknown legacy keys instead of throwing; Sentry breadcrumb now captures dropped keys for context. |
| sherpa-onnx not initialized (TTS fallback noise) | Warning | 4 | Fix on main (9135fbd), **needs release** | `OfflineTtsService` now records FFI probe failures and short-circuits to system TTS via typed `OfflineTtsException`; one info breadcrumb per process replaces ~one Sentry capture per `speak()`. |
| Sidechain orphans absorbed | Warning | 100+ | Fix on main (35db8c4), **needs release** | Sentry capture gated to `triedFetchOlder && hasMoreOlder && count≥5`; normal happy-path absorption now local-info-only. |
| Resume sessions sync timeout | Error | 6 | Fix on main (0621440), **needs release** | `TimeoutException` on resume is now caught and logged at info; underlying sync still completes via `onDataChanged`. |
| Resume conversation progress timeout | Warning | 6 | Fix on main (0621440), **needs release** | Safety-timer fallback demoted from Sentry warning to local info log. |
| Ref used in disposed widget (sessions dismissible) | Error | 1 | Fix on main (6a4776b), **needs release** | `ref.read` and `context.l10n` hoisted before `showDialog` await in `session_dismissible.dart` so swipe-and-unmount can't trigger StateError. |
| Back button error rate | Error | 3/8 (37.5%) | Open | `StandardComponentType.backButton` click action failing intermittently. |
| CryptoSecretBox.decrypt failed | Warning | 27 | Open | Decryption failures — possible key mismatch on legacy NaCl messages or corrupt ciphertext. |
| Stale profile in ChatScreen | Warning | 9 | Shipped in v1.0.0-154901 (51f1189) | `_loadInitialSettings` now catches `StateError` from `firstWhere` and falls back to no profile, clearing the stale `savedProfileId` from `DraftStorage`. |
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

1. **Immediate**: Cut a production release after v1.0.0-154901 to ship the May 2026 GlitchTip-driven fixes (TTS probe short-circuit, sync resume timeout demotion, sidechain orphan gating, ref-in-dispose hoist)
2. **This sprint**: Fix back button 37.5% error rate
3. **This sprint**: Guard session creation against offline machines (UX warning/disable)
4. **This sprint**: Investigate `CryptoSecretBox.decrypt failed` warnings (27 events)
5. **Next sprint**: Optimistic mutation layer for instant UI feedback
6. **Next sprint**: Profile and reduce cold start time (avg 4.6s → target < 3s)
7. **This quarter**: Sidebar navigation for tablet/desktop

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Ship next production release | Very Low | Tag a release — propagates 5 May 2026 fixes to users (TTS noise, sidechain noise, resume timeouts, ref-in-dispose) |
| Guard offline machine in NewSessionDialog | Low | Disable create button or show warning when machine offline — eliminates 33 warnings/day |
| Streaming cursor in assistant bubble | Low | Makes AI response feel continuous vs discrete jumps |
