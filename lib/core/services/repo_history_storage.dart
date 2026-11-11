import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mmkv_storage.dart';

/// Canonical identity of a repository for history lookups: `owner/repo`,
/// lower-cased, for every github.com spelling (HTTPS, `git@`, `ssh://`, with
/// or without `.git`); any other value is compared as trimmed lower-case
/// text. Empty input yields an empty key.
String repoHistoryKey(String repository) {
  var value = repository.trim();
  if (value.isEmpty) return '';
  value = value.replaceFirst(RegExp(r'^[a-z+]+://', caseSensitive: false), '');
  value = value.replaceFirst(RegExp(r'^[^@/]+@'), '');
  value = value.replaceFirst(
    RegExp(r'^(www\.)?github\.com[:/]', caseSensitive: false),
    '',
  );
  value = value.replaceAll(RegExp(r'/+$'), '');
  if (value.toLowerCase().endsWith('.git')) {
    value = value.substring(0, value.length - 4);
  }
  return value.toLowerCase();
}

/// Short label for a repository: `owner/repo` when it is a GitHub spelling,
/// else the text as typed.
String repoDisplayName(String repository) {
  final trimmed = repository.trim();
  final key = repoHistoryKey(trimmed);
  final parts = key.split('/');
  if (parts.length != 2 || parts.any((part) => part.isEmpty)) return trimmed;
  // Keep the user's capitalization when the tail of the URL matches.
  final lower = trimmed.toLowerCase();
  final at = lower.lastIndexOf(key);
  return at >= 0 ? trimmed.substring(at, at + key.length) : key;
}

/// A named group of repositories started together: one cloned as the working
/// directory on [repoRef], the others cloned beside it.
@immutable
class RepoSet {
  const RepoSet({
    required this.id,
    required this.name,
    required this.repoUrl,
    required this.repoRef,
    this.additionalRepos = const [],
  });

  static RepoSet? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    final repoUrl = json['url']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty || repoUrl.isEmpty) return null;
    final extra = json['extra'];
    return RepoSet(
      id: id,
      name: name,
      repoUrl: repoUrl,
      repoRef: json['ref']?.toString().trim() ?? '',
      additionalRepos: [
        if (extra is List)
          for (final repo in extra.whereType<String>())
            if (repo.trim().isNotEmpty) repo.trim(),
      ],
    );
  }

  final String id;
  final String name;
  final String repoUrl;
  final String repoRef;
  final List<String> additionalRepos;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'url': repoUrl,
    'ref': repoRef,
    if (additionalRepos.isNotEmpty) 'extra': additionalRepos,
  };

  @override
  bool operator ==(Object other) =>
      other is RepoSet &&
      id == other.id &&
      name == other.name &&
      repoUrl == other.repoUrl &&
      repoRef == other.repoRef &&
      listEquals(additionalRepos, other.additionalRepos);

  @override
  int get hashCode =>
      Object.hash(id, name, repoUrl, repoRef, Object.hashAll(additionalRepos));
}

/// Repositories and branches this device has started Kubernetes sessions
/// from, plus the user's saved [RepoSet]s.
@immutable
class RepoHistoryState {
  const RepoHistoryState({
    this.recentRepos = const [],
    this.branchesByRepo = const {},
    this.sets = const [],
  });

  /// Repository spellings as last typed, newest first.
  final List<String> recentRepos;

  /// Branches used per [repoHistoryKey], newest first.
  final Map<String, List<String>> branchesByRepo;
  final List<RepoSet> sets;

  /// Branches previously used for [repository], newest first.
  List<String> branchesFor(String repository) =>
      branchesByRepo[repoHistoryKey(repository)] ?? const [];

  /// The branch last used for [repository], if any.
  String? lastBranchFor(String repository) =>
      branchesFor(repository).firstOrNull;
}

/// Device-local history of Kubernetes repositories, persisted to MMKV.
///
/// Like Mission Control triage this is a per-device convenience and is not
/// part of the synced Settings object.
class RepoHistoryNotifier extends Notifier<RepoHistoryState> {
  RepoHistoryNotifier({MMKVStorage? storage})
    : _storage = storage ?? MMKVStorage();

  static const storageKey = 'kubernetes-repo-history-v1';
  static const maxRepos = 30;
  static const maxBranchesPerRepo = 8;
  static const maxSets = 20;

  final MMKVStorage _storage;

  @override
  RepoHistoryState build() => decode(_storage.getString(storageKey));

  /// Parses a stored payload; anything unreadable is an empty history.
  static RepoHistoryState decode(String? raw) {
    if (raw == null || raw.isEmpty) return const RepoHistoryState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const RepoHistoryState();
      final branches = <String, List<String>>{};
      final branchesJson = decoded['b'];
      if (branchesJson is Map) {
        for (final entry in branchesJson.entries) {
          final value = entry.value;
          if (value is! List) continue;
          final names = value.whereType<String>().toList(growable: false);
          if (names.isNotEmpty) branches[entry.key.toString()] = names;
        }
      }
      final setsJson = decoded['s'];
      final reposJson = decoded['r'];
      return RepoHistoryState(
        recentRepos: [if (reposJson is List) ...reposJson.whereType<String>()],
        branchesByRepo: branches,
        sets: [
          if (setsJson is List)
            for (final item in setsJson) ?RepoSet.fromJson(item),
        ],
      );
    } catch (_) {
      // A corrupt payload must not break the new-session dialog.
      return const RepoHistoryState();
    }
  }

  static String encode(RepoHistoryState state) => jsonEncode({
    'r': state.recentRepos,
    'b': state.branchesByRepo,
    's': [for (final set in state.sets) set.toJson()],
  });

  /// Remembers a started session's repositories and the branch it used.
  void recordUse({
    required String repoUrl,
    required String repoRef,
    List<String> additionalRepos = const [],
  }) {
    final url = repoUrl.trim();
    if (repoHistoryKey(url).isEmpty) return;
    var recent = state.recentRepos;
    // The primary ends up newest; additional repositories follow it.
    for (final repo in [...additionalRepos.reversed, url]) {
      recent = _promote(recent, repo.trim(), maxRepos, key: repoHistoryKey);
    }
    final branches = Map<String, List<String>>.from(state.branchesByRepo);
    final ref = repoRef.trim();
    if (ref.isNotEmpty) {
      final key = repoHistoryKey(url);
      branches[key] = _promote(
        branches[key] ?? const [],
        ref,
        maxBranchesPerRepo,
      );
    }
    final kept = {for (final repo in recent) repoHistoryKey(repo)};
    branches.removeWhere((key, _) => !kept.contains(key));
    _commit(
      RepoHistoryState(
        recentRepos: recent,
        branchesByRepo: branches,
        sets: state.sets,
      ),
    );
  }

  /// Adds [set], replacing a set with the same id or (case-insensitive) name.
  void saveSet(RepoSet set) {
    final name = set.name.trim().toLowerCase();
    final sets = [
      set,
      for (final existing in state.sets)
        if (existing.id != set.id && existing.name.trim().toLowerCase() != name)
          existing,
    ];
    _commit(
      RepoHistoryState(
        recentRepos: state.recentRepos,
        branchesByRepo: state.branchesByRepo,
        sets: sets.take(maxSets).toList(growable: false),
      ),
    );
  }

  void deleteSet(String id) {
    _commit(
      RepoHistoryState(
        recentRepos: state.recentRepos,
        branchesByRepo: state.branchesByRepo,
        sets: [
          for (final set in state.sets)
            if (set.id != id) set,
        ],
      ),
    );
  }

  static List<String> _promote(
    List<String> values,
    String value,
    int limit, {
    String Function(String)? key,
  }) {
    if (value.isEmpty) return values;
    final identity = key ?? (String v) => v;
    final id = identity(value);
    if (id.isEmpty) return values;
    return [
      value,
      for (final existing in values)
        if (identity(existing) != id) existing,
    ].take(limit).toList(growable: false);
  }

  void _commit(RepoHistoryState next) {
    state = next;
    _storage.setString(storageKey, encode(next));
  }
}

final repoHistoryProvider =
    NotifierProvider<RepoHistoryNotifier, RepoHistoryState>(
      RepoHistoryNotifier.new,
    );
