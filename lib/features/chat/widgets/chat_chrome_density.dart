import 'package:flutter/widgets.dart';

/// Vertical-density tier for the chat chrome, derived from the height of the
/// pane the chat is rendered into.
///
/// A chat pane that is half a phone tall — Android split screen, a small
/// landscape desktop window, a folded cover display — cannot afford the
/// chrome a full-height phone gets. The app bar, the sub-agent banner, the
/// task capsule, the activity bar and a two-row composer together stand
/// taller than such a pane, and the transcript is what loses: the reported
/// symptom is a split-screen session where the newest message is squeezed
/// to a sliver between the task capsule and the thinking bar.
///
/// Each tier drops decorative geometry rather than affordances: the banners
/// flatten to one dense row, and the tightest tier folds the composer's
/// selector row away while the field is idle, so reading and typing keep the
/// height. Nothing becomes unreachable — every control reappears the moment
/// the pane is big enough, or the composer is in use.
enum ChatChromeDensity {
  /// Full-height pane: the chrome renders at its designed size.
  regular,

  /// Short pane: banner cards flatten to single dense rows.
  compact,

  /// Very short pane: banner cards flatten *and* the composer sheds its
  /// selector row while idle.
  tight;

  /// Panes shorter than this get [compact].
  static const double compactMaxHeight = 560;

  /// Panes shorter than this get [tight].
  static const double tightMaxHeight = 460;

  /// Resolves the tier for a pane [height] in logical pixels.
  ///
  /// [height] should be the full height of the chat pane including its app
  /// bar — the chrome is what has to fit, so the app bar counts against the
  /// budget.
  static ChatChromeDensity fromPaneHeight(double height) {
    if (height < tightMaxHeight) return ChatChromeDensity.tight;
    if (height < compactMaxHeight) return ChatChromeDensity.compact;
    return ChatChromeDensity.regular;
  }

  /// Whether the banner chrome should render in its flattened single-row
  /// form.
  bool get isDense => this != ChatChromeDensity.regular;

  /// Whether the composer may fold its selector row away while idle.
  bool get isTight => this == ChatChromeDensity.tight;
}

/// Publishes the active [ChatChromeDensity] to the chat chrome widgets.
///
/// Reads default to [ChatChromeDensity.regular] when no scope is present, so
/// a banner or composer pumped on its own in a test renders exactly the
/// full-height layout.
class ChatChromeScope extends InheritedWidget {
  /// Publishes [density] to [child]'s subtree.
  const ChatChromeScope({
    required this.density,
    required super.child,
    super.key,
  });

  /// Density the subtree should render at.
  final ChatChromeDensity density;

  /// Density announced by the nearest enclosing scope, or
  /// [ChatChromeDensity.regular] when there is none.
  static ChatChromeDensity of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatChromeScope>()?.density ??
      ChatChromeDensity.regular;

  @override
  bool updateShouldNotify(ChatChromeScope oldWidget) =>
      density != oldWidget.density;
}
