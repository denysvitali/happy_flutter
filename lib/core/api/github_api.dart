import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// GitHub Integration API client
/// Handles GitHub OAuth and profile operations
/// Based on React Native's apiGithub.ts
class GitHubApi {
  final ApiClient _client;

  GitHubApi({ApiClient? client})
      : _client = client ?? ApiClient();

  /// Get GitHub OAuth parameters from the server
  /// Returns the OAuth URL to initiate the GitHub connection flow
  Future<GitHubOAuthParams> getOAuthParams() async {
    final response = await _client.get('/v1/connect/github/params');

    if (response.statusCode == 400) {
      final error = response.data as Map<String, dynamic>?;
      throw GitHubApiException(
        error?['error'] ?? 'GitHub OAuth not configured',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw GitHubApiException(
        'Failed to get GitHub OAuth params: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      return GitHubOAuthParams.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw GitHubApiException('Failed to parse OAuth params: $e');
    }
  }

  /// Get account profile including GitHub connection status
  /// Returns the user's profile with GitHub information if connected
  Future<AccountProfile> getAccountProfile() async {
    final response = await _client.get('/v1/account/profile');

    if (response.statusCode != 200) {
      throw GitHubApiException(
        'Failed to get account profile: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      return AccountProfile.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw GitHubApiException('Failed to parse account profile: $e');
    }
  }

  /// Disconnect GitHub account from the user's profile
  Future<void> disconnectGitHub() async {
    final response = await _client.delete('/v1/connect/github');

    if (response.statusCode == 404) {
      final error = response.data as Map<String, dynamic>?;
      throw GitHubApiException(
        error?['error'] ?? 'GitHub account not connected',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode != 200) {
      throw GitHubApiException(
        'Failed to disconnect GitHub: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw const GitHubApiException('Failed to disconnect GitHub account');
    }

    debugPrint('GitHub account disconnected successfully');
  }

  /// Register a GitHub OAuth callback token
  /// Called after successful OAuth redirect
  Future<void> registerOAuthToken(String token) async {
    if (token.isEmpty) {
      throw const GitHubApiException('OAuth token cannot be empty');
    }

    final response = await _client.post(
      '/v1/connect/github/register',
      data: {'token': token},
    );

    if (response.statusCode != 200) {
      throw GitHubApiException(
        'Failed to register GitHub token: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = response.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw const GitHubApiException('Failed to register GitHub token');
    }

    debugPrint('GitHub OAuth token registered successfully');
  }

  /// Check if GitHub account is connected
  Future<bool> isGitHubConnected() async {
    try {
      final profile = await getAccountProfile();
      return profile.github != null;
    } catch (e) {
      debugPrint('Error checking GitHub connection: $e');
      return false;
    }
  }
}

/// Exception thrown by GitHub API operations
class GitHubApiException implements Exception {
  final String message;
  final int? statusCode;

  const GitHubApiException(this.message, {this.statusCode});

  @override
  String toString() => 'GitHubApiException: $message';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GitHubApiException &&
        other.message == message &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode => Object.hash(message, statusCode);
}

/// GitHub OAuth parameters
class GitHubOAuthParams {
  final String url;

  const GitHubOAuthParams({required this.url});

  factory GitHubOAuthParams.fromJson(Map<String, dynamic> json) {
    return GitHubOAuthParams(
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url};
  }

  @override
  String toString() => 'GitHubOAuthParams(url: $url)';
}

/// Account profile information
class AccountProfile {
  final String id;
  final int timestamp;
  final GitHubProfileInfo? github;

  const AccountProfile({
    required this.id,
    required this.timestamp,
    this.github,
  });

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    return AccountProfile(
      id: json['id'] as String,
      timestamp: json['timestamp'] as int,
      github: json['github'] != null
          ? GitHubProfileInfo.fromJson(
              json['github'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'github': github?.toJson(),
    };
  }

  @override
  String toString() =>
      'AccountProfile(id: $id, timestamp: $timestamp, github: $github)';
}

/// GitHub profile information
class GitHubProfileInfo {
  final int id;
  final String login;
  final String name;
  final String avatarUrl;
  final String? email;

  const GitHubProfileInfo({
    required this.id,
    required this.login,
    required this.name,
    required this.avatarUrl,
    this.email,
  });

  factory GitHubProfileInfo.fromJson(Map<String, dynamic> json) {
    return GitHubProfileInfo(
      id: json['id'] as int,
      login: json['login'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'login': login,
      'name': name,
      'avatar_url': avatarUrl,
      'email': email,
    };
  }

  @override
  String toString() =>
      'GitHubProfileInfo(id: $id, login: $login, name: $name)';
}
