//! Decrypt-and-parse: the JSON stage of the message pipeline, in Rust.
//!
//! Every message body the app decrypts is UTF-8 JSON (the Dart encrypt path
//! runs `utf8.encode(jsonEncode(data))` before sealing). After the crypto
//! moved here, the next thing the Dart UI isolate did with every row was
//! `jsonDecode` it — and then copy the resulting object tree into the
//! message-processing isolate and copy the processed tree back out. Measured
//! on the 500-row benchmark page that is parse (3.9 ms) + copy-in (2.2 ms) +
//! copy-out (2.2 ms) of pure UI-isolate time per page, on top of the crypto.
//!
//! The Dart object tree itself cannot be built from Rust any cheaper than
//! `jsonDecode` builds it (every bridge codec would allocate the same objects
//! plus its own envelope), so the split is: Rust **parses** — the full JSON
//! grammar walk, UTF-8 and escape validation, per-row failure
//! classification — in the same crossing as the decrypt, and Dart
//! **materializes** the already-validated text into objects on its worker
//! isolate, never on the UI isolate. A row that fails here is reported with
//! an exact status so the caller can log the real cause instead of the
//! previous "base64 or auth, can't tell".

use serde::de::IgnoredAny;

use crate::crypto::{self, DecryptError};

/// Per-row outcome of [`decrypt_base64_json_batch`], as a stable small
/// integer so the bridge ships one byte per row. Keep in sync with
/// `NativeJsonRowStatus` on the Dart side.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum RowStatus {
    /// Decrypted and the plaintext is well-formed JSON.
    Ok = 0,
    /// Input was not valid base64.
    BadBase64 = 1,
    /// Envelope too short, or foreign version byte.
    BadEnvelope = 2,
    /// GCM authentication failed — wrong key or corrupt ciphertext.
    AuthFailed = 3,
    /// Plaintext was not UTF-8.
    NotUtf8 = 4,
    /// Plaintext decrypted but is not well-formed JSON.
    InvalidJson = 5,
    /// Key length was wrong; every row carries this.
    BadKey = 6,
}

impl From<DecryptError> for RowStatus {
    fn from(error: DecryptError) -> Self {
        match error {
            DecryptError::BadKeyLength => RowStatus::BadKey,
            DecryptError::TooShort | DecryptError::BadVersion => RowStatus::BadEnvelope,
            DecryptError::BadBase64 => RowStatus::BadBase64,
            DecryptError::AuthFailed => RowStatus::AuthFailed,
            DecryptError::NotUtf8 => RowStatus::NotUtf8,
        }
    }
}

/// Result of a decrypt-and-parse batch: index-aligned with the input.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DecryptedJsonBatch {
    /// Validated JSON text per row; `None` where `statuses[i] != Ok`.
    pub values: Vec<Option<String>>,
    /// One [`RowStatus`] discriminant per row.
    pub statuses: Vec<u8>,
}

/// Parse `text` as JSON without building a tree.
///
/// `IgnoredAny` drives the full serde_json parser — structure, string
/// escapes, numbers, nesting — and discards the values as it goes, so this
/// is the complete grammar check at zero allocation.
pub fn is_well_formed_json(text: &str) -> bool {
    serde_json::from_str::<IgnoredAny>(text).is_ok()
}

/// Decrypt a batch of base64 envelopes and validate each plaintext as JSON.
///
/// Never aborts the batch: a failed row carries its own status and a `None`
/// value, and a bad key marks every row [`RowStatus::BadKey`] so the caller's
/// fallback stays uniform with [`crypto::decrypt_base64_batch`].
pub fn decrypt_base64_json_batch(
    key: &[u8],
    envelopes_b64: &[String],
    associated_data: &[u8],
) -> DecryptedJsonBatch {
    let n = envelopes_b64.len();
    let cipher = match crypto::cipher_for(key) {
        Ok(cipher) => cipher,
        Err(_) => {
            return DecryptedJsonBatch {
                values: vec![None; n],
                statuses: vec![RowStatus::BadKey as u8; n],
            }
        }
    };
    let mut values = Vec::with_capacity(n);
    let mut statuses = Vec::with_capacity(n);
    for encoded in envelopes_b64 {
        match crypto::decrypt_base64_one(&cipher, encoded, associated_data) {
            Ok(text) if is_well_formed_json(&text) => {
                values.push(Some(text));
                statuses.push(RowStatus::Ok as u8);
            }
            Ok(_) => {
                values.push(None);
                statuses.push(RowStatus::InvalidJson as u8);
            }
            Err(error) => {
                values.push(None);
                statuses.push(RowStatus::from(error) as u8);
            }
        }
    }
    DecryptedJsonBatch { values, statuses }
}

#[cfg(test)]
mod tests {
    use super::*;
    use base64::engine::general_purpose::STANDARD as BASE64;
    use base64::Engine;

    fn key() -> Vec<u8> {
        (0..32u8).map(|i| i.wrapping_mul(11).wrapping_add(1)).collect()
    }

    fn nonce(i: u8) -> Vec<u8> {
        (0..12u8).map(|j| j.wrapping_add(i)).collect()
    }

    fn seal(plaintext: &str, i: u8) -> String {
        let cipher = crypto::cipher_for(&key()).unwrap();
        BASE64.encode(crypto::encrypt_one(&cipher, plaintext, &nonce(i), &[]).unwrap())
    }

    #[test]
    fn well_formed_json_is_the_full_grammar() {
        assert!(is_well_formed_json(r#"{"a":[1,2.5,-3e2,"x\u00e9\n",null,true],"b":{}}"#));
        assert!(is_well_formed_json("\"just a string\""));
        assert!(is_well_formed_json("42"));
        assert!(!is_well_formed_json(""));
        assert!(!is_well_formed_json("{\"a\":}"));
        assert!(!is_well_formed_json("[1,2,]"));
        assert!(!is_well_formed_json("{\"a\":1} trailing"));
        assert!(!is_well_formed_json("{'single':1}"));
        assert!(!is_well_formed_json("{\"bad escape\":\"\\q\"}"));
    }

    #[test]
    fn classifies_every_failure_kind_while_staying_aligned() {
        let ok = seal(r#"{"role":"user","content":"hi"}"#, 1);
        let not_json = seal("this is not json", 2);
        let mut tampered_raw = BASE64.decode(seal("{}", 3)).unwrap();
        let last = tampered_raw.len() - 1;
        tampered_raw[last] ^= 0x01;
        let tampered = BASE64.encode(&tampered_raw);
        let short = BASE64.encode([0u8; 4]);
        let bad_version = {
            let mut raw = BASE64.decode(seal("{}", 4)).unwrap();
            raw[0] = 7;
            BASE64.encode(raw)
        };

        let batch = decrypt_base64_json_batch(
            &key(),
            &[
                ok,
                not_json,
                tampered,
                short,
                bad_version,
                "%%not base64%%".to_string(),
            ],
            &[],
        );

        assert_eq!(
            batch.statuses,
            vec![
                RowStatus::Ok as u8,
                RowStatus::InvalidJson as u8,
                RowStatus::AuthFailed as u8,
                RowStatus::BadEnvelope as u8,
                RowStatus::BadEnvelope as u8,
                RowStatus::BadBase64 as u8,
            ]
        );
        assert_eq!(
            batch.values[0].as_deref(),
            Some(r#"{"role":"user","content":"hi"}"#)
        );
        assert!(batch.values[1..].iter().all(Option::is_none));
    }

    #[test]
    fn a_bad_key_marks_every_row_without_panicking() {
        let batch = decrypt_base64_json_batch(&[1, 2, 3], &[seal("{}", 1), seal("[]", 2)], &[]);
        assert_eq!(batch.statuses, vec![RowStatus::BadKey as u8; 2]);
        assert_eq!(batch.values, vec![None, None]);
    }

    #[test]
    fn the_validated_text_is_byte_identical_to_the_plaintext() {
        // The caller materializes this text with Dart's jsonDecode, so it
        // must reach Dart exactly as sealed — no normalization, no
        // re-serialization, unicode intact.
        let plaintext = "{\"unicode\":\"caffè ☕ 日本\",\"nested\":{\"deep\":[[[]]]},\"n\":1.0e-7}";
        let batch = decrypt_base64_json_batch(&key(), &[seal(plaintext, 9)], &[]);
        assert_eq!(batch.statuses, vec![RowStatus::Ok as u8]);
        assert_eq!(batch.values[0].as_deref(), Some(plaintext));
    }

    #[test]
    fn empty_batch_is_empty() {
        let batch = decrypt_base64_json_batch(&key(), &[], &[]);
        assert!(batch.values.is_empty() && batch.statuses.is_empty());
    }
}
