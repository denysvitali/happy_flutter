import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/sessions/widgets/sessions_list_content.dart';

void main() {
  group('shouldShowInactiveSessionsSection', () {
    test('returns false when there are no inactive sessions', () {
      expect(
        shouldShowInactiveSessionsSection(
          hideInactive: false,
          activeCount: 1,
          inactiveCount: 0,
        ),
        isFalse,
      );
    });

    test('returns true when hideInactive is disabled', () {
      expect(
        shouldShowInactiveSessionsSection(
          hideInactive: false,
          activeCount: 1,
          inactiveCount: 3,
        ),
        isTrue,
      );
    });

    test('returns false when hideInactive is enabled and active exist', () {
      expect(
        shouldShowInactiveSessionsSection(
          hideInactive: true,
          activeCount: 2,
          inactiveCount: 3,
        ),
        isFalse,
      );
    });

    test('returns true as fallback when only inactive sessions exist', () {
      expect(
        shouldShowInactiveSessionsSection(
          hideInactive: true,
          activeCount: 0,
          inactiveCount: 3,
        ),
        isTrue,
      );
    });
  });
}
