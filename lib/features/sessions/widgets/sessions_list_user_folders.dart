part of 'sessions_list_content.dart';

/// One lazily built row of the Folders view.
typedef _UserFolderRowSpec = ({Key key, Widget Function() build});

/// The "Folders" layout: the user's synced folder tree with its open
/// sessions, unfiled sessions below, then the archive as in the plain
/// list. Child sessions stay nested under their parent; folders anchored
/// at a session render among its sub-sessions ([_withUserFolders]).
extension _UserFoldersView on _SessionsListContentState {
  Widget _buildUserFoldersView(
    BuildContext context,
    List<Session> activeSessions,
    List<Session> inactiveSessions,
    Map<String, Machine> machines,
    SessionOrderingProjection orderingProjection, {
    required bool triggerStagger,
    required bool hideInactive,
    required bool showFlavorIcons,
    required AvatarStyle? avatarStyle,
  }) {
    final tree = _userFolderTree ?? FolderTree.empty;
    final folders = ref.watch(sessionFoldersProvider);
    final l10n = context.l10n;
    final searching = widget.searchQuery.isNotEmpty;

    final byFolder = <String, List<Session>>{};
    final unfiled = <Session>[];
    for (final session in activeSessions) {
      final folderId = tree.folderOfSession(session.id);
      if (folderId != null && tree.folder(folderId)?.anchor == null) {
        (byFolder[folderId] ??= <Session>[]).add(session);
      } else {
        unfiled.add(session);
      }
    }
    final stats = _UserFolderStats(
      tree: tree,
      anchor: null,
      sessionsOf: (id) => byFolder[id] ?? const <Session>[],
      needsApproval: _needsApprovalWithChildren,
    );

    final rows = <_UserFolderRowSpec>[];
    var stagger = 0;
    Widget sessionRow(Session session, int depth) {
      final item = ListItem.activeSession(session, stagger++);
      return Padding(
        padding: EdgeInsetsDirectional.only(start: depth * userFolderIndent),
        child: _buildPerSessionItem(
          item,
          showFlavorIcons: showFlavorIcons,
          avatarStyle: avatarStyle,
        ),
      );
    }

    void addFolder(String id, int depth) {
      if (searching && stats.count(id) == 0) return;
      final expanded = searching || !_collapsedUserFolders.contains(id);
      rows.add((
        key: ValueKey('uf-$id'),
        build: () => _userFolderRow(id, depth, stats, expanded: expanded),
      ));
      if (!expanded) return;
      for (final child in tree.childrenOf(parent: id)) {
        addFolder(child, depth + 1);
      }
      for (final session in byFolder[id] ?? const <Session>[]) {
        rows.add((
          key: ValueKey('s-${session.id}'),
          build: () => sessionRow(session, depth + 1),
        ));
      }
    }

    final topLevel = tree.childrenOf();
    if (!searching) {
      rows.add((
        key: const ValueKey('uf-toolbar'),
        build: () => UserFoldersToolbar(
          notice: folders.unreadable
              ? l10n.foldersUnreadable
              : folders.readOnly
              ? l10n.foldersReadOnly
              : null,
          showEmptyHint: topLevel.isEmpty && !folders.unreadable,
          onNewFolder: folders.readOnly
              ? null
              : () => unawaited(createFolderFlow(context, ref)),
        ),
      ));
    }
    for (final id in topLevel) {
      addFolder(id, 0);
    }
    if (unfiled.isNotEmpty) {
      if (topLevel.isNotEmpty) {
        rows.add((
          key: const ValueKey('uf-unfiled'),
          build: () => SectionHeader(title: l10n.foldersUnfiled),
        ));
      }
      for (final session in unfiled) {
        rows.add((
          key: ValueKey('s-${session.id}'),
          build: () => sessionRow(session, 0),
        ));
      }
    }
    if (shouldShowInactiveSessionsSection(
      hideInactive: hideInactive,
      activeCount: activeSessions.length,
      inactiveCount: inactiveSessions.length,
    )) {
      final archived = <ListItem>[
        ListItem.archiveHeader(
          inactiveSessions.length,
          _archivedGrouping,
          stagger,
        ),
        ...(_archivedGrouping == ArchivedGrouping.folder
            ? _buildFolderGroupedItems(
                inactiveSessions,
                machines,
                orderingProjection,
                startIndex: stagger,
              )
            : _buildDateGroupedItems(
                inactiveSessions,
                orderingProjection,
                startIndex: stagger,
              )),
      ];
      for (final item in archived) {
        rows.add((
          key: _keyForItem(item),
          build: () => _buildItemWidget(
            context,
            item,
            showFlavorIcons: showFlavorIcons,
            avatarStyle: avatarStyle,
          ),
        ));
      }
    }

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.lg),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final row = rows[i];
        return StaggeredSlideIn(
          key: row.key,
          index: i,
          animate: triggerStagger,
          child: row.build(),
        );
      },
    );
  }

  Widget _userFolderRow(
    String id,
    int depth,
    _UserFolderStats stats, {
    required bool expanded,
  }) {
    final tree = stats.tree;
    final readOnly = ref.read(sessionFoldersProvider).readOnly;
    return UserFolderRow(
      name: tree.folder(id)?.name ?? '',
      depth: depth,
      sessionCount: stats.count(id),
      needsApproval: stats.needsApproval(id),
      expanded: expanded,
      canAddSubfolder: tree.doc.depth(id) < maxSessionFolderDepth,
      onToggle: () => _toggleUserFolder(id),
      onAction: readOnly ? null : (action) => _onUserFolderAction(action, id),
    );
  }

  void _onUserFolderAction(UserFolderAction action, String id) {
    final flow = switch (action) {
      UserFolderAction.newSubfolder => createFolderFlow(
        context,
        ref,
        parent: id,
      ),
      UserFolderAction.rename => renameFolderFlow(context, ref, id),
      UserFolderAction.move => moveFolderFlow(context, ref, id),
      UserFolderAction.delete => deleteFolderFlow(context, ref, id),
    };
    unawaited(flow);
  }

  bool _needsApprovalWithChildren(Session session) {
    if (AutoArchiveService.hasPendingPermission(session)) return true;
    return _nesting.childrenOf(session.id).any(_needsApprovalWithChildren);
  }

  /// [children] of [parent] split into the folders anchored at [parent]
  /// (rendered first) and the unfiled rest; null when [parent] has no
  /// folders or the Folders view is not shown.
  ({List<Widget> folders, List<Session> unfiled})? _withUserFolders(
    Session parent,
    List<Session> children,
    Widget Function(Session child) childBuilder,
  ) {
    final tree = _userFolderTree;
    if (tree == null) return null;
    final topLevel = tree.childrenOf(anchor: parent.id);
    if (topLevel.isEmpty) return null;
    final assigned = <String, List<Session>>{};
    final unfiled = <Session>[];
    for (final child in children) {
      final folderId = tree.folderOfSession(child.id);
      if (folderId != null && tree.folder(folderId)?.anchor == parent.id) {
        (assigned[folderId] ??= <Session>[]).add(child);
      } else {
        unfiled.add(child);
      }
    }
    final stats = _UserFolderStats(
      tree: tree,
      anchor: parent.id,
      sessionsOf: (id) => assigned[id] ?? const <Session>[],
      needsApproval: _needsApprovalWithChildren,
    );
    Widget folder(String id) {
      final expanded =
          widget.searchQuery.isNotEmpty || !_collapsedUserFolders.contains(id);
      return Column(
        key: ValueKey('uf-$id'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _userFolderRow(id, 0, stats, expanded: expanded),
          if (expanded)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: userFolderIndent,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final sub in tree.childrenOf(
                    anchor: parent.id,
                    parent: id,
                  ))
                    folder(sub),
                  for (final session in assigned[id] ?? const <Session>[])
                    KeyedSubtree(
                      key: ValueKey('sub-session-${session.id}'),
                      child: childBuilder(session),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    return (folders: [for (final id in topLevel) folder(id)], unfiled: unfiled);
  }
}

/// Recursive session counts and approval markers of one anchor's folders.
class _UserFolderStats {
  _UserFolderStats({
    required this.tree,
    required this.anchor,
    required this.sessionsOf,
    required bool Function(Session) needsApproval,
  }) : _sessionNeedsApproval = needsApproval;

  final FolderTree tree;
  final String? anchor;
  final List<Session> Function(String folderId) sessionsOf;
  final bool Function(Session) _sessionNeedsApproval;
  final Map<String, int> _counts = {};
  final Map<String, bool> _approval = {};

  int count(String id) => _counts[id] ??= () {
    var n = sessionsOf(id).length;
    for (final child in tree.childrenOf(anchor: anchor, parent: id)) {
      n += count(child);
    }
    return n;
  }();

  bool needsApproval(String id) => _approval[id] ??=
      sessionsOf(id).any(_sessionNeedsApproval) ||
      tree.childrenOf(anchor: anchor, parent: id).any(needsApproval);
}
