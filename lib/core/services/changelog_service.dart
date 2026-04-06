import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logger_service.dart' show logger;

/// A single parsed changelog entry derived from a git commit.
class ChangelogEntry {
  const ChangelogEntry({
    required this.date,
    required this.message,
    required this.type,
    this.scope,
    this.isBreaking = false,
  });

  /// Commit date (ISO 8601).
  final String date;
  /// Commit subject line (first line).
  final String message;
  /// Conventional commit type: feat, fix, chore, docs, refactor, etc.
  final String type;
  /// Optional scope extracted from feat(scope): pattern.
  final String? scope;
  /// True if the commit has a BREAKING CHANGE footer.
  final bool isBreaking;
}

/// Result of parsing a range of commits into a changelog.
class ChangelogResult {
  const ChangelogResult({
    required this.entries,
    required this.fromVersion,
    required this.toVersion,
  });

  final List<ChangelogEntry> entries;
  final String? fromVersion;
  final String toVersion;
}

/// Service responsible for fetching and parsing git commits into
/// a changelog, typically between two version tags.
///
/// Uses the GitHub REST API to enumerate commits between two refs,
/// then parses each commit message using the Conventional Commits
/// specification (https://www.conventionalcommits.org/).
class ChangelogService {
  ChangelogService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Repository owner and name (e.g. "slopus/happy").
  /// In a self-hosted scenario this could come from ServerConfig.
  static const String _repoOwner = 'slopus';
  static const String _repoName = 'happy';
  static const String _githubApiBase = 'https://api.github.com';

  /// Regex for conventional commit prefix: type(scope)!: subject
  /// Examples: feat:, fix(scope):, chore!:, docs:!
  static final RegExp _conventionalPrefix =
      RegExp(r'^(\w+)(?:\([^)]+\))?!?:\s+(.*)$');

  /// Fetch the changelog between [fromVersion] and [toVersion].
  ///
  /// [fromVersion] may be null (first install / no previous version).
  /// When null, all commits up to [toVersion] are included.
  ///
  /// Returns a [ChangelogResult] with the parsed entries, or an
  /// empty result if the request fails or parsing yields nothing.
  Future<ChangelogResult> getChangelog({
    required String? fromVersion,
    required String toVersion,
  }) async {
    try {
      // Get commit SHAs for both version tags
      final fromSha = fromVersion != null
          ? await _getTagSha('v$fromVersion')
          : null;
      final toSha = await _getTagSha('v$toVersion');

      if (toSha == null) {
        logger.warning(
          'ChangelogService: to-tag "v$toVersion" not found in repository',
        );
        return ChangelogResult(
          entries: const [],
          fromVersion: fromVersion,
          toVersion: toVersion,
        );
      }

      // Enumerate commits in the range
      final commits = await _getCommitsInRange(
        fromSha: fromSha,
        toSha: toSha,
      );

      if (commits.isEmpty) {
        return ChangelogResult(
          entries: const [],
          fromVersion: fromVersion,
          toVersion: toVersion,
        );
      }

      // Parse each commit into ChangelogEntry
      final entries = <ChangelogEntry>[];
      for (final commit in commits) {
        final entry = _parseCommit(commit);
        if (entry != null) {
          entries.add(entry);
        }
      }

      logger.info(
        'ChangelogService: parsed ${entries.length} entries '
        'from ${fromVersion ?? 'beginning'} → v$toVersion',
      );

      return ChangelogResult(
        entries: entries,
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    } catch (e, s) {
      logger.warning('ChangelogService: failed to fetch changelog', e, s);
      return ChangelogResult(
        entries: const [],
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    }
  }

  /// Resolve a version tag (e.g. "1.2.3") to the commit SHA.
  Future<String?> _getTagSha(String tag) async {
    try {
      final url = Uri.parse(
        '$_githubApiBase/repos/$_repoOwner/$_repoName/git/refs/tags/$tag',
      );
      final response = await _client.get(url, headers: _headers);

      if (response.statusCode == 404) {
        // Try without 'v' prefix
        final withoutV = tag.startsWith('v') ? tag.substring(1) : tag;
        final url2 = Uri.parse(
          '$_githubApiBase/repos/$_repoOwner/$_repoName/git/refs/tags/$withoutV',
        );
        final response2 = await _client.get(url2, headers: _headers);
        if (response2.statusCode == 200) {
          final data =
              jsonDecode(response2.body) as Map<String, dynamic>;
          return data['object']?['sha'] as String?;
        }
        return null;
      }

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Annotated tag response wraps the sha in 'object'
      final object = data['object'] as Map<String, dynamic>?;
      if (object != null && object['type'] == 'tag') {
        // Peel the tag to get the commit SHA
        final tagSha = data['object']?['sha'] as String?;
        if (tagSha != null) {
          return _peelTag(tagSha);
        }
      }
      return data['object']?['sha'] as String?;
    } catch (e) {
      logger.warning('ChangelogService: failed to resolve tag $tag', e);
      return null;
    }
  }

  /// Peel an annotated tag to get the underlying commit SHA.
  Future<String?> _peelTag(String tagSha) async {
    try {
      final url = Uri.parse(
        '$_githubApiBase/repos/$_repoOwner/$_repoName/git/tags/$tagSha',
      );
      final response = await _client.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['object']?['sha'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Get commits between fromSha (exclusive) and toSha (inclusive).
  /// If fromSha is null, get all commits up to toSha (newest first, limited).
  Future<List<Map<String, dynamic>>> _getCommitsInRange({
    required String? fromSha,
    required String toSha,
  }) async {
    try {
      final String url;
      if (fromSha != null) {
        // Use commit comparison API
        url =
            '$_githubApiBase/repos/$_repoOwner/$_repoName/compare/$fromSha...$toSha';
      } else {
        // Get commits up to the tag (newest first, limit 100)
        url =
            '$_githubApiBase/repos/$_repoOwner/$_repoName/commits?sha=$toSha&per_page=100';
      }

      final response = await _client.get(Uri.parse(url), headers: _headers);
      if (response.statusCode != 200) {
        logger.warning(
          'ChangelogService: compare API returned ${response.statusCode}',
        );
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (fromSha != null) {
        // Compare response: { ..., "commits": [...] }
        final commits = data['commits'] as List<dynamic>? ?? [];
        return commits
            .where((c) {
              final sha = (c as Map<String, dynamic>)['sha'] as String?;
              return sha != null && !sha.startsWith(fromSha);
            })
            .map((c) => c as Map<String, dynamic>)
            .toList();
      } else {
        // Commits list response: directly the array
        final commits = data as List<dynamic>? ?? [];
        return commits.map((c) => c as Map<String, dynamic>).toList();
      }
    } catch (e) {
      logger.warning('ChangelogService: failed to get commits in range', e);
      return [];
    }
  }

  /// Parse a single commit payload into a [ChangelogEntry].
  /// Returns null if the message does not look like a conventional commit.
  ChangelogEntry? _parseCommit(Map<String, dynamic> commit) {
    try {
      final commitData = commit['commit'] as Map<String, dynamic>? ?? commit;
      final message =
          (commitData['message'] as String? ?? '').split('\n').first;
      final dateStr =
          (commitData['committer'] as Map<String, dynamic>?)?['date']
                  as String? ??
              '';

      final match = _conventionalPrefix.firstMatch(message);
      if (match == null) return null;

      final type = match.group(1)!;
      final subject = match.group(2)!;

      // Detect breaking change
      final isBreaking = subject.contains('BREAKING CHANGE') ||
          message.contains('BREAKING CHANGE:');

      return ChangelogEntry(
        date: dateStr,
        message: subject,
        type: type,
        isBreaking: isBreaking,
      );
    } catch (e) {
      return null;
    }
  }

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github.v3+json',
        // Optionally use a token for higher rate limits:
        // 'Authorization': 'token ...',
      };
}