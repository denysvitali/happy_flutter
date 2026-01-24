import 'package:dio/dio.dart';
import '../api/api_client.dart';

/// GitHub OAuth parameters from server
class GitHubOAuthParams {
  final String url;

  GitHubOAuthParams({required this.url});

  factory GitHubOAuthParams.fromJson(Map<String, dynamic> json) {
    return GitHubOAuthParams(url: json['url'] as String);
  }
}

/// GitHub profile data
class GitHubProfile {
  final int id;
  final String login;
  final String name;
  final String avatarUrl;
  final String? email;

  GitHubProfile({
    required this.id,
    required this.login,
    required this.name,
    required this.avatarUrl,
    this.email,
  });

  factory GitHubProfile.fromJson(Map<String, dynamic> json) {
    return GitHubProfile(
      id: json['id'] as int,
      login: json['login'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String,
      email: json['email'] as String?,
    );
  }
}

/// Account profile including GitHub connection status
class AccountProfile {
  final String id;
  final int timestamp;
  final GitHubProfile? github;

  AccountProfile({
    required this.id,
    required this.timestamp,
    this.github,
  });

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    return AccountProfile(
      id: json['id'] as String,
      timestamp: json['timestamp'] as int,
      github: json['github'] != null
          ? GitHubProfile.fromJson(json['github'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Service for GitHub OAuth and account profile (/v1/connect/github/*, /v1/account/*)
/// Based on React Native's apiGithub.ts
class GitHubService {
  static final GitHubService _instance = GitHubService._();
  factory GitHubService() => _instance;
  GitHubService._();

  final _apiClient = ApiClient();

  /// Get GitHub OAuth parameters from the server
  Future<GitHubOAuthParams> getOAuthParams() async {
    try {
      final response = await _apiClient.get('/v1/connect/github/params');

      if (response.statusCode == 400) {
        final data = response.data as Map<String, dynamic>;
        throw GitHubException(data['error'] as String? ??
            'GitHub OAuth not configured');
      }

      if (!_apiClient.isSuccess(response)) {
        throw GitHubException(
            'Failed to get GitHub OAuth params: ${response.statusCode}');
      }

      return GitHubOAuthParams.fromJson(
          response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw GitHubException('Failed to get GitHub OAuth params: ${e.message}');
    }
  }

  /// Get account profile including GitHub connection status
  Future<AccountProfile> getAccountProfile() async {
    try {
      final response = await _apiClient.get('/v1/account/profile');

      if (!_apiClient.isSuccess(response)) {
        throw GitHubException(
            'Failed to get account profile: ${response.statusCode}');
      }

      return AccountProfile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw GitHubException('Failed to get account profile: ${e.message}');
    }
  }

  /// Disconnect GitHub account from the user's profile
  Future<void> disconnect() async {
    try {
      final response = await _apiClient.delete('/v1/connect/github');

      if (response.statusCode == 404) {
        final data = response.data as Map<String, dynamic>;
        throw GitHubException(
            data['error'] as String? ?? 'GitHub account not connected');
      }

      if (!_apiClient.isSuccess(response)) {
        throw GitHubException(
            'Failed to disconnect GitHub: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw GitHubException('Failed to disconnect GitHub account');
      }
    } on DioException catch (e) {
      throw GitHubException('Failed to disconnect GitHub: ${e.message}');
    }
  }
}

/// Exception for GitHub operations
class GitHubException implements Exception {
  final String message;
  GitHubException(this.message);

  @override
  String toString() => 'GitHubException: $message';
}
