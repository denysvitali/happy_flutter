import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/profile.dart';

void main() {
  group('Profile.fromJson', () {
    test('parses nullable github fields without throwing', () {
      final profile = Profile.fromJson({
        'id': 'user-123',
        'timestamp': 123456,
        'github': {
          'id': '42',
          'login': 'octocat',
          'name': null,
          'avatar_url': null,
          'email': null,
          'bio': null,
        },
      });

      expect(profile.id, 'user-123');
      expect(profile.github, isNotNull);
      expect(profile.github!.id, 42);
      expect(profile.github!.login, 'octocat');
      expect(profile.github!.name, 'octocat');
      expect(profile.github!.avatarUrl, '');
      expect(profile.github!.email, isNull);
      expect(profile.github!.bio, isNull);
    });

    test('ignores non-map avatar payloads', () {
      final profile = Profile.fromJson({
        'id': 'user-123',
        'avatar': 'https://example.com/avatar.png',
      });

      expect(profile.avatar, isNull);
    });

    test('filters null connected services entries', () {
      final profile = Profile.fromJson({
        'id': 'user-123',
        'connectedServices': ['github', null, 'claude'],
      });

      expect(profile.connectedServices, ['github', 'claude']);
    });
  });
}
