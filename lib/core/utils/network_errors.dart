/// Connection-level transport-error classification.
///
/// These errors mean the device's network itself changed or dropped
/// mid-request — a Cronet `ERR_NETWORK_CHANGED` during a VPN handoff or a
/// wifi↔cellular transition, a DNS failure, a socket reset. They are routine
/// on mobile, they resolve without app action (the socket reconnects and the
/// next invalidation re-fetches), and cached data is unaffected — so callers
/// that only want to *log* them should not treat them as defects.
///
/// Distinct from the broader `Sync._isTransientConnectionError`, which also
/// accepts app-state transients (ApiClient reconfiguration, missing machine
/// encryption) that are worth a warning while the app warms up.

/// Whether [error] is a connection-level network failure.
bool isConnectionLevelNetworkError(Object error) {
  final msg = error.toString();
  return msg.contains('ERR_CONNECTION_ABORTED') ||
      msg.contains('ERR_CONNECTION_RESET') ||
      msg.contains('ERR_NAME_NOT_RESOLVED') ||
      msg.contains('ERR_CONNECTION_TIMED_OUT') ||
      msg.contains('ERR_NETWORK_CHANGED') ||
      msg.contains('ERR_INTERNET_DISCONNECTED') ||
      msg.contains('ERR_ADDRESS_UNREACHABLE') ||
      msg.contains('Failed host lookup') ||
      msg.contains('No address associated') ||
      msg.contains('Connection closed') ||
      msg.contains('Software caused connection abort');
}
