import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Permission mode options for chat input
enum PermissionMode {
  browse,
  read,
  edit,
}

extension PermissionModeExtension on PermissionMode {
  String get displayName {
    switch (this) {
      case PermissionMode.browse:
        return 'Browse';
      case PermissionMode.read:
        return 'Read';
      case PermissionMode.edit:
        return 'Edit';
    }
  }

  String get description {
    switch (this) {
      case PermissionMode.browse:
        return 'Read-only access';
      case PermissionMode.read:
        return 'Read and write files';
      case PermissionMode.edit:
        return 'Full edit access';
    }
  }

  Color get color {
    switch (this) {
      case PermissionMode.browse:
        return Colors.blue;
      case PermissionMode.read:
        return Colors.orange;
      case PermissionMode.edit:
        return Colors.green;
    }
  }
}

/// Permission mode selector dropdown widget
class PermissionModeSelector extends ConsumerStatefulWidget {
  final PermissionMode? selectedMode;
  final ValueChanged<PermissionMode>? onModeChanged;
  final bool enabled;
  final double? width;

  const PermissionModeSelector({
    super.key,
    this.selectedMode,
    this.onModeChanged,
    this.enabled = true,
    this.width,
  });

  @override
  ConsumerState<PermissionModeSelector> createState() =>
      _PermissionModeSelectorState();
}

class _PermissionModeSelectorState
    extends ConsumerState<PermissionModeSelector> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showDropdown() {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _hideDropdown,
        child: Stack(
          children: [
            // Backdrop
            Positioned.fill(child: Container(color: Colors.transparent)),
            // Dropdown panel
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              width: widget.width ?? 200,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                child: _buildDropdownItems(context),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildDropdownItems(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: PermissionMode.values.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: Theme.of(context).dividerColor),
      itemBuilder: (context, index) {
        final mode = PermissionMode.values[index];
        final isSelected = widget.selectedMode == mode;

        return InkWell(
          onTap: () {
            _hideDropdown();
            widget.onModeChanged?.call(mode);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Radio indicator
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? mode.color
                          : Theme.of(context).dividerColor,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mode.color,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mode.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? mode.color
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        mode.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _buttonKey,
      onTap: widget.enabled ? _showDropdown : null,
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.enabled
                ? Theme.of(context).dividerColor
                : Theme.of(context).disabledColor,
          ),
          borderRadius: BorderRadius.circular(8),
          color: widget.enabled
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).disabledColor.withOpacity(0.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Permission mode indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (widget.selectedMode ?? PermissionMode.browse).color,
              ),
            ),
            const SizedBox(width: 8),
            // Mode text
            Text(
              (widget.selectedMode ?? PermissionMode.browse).displayName,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
            if (widget.enabled) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact permission mode badge for display
class PermissionModeBadge extends StatelessWidget {
  final PermissionMode mode;
  final double fontSize;

  const PermissionModeBadge({
    super.key,
    required this.mode,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: mode.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mode.color.withOpacity(0.3)),
      ),
      child: Text(
        mode.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: mode.color,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
