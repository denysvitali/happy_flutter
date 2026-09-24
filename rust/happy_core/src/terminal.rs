//! ANSI stripping for copy-to-clipboard actions on large tool outputs.
//!
//! This runs through FRB's asynchronous worker so full-output scanning does
//! not block chat rendering while the user copies a large result.

use std::time::Instant;

pub struct StrippedOutput {
    pub text: String,
    pub scan_micros: u32,
}

/// Match the app's `\x1b\[([0-9;]*)m` SGR-only strip rule.
fn sgr_end(bytes: &[u8], at: usize) -> Option<usize> {
    if bytes.get(at) != Some(&0x1b) || bytes.get(at + 1) != Some(&b'[') {
        return None;
    }
    let mut end = at + 2;
    while matches!(bytes.get(end), Some(b'0'..=b'9' | b';')) {
        end += 1;
    }
    (bytes.get(end) == Some(&b'm')).then_some(end + 1)
}

pub fn strip_ansi(text: &str) -> StrippedOutput {
    let start = Instant::now();
    let bytes = text.as_bytes();
    let mut stripped = String::with_capacity(text.len());
    let mut segment_start = 0;
    let mut at = 0;
    while at < bytes.len() {
        if let Some(end) = sgr_end(bytes, at) {
            stripped.push_str(&text[segment_start..at]);
            at = end;
            segment_start = end;
            continue;
        }
        at += 1;
    }
    stripped.push_str(&text[segment_start..]);
    StrippedOutput {
        text: stripped,
        scan_micros: start.elapsed().as_micros().min(u32::MAX as u128) as u32,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_sgr_without_changing_unicode_or_invalid_sequences() {
        let text = "☕\x1b[31mred\x1b[0m\n日本\x1b[31K\x1b[3xm\x1b[m";
        assert_eq!(strip_ansi(text).text, "☕red\n日本\x1b[31K\x1b[3xm");
    }

    #[test]
    fn preserves_empty_and_plain_text() {
        assert_eq!(strip_ansi("").text, "");
        assert_eq!(strip_ansi("plain\ntext").text, "plain\ntext");
    }
}
