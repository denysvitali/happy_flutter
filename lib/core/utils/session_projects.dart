import '../models/session.dart';
import 'session_utils.dart';

const String _projectRepositoryPrefix = 'repo:';
const String _projectNamePrefix = 'name:';
const String _projectFolderPrefix = 'folder:';
const String _separator = '/';

/// A project: the thing the user works on, wherever its sessions run.
class SessionProject {
  const SessionProject({
    required this.key,
    required this.name,
    this.repository,
  });

  /// Stable group key shared by every session of the project.
  final String key;

  /// Short display name: the repository or folder name.
  final String name;

  /// Git identity, when any session of the project reports one.
  final RepositoryIdentity? repository;
}

/// Resolves sessions to projects across machines and Kubernetes pods.
///
/// A project is identified by, in order:
///
/// 1. its git repository (spawn repository or observed remote);
/// 2. the repository other sessions report for the same machine folder, so
///    conversations started before remotes were reported stay with it;
/// 3. the folder name. A name used by exactly one repository joins that
///    repository; otherwise same-named folders on different machines form
///    one project.
class SessionProjectIndex {
  SessionProjectIndex._(this._projectBySessionId);

  factory SessionProjectIndex.build(Iterable<Session> sessions) {
    final all = sessions.toList(growable: false);
    final own = <String, RepositoryIdentity>{};
    final folderRepository = <String, RepositoryIdentity>{};
    for (final session in all) {
      final repository = sessionRepository(session);
      if (repository == null) continue;
      own[session.id] = repository;
      folderRepository.putIfAbsent(sessionFolderKey(session), () => repository);
    }

    final repositoryKeysByName = <String, Set<String>>{};
    final repositories = <String, RepositoryIdentity>{};
    for (final repository in folderRepository.values.followedBy(own.values)) {
      repositories[repository.key] = repository;
      (repositoryKeysByName[_lastSegment(repository.path).toLowerCase()] ??= {})
          .add(repository.key);
    }

    final projects = <String, SessionProject>{};
    SessionProject repositoryProject(RepositoryIdentity repository) {
      return projects.putIfAbsent(
        '$_projectRepositoryPrefix${repository.key}',
        () {
          final name = _lastSegment(repository.path);
          final ambiguous =
              (repositoryKeysByName[name.toLowerCase()]?.length ?? 0) > 1;
          return SessionProject(
            key: '$_projectRepositoryPrefix${repository.key}',
            name: ambiguous ? repository.path : name,
            repository: repository,
          );
        },
      );
    }

    final bySessionId = <String, SessionProject>{};
    for (final session in all) {
      final repository =
          own[session.id] ?? folderRepository[sessionFolderKey(session)];
      if (repository != null) {
        bySessionId[session.id] = repositoryProject(repository);
        continue;
      }
      final name = _lastSegment(session.metadata?.path ?? '');
      if (name.isEmpty) {
        final key = '$_projectFolderPrefix${sessionFolderKey(session)}';
        bySessionId[session.id] = projects.putIfAbsent(
          key,
          () => SessionProject(key: key, name: ''),
        );
        continue;
      }
      final named = repositoryKeysByName[name.toLowerCase()];
      if (named != null && named.length == 1) {
        bySessionId[session.id] = repositoryProject(
          repositories[named.single]!,
        );
        continue;
      }
      final key = '$_projectNamePrefix${name.toLowerCase()}';
      bySessionId[session.id] = projects.putIfAbsent(
        key,
        () => SessionProject(key: key, name: name),
      );
    }
    return SessionProjectIndex._(bySessionId);
  }

  /// Returns the index for these catalog lists, rebuilding only when either
  /// list instance changes. The sessions list reuses its sorted lists until
  /// the catalog changes, so board rebuilds stay O(visible rows).
  factory SessionProjectIndex.cached(
    List<Session> active,
    List<Session> inactive,
  ) {
    final cached = _cached;
    if (cached != null &&
        identical(_cachedActive, active) &&
        identical(_cachedInactive, inactive)) {
      return cached;
    }
    _cachedActive = active;
    _cachedInactive = inactive;
    return _cached = SessionProjectIndex.build(active.followedBy(inactive));
  }

  static SessionProjectIndex? _cached;
  static List<Session>? _cachedActive;
  static List<Session>? _cachedInactive;

  final Map<String, SessionProject> _projectBySessionId;

  /// Project of [session]. Sessions the index was not built from resolve
  /// from their own metadata only.
  SessionProject projectOf(Session session) =>
      _projectBySessionId[session.id] ??
      SessionProjectIndex.build([session])._projectBySessionId[session.id]!;
}

String _lastSegment(String path) {
  final segments = path
      .split(_separator)
      .where((segment) => segment.isNotEmpty && segment != '~');
  return segments.isEmpty ? '' : segments.last;
}
