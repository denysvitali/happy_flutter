/// Centralized app-wide constants (URLs, brand strings, repository metadata).
///
/// Anything user-visible that names the project or points at an external
/// resource lives here so it can be audited in one place. URLs and brand
/// strings used to be hardcoded in `settings_screen.dart` (and scattered
/// through other features) — pulling them into a single constants object
/// makes it impossible for the About section to drift from the project's
/// real GitHub org or support links.
library;

abstract final class AppConfig {
  /// GitHub org that hosts the project.
  static const String githubOrg = 'denysvitali';

  /// GitHub repo slug under the org.
  static const String githubRepo = 'happy_flutter';

  /// Full repo URL: https://github.com/denysvitali/happy_flutter
  static const String githubUrl = 'https://github.com/$githubOrg/$githubRepo';

  /// Issues URL.
  static const String githubIssuesUrl = '$githubUrl/issues';

  /// Privacy policy URL.
  static const String privacyUrl = 'https://happy.dev/privacy';

  /// Terms of service URL.
  static const String termsUrl = 'https://happy.dev/terms';

  /// Combined `org/repo` slug used in the About subtitle.
  static const String githubSlug = '$githubOrg/$githubRepo';
}
