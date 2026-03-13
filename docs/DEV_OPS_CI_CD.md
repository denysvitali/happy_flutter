# DevOps / CI-CD Report

**Date:** 2026-03-13
**Agent:** A8 — DevOps / CI-CD Specialist
**Overall Score:** 5.5/10

---

## Current State

| Category | Score | Notes |
|----------|-------|-------|
| Code Analysis | 9/10 | Excellent lint config, strict typing |
| Android Build | 7/10 | APK builds work, missing AAB |
| Dependency Mgmt | 6/10 | Caching works, no vulnerability scanning |
| Testing in CI | 2/10 | **Tests not run in CI** |
| Release/Deploy | 3/10 | Minimal automation |
| iOS Support | 0/10 | Not configured |

---

## Critical Gaps (P0)

### 1. Tests Not Run in CI

No `flutter test` job exists. Tests cannot block merges.

**Fix — add to `ci.yml`:**
```yaml
test:
  name: Run Tests
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ env.FLUTTER_VERSION }}
        cache: true
    - run: flutter pub get
    - run: flutter test --coverage
    - uses: codecov/codecov-action@v3
      with:
        files: ./coverage/lcov.info
```

### 2. No iOS CI/CD Pipeline

No macOS runner, no Xcode build, no code signing, no IPA creation.

### 3. No AAB (Android App Bundle) Builds

Google Play requires AAB. Only APK is built currently.

**Fix:** Add `flutter build appbundle --release` to build-release job.

---

## High Priority (P1)

### 4. No Play Store Publishing

Manual upload required. Add:
```yaml
- uses: r0adkll/upload-google-play@v1
  with:
    serviceAccountJson: ${{ secrets.PLAY_STORE_SERVICE_ACCOUNT }}
    packageName: com.example.happy_flutter
    releaseFiles: build/app/outputs/bundle/*/release/*.aab
    track: internal
```

### 5. No Dependency Vulnerability Scanning

Create `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "weekly"
```

### 6. No Firebase App Distribution

Debug/preview builds have no distribution channel for QA.

### 7. Java Version Mismatch

`devenv.nix` uses JDK 21 but CI uses JDK 17. Should match.

---

## Medium Priority (P2)

| Issue | Fix |
|-------|-----|
| Static version (`1.0.0+$BUILD_NUMBER`) | Read from `pubspec.yaml` |
| No release notes generation | Enable `generate_release_notes: true` |
| No build matrix for flavors | Add `strategy.matrix.flavor` |
| No test coverage reporting | Add codecov integration |
| No artifact size monitoring | Track APK size in CI |

---

## What's Working Well

- Concurrency groups with cancel-in-progress
- Pub cache + Flutter cache in GitHub Actions
- Conditional build jobs (debug vs release)
- Gradle optimization (parallel, caching, 6GB heap)
- Sentry debug symbol uploads
- Disk space cleanup (~15GB freed)
- Keystore via secrets (not committed)
- 30-minute timeout (appropriate)

---

## Must-Have Before Production

1. Test execution in CI
2. iOS CI/CD pipeline
3. AAB builds for Play Store
4. Play Store publishing automation
5. Dependency vulnerability scanning
