import 'dart:async';
import 'dart:convert' show JsonUnsupportedObjectError;

import 'package:dio/dio.dart';

import 'opentelemetry_service.dart';

/// Centralised emit points for the client's failure counters.
///
/// Everything in this file exists to keep metric cardinality **bounded**.
/// Attribute values are drawn from small, closed vocabularies declared as
/// constants below — never from a session id, message id, `localId`, file
/// path, or a raw exception string.  An earlier revision of this
/// instrumentation tagged counters with ids and produced unbounded time
/// series; the classifier helpers here are the guard against a repeat.

// ---------------------------------------------------------------------------
// Vocabularies (closed sets — do not widen without checking cardinality)
// ---------------------------------------------------------------------------

/// Which cryptographic envelope the failing payload used.
///
/// One of `aes`, `nacl`, `unknown`.
typedef DecryptEnvelopeTag = String;

/// Which logical payload failed to decrypt.
///
/// One of `messages`, `metadata`, `agent_state`, `dek`, `raw`, `unknown`.
typedef DecryptStageTag = String;

const String kEnvelopeAes = 'aes';
const String kEnvelopeNacl = 'nacl';
const String kEnvelopeUnknown = 'unknown';

const String kStageMessages = 'messages';
const String kStageMetadata = 'metadata';
const String kStageAgentState = 'agent_state';
const String kStageDek = 'dek';
const String kStageRaw = 'raw';
const String kStageUnknown = 'unknown';

const String kReasonHttp = 'http';
const String kReasonDecrypt = 'decrypt';
const String kReasonParse = 'parse';
const String kReasonDisposed = 'disposed';
const String kReasonTimeout = 'timeout';

/// Metric names, so call sites and tests cannot drift apart.
const String kDecryptFailuresMetric = 'app.crypto.decrypt_failures';
const String kUndecryptableRenderedMetric = 'app.messages.undecryptable_rendered';
const String kSyncFailuresMetric = 'app.sync.failures';

// ---------------------------------------------------------------------------
// Emit helpers
// ---------------------------------------------------------------------------

/// Count [count] decryption failures sharing the same
/// `(envelope, stage, from_cache)` shape.
///
/// Callers are expected to aggregate: a wrong-key page fails every one of
/// its 500 messages, and emitting 500 counter adds (each allocating an
/// attribute map) on the decrypt hot path is exactly the kind of storm
/// this instrumentation is supposed to observe, not cause.  Pass the batch
/// total as [count] instead.
void recordDecryptFailure({
  required DecryptEnvelopeTag envelope,
  required DecryptStageTag stage,
  required bool fromCache,
  int count = 1,
}) {
  if (count <= 0) return;
  OpenTelemetryService().recordCount(
    kDecryptFailuresMetric,
    value: count,
    attributes: <String, Object?>{
      'envelope': envelope,
      'stage': stage,
      'from_cache': fromCache,
    },
    description: 'Payloads the client failed to decrypt, by envelope and '
        'the logical payload that failed',
  );
}

/// Count undecryptable messages that were turned into a user-visible
/// error bubble.  [count] is the per-batch total for the same
/// [errorType].
void recordUndecryptableRendered({
  required String errorType,
  int count = 1,
}) {
  if (count <= 0) return;
  OpenTelemetryService().recordCount(
    kUndecryptableRenderedMetric,
    value: count,
    attributes: <String, Object?>{'error_type': errorType},
    description: 'Messages rendered to the user as an error bubble because '
        'they could not be decrypted or decoded',
  );
}

/// Count a sync cycle that failed for [domain] with [reason].
///
/// [domain] must be a `SyncDomain` name or an equivalently bounded
/// string — never a session id or a name carrying a dynamic suffix.
void recordSyncFailure({
  required String domain,
  required String reason,
  int count = 1,
}) {
  if (count <= 0) return;
  OpenTelemetryService().recordCount(
    kSyncFailuresMetric,
    value: count,
    attributes: <String, Object?>{'domain': domain, 'reason': reason},
    description: 'Sync cycles that failed, by domain and failure class',
  );
}

// ---------------------------------------------------------------------------
// Classifiers
// ---------------------------------------------------------------------------

/// Bucket an arbitrary error into the closed `reason` vocabulary.
///
/// Deliberately returns a constant, never `error.toString()` — the whole
/// point is that a novel exception message cannot mint a new time series.
String classifySyncFailureReason(Object? error) {
  if (error is TimeoutException) return kReasonTimeout;
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return kReasonTimeout;
      case DioExceptionType.badResponse:
      case DioExceptionType.connectionError:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return kReasonHttp;
    }
  }
  if (error is StateError) {
    // `Bad state: ... after dispose` / "already disposed" style errors are
    // the disposed-provider class the roadmap tracks separately.
    return error.message.toLowerCase().contains('dispos')
        ? kReasonDisposed
        : kReasonParse;
  }
  if (error is FormatException ||
      error is TypeError ||
      error is JsonUnsupportedObjectError) {
    return kReasonParse;
  }
  return kReasonParse;
}

/// Map a `CryptoSecretBox` diagnostic scope (`session:<id>:messages`,
/// `machine:<id>:daemon-state`, ...) onto the bounded stage vocabulary.
///
/// Only the trailing segment is read; the embedded id is discarded so it
/// can never reach an attribute value.
DecryptStageTag decryptStageFromScope(String? scope) {
  if (scope == null || scope.isEmpty) return kStageUnknown;
  final lastColon = scope.lastIndexOf(':');
  final suffix = lastColon < 0 ? scope : scope.substring(lastColon + 1);
  switch (suffix) {
    case 'messages':
      return kStageMessages;
    case 'metadata':
      return kStageMetadata;
    case 'agent-state':
    case 'agent_state':
    case 'daemon-state':
      return kStageAgentState;
    case 'dek':
      return kStageDek;
    case 'raw':
      return kStageRaw;
    default:
      return kStageUnknown;
  }
}
