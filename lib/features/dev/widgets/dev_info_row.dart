import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/theme/app_tokens.dart';

/// Monospaced label/value row used by the developer diagnostic screens.
///
/// The encryption-debug, notification-test, and session-debug screens each
/// carried a byte-identical private copy of this widget.
class DevInfoRow extends StatelessWidget {
  const DevInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SettingsRow(
      icon: icon,
      title: label,
      iconColor: valueColor,
      trailing: Flexible(
        child: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: valueColor ?? cs.onSurfaceVariant,
            fontFamily: 'monospace',
            fontSize: AppFontSize.md,
          ),
          textAlign: TextAlign.end,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
