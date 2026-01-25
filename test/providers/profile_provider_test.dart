import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('ProfileProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should initialize with null profile', () {
      final profile = container.read(profileNotifierProvider);
      expect(profile, isNull);
    });

    test('should update profile', () {
      final notifier = container.read(profileNotifierProvider.notifier);

      final githubProfile = GitHubProfile(
        id: 123456,
        login: 'testuser',
        name: 'Test User',
        avatarUrl: 'https://github.com/testuser.png',
        email: 'test@example.com',
        bio: 'Test bio',
      );

      final profile = Profile(
        id: 'user-123',
        timestamp: 1234567890,
        firstName: 'Test',
        lastName: 'User',
        avatar: ImageRef(
          width: 200,
          height: 200,
          thumbhash: 'abc123',
          path: '/avatars/test.png',
          url: 'https://example.com/avatar.png',
        ),
        github: githubProfile,
        connectedServices: ['claude', 'github'],
      );

      notifier.updateProfile(profile);
      final updated = container.read(profileNotifierProvider);

      expect(updated, isNotNull);
      expect(updated?.id, 'user-123');
      expect(updated?.firstName, 'Test');
      expect(updated?.lastName, 'User');
      expect(updated?.github?.login, 'testuser');
      expect(updated?.connectedServices, contains('claude'));
      expect(updated?.connectedServices, contains('github'));
    });

    test('should update avatar URL', () async {
      final notifier = container.read(profileNotifierProvider.notifier);

      final profile = Profile(
        id: 'user-123',
        timestamp: 1234567890,
        firstName: 'Test',
        lastName: 'User',
      );

      notifier.updateProfile(profile);

      await notifier.updateAvatar('https://example.com/new-avatar.png');
      final updated = container.read(profileNotifierProvider);

      expect(updated?.avatarUrl, 'https://example.com/new-avatar.png');
    });

    test('should disconnect GitHub', () async {
      final notifier = container.read(profileNotifierProvider.notifier);

      final githubProfile = GitHubProfile(
        id: 123456,
        login: 'testuser',
        name: 'Test User',
        avatarUrl: 'https://github.com/testuser.png',
      );

      final profile = Profile(
        id: 'user-123',
        timestamp: 1234567890,
        github: githubProfile,
      );

      notifier.updateProfile(profile);

      await notifier.disconnectGitHub();
      final updated = container.read(profileNotifierProvider);

      expect(updated?.github, isNull);
    });

    test('should compute display name correctly', () {
      final notifier = container.read(profileNotifierProvider.notifier);

      // Test with name
      final profile1 = Profile(
        id: 'user-123',
        timestamp: 1234567890,
        firstName: 'John',
        lastName: 'Doe',
      );

      notifier.updateProfile(profile1);
      expect(container.read(profileNotifierProvider)?.displayName, 'John Doe');

      // Test with GitHub name
      final githubProfile = GitHubProfile(
        id: 123456,
        login: 'johndoe',
        name: 'John Doe',
        avatarUrl: 'https://github.com/johndoe.png',
      );

      final profile2 = Profile(
        id: 'user-123',
        timestamp: 1234567890,
        github: githubProfile,
      );

      notifier.updateProfile(profile2);
      expect(container.read(profileNotifierProvider)?.displayName, 'John Doe');

      // Test with GitHub login fallback
      final githubProfile2 = GitHubProfile(
        id: 123456,
        login: 'johndoe',
        name: '',
        avatarUrl: 'https://github.com/johndoe.png',
      );

      final profile3 = Profile(
        id: 'user-123',
        timestamp: 1234567890,
        github: githubProfile2,
      );

      notifier.updateProfile(profile3);
      expect(container.read(profileNotifierProvider)?.displayName, 'johndoe');
    });

    test('should compute avatar URL correctly', () {
      final notifier = container.read(profileNotifierProvider.notifier);

      // Test with ImageRef avatar
      final avatar = ImageRef(
        width: 200,
        height: 200,
        thumbhash: 'abc123',
        path: '/avatars/test.png',
        url: 'https://example.com/avatar.png',
      );

      final profile1 = Profile(
        id: 'user-123',
        timestamp: 1234567890,
        avatar: avatar,
      );

      notifier.updateProfile(profile1);
      expect(
        container.read(profileNotifierProvider)?.avatarUrl,
        'https://example.com/avatar.png',
      );

      // Test with GitHub avatar fallback
      final githubProfile = GitHubProfile(
        id: 123456,
        login: 'testuser',
        name: 'Test User',
        avatarUrl: 'https://github.com/testuser.png',
      );

      final profile2 = Profile(
        id: 'user-123',
        timestamp: 1234567890,
        github: githubProfile,
      );

      notifier.updateProfile(profile2);
      expect(
        container.read(profileNotifierProvider)?.avatarUrl,
        'https://github.com/testuser.png',
      );
    });
  });
}
