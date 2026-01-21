# TODO - Flutter Implementation Gap Analysis

This document tracks the missing features when comparing the Flutter implementation at `happy_flutter` with the React Native implementation at `../happy`.

## Architecture & Infrastructure

### Critical Missing Components

1. **Local Database / Data Persistence**
   - React Native: Uses MMKV for fast local storage with complex data structures
   - Flutter: Only has basic SharedPreferences (no structured data storage)
   - Impact: No offline support, no local caching of sessions/messages
   - Files to reference: `../happy/sources/sync/storage.ts`

2. **Encryption Service**
   - React Native: Full libsodium integration for end-to-end encryption
   - Flutter: `encryption_service.dart` is a placeholder (no real encryption)
   - Impact: Cannot decrypt encrypted messages from server
   - Files to reference: `../happy/sources/encryption/`, `../happy/sources/sync/encryption/`

3. **WebSocket RPC & Real-time Updates**
   - React Native: Socket.IO with automatic reconnection, RPC calls, encryption
   - Flutter: Basic WebSocket with no reconnection or RPC
   - Files to reference: `../happy/sources/sync/apiSocket.ts`

## Authentication

### Missing Features

1. **OAuth Integration**
   - React Native: Full OAuth flow with PKCE, WebView handling (`OAuthView.tsx`)
   - Flutter: QR code auth only
   - Files to reference: `../happy/sources/components/OAuthView.tsx`

2. **Auth Challenge/Response**
   - React Native: Sodium-based crypto challenge-response
   - Flutter: Basic token storage only
   - Files to reference: `../happy/sources/auth/authChallenge.ts`, `../happy/sources/auth/authApprove.ts`

3. **Multiple Auth Methods**
   - React Native: Supports QR auth, OAuth, account linking
   - Flutter: QR auth only

## API Client

### Missing Features

1. **Retry Mechanism with Backoff**
   - React Native: `backoff` utility wrapper for all API calls
   - Flutter: No retry logic
   - Files to reference: `../happy/sources/utils/time.ts` (backoff function)

2. **Schema Validation**
   - React Native: Zod schemas for all API responses
   - Flutter: No validation
   - Files to reference: `../happy/sources/sync/apiTypes.ts`

3. **Modular API Structure**
   - React Native: Separate files for each API domain (services, artifacts, feed, friends, etc.)
   - Flutter: Single generic ApiClient class
   - Files to reference:
     - `../happy/sources/sync/apiServices.ts`
     - `../happy/sources/sync/apiArtifacts.ts`
     - `../happy/sources/sync/apiFeed.ts`
     - `../happy/sources/sync/apiFriends.ts`
     - `../happy/sources/sync/apiPush.ts`
     - `../happy/sources/sync/apiVoice.ts`

4. **User CA Certificate Support**
   - React Native: Native module integration for custom certificates
   - Flutter: `CertificateProvider` returns null (not implemented)
   - Files to reference: `../happy/plugins/withNetworkSecurityConfig.js`

## Settings & Configuration

### Missing Features

1. **AI Backend Profiles**
   - React Native: Full profile system with Anthropic, OpenAI, Azure, Together AI configs
   - Flutter: Basic settings only
   - Files to reference: `../happy/sources/sync/settings.ts` (AIBackendProfileSchema)

2. **Environment Variable Configuration**
   - React Native: `${VAR}` and `${VAR:-default}` template support
   - Flutter: Hardcoded values only
   - Impact: Cannot configure different AI backends

3. **Favorite Directories & Machines**
   - React Native: Persistent favorites for quick access
   - Flutter: Not implemented

4. **CLI Warning Dismissal Tracking**
   - React Native: Per-machine and global dismissal tracking
   - Flutter: Not implemented

### App Configuration

1. **Runtime Config Overrides**
   - React Native: EXPO_PUBLIC_* env vars override baked config at runtime
   - Flutter: Compile-time only
   - Files to reference: `../happy/sources/sync/appConfig.ts`

## Features & Screens

### Missing Screens/Components

1. **Chat/Message Display**
   - React Native: Full message rendering with markdown, code blocks, diffs
   - Flutter: Basic placeholder only
   - Files to reference:
     - `../happy/sources/components/MessageView.tsx`
     - `../happy/sources/components/markdown/`
     - `../happy/sources/components/tools/`

2. **Tool Call Display**
   - React Native: Specialized views for each tool type (Bash, Edit, Task, etc.)
   - Flutter: No tool rendering
   - Files to reference:
     - `../happy/sources/components/tools/ToolFullView.tsx`
     - `../happy/sources/components/tools/views/`

3. **Feed/Social Features**
   - React Native: User feed, friend requests, profiles
   - Flutter: Not implemented
   - Files to reference:
     - `../happy/sources/sync/apiFeed.ts`
     - `../happy/sources/sync/apiFriends.ts`

4. **Artifacts**
   - React Native: Artifact creation, viewing, updating
   - Flutter: Not implemented
   - Files to reference: `../happy/sources/sync/apiArtifacts.ts`

5. **Voice Integration**
   - React Native: LiveKit integration for voice chat
   - Flutter: Not implemented
   - Files to reference: `../happy/sources/realtime/`

## State Management

### Missing Infrastructure

1. **Sync State Manager**
   - React Native: Complex `Sync` class with InvalidateSync for data freshness
   - Flutter: Basic Riverpod providers only
   - Files to reference: `../happy/sources/sync/sync.ts` (1000+ lines)

2. **Reducer System**
   - React Native: Event-based reducer with activity accumulation
   - Flutter: No equivalent
   - Files to reference: `../happy/sources/sync/reducer/`

3. **Session/Message Storage**
   - React Native: Local MMKV database of all sessions and messages
   - Flutter: No local storage
   - Files to reference: `../happy/sources/sync/storage.ts`

## UI/UX

### Missing Components

1. **Keyboard Handling**
   - React Native: `react-native-keyboard-controller` for smooth keyboard avoidance
   - Flutter: Basic keyboard handling

2. **Safe Area/Insets**
   - React Native: Dynamic safe area handling
   - Flutter: SafeArea widget

3. **Pull to Refresh**
   - React Native: Implemented on lists
   - Flutter: Not implemented

4. **Lottie Animations**
   - React Native: Lottie for loading states
   - Flutter: Not implemented

## Dependencies to Add

```
# Encryption
- libsodium (need Flutter equivalent: flutter_sodium || pointycastle)

# Database
- drift (SQLite ORM) or isar (NoSQL)

# WebSocket
- socket_io_client (if using Socket.IO protocol)

# Validation
- json_annotation + json_serializable
- freezed for immutable types

# UI
- lottie (animations)
- flutter_markdown (already have)

# HTTP
- dio (already have)
- retry package (dio_retry)

# Platform
- flutter_secure_storage (already have)
- path_provider for file storage
```

## Priority Implementation Order

### Phase 1 - Core Infrastructure
1. Add proper encryption (port from `../happy/sources/encryption/`)
2. Add local database (drift or isar)
3. Fix WebSocket with reconnection

### Phase 2 - Authentication
1. Add OAuth flow
2. Add auth challenge-response
3. Multiple auth methods

### Phase 3 - API & Sync
1. Add retry mechanism with backoff
2. Add schema validation
3. Implement modular API structure
4. Implement sync state manager

### Phase 4 - Features
1. Message display (markdown, code, diffs)
2. Tool call rendering
3. Sessions list with real data
4. Settings with profiles

### Phase 5 - Polish
1. Offline support
2. Caching
3. Pull to refresh
4. Animations

## File Reference Map

| Feature | React Native Files | Flutter Files (to create/update) |
|---------|-------------------|----------------------------------|
| Encryption | `sources/encryption/*.ts` | `lib/core/services/encryption_service.dart` |
| API | `sources/sync/api*.ts` | `lib/core/api/*.dart` |
| WebSocket | `sources/sync/apiSocket.ts` | `lib/core/api/websocket_client.dart` |
| Auth | `sources/auth/*.ts` | `lib/features/auth/` |
| Settings | `sources/sync/settings.ts` | `lib/core/models/settings.dart` |
| Storage | `sources/sync/storage.ts` | `lib/core/services/storage_service.dart` |
| Sync | `sources/sync/sync.ts` | NEW |
| Messages | `sources/components/MessageView.tsx` | `lib/features/chat/message_widget.dart` |
| Tools | `sources/components/tools/` | NEW |
