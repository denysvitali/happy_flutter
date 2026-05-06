import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'logger_service.dart';

const _sentrySendTimeout = Duration(seconds: 10);

/// Sends Sentry envelopes through Dart HTTP.
///
/// On mobile, sentry_flutter defaults to FileSystemTransport, which hands Dart
/// envelopes to the native SDK. This transport keeps Dart-originated delivery
/// observable in app logs and bounded by explicit timeouts while still relying
/// on the platform trust store for TLS validation.
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

    final http.Response response;
    try {
      final body = await _envelopeBytes(envelope);
      final request = http.Request('POST', _dsn.postUri)
        ..headers.addAll(_headers())
        ..bodyBytes = body;
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

    final responseContext = _responseContext(response);
    if (response.statusCode == 200) {
      final parsedEventId = _eventIdFrom(response.body);
      if (parsedEventId == null) {
        logger.warning(
          '[Sentry] Dart transport got 200 without response event id '
          '$responseContext',
        );
      }
      final eventId = parsedEventId ?? envelope.header.eventId;
      logger.info('[Sentry] Dart transport sent envelope id=$eventId');
      return eventId;
    }

    logger.warning(
      '[Sentry] Dart transport send failed: status=${response.statusCode} '
      '$responseContext',
    );
    _options.log(
      SentryLevel.error,
      'Failed to send Sentry envelope with Dart transport: '
      'statusCode=${response.statusCode}',
    );
    return SentryId.empty();
  }

  String _responseContext(http.Response response) {
    final contentType = response.headers['content-type'] ?? '-';
    final server = response.headers['server'] ?? '-';
    final body = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final snippet = body.length <= 180 ? body : '${body.substring(0, 180)}...';
    return 'contentType=$contentType server=$server '
        'bodyLen=${response.body.length} body="$snippet"';
  }

  Future<Uint8List> _envelopeBytes(SentryEnvelope envelope) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk
        in envelope.envelopeStream(_options).timeout(_sentrySendTimeout)) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
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
  return HttpClient()..connectionTimeout = _sentrySendTimeout;
}
