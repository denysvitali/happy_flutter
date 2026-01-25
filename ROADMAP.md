# Feature Parity Roadmap

This roadmap tracks the work needed to achieve full feature parity between **happy_flutter** (Flutter) and **happy** (React Native).

## Changelog

### 2025-01-25 - Authentication (P1 #4) ✅ COMPLETED
- **Link Device Feature**: Full parity with React Native implementation
  - QR code generation and scanning
  - Device linking via QR code and URL input
  - Deep link handling (`happy://` protocol)
- **Account Management**:
  - Secret key backup with Crockford's base32 encoding (`XXXXX-XXXXX-XXXXX...`)
  - Account restoration from backup key
  - Linked devices management (view/unlink)
  - Connected services display (Claude, GitHub, Gemini, OpenAI)
- **Tests**: 80+ comprehensive tests added
  - `test/services/auth_service_test.dart` - Auth URL parsing, credentials, exceptions
  - `test/encryption/crypto_box_test.dart` - Encryption/decryption roundtrip
  - `test/utils/backup_key_utils_test.dart` - Backup key encoding/decoding
- **Documentation**: `docs/LINK_DEVICE_FEATURE_PARITY.md` - Detailed analysis

---

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

## P0: Critical Security & Compatibility

### 1. True AES-256-GCM Encryption
**Issue**: Current implementation fakes AES-GCM using CryptoSecretBox
**Impact**: Encrypted data from React Native cannot be decrypted by Flutter

| Task | Description |
|------|-------------|
| Replace fake AES implementation | Implement actual AES-256-GCM using platform crypto |
| Android native module | Integrate `rn-encryption` equivalent or use platform channels |
| iOS native module | Integrate CommonCrypto or CryptoKit |
| Cross-platform compatibility | Ensure same encryption format as React Native |

**References**:
- React Native: `/../happy/sources/encryption/aes.ts` (uses `rn-encryption`)
- Flutter current: `/lib/core/encryption/encryptor.dart:85-126`

### 2. libsodium Integration
**Issue**: Different nonce sizes and algorithms (24 bytes vs 16 bytes)
**Impact**: Cannot decrypt React Native session/machine data

| Task | Description |
|------|-------------|
| Add libsodium package | Use `libsodium_ffi` or equivalent |
| Align nonce sizes | Match 24-byte nonce from libsodium |
| Update key derivation | Match React Native's HKDF implementation |

**References**:
- React Native: `@more-tech/react-native-libsodium`
- Flutter current: `/lib/core/encryption/crypto_box.dart`, `crypto_secret_box.dart`

### 3. Web Platform Encryption
**Issue**: Encryption throws `UnimplementedError` on web
**Impact**: App cannot function on web platform

| Task | Description |
|------|-------------|
| Implement Web Crypto API | Use browser's SubtleCrypto for AES-GCM |
| Polyfill NaCl operations | Web-compatible crypto_box/crypto_secretbox |
| Test web encryption | Verify encryption/decryption in browser |

**References**:
- React Native: `/../happy/sources/encryption/libsodium.lib.web.ts`

---

## P1: Core Features

### 4. Authentication - Account Management ✅ **COMPLETED**
**Status**: Link Device feature has full parity with React Native

| Task | Description | Status |
|------|-------------|--------|
| Secret key backup UI | Format key as "XXXXX-XXXXX-XXXXX..." (base32 with dashes) | ✅ Done |
| Account restoration screen | Input backup key, validate and restore account | ✅ Done |
| Device linking via QR | Scan QR on other device, approve via deep link | ✅ Done |
| Connected services UI | Display/disconnect Claude, GitHub, Gemini, OpenAI | ✅ Done |

**What's Implemented**:
- QR code generation and scanning (`lib/features/auth/auth_screen.dart`)
- Device linking with QR and URL input (`lib/features/settings/account_screen.dart`)
- Account restore from backup key (`RestoreAccountScreen`)
- Linked devices management (`LinkedDevicesScreen`)
- Deep link handling (`happy://` protocol)
- Comprehensive tests (80+ tests in `test/services/`, `test/encryption/`, `test/utils/`)

**Documentation**:
- Feature parity analysis: `docs/LINK_DEVICE_FEATURE_PARITY.md`
- Protocol documentation: `docs/PROTOCOL.md`

**References**:
- React Native: `/../happy/sources/auth/secretKeyBackup.ts`, `/../happy/sources/app/(app)/settings/account.tsx`
- Flutter: `/lib/core/services/auth_service.dart`, `/lib/features/settings/account_screen.dart`

### 5. Chat - Full Markdown Rendering
**Missing**: Tables, mermaid diagrams, option buttons, text selection

| Task | Description |
|------|-------------|
| Full markdown parser | Support H1-H6, tables, lists, links |
| Mermaid diagram rendering | Add `mermaid` package or custom renderer |
| Interactive option buttons | Handle `@option` markdown blocks |
| Long-press text selection | Copy text functionality |

**References**:
- React Native: `/../happy/sources/components/markdown/MarkdownView.tsx`, `MermaidRenderer.tsx`

### 6. Chat - Syntax Highlighting
**Missing**: Language detection, bracket nesting colors, copy button

| Task | Description |
|------|-------------|
| Syntax highlighter widget | Tokenize keywords, strings, comments, etc. |
| Bracket nesting colors | 5 colors for depth visualization |
| Copy code button | Hover-to-reveal copy functionality |
| Language auto-detection | Detect from code block or file extension |

**References**:
- React Native: `/../happy/sources/components/SimpleSyntaxHighlighter.tsx`

### 7. Storage - MMKV Migration
**Issue**: Using SharedPreferences instead of MMKV
**Impact**: Slower performance, missing key features

| Task | Description |
|------|-------------|
| Add flutter_mmkv | Replace SharedPreferences with MMKV |
| Session drafts persistence | Store per-session draft messages |
| Session permission modes | Persist permission mode per session |
| Profile storage | Load/save user profile data |
| Server config storage | Separate MMKV instance for server URL |

**References**:
- React Native: `/../happy/sources/sync/persistence.ts`, `/../happy/sources/sync/serverConfig.ts`

### 8. State Management - Missing Providers
**Missing**: Git status, artifacts, profile, friends, feed

| Task | Description |
|------|-------------|
| Git status provider | Per-session git status tracking |
| Artifacts provider | Store encrypted artifacts (files, images) |
| Profile provider | User profile with name, avatar, GitHub |
| Friends provider | Social features, friend requests |
| Feed provider | Activity feed, notifications |
| Todo state provider | Todo list with drag-and-drop |

**References**:
- React Native: `/../happy/sources/sync/storage.ts`, `/../happy/sources/sync/storageTypes.ts`

### 9. WebSocket - Socket.io Protocol
**Issue**: Custom JSON protocol vs Socket.io with built-in ack/reconnect

| Task | Description |
|------|-------------|
| Socket.io client | Implement Socket.io protocol or update server |
| Exponential backoff | Add backoff utility with min/max delay |
| Auto-reconnect | Built-in reconnection with ack support |
| Event handlers | Match React Native's messageHandlers Map |

**References**:
- React Native: `/../happy/sources/sync/apiSocket.ts`

---

## P1: API Coverage

### 10. Missing API Endpoints
**Missing**: KV store, push notifications, GitHub, services, usage

| Task | Description |
|------|-------------|
| KV Store API | `/v1/kv/*` - key-value storage operations |
| Push notifications | Register push tokens, handle notifications |
| GitHub integration | Profile and operations API |
| Connected services | Connect/disconnect third-party services |
| Usage statistics | Track API usage and costs |

**References**:
- React Native: `/../happy/sources/sync/apiKv.ts`, `/../happy/sources/sync/apiPush.ts`, `/../happy/sources/sync/apiGithub.ts`

---

## P2: Enhanced Features

### 11. Sessions - Feature Parity
**Missing**: Date grouping, avatars, enhanced status, vibing messages

| Task | Description |
|------|-------------|
| Date headers | Group sessions by "Today", "Yesterday", etc. |
| Session avatars | Support brutalist, gradient, pixelated styles |
| Enhanced status states | disconnected, thinking, waiting, permission_required |
| Vibing messages | "Accomplishing...", "Actioning..." animations |
| Active sessions section | Separate group for currently active sessions |

**References**:
- React Native: `/../happy/sources/app/(app)/session/recent.tsx`, `/../happy/sources/sync/storage.ts`

### 12. Chat - Input Enhancements
**Missing**: Draft auto-save, autocomplete, permission selector, profile selector

| Task | Description |
|------|-------------|
| Draft auto-save | Persist message drafts automatically |
| File autocomplete | @file mentions with file picker |
| Command autocomplete | /commands with suggestions |
| Permission mode selector | Dropdown for Browse/Read/Edit modes |
| Profile selector | Switch between AI backends |

**References**:
- React Native: `/../happy/sources/components/AgentInputAutocomplete.tsx`, `/../happy/sources/components/PermissionModeSelector.tsx`

### 13. Settings - Full Implementation
**Missing**: Theme, language, voice, features, profiles, account, usage

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

### 14. Tool Call Rendering
**Missing**: Known tools views, permission UI, status indicators

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

### 15. UI Components
**Missing**: Avatar, sidebar, autocomplete, shimmer, command palette

| Task | Description |
|------|-------------|
| Avatar component | Multiple styles: brutalist, gradient, pixelated, circle |
| Sidebar navigation | Collapsible sidebar with navigation |
| Shimmer loading | Loading skeleton states |
| Command palette | Modal command search (7 files) |
| Status bar provider | Dynamic status bar theming |
| Diff view | Git diff rendering |
| Tab bar | Bottom/app tab navigation |

**References**:
- React Native: `/../happy/sources/components/Avatar.tsx`, `/../happy/sources/components/SidebarView.tsx`, `/../happy/sources/components/ShimmerView.tsx`, `/../happy/sources/components/CommandPalette/`

---

## P2: Error Handling & Diagnostics

### 16. Logging System
**Missing**: In-memory logger, dev logs screen, remote logging

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

### 17. Native Platform Integrations
**Missing**: WebRTC, camera, notifications, biometrics, location

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

### 18. Utilities Parity
**Missing**: Device detection, advanced debounce, path utilities

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

### 19. CI/CD Enhancements
**Missing**: Caching, flavors, multi-env, workflow dispatch

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

### 20. Internationalization (i18n)
**Missing**: Multi-language support, translations

| Task | Description |
|------|-------------|
| i18n framework | Add flutter_localization package |
| Translation strings | Extract all strings to translation files |
| Language selector | UI to switch languages (15+ languages) |
| RTL support | Right-to-left layout support |

**References**:
- React Native: `/../happy/sources/text/_default.ts`, `expo-localization`

---

## Data Models to Add

| Model | Purpose | Priority |
|-------|---------|----------|
| `Artifact` | File attachments | P1 |
| `DecryptedArtifact` | UI-ready artifact | P1 |
| `Profile` | User profile (name, avatar, GitHub) | P1 |
| `UserProfile` | Friend user profile | P1 |
| `RelationshipStatus` | Friend status enum | P1 |
| `FeedItem` | Activity feed posts | P2 |
| `NormalizeMessage` | Fully normalized message | P2 |
| `RawAgentContent` | Content blocks (text, tool_use, tool_result) | P2 |

**References**:
- React Native: `/../happy/sources/sync/artifactTypes.ts`, `/../happy/sources/sync/profile.ts`, `/../happy/sources/sync/friendTypes.ts`

---

## Testing Strategy

### Priority Test Areas
1. **Encryption round-trip** - Verify Flutter can decrypt React Native data
2. **Authentication flow** - QR auth, token refresh, sign out
3. **WebSocket reconnection** - Auto-reconnect on disconnect
4. **State persistence** - Verify settings/sessions survive app restart
5. **Markdown rendering** - Test tables, code blocks, mermaid diagrams

---

## Quick Wins

| Task | Effort | Impact |
|------|--------|--------|
| Copy translation strings | Low | i18n foundation |
| Add shimmer loading state | Low | Better UX |
| Copy avatar component styles | Low | Visual parity |
| Add exponential backoff utility | Low | Reliability |
| Copy error types from React Native | Low | Better debugging |

---

## Progress Tracking

| Category | Status | Notes |
|----------|--------|-------|
| Authentication | ✅ **Done** | QR auth, device linking, account restore, backup key all implemented |
| Encryption | Blocked | Needs true AES-GCM before data migration |
| Chat | Basic | Scaffold exists, needs markdown/syntax highlighting |
| Sessions | Basic | List exists, needs avatars/date grouping |
| Settings | Partial | Account screen implemented, other settings stub |
| Storage | Partial | SharedPreferences, needs MMKV |
| State | Partial | Core providers exist, missing artifacts/profile |
| WebSocket | Custom | Needs Socket.io protocol alignment |
| API | Partial | Core endpoints exist, missing KV/push/GitHub |
| UI Components | Minimal | Needs avatar, sidebar, autocomplete |
| Error Handling | Partial | Error types exist, logging missing |
| Native | None | WebRTC/camera/notifications not started |
| CI/CD | Basic | Debug/release builds, needs enhancement |
| i18n | None | Not started |

---

## Next Steps

1. **Immediate**: Fix AES encryption compatibility (P0)
2. **This sprint**: Full markdown rendering (P1 #5)
3. **Next sprint**: Syntax highlighting for code blocks (P1 #6)
4. **This quarter**: Complete settings screens (P2)

**Recent Wins**:
- ✅ **Authentication (P1 #4)**: Complete implementation with 80+ tests
- ✅ **Link Device**: Full parity with React Native
- ✅ **Account Management**: Backup, restore, device linking all working
