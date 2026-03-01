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

## P0: Critical Bugs

### 1. Session Creation Failure

**Status**: 🚨 **BLOCKING** - Sessions cannot be created or used

**Issue**: Creating a new session fails to properly initialize the session state. When attempting to send a message, the app throws:

```
Failed to send message: Bad state: Session cb28ed0b17eda800a5bcf6b1b not loaded
```

**Impact**: Users cannot use the core chat functionality. The app appears to create a session but it is not properly loaded into the sync state, causing all subsequent operations to fail.

**Likely Causes**:
- Race condition between session creation and sync state update
- Session not being added to `sessionsNotifierProvider` after creation
- Missing or failed `refreshFromSync()` call after session creation
- Sync singleton not properly handling new session events from WebSocket

**Files to Investigate**:
- `lib/core/services/sync_service.dart` - Session creation and sync logic
- `lib/core/providers/app_providers.dart` - Sessions notifier
- `lib/features/sessions/sessions_screen.dart` - Session creation flow
- `lib/features/chat/chat_screen.dart` - Message sending logic

---

## P2: Enhanced Features

### 2. Sessions - Feature Parity

| Task | Description |
|------|-------------|
| Date headers | Group sessions by "Today", "Yesterday", etc. |
| Vibing messages | "Accomplishing...", "Actioning..." animations |

**References**:
- React Native: `/../happy/sources/app/(app)/session/recent.tsx`, `/../happy/sources/sync/storage.ts`

### 3. Chat - Input Enhancements

| Task | Description |
|------|-------------|
| Draft auto-save | Persist message drafts automatically |
| File autocomplete | @file mentions with file picker |
| Command autocomplete | /commands with suggestions |
| Permission mode selector | Dropdown for Browse/Read/Edit modes |
| Profile selector | Switch between AI backends |

**References**:
- React Native: `/../happy/sources/components/AgentInputAutocomplete.tsx`, `/../happy/sources/components/PermissionModeSelector.tsx`

### 4. Settings - Full Implementation

| Task | Description |
|------|-------------|
| Theme settings | Adaptive/light/dark theme selection |
| Language settings | Preferred language with auto-detection |
| Voice settings | ElevenLabs voice assistant language |
| Features toggles | Experiments, markdown copy v2, etc. |
| Profiles management | AI backend profiles (Claude, Gemini, OpenAI) |
| Usage statistics | Token usage, costs, limits display |
| Developer mode | 10x click to enable, debug tools |

**References**:
- React Native: `/../happy/sources/app/(app)/settings/appearance.tsx`, `/../happy/sources/app/(app)/settings/language.tsx`, `/../happy/sources/app/(app)/settings/features.tsx`, `/../happy/sources/app/(app)/settings/profiles.tsx`, `/../happy/sources/app/(app)/settings/usage.tsx`

### 5. Tool Call Rendering

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

### 6. UI Components

| Task | Description |
|------|-------------|
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

### 7. Logging System

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

### 8. Native Platform Integrations

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

### 9. Utilities Parity

| Task | Description |
|------|-------------|
| Device utilities | Phone/tablet detection, header height |
| Advanced debounce | Cancel/reset/flush methods |
| Path utilities | Resolve ~ paths, relative paths |
| AsyncLock | Async mutex/locking |
| Version utilities | Compare semantic versions |
| Message utilities | Strip markdown, get preview |

**References**:
- React Native: `/../happy/sources/utils/calculateDeviceDimensions.ts`, `/../happy/sources/utils/path.ts`

### 10. CI/CD Enhancements

| Task | Description |
|------|-------------|
| Dependency caching | Cache pub-cache, Gradle builds |
| Workflow dispatch | Manual trigger with build type selection |
| Version tags | Auto-build on `v*` tags |
| Artifact retention | Set retention-days |
| Concurrent builds | Cancel redundant runs |

**References**:
- React Native: `/../happy/.github/workflows/`, `/../happy/eas.json`

### 11. Internationalization (i18n)

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
| Session Creation | 🚨 **BLOCKING BUG** | Sessions fail to initialize, message sending throws "not loaded" error |
| Authentication | Done | QR auth, device linking, account restore, backup key |
| Encryption | Done | AES-256-GCM, libsodium, Web Crypto API |
| Chat | Done | Full markdown, syntax highlighting, code blocks |
| Storage | Done | MMKV with migration, drafts, permission modes |
| State | Done | All providers implemented with 63+ tests |
| WebSocket | Done | Socket.io protocol with exponential backoff |
| API | Done | All endpoints implemented with 250+ tests |
| Sessions | Partial | Date headers, vibing messages pending |
| Settings | Partial | Account screen done, other settings stub |
| UI Components | Partial | Needs sidebar, autocomplete, command palette |
| Tool Rendering | Not Started | 15+ tool views needed |
| Logging | Not Started | In-memory logger, dev logs screen |
| Native | Not Started | WebRTC/camera/notifications not started |
| CI/CD | Partial | Debug/release builds, needs enhancement |
| i18n | Not Started | Not started |

---

## Next Steps

1. **URGENT**: Fix session creation bug (P0) - investigate sync state, session initialization
2. **This sprint**: Settings screens (theme, language, features)
3. **Next sprint**: Sessions UI - date headers, vibing messages
4. **This quarter**: Tool call rendering and UI components

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Copy translation strings | Low | i18n foundation |
| Add shimmer loading state | Low | Better UX |
| Add sidebar navigation | Low | Visual parity |
| Add logging service | Low | Better debugging |
