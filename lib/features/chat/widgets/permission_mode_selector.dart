import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Permission mode options for Claude/Gemini agents
/// Based on React Native's PermissionModeSelector.tsx
enum PermissionMode {
  // Claude/Gemini modes
  defaultMode,
  acceptEdits,
  plan,
  bypassPermissions,
  // Codex modes
  readOnly,
  safeYolo,
  yolo,
}

/// Extension for PermissionMode with React Native compatible configuration
extension PermissionModeExtension on PermissionMode {
  /// Get the display name for this mode
  String get displayName {
    switch (this) {
      case PermissionMode.defaultMode:
        return 'Default';
      case PermissionMode.acceptEdits:
        return 'Accept Edits';
      case PermissionMode.plan:
        return 'Plan';
      case PermissionMode.bypassPermissions:
        return 'Yolo';
      case PermissionMode.readOnly:
        return 'Read-only';
      case PermissionMode.safeYolo:
        return 'Safe YOLO';
      case PermissionMode.yolo:
        return 'YOLO';
    }
  }

  /// Get the description for this mode
  String get description {
    switch (this) {
      case PermissionMode.defaultMode:
        return 'Ask for permissions';
      case PermissionMode.acceptEdits:
        return 'Auto-approve edits';
      case PermissionMode.plan:
        return 'Plan before executing';
      case PermissionMode.bypassPermissions:
        return 'Skip all permissions';
      case PermissionMode.readOnly:
        return 'Read-only mode';
      case PermissionMode.safeYolo:
        return 'Safe YOLO mode';
      case PermissionMode.yolo:
        return 'YOLO mode';
    }
  }

  /// Get the color for this mode (color-coded badges)
  Color get color {
    switch (this) {
      case PermissionMode.defaultMode:
        return Colors.blue;
      case PermissionMode.acceptEdits:
        return Colors.purple;
      case PermissionMode.plan:
        return Colors.orange;
      case PermissionMode.bypassPermissions:
        return Colors.red;
      case PermissionMode.readOnly:
        return Colors.teal;
      case PermissionMode.safeYolo:
        return Colors.amber;
      case PermissionMode.yolo:
        return Colors.deepOrange;
    }
  }

  /// Get the icon for this mode
  IconData get icon {
    switch (this) {
      case PermissionMode.defaultMode:
        return Icons.shield_outlined;
      case PermissionMode.acceptEdits:
        return Icons.edit_outlined;
      case PermissionMode.plan:
        return Icons.list_alt_outlined;
      case PermissionMode.bypassPermissions:
        return Icons.flash_on_outlined;
      case PermissionMode.readOnly:
        return Icons.visibility_outlined;
      case PermissionMode.safeYolo:
        return Icons.security_outlined;
      case PermissionMode.yolo:
        return Icons.rocket_launch_outlined;
    }
  }

  /// Get the icon name string for this mode (React Native compatible)
  String get iconName {
    switch (this) {
      case PermissionMode.defaultMode:
        return 'shield-checkmark';
      case PermissionMode.acceptEdits:
        return 'create';
      case PermissionMode.plan:
        return 'list';
      case PermissionMode.bypassPermissions:
        return 'flash';
      case PermissionMode.readOnly:
        return 'eye';
      case PermissionMode.safeYolo:
        return 'shield';
      case PermissionMode.yolo:
        return 'rocket';
    }
  }

  /// Check if this is a Claude/Gemini compatible mode
  bool get isClaudeGeminiMode {
    return this == PermissionMode.defaultMode ||
        this == PermissionMode.acceptEdits ||
        this == PermissionMode.plan ||
        this == PermissionMode.bypassPermissions;
  }

  /// Check if this is a Codex compatible mode
  bool get isCodexMode {
    return this == PermissionMode.defaultMode ||
        this == PermissionMode.readOnly ||
        this == PermissionMode.safeYolo ||
        this == PermissionMode.yolo;
  }

  /// Get modes for Claude/Gemini agents
  static List<PermissionMode> get claudeGeminiModes => [
        PermissionMode.defaultMode,
        PermissionMode.acceptEdits,
        PermissionMode.plan,
        PermissionMode.bypassPermissions,
      ];

  /// Get modes for Codex agents
  static List<PermissionMode> get codexModes => [
        PermissionMode.defaultMode,
        PermissionMode.readOnly,
        PermissionMode.safeYolo,
        PermissionMode.yolo,
      ];

  /// Get all available modes
  static List<PermissionMode> get allModes => PermissionMode.values;

  /// Parse mode from string (React Native compatible)
  static PermissionMode? fromString(String value) {
    final mapping = {
      'default': PermissionMode.defaultMode,
      'acceptEdits': PermissionMode.acceptEdits,
      'plan': PermissionMode.plan,
      'bypassPermissions': PermissionMode.bypassPermissions,
      'read-only': PermissionMode.readOnly,
      'readOnly': PermissionMode.readOnly,
      'safe-yolo': PermissionMode.safeYolo,
      'safeYolo': PermissionMode.safeYolo,
      'yolo': PermissionMode.yolo,
    };
    return mapping[value];
  }

  /// Convert to string for storage/API
  String toModeString() {
    switch (this) {
      case PermissionMode.defaultMode:
        return 'default';
      case PermissionMode.acceptEdits:
        return 'acceptEdits';
      case PermissionMode.plan:
        return 'plan';
      case PermissionMode.bypassPermissions:
        return 'bypassPermissions';
      case PermissionMode.readOnly:
        return 'read-only';
      case PermissionMode.safeYolo:
        return 'safe-yolo';
      case PermissionMode.yolo:
        return 'yolo';
    }
  }
}

/// Permission mode selector dropdown widget
class PermissionModeSelector extends ConsumerStatefulWidget {
  final PermissionMode? selectedMode;
  final ValueChanged<PermissionMode>? onModeChanged;
  final bool enabled;
  final double? width;
  final List<PermissionMode>? availableModes;

  const PermissionModeSelector({
    super.key,
    this.selectedMode,
    this.onModeChanged,
    this.enabled = true,
    this.width,
    this.availableModes,
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
              width: widget.width ?? 280,
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

  List<PermissionMode> _getAvailableModes() {
    return widget.availableModes ?? PermissionMode.allModes;
  }

  Widget _buildDropdownItems(BuildContext context) {
    final modes = _getAvailableModes();

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: modes.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: Theme.of(context).dividerColor),
      itemBuilder: (context, index) {
        final mode = modes[index];
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
                // Radio indicator with mode color
                _buildRadioIndicator(context, mode, isSelected),
                const SizedBox(width: 12),
                // Mode icon
                Icon(
                  mode.icon,
                  size: 20,
                  color: isSelected ? mode.color : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                // Mode name and description
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
                // Selected check
                if (isSelected)
                  Icon(
                    Icons.check,
                    size: 18,
                    color: mode.color,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRadioIndicator(
    BuildContext context,
    PermissionMode mode,
    bool isSelected,
  ) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? mode.color : Theme.of(context).dividerColor,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = widget.selectedMode ?? PermissionMode.defaultMode;

    return GestureDetector(
      key: _buttonKey,
      onTap: widget.enabled ? _showDropdown : null,
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.enabled
                ? currentMode.color.withOpacity(0.5)
                : Theme.of(context).disabledColor,
          ),
          borderRadius: BorderRadius.circular(20),
          color: widget.enabled
              ? currentMode.color.withOpacity(0.1)
              : Theme.of(context).disabledColor.withOpacity(0.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Permission mode indicator (color-coded dot)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: currentMode.color,
              ),
            ),
            const SizedBox(width: 8),
            // Mode text
            Text(
              currentMode.displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: widget.enabled
                        ? currentMode.color
                        : Theme.of(context).disabledColor,
                  ),
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

/// Compact permission mode badge for display (color-coded)
class PermissionModeBadge extends StatelessWidget {
  final PermissionMode mode;
  final double fontSize;
  final bool showIcon;
  final EdgeInsetsGeometry? padding;

  const PermissionModeBadge({
    super.key,
    required this.mode,
    this.fontSize = 11,
    this.showIcon = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: mode.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mode.color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              mode.icon,
              size: fontSize + 2,
              color: mode.color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            mode.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mode.color,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                ),
          ),
        ],
      ),
    );
  }
}

/// Large permission mode selector for settings overlay
/// Shows all available modes as radio list tiles
class PermissionModeSettingsList extends StatelessWidget {
  final PermissionMode? selectedMode;
  final ValueChanged<PermissionMode> onModeChanged;
  final List<PermissionMode>? availableModes;

  const PermissionModeSettingsList({
    super.key,
    this.selectedMode,
    required this.onModeChanged,
    this.availableModes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modes = availableModes ?? PermissionMode.allModes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Permission Mode',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Mode options
        ...modes.map(
          (mode) => RadioListTile<PermissionMode>(
            value: mode,
            groupValue: selectedMode,
            onChanged: (value) {
              if (value != null) {
                onModeChanged(value);
              }
            },
            title: Row(
              children: [
                Icon(
                  mode.icon,
                  size: 20,
                  color: mode.color,
                ),
                const SizedBox(width: 12),
                Text(
                  mode.displayName,
                  style: TextStyle(
                    color: selectedMode == mode ? mode.color : null,
                    fontWeight:
                        selectedMode == mode ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            subtitle: Text(mode.description),
            activeColor: mode.color,
          ),
        ),
      ],
    );
  }
}
