import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/network_errors.dart';

void main() {
  group('isConnectionLevelNetworkError', () {
    // GlitchTip 4900/8573: Cronet aborts during VPN handoffs and network
    // transitions surfaced as error-level issues even though the client
    // preserved cached data and re-armed its fetches. Only the
    // connection-level family counts — server-side failures must keep
    // their error-level reporting (they are the brownout signal).
    test('classifies Cronet network-transition aborts', () {
      expect(
        isConnectionLevelNetworkError(
          'ClientException: Cronet exception: Exception in '
          'CronetUrlRequest: net::ERR_NETWORK_CHANGED, Retryable=true',
        ),
        isTrue,
      );
      expect(
        isConnectionLevelNetworkError(
          'ClientException: Cronet exception: Exception in '
          'CronetUrlRequest: net::ERR_CONNECTION_ABORTED, '
          'Retryable=false',
        ),
        isTrue,
      );
    });

    test('classifies DNS and socket-level failures', () {
      expect(isConnectionLevelNetworkError('Failed host lookup: x'), isTrue);
      expect(isConnectionLevelNetworkError('Connection closed'), isTrue);
      expect(
        isConnectionLevelNetworkError('Software caused connection abort'),
        isTrue,
      );
    });

    test('does not swallow server-side failures', () {
      expect(
        isConnectionLevelNetworkError(
          'DioException [receive timeout]: The request took longer than '
          '0:00:23.000000 to receive data',
        ),
        isFalse,
      );
      expect(isConnectionLevelNetworkError('Bad state: HTTP 504'), isFalse);
      expect(isConnectionLevelNetworkError(StateError('spawn failed')), isFalse);
    });
  });
}
