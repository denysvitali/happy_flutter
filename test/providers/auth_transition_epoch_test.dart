import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/providers/auth_transition_epoch.dart';

void main() {
  group('AuthTransitionEpoch', () {
    test('sign-out invalidates a pending auth restore continuation', () {
      final epoch = AuthTransitionEpoch();
      final restore = epoch.begin();

      expect(epoch.isCurrent(restore), isTrue);

      epoch.invalidate();

      expect(epoch.isCurrent(restore), isFalse);
    });

    test('a newer account transition supersedes the older transition', () {
      final epoch = AuthTransitionEpoch();
      final firstAccount = epoch.begin();
      final secondAccount = epoch.begin();

      expect(epoch.isCurrent(firstAccount), isFalse);
      expect(epoch.isCurrent(secondAccount), isTrue);
    });
  });
}
