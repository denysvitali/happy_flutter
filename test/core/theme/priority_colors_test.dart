import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';

void main() {
  group('AppColors.priority*', () {
    test('priorityCritical is aliased to error', () {
      // The priority signal and the error signal should never drift.
      // Asserting identity via colour value is the strongest check
      // (a future rename of `error` would also need to update the
      // alias, but a value-level check catches the real risk:
      // someone introducing a different red for "critical").
      expect(AppColors.priorityCritical, AppColors.error);
    });

    test('priorityHigh is aliased to warning', () {
      expect(AppColors.priorityHigh, AppColors.warning);
    });

    test('priorityMedium uses the canonical amber hex', () {
      // Pinned so a future drift against the design system surfaces
      // here rather than as a visual inconsistency between Zen
      // section headers and todo-row priority chips.
      expect(AppColors.priorityMedium, const Color(0xFFF59E0B));
    });

    test('priorityLow uses the canonical iOS system gray hex', () {
      expect(AppColors.priorityLow, const Color(0xFF8E8E93));
    });

    test('all four priority colors are distinct', () {
      // Sanity: a future regression that accidentally set two
      // priorities to the same colour would be visually
      // indistinguishable. Pin distinctness.
      final set = <Color>{
        AppColors.priorityCritical,
        AppColors.priorityHigh,
        AppColors.priorityMedium,
        AppColors.priorityLow,
      };
      expect(set.length, 4);
    });
  });
}
