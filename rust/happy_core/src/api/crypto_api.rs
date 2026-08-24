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

/// Synchronous batch decrypt for the per-row callers.
///
/// `SessionEncryption.decryptMetadata` / `decryptAgentState` / `decryptRaw`
/// each decrypt a single small payload, and a cold catalog runs ~502 of them.
/// Those want the *sync* bridge: it executes on the calling isolate with no
/// worker hop, which for a few-KB payload is dominated by hop latency rather
/// than cipher time — while still being hardware AES instead of a pure-Dart
/// block cipher. Large batches should use the async entry points above so the
/// work leaves the UI isolate entirely.
#[flutter_rust_bridge::frb(sync)]
pub fn decrypt_aes_gcm_batch_sync(
    key: Vec<u8>,
    envelopes: Vec<Vec<u8>>,
    associated_data: Vec<u8>,
) -> Vec<Option<String>> {
    crypto::decrypt_batch(&key, &envelopes, &associated_data)
}

/// Synchronous batch encrypt, mirroring [`decrypt_aes_gcm_batch_sync`].
///
/// `nonces` must supply one [`crypto::NONCE_LEN`]-byte CSPRNG nonce per
/// plaintext; generating them stays on the Dart side so this function has no
/// ambient randomness and remains deterministic under test.
#[flutter_rust_bridge::frb(sync)]
pub fn encrypt_aes_gcm_batch_sync(
    key: Vec<u8>,
    plaintexts: Vec<String>,
    nonces: Vec<Vec<u8>>,
    associated_data: Vec<u8>,
) -> Vec<Option<Vec<u8>>> {
    crypto::encrypt_batch(&key, &plaintexts, &nonces, &associated_data)
}

/// At-rest batch decrypt: `[nonce][ciphertext][tag]`, no version byte, with
/// the caller's domain string bound as GCM associated data.
///
/// Sync because the caller that matters is the suspend flush, which must
/// finish before the process can be killed.
#[flutter_rust_bridge::frb(sync)]
pub fn decrypt_at_rest_batch_sync(
    key: Vec<u8>,
    payloads: Vec<Vec<u8>>,
    associated_data: Vec<u8>,
) -> Vec<Option<String>> {
    crypto::decrypt_at_rest_batch(&key, &payloads, &associated_data)
}

/// At-rest batch encrypt. See [`decrypt_at_rest_batch_sync`].
///
/// The Dart side keeps ownership of nonce generation so this stays free of
/// ambient randomness; each nonce must be 12 CSPRNG bytes, never reused.
#[flutter_rust_bridge::frb(sync)]
pub fn encrypt_at_rest_batch_sync(
    key: Vec<u8>,
    plaintexts: Vec<String>,
    nonces: Vec<Vec<u8>>,
    associated_data: Vec<u8>,
) -> Vec<Option<Vec<u8>>> {
    crypto::encrypt_at_rest_batch(&key, &plaintexts, &nonces, &associated_data)
}
