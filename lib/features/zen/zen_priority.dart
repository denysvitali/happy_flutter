import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ZenPriority {
  const ZenPriority._();

  static Color colorFor(String priority, ColorScheme cs) {
    switch (priority) {
      case 'critical':
        return cs.error;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return cs.tertiary;
      default:
        return cs.outline;
    }
  }
}
