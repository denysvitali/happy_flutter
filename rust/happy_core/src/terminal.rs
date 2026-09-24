//! One pass over streaming terminal output for preview and clipboard text.
//!
//! The Flutter widget used to split every line into a Dart list, join the
//! visible prefix, then run a regex over the full output on every update.
//! Tool output can grow to megabytes, so keep this work in one native pass.

use std::time::Instant;

#[derive(Debug, PartialEq, Eq)]
pub struct TerminalPreparation {
    pub visible_text: String,
    pub stripped_output: String,
    pub total_lines: u32,
    pub scan_micros: u32,
}

fn micros(start: Instant) -> u32 {
    start.elapsed().as_micros().min(u32::MAX as u128) as u32
}

/// Match exactly the app's `\x1b\[([0-9;]*)m` SGR-only strip rule.
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

pub fn prepare(text: &str, max_lines: u32) -> TerminalPreparation {
    let start = Instant::now();
    let bytes = text.as_bytes();
    let mut stripped = String::with_capacity(text.len());
    let mut segment_start = 0;
    let mut visible_end = if max_lines == 0 { Some(0) } else { None };
    let mut newlines = 0u32;
    let mut at = 0;

    while at < bytes.len() {
        if bytes[at] == b'\n' {
            newlines = newlines.saturating_add(1);
            if newlines == max_lines && visible_end.is_none() {
                visible_end = Some(at);
            }
        }
        if let Some(end) = sgr_end(bytes, at) {
            stripped.push_str(&text[segment_start..at]);
            at = end;
            segment_start = end;
            continue;
        }
        at += 1;
    }
    stripped.push_str(&text[segment_start..]);
    let total_lines = newlines.saturating_add(1);
    let visible_text = if total_lines > max_lines {
        text[..visible_end.unwrap_or(0)].to_owned()
    } else {
        text.to_owned()
    };
    TerminalPreparation {
        visible_text,
        stripped_output: stripped,
        total_lines,
        scan_micros: micros(start),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_split_join_and_sgr_strip_with_unicode() {
        let text = "☕\x1b[31mred\x1b[0m\n日本\nlast\n";
        let result = prepare(text, 2);
        assert_eq!(result.visible_text, "☕\x1b[31mred\x1b[0m\n日本");
        assert_eq!(result.stripped_output, "☕red\n日本\nlast\n");
        assert_eq!(result.total_lines, 4);
    }

    #[test]
    fn preserves_invalid_escape_sequences_and_empty_input() {
        let text = "a\x1b[31K\x1b[3xm\x1b[mz";
        let result = prepare(text, 1);
        assert_eq!(result.visible_text, text);
        assert_eq!(result.stripped_output, "a\x1b[31K\x1b[3xmz");
        assert_eq!(prepare("", 0).total_lines, 1);
        assert_eq!(prepare("a\nb", 0).visible_text, "");
        assert_eq!(prepare("a\nb", 1).visible_text, "a");
    }
}
