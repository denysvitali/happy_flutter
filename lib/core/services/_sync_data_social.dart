part of 'sync_service.dart';

extension SyncDataSocial on Sync {
  /// Fetch friends list from server
  Future<void> fetchFriends() async {
    logger.info('Fetching friends...');
    try {
      final api = ApiClient();
      final response = await api.get('/v1/friends');
      if (!api.isSuccess(response)) {
        logger.warning(
          'Failed to fetch friends: ${response.statusCode}',
        );
        return;
      }

      final data = response.data;
      final rawFriends = (data is Map<String, dynamic>)
          ? data['friends']
          : data;
      if (rawFriends is! List) {
        _friends.clear();
        _friendRequests.clear();
        return;
      }

      final parsedFriends = <UserProfile>[];
      for (final raw in rawFriends) {
        if (raw is Map<String, dynamic>) {
          parsedFriends.add(_mapFriendProfile(raw));
        }
      }

      _friends
        ..clear()
        ..addAll(parsedFriends);
      _friendRequests
        ..clear()
        ..addAll(_deriveFriendRequests(parsedFriends));

      logger.info(
        'Fetched friends: ${_friends.length}, '
        'pending requests: ${_friendRequests.length}',
      );
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error(
        'Failed to fetch friends',
        error,
        stack,
      );
    }
  }

  /// Fetch friend requests from server.
  /// Friends and requests are both returned by fetchFriends() from
  /// /v1/friends, so this is a no-op to avoid a double network
  /// request.
  Future<void> fetchFriendRequests() async {}

  /// Fetch feed items from server
  Future<void> fetchFeed() async {
    logger.info('Fetching feed...');
    try {
      final api = ApiClient();
      final response = await api.get(
        '/v1/feed',
        queryParameters: <String, dynamic>{'limit': 50},
      );
      if (!api.isSuccess(response)) {
        logger.warning(
          'Failed to fetch feed: ${response.statusCode}',
        );
        return;
      }

      final data = response.data;
      final rawItems =
          (data is Map<String, dynamic>) ? data['items'] : data;
      if (rawItems is! List) {
        _feedItems.clear();
        return;
      }

      final parsed = <FeedItem>[];
      for (final raw in rawItems) {
        if (raw is Map<String, dynamic>) {
          parsed.add(_mapFeedItem(raw));
        }
      }

      _feedItems
        ..clear()
        ..addAll(parsed);
      logger.info('Fetched feed items: ${_feedItems.length}');
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Failed to fetch feed', error, stack);
    }
  }

  /// Fetch todos from server
  Future<void> fetchTodos() async {
    logger.info('Fetching todos...');
    try {
      final items = await KvApi().getByPrefix('todo.', limit: 1000);
      final decryptedByKey = <String, Map<String, dynamic>>{};

      final results = await Future.wait(
        items.map((item) async {
          try {
            final decrypted =
                await encryption.decryptRaw(item.value);
            if (decrypted is Map<String, dynamic>) {
              return MapEntry(item.key, decrypted);
            }
          } catch (error, stack) {
            logger.warning(
              'Failed to decrypt todo item ${item.key}',
              error,
              stack,
            );
          }
          return null;
        }),
      );
      for (final entry in results) {
        if (entry != null) {
          decryptedByKey[entry.key] = entry.value;
        }
      }

      final parsedTodoLists =
          parseTodoListsFromDecryptedKv(decryptedByKey);
      _todoLists
        ..clear()
        ..addAll(parsedTodoLists);

      final totalItems = parsedTodoLists.values
          .expand((list) => list.items)
          .toSet()
          .length;
      logger.info(
        'Fetched todos: ${parsedTodoLists.length} list(s),'
        ' $totalItems item(s)',
      );
    } on DioException {
      rethrow;
    } catch (error, stack) {
      logger.error('Failed to fetch todos', error, stack);
    }
  }

  /// Fetch session git status from server
  /// Git status is managed locally and updated via socket events
  Future<void> _fetchSessionGitStatus() async {
    // Git status is currently managed locally via the provider
    // This sync can be extended to fetch from server when needed
    logger.info('Session git status sync triggered');
  }

  @visibleForTesting
  Map<String?, TodoList> parseTodoListsFromDecryptedKv(
    Map<String, Map<String, dynamic>> decryptedByKey,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final todosById = <String, TodoItem>{};
    var undoneOrder = <String>[];
    var doneOrder = <String>[];

    for (final entry in decryptedByKey.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key == 'todo.index') {
        final rawUndone = value['undoneOrder'];
        if (rawUndone is List) {
          undoneOrder = rawUndone.whereType<String>().toList();
        }

        final rawCompleted = value['completedOrder'];
        if (rawCompleted is List) {
          doneOrder =
              rawCompleted.whereType<String>().toList();
        } else {
          final rawDone = value['doneOrder'];
          if (rawDone is List) {
            doneOrder =
                rawDone.whereType<String>().toList();
          }
        }
        continue;
      }

      if (!key.startsWith('todo.')) {
        continue;
      }

      final todoId = key.substring(5);
      if (todoId.isEmpty || todoId == 'index') {
        continue;
      }

      final mapped = _mapDecryptedTodoItem(
        todoId,
        value,
        createdFallbackAt: now,
      );
      todosById[todoId] = mapped;
    }

    undoneOrder =
        undoneOrder.where(todosById.containsKey).toList();
    doneOrder = doneOrder.where(todosById.containsKey).toList();

    final orderedIds = <String>{...undoneOrder, ...doneOrder};
    for (final entry in todosById.entries) {
      if (!orderedIds.contains(entry.key)) {
        if (entry.value.status == TodoState.completed ||
            entry.value.status == TodoState.canceled) {
          doneOrder.add(entry.key);
        } else {
          undoneOrder.add(entry.key);
        }
      }
    }

    final allOrderedIds = <String>[...undoneOrder, ...doneOrder];
    final grouped = <String?, List<TodoItem>>{null: <TodoItem>[]};
    var order = 0;

    for (final todoId in allOrderedIds) {
      final base = todosById[todoId];
      if (base == null) {
        continue;
      }

      final item = base.copyWith(order: order++);
      grouped[null]!.add(item);

      final sessionId = item.sessionId;
      if (sessionId != null && sessionId.isNotEmpty) {
        grouped
            .putIfAbsent(sessionId, () => <TodoItem>[])
            .add(item);
      }
    }

    final result = <String?, TodoList>{};
    for (final entry in grouped.entries) {
      result[entry.key] = TodoList(
        sessionId: entry.key,
        items: entry.value,
        updatedAt: now,
      );
    }
    return result;
  }

  TodoItem _mapDecryptedTodoItem(
    String todoId,
    Map<String, dynamic> raw, {
    required int createdFallbackAt,
  }) {
    final content =
        (raw['content'] as String?) ?? (raw['title'] as String?) ?? '';

    final rawStatus = raw['status'];
    final status = _mapTodoStatus(rawStatus, raw['done']);

    final linkedSessions = raw['linkedSessions'];
    var sessionId = raw['sessionId'] as String?;
    if ((sessionId == null || sessionId.isEmpty) &&
        linkedSessions is Map<String, dynamic> &&
        linkedSessions.isNotEmpty) {
      sessionId = linkedSessions.keys.first;
    }

    final dependenciesRaw = raw['dependencies'];
    final dependencies = dependenciesRaw is List
        ? dependenciesRaw.whereType<String>().toList()
        : <String>[];

    return TodoItem(
      id: (raw['id'] as String?) ?? todoId,
      content: content,
      status: status,
      priority: (raw['priority'] as String?) ?? 'medium',
      order: 0,
      parentId: raw['parentId'] as String?,
      dependencies: dependencies,
      dueAt: _asInt(raw['dueAt']),
      createdAt: _asInt(raw['createdAt']) ?? createdFallbackAt,
      updatedAt: _asInt(raw['updatedAt']) ?? createdFallbackAt,
      sessionId: sessionId,
      completedAt: _asInt(raw['completedAt']),
    );
  }

  TodoState _mapTodoStatus(dynamic rawStatus, dynamic rawDone) {
    if (rawStatus is String) {
      return TodoState.fromString(rawStatus);
    }

    if (rawDone is bool) {
      return rawDone ? TodoState.completed : TodoState.pending;
    }

    return TodoState.pending;
  }

  int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return null;
  }

  @visibleForTesting
  UserProfile mapFriendProfile(Map<String, dynamic> raw) {
    return _mapFriendProfile(raw);
  }

  UserProfile _mapFriendProfile(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ??
        (raw['uid'] as String?) ??
        'unknown';
    final firstName = (raw['firstName'] as String?) ?? '';
    final lastName = raw['lastName'] as String?;
    final username = (raw['username'] as String?) ?? '';
    final avatarRaw = raw['avatar'];
    AvatarRef? avatar;
    if (avatarRaw is Map<String, dynamic>) {
      avatar = AvatarRef.fromJson(avatarRaw);
    }

    return UserProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      username: username,
      avatar: avatar,
      bio: raw['bio'] as String?,
      status: RelationshipStatus.fromString(
        raw['status'] as String? ?? 'none',
      ),
    );
  }

  List<FriendRequest> _deriveFriendRequests(
    List<UserProfile> profiles,
  ) {
    return profiles
        .where(
          (profile) =>
              profile.status == RelationshipStatus.pending,
        )
        .map(
          (profile) => FriendRequest(
            id: 'friend-request-${profile.id}',
            fromUserId: profile.id,
            fromUserName: profile.name ?? profile.id,
            fromUserAvatarUrl: profile.avatarUrl,
            toUserId: serverID,
            createdAt: 0,
            status: 'pending',
          ),
        )
        .toList();
  }

  @visibleForTesting
  FeedItem mapFeedItem(Map<String, dynamic> raw) {
    return _mapFeedItem(raw);
  }

  FeedItem _mapFeedItem(Map<String, dynamic> raw) {
    final id = (raw['id'] as String?) ?? '';
    final createdAt = _asInt(raw['createdAt']) ??
        DateTime.now().millisecondsSinceEpoch;
    final bodyRaw = raw['body'];
    final bodyMap = bodyRaw is Map<String, dynamic>
        ? bodyRaw
        : <String, dynamic>{};
    final kind = bodyMap['kind'] as String? ?? 'text';
    var userId = raw['userId'] as String? ?? 'system';

    // Derive userId from uid in body for relationship events
    if (kind == 'friend_request' || kind == 'friend_accepted') {
      userId = (bodyMap['uid'] as String?) ?? userId;
    }

    final body = FeedBody(
      kind: kind,
      uid: bodyMap['uid'] as String?,
      text: bodyMap['text'] as String?,
    );

    return FeedItem(
      id: id,
      userId: userId,
      userName: raw['userName'] as String?,
      userAvatarUrl: raw['userAvatarUrl'] as String?,
      body: body,
      createdAt: createdAt,
      read: raw['read'] as bool? ?? false,
      sessionId: raw['sessionId'] as String?,
      repeatKey: raw['repeatKey'] as String?,
      cursor: raw['cursor'] as String?,
      counter: raw['counter'] as int?,
    );
  }
}
