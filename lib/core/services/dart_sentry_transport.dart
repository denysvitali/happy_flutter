import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../sentry_config.dart';
import 'logger_service.dart';

const _sentrySendTimeout = Duration(seconds: 10);

/// Sends Sentry envelopes through Dart HTTP.
///
/// On mobile, sentry_flutter defaults to FileSystemTransport, which hands Dart
/// envelopes to the native SDK. That native sender does not respect Dart
/// HttpOverrides, so self-hosted/private-CA GlitchTip endpoints can silently
/// fail after the SDK returns a non-empty event id.
class DartSentryTransport implements Transport {
  DartSentryTransport(this._options, {http.Client? client})
    : _client = client ?? IOClient(_sentryHttpClient()),
      _dsn = Dsn.parse(_options.dsn ?? '');

  final SentryOptions _options;
  final http.Client _client;
  final Dsn _dsn;

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelope.header.sentAt = DateTime.now().toUtc();
    final envelopeId = envelope.header.eventId;
    logger.info('[Sentry] Dart transport sending envelope id=$envelopeId');

    final request = http.StreamedRequest('POST', _dsn.postUri);
    request.headers.addAll(_headers());

    final http.Response response;
    try {
      await request.sink
          .addStream(envelope.envelopeStream(_options))
          .timeout(_sentrySendTimeout);
      await request.sink.close().timeout(_sentrySendTimeout);
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_sentrySendTimeout);
    } on TimeoutException catch (error, stackTrace) {
      logger.warning('[Sentry] Dart transport timed out for id=$envelopeId');
      _options.log(
        SentryLevel.error,
        'Timed out sending Sentry envelope with Dart transport',
        exception: error,
        stackTrace: stackTrace,
      );
      return SentryId.empty();
    } catch (error, stackTrace) {
      logger.warning('[Sentry] Dart transport send failed: $error');
      _options.log(
        SentryLevel.error,
        'Failed to send Sentry envelope with Dart transport',
        exception: error,
        stackTrace: stackTrace,
      );
      return SentryId.empty();
    }

    if (response.statusCode == 200) {
      final eventId = _eventIdFrom(response.body) ?? envelope.header.eventId;
      logger.info('[Sentry] Dart transport sent envelope id=$eventId');
      return eventId;
    }

    logger.warning(
      '[Sentry] Dart transport send failed: status=${response.statusCode}',
    );
    _options.log(
      SentryLevel.error,
      'Failed to send Sentry envelope with Dart transport: '
      'statusCode=${response.statusCode}',
    );
    return SentryId.empty();
  }

  Map<String, String> _headers() {
    var auth =
        'Sentry sentry_version=7, '
        'sentry_client=${_options.sentryClientName}, '
        'sentry_key=${_dsn.publicKey}';
    final secretKey = _dsn.secretKey;
    if (secretKey != null) {
      auth += ', sentry_secret=$secretKey';
    }

    return <String, String>{
      'Content-Type': 'application/x-sentry-envelope',
      'User-Agent': _options.sentryClientName,
      'X-Sentry-Auth': auth,
    };
  }

  SentryId? _eventIdFrom(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, Object?>) {
        final id = decoded['id'];
        if (id is String && id.isNotEmpty) {
          return SentryId.fromId(id);
        }
      }
    } catch (_) {
      // Older/self-hosted Sentry-compatible servers may return an empty body
      // for accepted envelopes; the envelope header still has the event id.
    }
    return null;
  }
}

HttpClient _sentryHttpClient() {
  return HttpClient()
    ..connectionTimeout = _sentrySendTimeout
    ..badCertificateCallback = (cert, host, port) => host == sentryHost;
}
