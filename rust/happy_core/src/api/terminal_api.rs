//! Dart-facing terminal-output preparation.

use crate::terminal;

#[flutter_rust_bridge::frb]
pub struct PreparedTerminalOutput {
    pub visible_text: String,
    pub stripped_output: String,
    pub total_lines: u32,
    pub scan_micros: u32,
}

/// Prepare the preview and clipboard text in one synchronous native pass.
#[flutter_rust_bridge::frb(sync)]
pub fn prepare_terminal_output(text: String, max_lines: u32) -> PreparedTerminalOutput {
    let result = terminal::prepare(&text, max_lines);
    PreparedTerminalOutput {
        visible_text: result.visible_text,
        stripped_output: result.stripped_output,
        total_lines: result.total_lines,
        scan_micros: result.scan_micros,
    }
}
