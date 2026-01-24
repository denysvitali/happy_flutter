# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Happy Flutter is a **reimplementation of happy's mobile app** (React Native) located at `../happy`. The goal is to achieve full feature parity with the original React Native implementation.

**Flutter Version**: 3.38.7 (Dart 3.10+) - configured in `.fvmrc`

**Source of Truth**: This is a reimplementation of the React Native mobile app at `../happy`. See `ROADMAP.md` for feature parity tracking.

## Common Commands

```bash
# Get dependencies
flutter pub get

# Analyze code (strict mode - required errors for missing_required_param, missing_return, must_be_immutable)
flutter analyze

# Run tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Run app
flutter run
```

## Architecture

**Feature-Based Clean Architecture** with layered structure:

```
lib/
├── main.dart                    # App entry point, initializes storage + API
├── core/
│   ├── api/                     # Network layer (Dio REST client, WebSocket)
│   ├── encryption/              # NaCl crypto, session/machine encryption
│   ├── models/                  # Data models with JSON serialization
│   ├── providers/               # Riverpod Notifier providers (state management)
│   ├── services/                # Business logic (auth, storage, certificates)
│   └── utils/
└── features/
    ├── auth/                    # Landing + QR authentication screen
    ├── chat/                    # Chat interface with session context
    ├── sessions/                # Session list management
    └── settings/                # App settings screen
```

**State Management**: Riverpod v3 with `NotifierProvider` pattern
- `AuthStateNotifier` - Authentication state
- `SessionsNotifier` - Session list
- `CurrentSessionNotifier` - Active chat session
- `MachinesNotifier` - Machine list
- `SettingsNotifier` - App settings

**Navigation**: go_router with `AuthGate` wrapper for route protection based on `authStateNotifierProvider`.

## Key Services

| Service | Purpose |
|---------|---------|
| `ApiClient` | REST API (Dio + cronet_http) with server URL config |
| `WebSocketClient` | Real-time communication |
| `AuthService` | QR authentication, Ed25519 signatures |
| `EncryptionService` | NaCl crypto abstraction |
| `StorageService` | SharedPreferences wrapper |

## Coding Standards

- **Strict typing**: `implicit-casts: false`, `implicit-dynamic: false`
- **Line length**: 80 characters max
- **Required**: Package API docs (`package_api_docs` rule)
- **Prefer**: const constructors, final fields, single quotes, spread collections
- **Avoid**: print statements (warning), relative lib imports
- **Errors**: missing_required_param, missing_return, must_be_immutable

## Security Considerations

- End-to-end encryption using NaCl/libsodium
- Ed25519 for authentication signatures
- Certificate pinning via `CertificateProvider`
- Secure storage for encryption keys
