# Happy Flutter

A Flutter reimplementation of the Happy mobile app, achieving full feature parity with the original React Native implementation.

## Overview

Happy Flutter is a cross-platform mobile application built with Flutter that provides secure, end-to-end encrypted messaging, session management, and AI-assisted development workflows. This project maintains complete compatibility with the React Native implementation while leveraging Flutter's performance and native capabilities.

## Architecture

The project follows **Feature-Based Clean Architecture** with clear separation of concerns:

```
lib/
├── main.dart                    # App entry, router (GoRouter), all route definitions
├── core/
│   ├── api/                     # ApiClient (Dio+NativeAdapter), SocketIoClient, feature API classes
│   ├── encryption/              # NaCl crypto, session/machine/artifact encryption, key caching
│   ├── models/                  # Pure Dart models with manual fromJson/toJson/copyWith
│   ├── providers/               # Riverpod NotifierProvider state (all in app_providers.dart)
│   ├── services/                # Auth, sync (Sync singleton), storage, certificates
│   ├── theme/                   # app_tokens.dart: AppSpacing, AppRadius design tokens
│   ├── ui/                      # Lower-level shared widgets (avatars, tab_bar, shimmer, diff, sidebar)
│   ├── components/              # Higher-level shared components (AppCard, AppEmptyState, etc.)
│   └── utils/                   # InvalidateSync, logging, helpers
└── features/
    ├── auth/                    # Landing + QR authentication
    ├── chat/                    # Chat interface with message pagination
    ├── sessions/                # Session list (also embeds Inbox + Settings as inline tabs)
    ├── settings/                # App settings
    ├── inbox/                   # Notifications inbox
    ├── artifacts/               # Artifacts browser
    ├── machine/                 # Machine management
    ├── zen/                     # Todo/zen mode
    └── terminal/                # Terminal feature
```

### Key Architectural Patterns

- **State Management**: Riverpod v3 with manual `NotifierProvider` (no code generation)
- **Sync Singleton**: Central in-memory data hub (`Sync` class) with `InvalidateSync` for debounced server fetches
- **Provider Bridge**: Screens subscribe to `sync.onDataChanged` and call `loadFromSync()` / `refreshFromSync()`
- **Service/API Duality**: Each feature has a singleton `XxxService` for production and injectable `XxxApi` class for tests
- **Platform-Specific Code**: Conditional exports (`lib/platform_io.dart`, `lib/platform_stub.dart`)

## Technology Stack

- **Flutter**: 3.38.7 (Dart 3.10+)
- **State Management**: Riverpod v3
- **HTTP Client**: Dio with NativeAdapter (Cronet/cupertino_http)
- **WebSocket**: Socket.IO protocol implementation
- **Encryption**: libsodium via `sodium` package + AES-256-GCM via `cryptography` package
- **Storage**: MMKV (flutter_mmkv) for fast local storage
- **Navigation**: GoRouter
- **UI**: Material Design 3 with custom design tokens

## Setup Instructions

### Prerequisites

1. Install devenv: `curl -fsSL https://devenv.sh | bash`
2. Ensure you have the Flutter SDK (managed via devenv)

### Development Environment

```bash
# Enter the development shell
devenv shell

# Get dependencies
devenv shell -- flutter pub get

# Run code generation (for mocks)
devenv shell -- flutter pub run build_runner build

# Run the app
devenv shell -- flutter run

# Run tests
devenv shell -- flutter test

# Analyze code
devenv shell -- flutter analyze
```

### Build Flavors

- `development` — development server, debug logging enabled
- `preview` — staging server, reduced logging
- `production` — production server at `api.cluster-fluster.com`

```bash
# Build APK for development
devenv shell -- flutter build apk --debug --flavor development

# Build APK for production
devenv shell -- flutter build apk --release --flavor production

# Build for iOS
devenv shell -- flutter build ios --release
```

## Project Structure

### Design Tokens

Spacing and radius tokens are defined in `lib/core/theme/app_tokens.dart`:

- **Spacing**: `AppSpacing.xs/sm/md/lg/xl/xxl/xxxl` (4/8/12/16/20/24/32 px)
- **Radius**: `AppRadius.xs/sm/md/lg/xl/pill` (4/8/12/16/20/100 px)

### Key Services

| Service | Pattern | Purpose |
|---------|---------|---------|
| `ApiClient` | Singleton | Dio + NativeAdapter. `validateStatus: (_) => true` — callers must check status manually |
| `SocketIoClient` | Singleton | Socket.IO on path `/v1/updates`, transport `['websocket']` only |
| `AuthService` | Singleton | QR authentication, Ed25519 signatures |
| `Sync` | Singleton | Central in-memory data hub with all server state |
| `Storage` | Singleton | MMKV wrapper for user data (cleared on logout) |

### State Management

All providers are manually declared in `lib/core/providers/app_providers.dart`:

| Provider | State |
|----------|-------|
| `authStateNotifierProvider` | `AuthState` |
| `sessionsNotifierProvider` | `Map<String, Session>` |
| `machinesNotifierProvider` | `Map<String, Machine>` |
| `settingsNotifierProvider` | `Settings` |
| `connectionNotifierProvider` | `ConnectionStatus` |
| `currentSessionNotifierProvider` | `Session?` |
| `profileNotifierProvider` | `Profile?` |
| `sessionGitStatusProvider` | `Map<String, GitStatus>` |
| `artifactsNotifierProvider` | `Map<String, Artifact>` |
| `friendsNotifierProvider` | `FriendsState` |
| `feedNotifierProvider` | `FeedState` |
| `todoStateNotifierProvider` | `TodoListState` |

## Security

- **End-to-end encryption**: NaCl/libsodium for session/machine data, AES-256-GCM for artifacts
- **Authentication**: Ed25519 signatures for device linking
- **Credentials**: Stored in `flutter_secure_storage`
- **App data**: Stored in MMKV (separate instance for server config that persists across logouts)
- **Certificate pinning**: Currently relies on platform CA store via NativeAdapter

**Note**: Web build is disabled — `sodium` and `mmkv` are not web-compatible.

## Testing

- **Unit tests**: Comprehensive test suites for all providers, APIs, and services
- **Widget tests**: Key UI components tested
- **Mock generation**: Mockito for `ApiClient` mocking
- **Test command**: `devenv shell -- flutter test`

### Test Structure

```
test/
├── api/                    # API client tests
├── core/                   # Core utility tests
├── encryption/             # Encryption round-trip tests
├── features/               # Feature widget tests
├── providers/              # State management tests
└── services/               # Service tests
```

## Contribution Guidelines

### Coding Standards

- **Strict typing**: `implicit-casts: false`, `implicit-dynamic: false`
- **Line length**: 80 characters max
- **Prefer**: const constructors, final fields, single quotes, spread collections
- **Avoid**: `print` statements — use `logger.info/warning/error()`; `unawaited()` for intentional fire-and-forget

### Git Workflow

1. Create a feature branch from `main`
2. Make changes following the architecture patterns
3. Run tests: `devenv shell -- flutter test`
4. Run analysis: `devenv shell -- flutter analyze`
5. Commit with clear messages
6. Push and create PR

### Code Style

- Use `ConsumerStatefulWidget` + `ConsumerState` when the screen needs local state and Riverpod
- Use `ConsumerWidget` for stateless screens that only read providers
- Always guard on `sync.isInitialized` before calling `loadFromSync()`
- Hide Flutter's built-in `TabBar` when importing the custom one: `import 'package:flutter/material.dart' hide TabBar;`

## Documentation

- **Feature Parity**: See `ROADMAP.md` for detailed tracking against React Native implementation
- **Architecture**: See `docs/ARCHITECTURE.md` for system design and data flow diagrams
- **Protocol**: See `docs/PROTOCOL.md` for authentication and encryption protocols

## References

- **Source of Truth**: `../happy` (React Native implementation)
- **Flutter Version**: 3.38.7 (Dart 3.10+)
- **CI/CD**: GitHub Actions with build flavors

## License

[Add your license information here]
