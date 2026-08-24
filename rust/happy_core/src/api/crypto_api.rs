//! Dart-facing batch crypto entry points.
//!
//! Everything here is deliberately *batch* shaped: the win over the Dart
//! implementation comes from doing a whole session catalog (or message page)
//! in one crossing on a worker thread, rather than paying per-row overhead.
//! Each function returns one slot per input, `None` for rows that failed, so
//! callers can scatter results back by index and fall through to the existing
//! Dart/NaCl path for the failures.

use crate::crypto;

/// Decrypt base64-encoded `[version][nonce][ct][tag]` envelopes.
///
/// This is the shape the wire delivers, so base64 decoding happens here too
/// instead of costing the UI isolate a second pass over the same bytes.
#[flutter_rust_bridge::frb]
pub fn decrypt_aes_gcm_base64_batch(
    key: Vec<u8>,
    envelopes_base64: Vec<String>,
    associated_data: Vec<u8>,
) -> Vec<Option<String>> {
    crypto::decrypt_base64_batch(&key, &envelopes_base64, &associated_data)
}

/// Decrypt raw (already base64-decoded) envelopes.
#[flutter_rust_bridge::frb]
pub fn decrypt_aes_gcm_batch(
    key: Vec<u8>,
    envelopes: Vec<Vec<u8>>,
    associated_data: Vec<u8>,
) -> Vec<Option<String>> {
    crypto::decrypt_batch(&key, &envelopes, &associated_data)
}

/// Cheap liveness probe used by the Dart side to decide whether the native
/// core loaded on this platform before routing any real work to it.
#[flutter_rust_bridge::frb(sync)]
pub fn native_core_ready() -> bool {
    true
}
