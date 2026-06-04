# 12. Routing, Theme, Widgets

The plumbing for navigation, visual style, and the three widget layers. Less code, more conventions.

## Routing: GoRouter

The router is a single file: `lib/core/routing/app_router.dart`. It contains:

- ~64 flat `GoRoute` entries
- Three custom page transitions
- A few `ShellRoute`s for tab shells
- The `AuthGate` wrapper

### The transitions

```dart
Page<T> _fadePage<T>(GoRouterState state, Widget child) { ... }    // tab destinations
Page<T> _slideUpPage<T>(GoRouterState state, Widget child) { ... } // creation / modal
Page<T> _slidePage<T>(GoRouterState state, Widget child) { ... }  // detail with iOS swipe-back
```

The choice of transition is per-route. By convention:

- **Tab destinations** (Sessions, Inbox, etc.) — `_fadePage`. Tabs crossfade.
- **Creation flows** (New Session, Profile Wizard) — `_slideUpPage`. Modal-ish.
- **Detail screens** (Session Info, Message Detail) — `_slidePage`. Swipe-back on all platforms (including Android).

### Named routes

Every route has a name. Use `context.goNamed('chat', pathParameters: {'sessionId': id})` instead of `context.go('/sessions/...')`.

For non-URL data (e.g. `message-detail`), pass `Map<String, dynamic>` via `state.extra`:

```dart
context.goNamed('message-detail', extra: {'message': message});
```

The receiving screen reads `GoRouterState.of(context).extra` in its `build`.

### The `AuthGate`

Every route wraps its child in `AuthGate`. The gate is a simple widget that:

- If `isAuthenticated`, shows the child
- Else shows the auth flow (QR screen or restore)

The router itself only redirects `/` → `/sessions` for authenticated users. The auth state machine is in `AuthGate`.

### The `SessionsScreen` tab shell

`SessionsScreen` is a stateful tab shell that renders `SettingsScreen` inline. It is **not** a `ShellRoute` in the GoRouter sense. The reasoning: the original implementation pre-dated GoRouter's shell support, and rewriting it would have rippled through the navigation stack. It works; it's just unconventional.

If you need to add a tab to the sessions screen, edit `sessions_screen.dart` directly. Do not introduce a `ShellRoute`.

## Theme: design tokens

The theme is a set of **design tokens** in `lib/core/theme/app_tokens.dart`. The single source of truth for spacing, radii, fonts, durations, touch targets, breakpoints.

```dart
class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 100;
}

class AppFontSize {
  static const double xxs = 10;
  static const double xs = 11;
  static const double sm = 13;
  static const double md = 14;
  static const double lg = 16;
}

class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration slower = Duration(milliseconds: 500);
}

class AppTouchTarget {
  static const double min = 44;
  static const double comfortable = 48;
}

class AppBreakpoint {
  static const double tablet = 600;
  static const double desktop = 960;
}

class AppScreenPadding {
  static const EdgeInsets standard = EdgeInsets.all(16);
  static const EdgeInsets compact = EdgeInsets.all(12);
  static const EdgeInsets settings = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets listItem = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
}
```

The convention: use tokens, never raw numbers. If you need a new spacing, add it to `AppSpacing`.

### Color scheme

- `app_colors.dart` — the palette
- `app_color_scheme.dart` — light/dark `ColorScheme` construction
- `app_typography.dart` — text styles
- `file_type_colors.dart` — file extension → color (used in file viewers)

The theme wiring is in `main.dart`. The app follows the system brightness by default, with an override in settings.

## Widgets: three layers

The codebase has three widget directories. The naming is confusing; the convention is:

| Directory | What lives there | Examples |
|---|---|---|
| `lib/core/ui/` | **Lower-level** — small primitives | avatars, tab_bar, shimmer primitives, status bar, diff primitives |
| `lib/core/components/` | **Higher-level** — composed pieces | AppCard, AppEmptyState, AppLoadingIndicator, sidebar, settings sections |
| `lib/core/widgets/` | **App-level** — full widgets | AuthGate, ErrorBoundary, OfflineBanner, SyncProgressBar |

Rule of thumb: if it's a single `Container` with padding, it's `ui/`. If it's a composed card or section, it's `components/`. If it's a full app widget, it's `widgets/`.

### The custom `TabBar` name collision

`lib/core/ui/tab_bar/tab_bar.dart` exports a `TabBar` that conflicts with `material.dart`'s `TabBar`. The import is:

```dart
import 'package:flutter/material.dart' hide TabBar;
import 'package:.../ui/tab_bar/tab_bar.dart';
```

Don't forget the `hide TabBar`. The compiler won't catch it if you do; you'll just get a compile error that's hard to read.

### The `components` subdirs

`lib/core/components/` has a few subdirectories:

- `avatars/` — small avatar primitives (overlaps with `ui/avatars/`)
- `sidebar/` — sidebar shell for tablet/desktop (P3 roadmap item)
- `settings/` — settings-specific layouts
- `tablet/` — tablet-specific layouts

The avatar duplication is historical. If you're adding a new avatar, use `ui/avatars/` and the rest will follow.

## Settings screens: a tour

There are 16 settings screens in `lib/features/settings/`. The full list:

- `settings_screen.dart` — the main settings list
- `account_screen.dart` — account info
- `claude_limits_screen.dart` — Claude usage limits
- `codex_usage_screen.dart` — Codex usage
- `developer_screen.dart` — dev tools entry
- `features_settings_screen.dart` — feature flags
- `link_device_screen.dart` — link a new device
- `linked_devices_screen.dart` — manage linked devices
- `machines_screen.dart` — manage machines
- `offline_voices_screen.dart` — offline voice settings
- `profile_editor_screen.dart` — edit a profile
- `profile_setup_catalog.dart` — profile setup catalog
- `profile_wizard_screen.dart` — profile creation wizard
- `profiles_screen.dart` — manage profiles
- `restore_account_screen.dart` — restore from backup
- `server_settings_screen.dart` — custom server URL
- `settings_screen_search.dart` — settings search
- `theme_settings_screen.dart` — theme picker
- `usage_screen.dart` — usage stats
- `voice_language_settings_screen.dart` — voice language
- `voice_settings_screen.dart` — TTS settings

The "new" screens follow a pattern: a `Scaffold` with a list of `AppCard` or `SettingsSection` rows. The settings_section.dart primitive is in `lib/core/components/settings_section.dart`.

## Files to read next

- `lib/core/routing/app_router.dart` — the router
- `lib/core/theme/app_tokens.dart` — the tokens
- `lib/core/utils/safe_pop.dart` — `safePop(context)` helper
- `lib/core/widgets/auth_gate.dart` — the auth gate
- `lib/core/widgets/error_boundary.dart` — the error boundary

## Gotchas

- The router redirects `/` → `/sessions` for authenticated users only. Unauthenticated users land on the auth flow via `AuthGate`, not the router.
- `_slidePage` provides iOS-style swipe-back on all platforms. The `PopScope` / `canPop` logic must be carefully constructed to avoid the back-button error rate (37.5% at one point, now fixed in `ec102e5`, `2bca2c8`, `bd011fd`).
- The `safePop` helper (`lib/core/utils/safe_pop.dart`) is the canonical way to pop a route. It checks `context.mounted` + `context.canPop()` and falls back to a named route. Use it instead of `context.pop()`.
- The three widget layers are not strict. Some widgets exist in both `ui/` and `components/` (avatars). When in doubt, follow the imports in a feature screen.
- The custom `TabBar` import requires `hide TabBar` from `material.dart`. Don't forget it.
- The theme follows system brightness by default. The override is in settings; the wiring is in `main.dart`.
- The router has ~64 routes. Don't add a route for every state; use the `extra` map for non-URL data.
- `SessionsScreen` is a tab shell, not a `ShellRoute`. Don't try to make it one.
- The design tokens are the **only** place to define spacing, radii, fonts. Don't hardcode `EdgeInsets.all(16)`; use `AppScreenPadding.standard`.
