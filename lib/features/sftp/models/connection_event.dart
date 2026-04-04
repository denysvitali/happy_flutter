/// Connection event type
enum ConnectionEventType {
  connect,
  disconnect,
  authSuccess,
  authFailure,
  sessionStart,
  sessionEnd,
}

/// A single SFTP connection event
class ConnectionEvent {
  const ConnectionEvent({
    required this.timestamp,
    required this.deviceId,
    required this.deviceName,
    required this.eventType,
    required this.username,
    this.ipAddress,
    this.duration,
    this.reason,
    this.bytesTransferred,
  });

  factory ConnectionEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    return ConnectionEvent(
      timestamp: DateTime.parse(
        json['timestamp'] as String,
      ),
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      eventType: ConnectionEventType.values.firstWhere(
        (e) => e.name == json['eventType'],
        orElse: () => ConnectionEventType.connect,
      ),
      username: json['username'] as String,
      ipAddress: json['ipAddress'] as String?,
      duration: json['duration'] != null
          ? Duration(seconds: json['duration'] as int)
          : null,
      reason: json['reason'] as String?,
      bytesTransferred:
          json['bytesTransferred'] as int?,
    );
  }

  final DateTime timestamp;
  final String deviceId;
  final String deviceName;
  final ConnectionEventType eventType;
  final String username;
  final String? ipAddress;
  final Duration? duration;
  final String? reason;
  final int? bytesTransferred;

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
      'deviceName': deviceName,
      'eventType': eventType.name,
      'username': username,
      if (ipAddress != null) 'ipAddress': ipAddress,
      if (duration != null)
        'duration': duration!.inSeconds,
      if (reason != null) 'reason': reason,
      if (bytesTransferred != null)
        'bytesTransferred': bytesTransferred,
    };
  }
}
