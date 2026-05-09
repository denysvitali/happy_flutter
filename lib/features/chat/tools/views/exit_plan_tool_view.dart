import 'package:flutter/material.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/utils/clipboard_utils.dart';
import '../../../../core/utils/wire_parsers.dart';
import '../../markdown/markdown_view.dart';
import '../tool_section_view.dart';
import '../tool_view_colors.dart';

/// View for displaying ExitPlanMode tool (plan proposal).
///
/// Renders the plan text as markdown inside a [ToolSectionView] with a
/// copy-to-clipboard action. Permission actions (accept edits, yolo, deny)
/// are handled by the [PermissionFooter] in the parent [ToolView].
class ExitPlanToolView extends StatefulWidget {
  const ExitPlanToolView({
    required this.tool,
    super.key,
    this.metadata,
  });

  /// The tool data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  @override
  State<ExitPlanToolView> createState() => _ExitPlanToolViewState();
}

class _ExitPlanToolViewState extends State<ExitPlanToolView> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final input = WireParsers.asMap(widget.tool['input']) ?? {};
    final plan = input['plan'] as String? ?? '';
    final hasPlan = plan.isNotEmpty;
    final displayPlan = hasPlan ? plan : '(no plan provided)';

    return ToolSectionView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPlan)
              Align(
                alignment: Alignment.centerRight,
                child: _CopyPlanButton(
                  text: plan,
                  copied: _copied,
                  onCopied: _handleCopied,
                ),
              ),
            MarkdownView(markdown: displayPlan),
          ],
        ),
      ),
    );
  }

  void _handleCopied() {
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _copied = false);
    });
  }
}

class _CopyPlanButton extends StatelessWidget {
  const _CopyPlanButton({
    required this.text,
    required this.copied,
    required this.onCopied,
  });

  final String text;
  final bool copied;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final c = ToolViewColors.of(context);
    final l10n = context.l10n;
    return Tooltip(
      message: copied ? l10n.commonCopied : l10n.commonCopy,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          await setClipboardTextSafely(text);
          onCopied();
        },
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              copied ? Icons.check : Icons.copy,
              key: ValueKey(copied),
              size: 16,
              color: copied ? c.copyIconDone : c.copyIcon,
            ),
          ),
        ),
      ),
    );
  }
}
