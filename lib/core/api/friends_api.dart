import '../models/friend_request.dart';
import '../services/logger_service.dart' show logger;
import 'api_client.dart';

/// API client for friend requests.
class FriendsApi {
  FriendsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  /// Fetches pending inbound friend requests for the current user.
  Future<List<FriendRequest>> fetchPendingRequests() async {
    try {
      final response = await _client.get('/v1/friends/requests/pending');
      final data = response.data;
      if (data is! List) return [];
      return data
          .whereType<Map<String, dynamic>>()
          .map(FriendRequest.fromJson)
          .toList();
    } catch (e, st) {
      logger.warning('FriendsApi.fetchPendingRequests failed', e, st);
      return [];
    }
  }

  /// Accepts a friend request by [requestId].
  Future<bool> acceptRequest(String requestId) async {
    try {
      final response = await _client.post(
        '/v1/friends/requests/$requestId/accept',
      );
      final statusCode = response.statusCode;
      return statusCode != null && statusCode >= 200 && statusCode < 300;
    } catch (e, st) {
      logger.warning(
        'FriendsApi.acceptRequest failed requestId=$requestId',
        e,
        st,
      );
      return false;
    }
  }

  /// Declines (rejects) a friend request by [requestId].
  Future<bool> declineRequest(String requestId) async {
    try {
      final response = await _client.post(
        '/v1/friends/requests/$requestId/decline',
      );
      final statusCode = response.statusCode;
      return statusCode != null && statusCode >= 200 && statusCode < 300;
    } catch (e, st) {
      logger.warning(
        'FriendsApi.declineRequest failed requestId=$requestId',
        e,
        st,
      );
      return false;
    }
  }
}
