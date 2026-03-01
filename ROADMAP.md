# Feature Parity Roadmap

This roadmap tracks the work needed to achieve full feature parity between **happy_flutter** (Flutter) and **happy** (React Native).

**Last Updated**: 2026-03-01

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

## Completed Features

All P0 and P1 features are complete:

- ✅ **Encryption**: AES-256-GCM, libsodium, Web Crypto API
- ✅ **Authentication**: QR auth, device linking, account restore, backup key
- ✅ **Chat**: Full markdown rendering, syntax highlighting, code blocks
- ✅ **Storage**: MMKV migration, session drafts, permission modes
- ✅ **State Management**: Profile, git status, artifacts, friends, feed, todos
- ✅ **WebSocket**: Socket.io protocol, exponential backoff, auto-reconnect
- ✅ **API Coverage**: KV store, push notifications, GitHub, services, usage

---

## P2: Enhanced Features

### 1. Sessions - Feature Parity 🔄 **PARTIAL**

| Task | Description | Status |
|------|-------------|--------|
| Date headers | Group sessions by "Today", "Yesterday", etc. | ⏳ Pending |
| Session avatars | Support brutalist, gradient, pixelated styles | ✅ Done |
| Enhanced status states | disconnected, thinking, waiting, permission_required | ✅ Done |
| Vibing messages | "Accomplishing...", "Actioning..." animations | ⏳ Pending |
| Active sessions section | Separate group for currently active sessions | ✅ Done |

**References**:
- React Native: `/../happy/sources/app/(app)/session/recent.tsx`, `/../happy/sources/sync/storage.ts`

### 2. Chat - Input Enhancements

| Task | Description |
|------|-------------|
| Draft auto-save | Persist message drafts automatically |
| File autocomplete | @file mentions with file picker |
| Command autocomplete | /commands with suggestions |
| Permission mode selector | Dropdown for Browse/Read/Edit modes |
| Profile selector | Switch between AI backends |

**References**:
- React Native: `/../happy/sources/components/AgentInputAutocomplete.tsx`, `/../happy/sources/components/PermissionModeSelector.tsx`

### 3. Settings - Full Implementation

| Task | Description |
|------|-------------|
| Theme settings | Adaptive/light/dark theme selection |
| Language settings | Preferred language with auto-detection |
| Voice settings | ElevenLabs voice assistant language |
| Features toggles | Experiments, markdown copy v2, etc. |
| Profiles management | AI backend profiles (Claude, Gemini, OpenAI) |
| Account screen | Profile, connected services, secret key backup |
| Usage statistics | Token usage, costs, limits display |
| Developer mode | 10x click to enable, debug tools |

**References**:
- React Native: `/../happy/sources/app/(app)/settings/appearance.tsx`, `/../happy/sources/app/(app)/settings/language.tsx`, `/../happy/sources/app/(app)/settings/features.tsx`, `/../happy/sources/app/(app)/settings/account.tsx`, `/../happy/sources/app/(app)/settings/profiles.tsx`, `/../happy/sources/app/(app)/settings/usage.tsx`

### 4. Tool Call Rendering

| Task | Description |
|------|-------------|
| Known tools views | 15+ tool-specific UI components |
| Tool icons | Display tool-specific icons |
| Elapsed time | Show how long tool has been running |
| Permission handling | Show permission request UI (PermissionFooter) |
| Tool error display | Error messages with styling |
| Expandable sections | Input/Output sections with headers |

**References**:
- React Native: `/../happy/sources/components/tools/knownTools.tsx`, `/../happy/sources/components/tools/ToolView.tsx`

### 5. UI Components

| Task | Description |
|------|-------------|
| Avatar component | Multiple styles: brutalist, gradient, pixelated, circle |
| Sidebar navigation | Collapsible sidebar with navigation |
| Shimmer loading | Loading skeleton states |
| Command palette | Modal command search |
| Status bar provider | Dynamic status bar theming |
| Diff view | Git diff rendering |
| Tab bar | Bottom/app tab navigation |

**References**:
- React Native: `/../happy/sources/components/Avatar.tsx`, `/../happy/sources/components/SidebarView.tsx`, `/../happy/sources/components/ShimmerView.tsx`, `/../happy/sources/components/CommandPalette/`

---

## P2: Error Handling & Diagnostics

### 6. Logging System

| Task | Description |
|------|-------------|
| Logger service | Keep last 5000 logs in memory with listeners |
| Dev logs screen | View, copy, clear logs (debug builds only) |
| Remote logging | Monkey-patch console.log for AI debugging |
| Tool error parser | Parse `<tool_use_error>` tags |
| Error boundary | Centralized error display/snackbar |

**References**:
- React Native: `/../happy/sources/log.ts`, `/../happy/sources/app/(app)/dev/logs.tsx`, `/../happy/sources/utils/remoteLogger.ts`

---

## P3: Polish Features

### 7. Native Platform Integrations

| Task | Description |
|------|-------------|
| WebRTC/LiveKit | Audio/video calls support |
| Camera access | QR scanning for device linking |
| Push notifications | Remote/local notifications |
| Biometric auth | Face ID, Touch ID, fingerprint |
| Location services | GPS, background location |
| Audio recording | Voice input integration |
| Haptic feedback | Vibration on interactions |
| Keep awake | Prevent screen sleep |

**References**:
- React Native: `@livekit/react-native-webrtc`, `expo-camera`, `expo-notifications`, `expo-local-authentication`

### 8. Utilities Parity

| Task | Description |
|------|-------------|
| Device utilities | Phone/tablet detection, header height |
| Advanced debounce | Cancel/reset/flush methods |
| Path utilities | Resolve ~ paths, relative paths |
| Exponential backoff | Delay calculation with backoff |
| AsyncLock | Async mutex/locking |
| Version utilities | Compare semantic versions |
| Message utilities | Strip markdown, get preview |

**References**:
- React Native: `/../happy/sources/utils/calculateDeviceDimensions.ts`, `/../happy/sources/utils/path.ts`

### 9. CI/CD Enhancements

| Task | Description |
|------|-------------|
| Dependency caching | Cache pub-cache, Gradle builds |
| Build flavors | development/preview/production environments |
| Workflow dispatch | Manual trigger with build type selection |
| Version tags | Auto-build on `v*` tags |
| Artifact retention | Set retention-days |
| Concurrent builds | Cancel redundant runs |

**References**:
- React Native: `/../happy/.github/workflows/`, `/../happy/eas.json`

### 10. Internationalization (i18n)

| Task | Description |
|------|-------------|
| i18n framework | Add flutter_localization package |
| Translation strings | Extract all strings to translation files |
| Language selector | UI to switch languages (15+ languages) |
| RTL support | Right-to-left layout support |

**References**:
- React Native: `/../happy/sources/text/_default.ts`, `expo-localization`

---

## Progress Tracking

| Category | Status | Notes |
|----------|--------|-------|
| Authentication | ✅ Done | QR auth, device linking, account restore, backup key all implemented |
| Encryption | ✅ Done | AES-256-GCM, libsodium, Web Crypto API |
| Chat | ✅ Done | Full markdown, syntax highlighting, code blocks |
| Sessions | 🔄 Partial | Date headers, vibing messages pending |
| Settings | 🔄 Partial | Account screen done, other settings stub |
| Storage | ✅ Done | MMKV with migration, drafts, permission modes |
| State | ✅ Done | All providers implemented with 63+ tests |
| WebSocket | ✅ Done | Socket.io protocol with exponential backoff |
| API | ✅ Done | All endpoints implemented with 250+ tests |
| UI Components | 🔄 Partial | Needs sidebar, autocomplete, command palette |
| Tool Rendering | ⏳ Not Started | 15+ tool views needed |
| Error Handling | 🔄 Partial | Error types exist, logging missing |
| Native | ⏳ Not Started | WebRTC/camera/notifications not started |
| CI/CD | 🔄 Partial | Debug/release builds, needs enhancement |
| i18n | ⏳ Not Started | Not started |

---

## Next Steps

1. **This sprint**: Settings screens (theme, language, features)
2. **Next sprint**: Sessions UI - date headers, vibing messages
3. **This quarter**: Tool call rendering and UI components
4. **This quarter**: Logging system and error handling

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Copy translation strings | Low | i18n foundation |
| Add shimmer loading state | Low | Better UX |
| Add sidebar navigation | Low | Visual parity |
| Add logging service | Low | Better debugging |
