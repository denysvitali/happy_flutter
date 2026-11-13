//! ANSI stripping for copy-to-clipboard actions on large tool outputs.
//!
//! This runs through FRB's asynchronous worker so full-output scanning does
//! not block chat rendering while the user copies a large result.

use web_time::Instant;

pub struct StrippedOutput {
    pub text: String,
    pub scan_micros: u32,
}

/// Returns the end of the escape sequence starting at `at`, mirroring the
/// app's `AnsiParser` rule: CSI (any final byte), OSC and DCS/SOS/PM/APC
/// strings (ending at their terminator or the next line break), nF charset
/// designations such as `ESC(B`, and single-character escapes. A lone ESC is
/// dropped on its own.
fn escape_end(bytes: &[u8], at: usize) -> Option<usize> {
    if bytes.get(at) != Some(&0x1b) {
        return None;
    }
    let lone = Some(at + 1);
    let next = at + 1;
    let Some(&kind) = bytes.get(next) else {
        return lone;
    };
    match kind {
        b'[' => {
            let mut end = next + 1;
            while matches!(bytes.get(end), Some(0x30..=0x3f)) {
                end += 1;
            }
            while matches!(bytes.get(end), Some(0x20..=0x2f)) {
                end += 1;
            }
            if matches!(bytes.get(end), Some(0x40..=0x7e)) {
                Some(end + 1)
            } else {
                Some(next + 1)
            }
        }
        b']' | b'P' | b'X' | b'^' | b'_' => {
            let mut end = next + 1;
            while let Some(&b) = bytes.get(end) {
                if b == 0x1b || b == b'\n' || (kind == b']' && b == 0x07) {
                    break;
                }
                end += 1;
            }
            match bytes.get(end) {
                Some(0x07) => Some(end + 1),
                Some(0x1b) if bytes.get(end + 1) == Some(&b'\\') => Some(end + 2),
                _ => Some(end),
            }
        }
        0x20..=0x2f => {
            let mut end = next;
            while matches!(bytes.get(end), Some(0x20..=0x2f)) {
                end += 1;
            }
            if matches!(bytes.get(end), Some(0x30..=0x7e)) {
                Some(end + 1)
            } else {
                lone
            }
        }
        0x30..=0x7e => Some(next + 1),
        _ => lone,
    }
}

pub fn strip_ansi(text: &str) -> StrippedOutput {
    let start = Instant::now();
    let bytes = text.as_bytes();
    let mut stripped = String::with_capacity(text.len());
    let mut segment_start = 0;
    let mut at = 0;
    while at < bytes.len() {
        if let Some(end) = escape_end(bytes, at) {
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
    fn strips_sgr_without_changing_unicode() {
        let text = "☕\x1b[31mred\x1b[0m\n日本\x1b[m";
        assert_eq!(strip_ansi(text).text, "☕red\n日本");
    }

    #[test]
    fn strips_non_sgr_sequences_like_the_dart_parser() {
        let text = "\x1b[2K\x1b[?25lstep\x1b(B\x1b[m \x1b]8;;https://e.x\x07link\x1b]8;;\x1b\\ \x1b]0;t\x07end\x1b=";
        assert_eq!(strip_ansi(text).text, "step link end");
        assert_eq!(strip_ansi("\x1b[31K\x1b[3xm").text, "m");
        assert_eq!(strip_ansi("\x1b]0;cut off\nnext").text, "\nnext");
        assert_eq!(strip_ansi("a\x1b").text, "a");
    }

    #[test]
    fn preserves_empty_and_plain_text() {
        assert_eq!(strip_ansi("").text, "");
        assert_eq!(strip_ansi("plain\ntext").text, "plain\ntext");
    }
}
