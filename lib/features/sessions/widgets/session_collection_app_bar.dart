import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/socket_io_client.dart' show ConnectionStatus;
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/session_utils.dart';
import '../../../core/widgets/app_linear_progress_indicator.dart';
import 'connection_status_badge.dart';
import 'session_headers.dart' show folderBreakdownLabel;
import 'sessions_view_style.dart';

double _searchInputHeight(BuildContext context) {
  final style = Theme.of(context).textTheme.bodyLarge;
  final fontSize = style?.fontSize ?? AppFontSize.lg;
  return math.max(
    AppTouchTarget.min,
    MediaQuery.textScalerOf(context).scale(fontSize) *
            (style?.height ?? AppLineHeight.normal) +
        AppSpacing.sm * 2,
  );
}

/// The session collection's layout, search and new-conversation controls.
class SessionCollectionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SessionCollectionAppBar({
    required this.searching,
    required this.controller,
    required this.connectionStatus,
    required this.scrolled,
    required this.toolbarHeight,
    required this.onStartSearch,
    required this.onCloseSearch,
    required this.onClearSearch,
    required this.onQueryChanged,
    required this.onSubmitSearch,
    required this.onCreate,
    super.key,
  });

  final bool searching;
  final TextEditingController controller;
  final ConnectionStatus connectionStatus;
  final bool scrolled;
  final double toolbarHeight;
  final VoidCallback onStartSearch;
  final VoidCallback onCloseSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onSubmitSearch;
  final VoidCallback onCreate;

  static double heightOf(BuildContext context, {required bool searching}) =>
      searching
      ? math.max(
          kToolbarHeight,
          _searchInputHeight(context) + AppSpacing.sm * 2,
        )
      : kToolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (searching) {
      return AppBar(
        toolbarHeight: toolbarHeight,
        excludeHeaderSemantics: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.commonBack,
          onPressed: onCloseSearch,
        ),
        title: _SessionSearchField(
          controller: controller,
          onChanged: onQueryChanged,
          onClear: onClearSearch,
          onClose: onCloseSearch,
          onSubmitted: onSubmitSearch,
        ),
      );
    }
    return AppBar(
      title: const SessionsViewStyleButton(asTitle: true),
      shape: scrolled
          ? Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            )
          : null,
      actions: [
        if (connectionStatus != ConnectionStatus.connected)
          ConnectionStatusBadge(status: connectionStatus),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.commonSearch,
          onPressed: onStartSearch,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.sessionsNew,
          onPressed: onCreate,
        ),
      ],
    );
  }
}

class _SessionSearchField extends StatefulWidget {
  const _SessionSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onClose,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final VoidCallback onSubmitted;

  @override
  State<_SessionSearchField> createState() => _SessionSearchFieldState();
}

class _SessionSearchFieldState extends State<_SessionSearchField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: BorderSide.none,
    );
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onClose();
              return null;
            },
          ),
        },
        child: SizedBox(
          height: _searchInputHeight(context),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            autofocus: true,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: context.l10n.sessionsBoardSearchHint,
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              prefixIcon: const Icon(Icons.search, size: AppIconSize.md),
              prefixIconConstraints: const BoxConstraints(
                minWidth: AppTouchTarget.min,
                minHeight: AppTouchTarget.min,
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: AppTouchTarget.min,
                minHeight: AppTouchTarget.min,
              ),
              // Keep the input's structure stable while only the clear
              // action reacts to text changes.
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) => IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.l10n.commonClear,
                  onPressed: value.text.isEmpty
                      ? null
                      : () {
                          _focusNode.unfocus();
                          widget.onClear();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _focusNode.requestFocus();
                          });
                        },
                ),
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(color: cs.primary),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            textInputAction: TextInputAction.search,
            onChanged: widget.onChanged,
            onSubmitted: (_) => widget.onSubmitted(),
          ),
        ),
      ),
    );
  }
}

/// Bulk actions share a horizontally scrollable row at larger text sizes.
class SessionSelectionAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SessionSelectionAppBar({
    required this.count,
    required this.allSelected,
    required this.busy,
    required this.hasActive,
    required this.hasPinned,
    required this.actionsHeight,
    required this.onCancel,
    required this.onSelectAll,
    required this.onArchive,
    required this.onPin,
    required this.onDelete,
    super.key,
  });

  final int count;
  final bool allSelected;
  final bool busy;
  final bool hasActive;
  final bool hasPinned;
  final double actionsHeight;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onArchive;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  static double actionsHeightOf(BuildContext context) => math.max(
    AppTouchTarget.comfortable,
    MediaQuery.textScalerOf(context).scale(AppFontSize.sm) *
            AppLineHeight.normal +
        AppSpacing.md,
  );

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + actionsHeight + AppSpacing.xxs);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.commonCancel,
        onPressed: busy ? null : onCancel,
      ),
      title: Text(l10n.sessionsSelectedCount(count)),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(actionsHeight + AppSpacing.xxs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  TextButton(
                    onPressed: busy ? null : onSelectAll,
                    child: Text(
                      allSelected
                          ? l10n.sessionsDeselectAll
                          : l10n.sessionsSelectAll,
                    ),
                  ),
                  if (hasActive)
                    IconButton(
                      icon: const Icon(Icons.archive_outlined),
                      tooltip: l10n.sessionsArchive,
                      onPressed: count == 0 || busy ? null : onArchive,
                    ),
                  IconButton(
                    icon: Icon(
                      hasPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    ),
                    tooltip: hasPinned ? l10n.sessionsUnpin : l10n.sessionsPin,
                    onPressed: count == 0 || busy ? null : onPin,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: busy ? null : cs.error,
                    ),
                    tooltip: l10n.commonDelete,
                    onPressed: count == 0 || busy ? null : onDelete,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: AppSpacing.xxs,
              child: busy
                  ? Semantics(
                      liveRegion: true,
                      child: AppLinearProgressIndicator(
                        minHeight: AppSpacing.xxs,
                        semanticsLabel: l10n.commonLoading,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Folder context keeps both its title and machine summary readable.
class SessionFolderAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SessionFolderAppBar({
    required this.folder,
    required this.toolbarHeight,
    required this.onBack,
    required this.onCreate,
    super.key,
  });

  final SessionFolderHeader folder;
  final double toolbarHeight;
  final VoidCallback onBack;
  final void Function(String? machineId, String? path) onCreate;

  static double heightOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return math.max(
      kToolbarHeight,
      (scaler.scale(AppFontSize.xl) + scaler.scale(AppFontSize.sm)) *
              AppLineHeight.normal +
          AppSpacing.sm * 2,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: toolbarHeight,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.commonBack,
      onPressed: onBack,
    ),
    title: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          folder.displayPath,
          style: AppText.screenTitle(Theme.of(context)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${folder.machineName} • ${folderBreakdownLabel(context, folder)}',
          style: AppText.secondary(Theme.of(context)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: context.l10n.sessionsNew,
        onPressed: () {
          final key = folder.folderKey;
          final colon = key.indexOf(':');
          onCreate(
            colon > 0 ? key.substring(0, colon) : null,
            colon > 0 && colon < key.length - 1
                ? key.substring(colon + 1)
                : null,
          );
        },
      ),
    ],
  );
}
