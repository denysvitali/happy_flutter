//! Batch AES-256-GCM matching the app's on-wire envelope byte for byte.
//!
//! Envelope (identical to `AES256Encryption` in
//! `lib/core/encryption/encryptor.dart`, itself compatible with React
//! Native's `rn-encryption`):
//!
//! ```text
//! [1-byte version = 0][12-byte nonce/IV][ciphertext][16-byte auth tag]
//! ```
//!
//! The plaintext is always UTF-8 JSON, because the Dart encrypt path runs
//! `utf8.encode(jsonEncode(data))` before sealing.
//!
//! Why this lives in Rust: the Dart implementation resolves to `DartAesGcm`
//! (the app depends on `cryptography` with no `cryptography_flutter`), i.e.
//! a pure-Dart block cipher at roughly 8-15 MB/s that runs *on the UI
//! isolate*. A cold session catalog decrypts up to two payloads per session
//! (metadata + agent state), so at 251+ sessions that is ~502 inline
//! decrypts draining in a single pass and blocking every frame in it.
//! `aes-gcm` here compiles to AES-NI / ARMv8 crypto extensions, and the
//! batch entry points let the caller pay one FFI crossing per catalog
//! instead of one per row.

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use base64::engine::general_purpose::STANDARD as BASE64;
use base64::Engine;

/// Envelope version byte written and required by the Dart implementation.
pub const ENVELOPE_VERSION: u8 = 0;
/// GCM nonce length in bytes.
pub const NONCE_LEN: usize = 12;
/// GCM authentication tag length in bytes.
pub const TAG_LEN: usize = 16;
/// AES-256 key length in bytes.
pub const KEY_LEN: usize = 32;

/// Smallest envelope that can possibly be valid: version + nonce + tag,
/// i.e. an empty ciphertext.
const MIN_ENVELOPE_LEN: usize = 1 + NONCE_LEN + TAG_LEN;

/// Why a single row could not be decrypted.
///
/// Mirrors the Dart contract: a recoverable failure yields `null` for that
/// row so the caller can fall through to legacy/NaCl decryption or treat the
/// row as undecryptable — it must never abort the whole batch.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DecryptError {
    /// Key was not exactly [`KEY_LEN`] bytes.
    BadKeyLength,
    /// Envelope was too short to contain version + nonce + tag.
    TooShort,
    /// Leading byte was not [`ENVELOPE_VERSION`].
    BadVersion,
    /// Input was not valid base64 (base64 entry points only).
    BadBase64,
    /// GCM authentication failed — wrong key, or corrupt ciphertext.
    AuthFailed,
    /// Plaintext was not valid UTF-8, so it cannot be the JSON the app wrote.
    NotUtf8,
}

fn cipher_for(key: &[u8]) -> Result<Aes256Gcm, DecryptError> {
    if key.len() != KEY_LEN {
        return Err(DecryptError::BadKeyLength);
    }
    Ok(Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(key)))
}

/// Decrypt one envelope, returning the UTF-8 JSON plaintext.
///
/// `associated_data` is passed through to GCM's AAD. The session-message
/// envelope uses no AAD (pass an empty slice); the at-rest cache envelope
/// binds a domain string, so it passes that.
pub fn decrypt_one(
    cipher: &Aes256Gcm,
    envelope: &[u8],
    associated_data: &[u8],
) -> Result<String, DecryptError> {
    if envelope.len() < MIN_ENVELOPE_LEN {
        return Err(DecryptError::TooShort);
    }
    if envelope[0] != ENVELOPE_VERSION {
        return Err(DecryptError::BadVersion);
    }
    let nonce = Nonce::from_slice(&envelope[1..1 + NONCE_LEN]);
    // `aes-gcm` expects the tag appended to the ciphertext, which is exactly
    // how the Dart side lays it out — so this is a plain slice, no splicing.
    let ciphertext = &envelope[1 + NONCE_LEN..];
    let plaintext = cipher
        .decrypt(
            nonce,
            Payload {
                msg: ciphertext,
                aad: associated_data,
            },
        )
        .map_err(|_| DecryptError::AuthFailed)?;
    String::from_utf8(plaintext).map_err(|_| DecryptError::NotUtf8)
}

/// Decrypt a batch of raw envelopes.
///
/// Returns one entry per input, `None` where that row failed, preserving
/// index alignment so the caller can scatter results back by position.
pub fn decrypt_batch(
    key: &[u8],
    envelopes: &[Vec<u8>],
    associated_data: &[u8],
) -> Vec<Option<String>> {
    let cipher = match cipher_for(key) {
        Ok(cipher) => cipher,
        // A bad key fails every row; still return aligned `None`s rather
        // than an error so the caller's fallback path is uniform.
        Err(_) => return vec![None; envelopes.len()],
    };
    envelopes
        .iter()
        .map(|envelope| decrypt_one(&cipher, envelope, associated_data).ok())
        .collect()
}

/// Decrypt a batch of base64-encoded envelopes.
///
/// This is the shape the wire actually delivers, so decoding here saves the
/// caller a second full pass over the same bytes on the UI isolate.
pub fn decrypt_base64_batch(
    key: &[u8],
    envelopes_b64: &[String],
    associated_data: &[u8],
) -> Vec<Option<String>> {
    let cipher = match cipher_for(key) {
        Ok(cipher) => cipher,
        Err(_) => return vec![None; envelopes_b64.len()],
    };
    envelopes_b64
        .iter()
        .map(|encoded| {
            let raw = BASE64.decode(encoded.as_bytes()).ok()?;
            decrypt_one(&cipher, &raw, associated_data).ok()
        })
        .collect()
}

/// Seal one UTF-8 JSON plaintext into the app's envelope.
///
/// `nonce` must be exactly [`NONCE_LEN`] cryptographically random bytes and
/// must never repeat for a given key. It is supplied by the caller so this
/// function stays deterministic and testable; production callers pass bytes
/// from a CSPRNG.
pub fn encrypt_one(
    cipher: &Aes256Gcm,
    plaintext: &str,
    nonce: &[u8],
    associated_data: &[u8],
) -> Result<Vec<u8>, DecryptError> {
    if nonce.len() != NONCE_LEN {
        return Err(DecryptError::TooShort);
    }
    let sealed = cipher
        .encrypt(
            Nonce::from_slice(nonce),
            Payload {
                msg: plaintext.as_bytes(),
                aad: associated_data,
            },
        )
        .map_err(|_| DecryptError::AuthFailed)?;
    let mut out = Vec::with_capacity(1 + NONCE_LEN + sealed.len());
    out.push(ENVELOPE_VERSION);
    out.extend_from_slice(nonce);
    out.extend_from_slice(&sealed);
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key() -> Vec<u8> {
        (0u8..32).collect()
    }

    fn nonce() -> Vec<u8> {
        (0u8..12).collect()
    }

    #[test]
    fn round_trips_and_lays_out_the_envelope_exactly() {
        let cipher = cipher_for(&key()).unwrap();
        let plaintext = r#"{"hello":"world"}"#;
        let envelope = encrypt_one(&cipher, plaintext, &nonce(), b"").unwrap();

        assert_eq!(envelope[0], ENVELOPE_VERSION, "version byte first");
        assert_eq!(&envelope[1..13], nonce().as_slice(), "nonce follows");
        assert_eq!(
            envelope.len(),
            1 + NONCE_LEN + plaintext.len() + TAG_LEN,
            "ciphertext is same length as plaintext, tag appended",
        );
        assert_eq!(decrypt_one(&cipher, &envelope, b"").unwrap(), plaintext);
    }

    #[test]
    fn rejects_a_foreign_version_byte() {
        let cipher = cipher_for(&key()).unwrap();
        let mut envelope = encrypt_one(&cipher, "{}", &nonce(), b"").unwrap();
        envelope[0] = 1;
        assert_eq!(
            decrypt_one(&cipher, &envelope, b""),
            Err(DecryptError::BadVersion),
        );
    }

    #[test]
    fn rejects_tampered_ciphertext() {
        let cipher = cipher_for(&key()).unwrap();
        let mut envelope = encrypt_one(&cipher, "{}", &nonce(), b"").unwrap();
        let last = envelope.len() - 1;
        envelope[last] ^= 0xff;
        assert_eq!(
            decrypt_one(&cipher, &envelope, b""),
            Err(DecryptError::AuthFailed),
        );
    }

    #[test]
    fn associated_data_must_match() {
        let cipher = cipher_for(&key()).unwrap();
        let envelope = encrypt_one(&cipher, "{}", &nonce(), b"domain-a").unwrap();
        assert!(decrypt_one(&cipher, &envelope, b"domain-a").is_ok());
        assert_eq!(
            decrypt_one(&cipher, &envelope, b"domain-b"),
            Err(DecryptError::AuthFailed),
        );
    }

    #[test]
    fn a_failed_row_does_not_abort_the_batch() {
        let cipher = cipher_for(&key()).unwrap();
        let good = encrypt_one(&cipher, r#"{"n":1}"#, &nonce(), b"").unwrap();
        let mut bad = good.clone();
        bad[0] = 9;

        let results = decrypt_batch(&key(), &[good.clone(), bad, good], b"");

        assert_eq!(results.len(), 3, "index alignment is preserved");
        assert_eq!(results[0].as_deref(), Some(r#"{"n":1}"#));
        assert_eq!(results[1], None, "the bad row yields null, not a panic");
        assert_eq!(results[2].as_deref(), Some(r#"{"n":1}"#));
    }

    #[test]
    fn a_short_envelope_is_rejected_without_panicking() {
        let cipher = cipher_for(&key()).unwrap();
        for len in 0..MIN_ENVELOPE_LEN {
            let truncated = vec![ENVELOPE_VERSION; len];
            assert!(decrypt_one(&cipher, &truncated, b"").is_err());
        }
    }

    #[test]
    fn a_wrong_length_key_fails_every_row_but_stays_aligned() {
        let results = decrypt_batch(&[0u8; 16], &[vec![0u8; 40]], b"");
        assert_eq!(results, vec![None]);
    }

    #[test]
    fn decodes_base64_envelopes() {
        let cipher = cipher_for(&key()).unwrap();
        let envelope = encrypt_one(&cipher, r#"{"a":2}"#, &nonce(), b"").unwrap();
        let encoded = BASE64.encode(&envelope);

        let results = decrypt_base64_batch(&key(), &[encoded, "!!not base64".into()], b"");

        assert_eq!(results[0].as_deref(), Some(r#"{"a":2}"#));
        assert_eq!(results[1], None);
    }
}

/// Cross-language vectors.
///
/// These are the real guarantee that this module is wire-compatible with
/// `AES256Encryption` in Dart: the envelope below was produced by the Dart
/// implementation and must decrypt here unchanged. If a refactor ever breaks
/// the layout, every persisted message and every server payload becomes
/// undecryptable — so this test failing means "do not ship", never "update
/// the vector".
#[cfg(test)]
mod dart_compat {
    use super::*;

    /// Key is bytes 0..31, matching the generator that produced the vector.
    fn dart_key() -> Vec<u8> {
        (0u8..32).collect()
    }

    /// Emitted by Dart: `AES256Encryption(key).encrypt([{hello, n}])`.
    const DART_ENVELOPE_B64: &str =
        "ACLN5UynvgoPhdsOLoivEjNNe18DKRqmhdDKBh0Ovr5aeQ/aIktvjlrhswNDOivXTG4CsQk=";

    #[test]
    fn decrypts_an_envelope_produced_by_the_dart_implementation() {
        let results = decrypt_base64_batch(&dart_key(), &[DART_ENVELOPE_B64.into()], b"");
        assert_eq!(
            results[0].as_deref(),
            Some(r#"{"hello":"world","n":42}"#),
            "Rust must read the exact bytes Dart writes",
        );
    }

    #[test]
    fn dart_written_envelopes_use_the_expected_layout() {
        let raw = BASE64.decode(DART_ENVELOPE_B64).unwrap();
        assert_eq!(raw[0], ENVELOPE_VERSION);
        // version + nonce + tag + a non-empty JSON body.
        assert!(raw.len() > MIN_ENVELOPE_LEN);
    }

    #[test]
    fn rust_written_envelopes_are_readable_by_the_same_reader_dart_uses() {
        // Round-trip through the batch API the Dart side will call, so the
        // encrypt path is covered by the same compatibility contract.
        let cipher = cipher_for(&dart_key()).unwrap();
        let sealed = encrypt_one(&cipher, r#"{"hello":"world","n":42}"#, &(0u8..12).collect::<Vec<_>>(), b"").unwrap();
        let results = decrypt_batch(&dart_key(), &[sealed], b"");
        assert_eq!(results[0].as_deref(), Some(r#"{"hello":"world","n":42}"#));
    }
}
