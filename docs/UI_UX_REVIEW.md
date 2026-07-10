# UI/UX Review

**Date:** 2026-03-13
**Agent:** A2 — UI/UX Designer

## July 2026 implementation update

- Code and JSON rendering use theme extensions rather than fixed palettes.
- Code blocks have pinned line numbers, horizontal-scroll affordance, copy
  feedback, truncation protection, and a full-screen reader.
- Chat configuration chips use distinct `Permissions`, `Model`, and `Profile`
  labels instead of several visually identical `Default` labels.
- Session cards prioritize recent message content over repeating the repository
  path, suppress long non-actionable archive countdowns, and expose a concise
  screen-reader summary.
- Tablet sessions automatically open the most-recent session while preserving
  an explicit user dismissal, and desktop chat retains its resizable inspector.
- Stop requests have an explicit `Stopping` state, prevent repeated actions,
  and offer recovery after an acknowledgement failure.

The original findings below are retained as historical audit evidence.

---

## Summary

The project has a **strong design foundation** with excellent token organization (11 token categories), solid component architecture, and thoughtful animations. Primary improvement areas: hardcoded values, accessibility gaps, and widget extraction opportunities.

---

## Design Token Coverage

| Category | Status | Notes |
|----------|--------|-------|
| Spacing | Complete | 12 tokens (2–32px) |
| Border Radius | Complete | 11 tokens + pill |
| Typography | Complete | Full Material 3 scale |
| Colors | Mostly | Missing code syntax tokens |
| Shadows | Complete | 3 presets |
| Elevation | Complete | 4 levels |
| Opacity | Complete | 6 levels |
| Animation | Complete | 4 durations + 3 curves |
| Touch Targets | Complete | 44px min, 48px comfortable |
| Breakpoints | Complete | 4 breakpoints |
| Code Syntax | Incomplete | Hardcoded Catppuccin palette |
| Focus States | Partial | Border defined, no composite token |

---

## High Priority Issues

### 1. Hardcoded Font Sizes (20+ instances)

| File | Line | Value | Should Use |
|------|------|-------|------------|
| `tools/tool_view.dart` | 24 | `18` | `AppFontSize.lg` |
| `tools/tool_view.dart` | 113 | `13` | `AppFontSize.md` |
| `tools/tool_view.dart` | 290 | `10` | `AppFontSize.xxs` |
| `tools/tool_section_view.dart` | 74 | `9` | `AppFontSize.xxs` |
| `tools/json_viewer.dart` | 62 | `12` | `AppFontSize.sm` |
| `tools/permission_footer.dart` | 126 | `11.5` | `AppFontSize.xs` |
| `session_file_viewer_screen.dart` | 95, 167 | `12` | `AppFontSize.sm` |
| `session_info_screen.dart` | 752 | `12` | `AppFontSize.sm` |
| `session_cards.dart` | 55 | `10` | `AppFontSize.xxs` |
| `tools/views/ask_user_question_view.dart` | 234, 242 | `11/10` | `AppFontSize.xs` |

### 2. Hardcoded Colors

| File | Line | Issue |
|------|------|-------|
| `code_block_widget.dart` | 8–24 | Catppuccin Mocha palette not theme-aware |
| `code_block_widget.dart` | 87–88 | `0xFFF1F5F9`, `0xFFD0D7DE` hardcoded |
| `json_viewer.dart` | 33–54 | VS Code JSON syntax colors hardcoded |

**Recommendation:** Create `AppCodeSyntaxColors` extension on ThemeData with light/dark variants.

### 3. Missing Accessibility Labels (15+ buttons)

| Location | Issue |
|----------|-------|
| `sidebar_view.dart` | Settings/experiments icons lack semantic labels |
| `tool_view.dart` | Collapse/expand buttons missing labels |
| `web_fetch_view.dart` | Close button in modal |
| `session_cards.dart` | Session delete button |
| `message_widget.dart` | Message action buttons |
| `diff_view_widget.dart` | Copy/expand buttons |

**Fix pattern:**
```dart
Semantics(
  label: 'Delete session',
  button: true,
  child: Tooltip(
    message: 'Delete session',
    child: IconButton(...),
  ),
)
```

---

## Medium Priority Issues

### 4. Widget Extraction Opportunities

| Pattern | Occurrences | Suggested Widget |
|---------|-------------|-----------------|
| Status badge styling | 4+ (tool_view, session_cards) | `StatusBadge` |
| Section header with accent bar | 2 (app_section_header, tool_section_view) | Unified `AppSectionHeader` |
| Modal/bottom-sheet header | 3+ (web_fetch, tool views) | `ModalHeader` |
| Tool output containers | 5+ (tool views) | `ToolOutputBox`, `ToolInputBox` |

### 5. Layout Overflow Risks

| File | Issue |
|------|-------|
| `settings_section.dart:84–95` | Subtitle text in Row without Expanded |
| `web_fetch_view.dart:38–52` | Close button + title without Expanded |
| `tool_view.dart:1094` | maxLines: 1 with no width constraint on parent |

### 6. Hardcoded Spacing

| File | Value | Should Use |
|------|-------|------------|
| `web_fetch_view.dart:37` | `16` | `AppSpacing.lg` |
| `session_info_screen.dart:96` | `2` | Token or constant |
| `machines_screen.dart:170` | `2` | Token or constant |

---

## Strengths to Preserve

- **Animation system**: 82 instances, consistent AppDuration tokens, smart optimizations (skip animations on bulk-loaded messages)
- **AppCard press animation**: AnimatedScale 0.98, clean and responsive
- **AppStatusDot pulse**: Respects pulse prop for conditional animation
- **Tab indicator**: Smooth pill movement with LayoutBuilder
- **MarkdownView caching**: Only rebuilds stylesheet on theme/color change
- **Material 3 adoption**: ColorScheme-based with AppColorScheme extension
