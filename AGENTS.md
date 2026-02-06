# Repository Guidelines

## Project Structure & Module Organization
- App code lives in `lib/`.
- Shared/platform-agnostic code is in `lib/core/` (`api/`, `services/`, `models/`, `providers/`, `encryption/`, `ui/`, `widgets/`).
- User-facing flows are in `lib/features/` (`auth/`, `chat/`, `inbox/`, `sessions/`, `settings/`, `dev/`).
- Localization sources are in `l10n/`; generated localization output is in `lib/l10n/`.
- Tests mirror runtime domains under `test/` (`api/`, `services/`, `providers/`, `features/`, `utils/`, `encryption/`).
- Docs and protocol notes are in `docs/`.

## Build, Test, and Development Commands
- Always execute Flutter/FVM commands via `devenv shell` in this repo, e.g.:
  `devenv shell -- fvm flutter test`.
- Use FVM-managed Flutter (`.fvmrc` is `stable`): `fvm flutter pub get`.
- Run app locally: `fvm flutter run`.
- Static analysis (matches CI): `fvm flutter analyze --no-fatal-infos --no-fatal-warnings`.
- Run all tests: `fvm flutter test`.
- Build debug APK (flavor example):  
  `fvm flutter build apk --debug --flavor production --target-platform android-arm64`.
- Update generated localization after `l10n/*.arb` changes: `fvm flutter gen-l10n`.

## Coding Style & Naming Conventions
- Follow `analysis_options.yaml` and `flutter_lints`.
- Use 2-space indentation and keep lines <= 80 chars.
- Prefer single quotes, `final`, explicit return types, and immutable patterns.
- Naming:
  - Files: `snake_case.dart`
  - Types/classes/extensions: `PascalCase`
  - Variables/functions/methods: `camelCase`
  - Constants: `lowerCamelCase` unless Dart style requires otherwise.
- Avoid editing generated files (`*.g.dart`, `*.freezed.dart`, mocks) manually.

## Testing Guidelines
- Frameworks: `flutter_test`, `test`, and `mockito`.
- Test files must end with `_test.dart` and should sit near corresponding domain folders.
- Add or update tests for every behavior change, especially providers, APIs, encryption, and parsing logic.
- Prefer deterministic unit tests over broad widget/integration tests unless UI behavior is the target.

## Commit & Pull Request Guidelines
- Use Conventional Commit style seen in history: `fix: ...`, `ci: ...`, `chore: ...`, `feat: ...`.
- Keep commits focused and atomic; avoid mixing refactors with behavior changes.
- PRs should include:
  - Clear summary of user-visible and technical changes
  - Linked issue/task (if available)
  - Test evidence (`fvm flutter test`, analyzer output)
  - Screenshots/video for UI changes across relevant platforms
