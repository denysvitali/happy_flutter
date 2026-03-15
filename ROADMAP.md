# Feature Parity Roadmap

This roadmap tracks the work needed to achieve full feature parity between **happy_flutter** (Flutter) and **happy** (React Native).

**Last Updated**: 2026-03-15

## Project Context

- **Flutter Version**: 3.38.7 (Dart 3.10+)
- **Source of Truth**: `/../happy` (React Native implementation)
- **Goal**: Match all features from the React Native app

---

## Priority Levels

- **P0**: Critical - Blocking features or security issues
- **P1**: High - Core functionality users expect
- **P2**: Medium - Enhanced user experience
- **P3**: Low - Nice to have, polish features

---

## P1: High Priority

### 1. Sessions - Remaining Parity

| Task | Status | Description |
|------|--------|-------------|
| Vibing messages | Not Started | "Accomplishing...", "Actioning..." cycling animations on active session cards. The `thinking` state currently shows no status text (`shouldShowStatus: false`). |

**References**:
- React Native: `/../happy/sources/app/(app)/session/recent.tsx`

### 2. Chat - Input Behavior

| Task | Status | Description |
|------|--------|-------------|
| Wire `agentInputEnterToSend` | Not Started | Setting exists end-to-end (model, provider, storage) but `chat_input.dart` ignores it — hard-codes `textInputAction` based on platform instead of reading the setting |

---

## P2: Enhanced Features

### 3. Offline & Performance

| Task | Status | Description |
|------|--------|-------------|
| Persist messages to MMKV | Not Started | Session messages live only in-memory (`_sessionMessages` map). On cold start, users see a blank screen until HTTP completes. Caching last N messages per session in MMKV would give instant load. |
| Offline message outbox | Not Started | No retry/queue for message sends. If network drops mid-send, the message is silently lost. The `localId` field on `SendMessageRequest`/`SendMessageResponse` already supports server-side dedup. |

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
| Test coverage reporting | Not Started | CI runs `flutter test` pass/fail but no coverage visibility. Add `--coverage` + Codecov upload. |

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
| CI/CD | Done | 4-job pipeline (analyze, test, build-debug, build-release), caching, `v*` tag releases with obfuscation |
| Native | Partial | TTS, video call stubs, push stubs — WebRTC/biometric/audio not started |

---

## Next Steps

1. **Quick win**: Wire `agentInputEnterToSend` setting to chat input (10-line fix)
2. **Quick win**: Add vibing status animations for thinking sessions
3. **This sprint**: Persist session messages to MMKV for instant cold starts
4. **This sprint**: Optimistic mutation layer for instant UI feedback
5. **Next sprint**: Offline message outbox with retry queue
6. **This quarter**: Sidebar navigation for tablet/desktop

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Wire `agentInputEnterToSend` | Very Low | Fixes broken setting, improves core input UX |
| Vibing status animations | Low | Most visible gap vs RN app during agent work |
| Streaming cursor in assistant bubble | Low | Makes AI response feel continuous vs discrete jumps |
| Test coverage in CI | Very Low | One-line CI change, surfaces coverage gaps on every PR |
