import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('githubUrl is composed from org + repo', () {
      // The single source of truth for repo URL. If the org/repo
      // ever change, only [AppConfig] needs to be updated — the
      // about section and any future surface all read from this.
      expect(
        AppConfig.githubUrl,
        equals('https://github.com/${AppConfig.githubOrg}/${AppConfig.githubRepo}'),
      );
    });

    test('githubSlug mirrors the repo path without scheme', () {
      expect(
        AppConfig.githubSlug,
        equals('${AppConfig.githubOrg}/${AppConfig.githubRepo}'),
      );
    });

    test('githubIssuesUrl points at the issues path under the repo', () {
      expect(
        AppConfig.githubIssuesUrl,
        equals('${AppConfig.githubUrl}/issues'),
      );
    });

    test('privacy and terms URLs are non-empty and use https', () {
      expect(AppConfig.privacyUrl, startsWith('https://'));
      expect(AppConfig.termsUrl, startsWith('https://'));
      expect(AppConfig.privacyUrl, isNotEmpty);
      expect(AppConfig.termsUrl, isNotEmpty);
    });
  });
}
