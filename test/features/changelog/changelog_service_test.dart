// ChangelogService parses GitHub commit payloads into the entries the
// changelog screen renders. Every case below is a shape the app really
// receives: an annotated tag, a compare range, and the first-install path
// where there is no previous version to compare against.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/changelog_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Serves canned GitHub API responses keyed by URL substring.
http.Client fakeGithub(Map<String, Object> routes) {
  return MockClient((request) async {
    for (final entry in routes.entries) {
      if (request.url.toString().contains(entry.key)) {
        return http.Response(jsonEncode(entry.value), 200);
      }
    }
    return http.Response('{"message":"Not Found"}', 404);
  });
}

Map<String, Object> commit(String message, {String date = '2026-08-01T10:00:00Z'}) {
  return {
    'sha': 'sha-${message.hashCode}',
    'commit': {
      'message': message,
      'committer': {'date': date},
    },
  };
}

void main() {
  group('conventional commit parsing', () {
    Future<ChangelogResult> compareRange(List<Map<String, Object>> commits) {
      final service = ChangelogService(
        client: fakeGithub({
          'git/refs/tags/v1.0.0': {
            'object': {'sha': 'from-sha', 'type': 'commit'},
          },
          'git/refs/tags/v1.1.0': {
            'object': {'sha': 'to-sha', 'type': 'commit'},
          },
          'compare/': {'commits': commits},
        }),
      );
      return service.getChangelog(fromVersion: '1.0.0', toVersion: '1.1.0');
    }

    test('keeps type and subject, drops non-conventional commits', () async {
      final result = await compareRange([
        commit('feat: add the loops screen'),
        commit('Merge pull request #12 from a/b'),
        commit('fix: stop the double send'),
      ]);

      expect(result.entries, hasLength(2));
      expect(result.entries[0].type, 'feat');
      expect(result.entries[0].message, 'add the loops screen');
      expect(result.entries[1].type, 'fix');
      expect(result.entries[1].message, 'stop the double send');
      expect(result.toVersion, '1.1.0');
      expect(result.fromVersion, '1.0.0');
    });

    test('extracts the scope the entry model documents', () async {
      final result = await compareRange([
        commit('fix(settings): keep the MCP row visible'),
        commit('chore: bump deps'),
      ]);

      expect(result.entries[0].scope, 'settings');
      expect(result.entries[0].message, 'keep the MCP row visible');
      expect(result.entries[1].scope, isNull);
    });

    test('treats the conventional "!" marker as breaking', () async {
      final result = await compareRange([
        commit('feat(api)!: drop the v1 endpoint'),
        commit('feat: additive change'),
        commit('refactor: rename\n\nBREAKING CHANGE: renamed the field'),
      ]);

      expect(result.entries[0].isBreaking, isTrue);
      expect(result.entries[0].scope, 'api');
      expect(result.entries[1].isBreaking, isFalse);
      expect(result.entries[2].isBreaking, isTrue);
    });

    test('carries the committer date through', () async {
      final result = await compareRange([
        commit('docs: rewrite the readme', date: '2026-07-04T09:30:00Z'),
      ]);

      expect(result.entries.single.date, '2026-07-04T09:30:00Z');
    });
  });

  group('first install (no previous version)', () {
    test('parses the commits-list array response', () async {
      final service = ChangelogService(
        client: fakeGithub({
          'git/refs/tags/v1.1.0': {
            'object': {'sha': 'to-sha', 'type': 'commit'},
          },
          'commits?sha=': [
            commit('feat: first release'),
            commit('fix: ship it'),
          ],
        }),
      );

      final result = await service.getChangelog(
        fromVersion: null,
        toVersion: '1.1.0',
      );

      expect(result.entries.map((e) => e.message), [
        'first release',
        'ship it',
      ]);
      expect(result.fromVersion, isNull);
    });
  });

  group('failure paths stay quiet', () {
    test('unknown target tag yields an empty result, not a throw', () async {
      final service = ChangelogService(client: fakeGithub(const {}));

      final result = await service.getChangelog(
        fromVersion: '1.0.0',
        toVersion: '9.9.9',
      );

      expect(result.entries, isEmpty);
      expect(result.toVersion, '9.9.9');
    });

    test('malformed compare payload yields an empty result', () async {
      final service = ChangelogService(
        client: MockClient((request) async {
          if (request.url.path.contains('refs/tags')) {
            return http.Response(
              jsonEncode({
                'object': {'sha': 'to-sha', 'type': 'commit'},
              }),
              200,
            );
          }
          return http.Response('<html>not json</html>', 200);
        }),
      );

      final result = await service.getChangelog(
        fromVersion: '1.0.0',
        toVersion: '1.1.0',
      );

      expect(result.entries, isEmpty);
    });
  });
}
