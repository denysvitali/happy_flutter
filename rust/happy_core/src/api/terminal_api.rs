//! Dart-facing terminal-output copy preparation.

use crate::terminal;

#[flutter_rust_bridge::frb]
pub struct StrippedTerminalOutput {
    pub text: String,
    pub scan_micros: u32,
}

/// Strip SGR escapes on a Rust worker after the user taps Copy.
#[flutter_rust_bridge::frb]
pub fn strip_terminal_ansi(text: String) -> StrippedTerminalOutput {
    let result = terminal::strip_ansi(&text);
    StrippedTerminalOutput {
        text: result.text,
        scan_micros: result.scan_micros,
    }
}
