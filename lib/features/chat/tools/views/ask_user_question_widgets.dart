import 'package:flutter/material.dart';
import '../../../../core/theme/app_tokens.dart';
import 'ask_user_question_view.dart' show Question, QuestionOption;

/// Section displaying a single question with selectable option
/// chips.
class QuestionSection extends StatelessWidget {

  const QuestionSection({
    required this.question,
    required this.questionIndex,
    required this.selectedOptions,
    required this.isInteractive,
    required this.onToggle,
    this.notesController,
    super.key,
  });
  final Question question;
  final int questionIndex;
  final Set<int> selectedOptions;
  final bool isInteractive;
  final ValueChanged<int> onToggle;
  final TextEditingController? notesController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(
        bottom: 10,
        top: questionIndex > 0 ? 4 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header + question text
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: theme
                      .colorScheme.secondaryContainer,
                  borderRadius:
                      BorderRadius.circular(AppRadius.xsm),
                ),
                child: Text(
                  question.header.toUpperCase(),
                  style: TextStyle(
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme
                        .onSecondaryContainer,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (question.multiSelect) ...[
                const SizedBox(width: AppSpacing.xsm),
                Text(
                  'Select all that apply',
                  style:
                      theme.textTheme.labelSmall
                          ?.copyWith(
                    color: theme
                        .colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Question text with question mark icon
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: theme
                    .colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xsm),
              Expanded(
                child: Text(
                  question.question,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Options as wrapping pill chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: question.options
                .asMap()
                .entries
                .map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected =
                  selectedOptions.contains(index);

              return OptionChip(
                option: option,
                isSelected: isSelected,
                isMultiSelect: question.multiSelect,
                isInteractive: isInteractive,
                onTap: () => onToggle(index),
              );
            }).toList(),
          ),
          // Optional free-text notes, carried through to the
          // agent as `annotations[question].notes`.
          if (notesController != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              enabled: isInteractive,
              maxLines: 2,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Add notes (optional)',
                isDense: true,
                filled: true,
                fillColor: theme
                    .colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Interactive chip for a single question option with press
/// animation.
class OptionChip extends StatefulWidget {

  const OptionChip({
    required this.option,
    required this.isSelected,
    required this.isMultiSelect,
    required this.isInteractive,
    required this.onTap,
    super.key,
  });
  final QuestionOption option;
  final bool isSelected;
  final bool isMultiSelect;
  final bool isInteractive;
  final VoidCallback onTap;

  @override
  State<OptionChip> createState() => _OptionChipState();
}

class _OptionChipState extends State<OptionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration:
          const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.isInteractive) {
      _pressController.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isSelected = widget.isSelected;

    // Determine if option has a description to show
    // as a full-width card vs compact chip.
    final hasDesc =
        widget.option.description.isNotEmpty;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.isInteractive ? widget.onTap : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isSelected
                ? primary.withValues(alpha: 28 / 255.0)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              hasDesc ? 12 : 20,
            ),
            border: Border.all(
              color: isSelected
                  ? primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 40 / 255.0),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: hasDesc ? 12 : 14,
            vertical: hasDesc ? 10 : 8,
          ),
          child: hasDesc
              ? _buildWithDescription(
                  context, theme, isSelected)
              : _buildCompact(
                  context, theme, isSelected),
        ),
      ),
    );
  }

  Widget _buildCompact(
    BuildContext context,
    ThemeData theme,
    bool isSelected,
  ) {
    final primary = theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIndicator(theme, size: 16),
        const SizedBox(width: 6),
        Text(
          widget.option.label,
          style: TextStyle(
            fontSize: AppFontSize.md,
            fontWeight: isSelected
                ? FontWeight.w600
                : FontWeight.w500,
            color: isSelected
                ? primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildWithDescription(
    BuildContext context,
    ThemeData theme,
    bool isSelected,
  ) {
    final primary = theme.colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: _buildIndicator(theme, size: 18),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.option.label,
                style: TextStyle(
                  fontSize: AppFontSize.base,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: isSelected
                      ? primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.option.description,
                style: TextStyle(
                  fontSize: AppFontSize.sm,
                  color: theme
                      .colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIndicator(
    ThemeData theme, {
    required double size,
  }) {
    final primary = theme.colorScheme.primary;
    final isSelected = widget.isSelected;
    final borderColor = isSelected
        ? primary
        : theme.colorScheme.onSurfaceVariant
            .withValues(alpha: 120 / 255.0);

    if (widget.isMultiSelect) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        decoration: BoxDecoration(
          border:
              Border.all(color: borderColor, width: 2),
          borderRadius:
              BorderRadius.circular(size * 0.25),
          color: isSelected
              ? primary
              : Colors.transparent,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: size * 0.7,
                color: theme.colorScheme.onPrimary,
              )
            : null,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        border:
            Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size * 0.5,
          height: size * 0.5,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(size * 0.25),
            color: isSelected
                ? primary
                : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
