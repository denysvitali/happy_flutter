/// Base class for all API-layer exceptions.
///
/// Provides consistent [message] + optional [statusCode] fields and
/// value-based equality so that exception types can be compared in tests.
abstract class BaseApiException implements Exception {
  const BaseApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other.runtimeType == runtimeType &&
        other is BaseApiException &&
        other.message == message &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode => Object.hash(runtimeType, message, statusCode);
}
