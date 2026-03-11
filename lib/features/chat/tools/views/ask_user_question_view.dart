import 'package:flutter/material.dart';
import '../../../../core/services/logger_service.dart' show logger;
import '../../../../core/services/sync_service.dart';
import '../../../../core/theme/app_tokens.dart';

/// Question option model.
class QuestionOption {

  QuestionOption({required this.label, required this.description});
  final String label;
  final String description;
}

/// Question model.
class Question {

  Question({
    required this.question,
    required this.header,
    required this.options,
    required this.multiSelect,
  });
  final String question;
  final String header;
  final List<QuestionOption> options;
  final bool multiSelect;
}

/// View for displaying AskUserQuestion tool with interactive options.
class AskUserQuestionView extends StatefulWidget {

  const AskUserQuestionView({
    required this.tool, super.key,
    this.metadata,
    this.sessionId,
  });
  /// The tool data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// The session ID for sending responses.
  final String? sessionId;

  @override
  State<AskUserQuestionView> createState() =>
      _AskUserQuestionViewState();
}

class _AskUserQuestionViewState extends State<AskUserQuestionView>
    with TickerProviderStateMixin {
  final Map<int, Set<int>> _selections = {};
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final questions = input['questions'] as List?;

    if (questions == null || questions.isEmpty) {
      return const SizedBox.shrink();
    }

    final parsedQuestions = questions
        .map((q) {
          if (q is! Map<String, dynamic>) return null;
          final options = (q['options'] as List?)
                  ?.map(
                    (o) => QuestionOption(
                      label: o['label'] as String? ?? '',
                      description:
                          o['description'] as String? ?? '',
                    ),
                  )
                  .toList() ??
              [];

          return Question(
            question: q['question'] as String? ?? '',
            header: q['header'] as String? ?? 'Question',
            options: options,
            multiSelect: q['multiSelect'] as bool? ?? false,
          );
        })
        .whereType<Question>()
        .toList();

    if (parsedQuestions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Only treat as completed if the user actually submitted locally.
    // In Yolo mode the server auto-approves the permission, which
    // moves the tool to 'completed' before the user can interact.
    if (_isSubmitted) {
      return _buildSubmittedView(context, parsedQuestions);
    }

    final canInteract = !_isSubmitting;
    final allAnswered =
        parsedQuestions.asMap().entries.every((e) {
      final s = _selections[e.key];
      return s != null && s.isNotEmpty;
    });

    return _buildInteractiveView(
      context,
      parsedQuestions,
      canInteract: canInteract,
      allAnswered: allAnswered,
    );
  }

  Widget _buildSubmittedView(
    BuildContext context,
    List<Question> questions,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md + AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant
              .withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xsm),
              Text(
                'Answered',
                style: theme.textTheme.labelMedium
                    ?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
          ...questions.asMap().entries.map((entry) {
            final qIndex = entry.key;
            final q = entry.value;
            final selected = _selections[qIndex];
            final labels = selected != null
                ? selected
                    .map(
                      (i) => i < q.options.length
                          ? q.options[i].label
                          : '',
                    )
                    .where((l) => l.isNotEmpty)
                    .join(', ')
                : '-';

            return Padding(
              padding: EdgeInsets.only(
                top: qIndex > 0 ? 6 : 0,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${q.header}: ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme
                          .colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      labels,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color:
                            theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInteractiveView(
    BuildContext context,
    List<Question> questions, {
    required bool canInteract,
    required bool allAnswered,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowAlpha =
            (12 + (_pulseAnimation.value * 20)).round();
        final borderAlpha =
            (80 + (_pulseAnimation.value * 80)).round();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color:
                theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: primary.withAlpha(borderAlpha),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withAlpha(glowAlpha),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          _buildHeader(context),

          // Questions
          Padding(
            padding: const EdgeInsets.fromLTRB(
                12, 12, 12, 12),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...questions.asMap().entries.map(
                  (entry) {
                    final qIndex = entry.key;
                    final question = entry.value;
                    return _QuestionSection(
                      question: question,
                      questionIndex: qIndex,
                      selectedOptions:
                          _selections[qIndex] ?? {},
                      isInteractive: canInteract,
                      onToggle: (optionIndex) =>
                          _handleToggle(
                        qIndex,
                        optionIndex,
                        question.multiSelect,
                      ),
                    );
                  },
                ),

                // Submit button
                if (canInteract) ...[
                  const SizedBox(height: 4),
                  _buildSubmitButton(
                    context,
                    allAnswered: allAnswered,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: primary.withAlpha(18),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primary.withAlpha(22),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: primary.withAlpha(60),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.help_rounded,
              size: 18,
              color: primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Input needed',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(
                    color: primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                Text(
                  'Please choose an option below',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(
                    color:
                        primary.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: primary.withAlpha(25),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: primary.withAlpha(60),
                width: 1,
              ),
            ),
            child: Text(
              'ACTION',
              style: TextStyle(
                fontSize: AppFontSize.xxs,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context, {
    required bool allAnswered,
  }) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed:
            allAnswered && !_isSubmitting
                ? _handleSubmit
                : null,
        icon: _isSubmitting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.send_rounded,
                size: 16,
              ),
        label: Text(
          _isSubmitting ? 'Submitting...' : 'Submit',
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          backgroundColor:
              allAnswered && !_isSubmitting
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
        ),
      ),
    );
  }

  void _handleToggle(
    int questionIndex,
    int optionIndex,
    bool multiSelect,
  ) {
    setState(() {
      final current =
          _selections[questionIndex] ?? <int>{};
      if (multiSelect) {
        if (current.contains(optionIndex)) {
          current.remove(optionIndex);
        } else {
          current.add(optionIndex);
        }
        _selections[questionIndex] = current;
      } else {
        _selections[questionIndex] = {optionIndex};
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || widget.sessionId == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isSubmitted = true;
    });

    final input =
        widget.tool['input'] as Map<String, dynamic>?
            ?? {};
    final questions =
        input['questions'] as List? ?? [];

    // Build answers map keyed by question text,
    // matching the AskUserQuestion tool schema.
    final answers = <String, String>{};
    for (var qIdx = 0;
        qIdx < questions.length;
        qIdx++) {
      final q =
          questions[qIdx] as Map<String, dynamic>;
      final selected = _selections[qIdx];
      if (selected == null || selected.isEmpty) {
        continue;
      }
      final options = q['options'] as List? ?? [];
      final labels = selected
          .map(
            (i) => i < options.length
                ? (options[i]
                        as Map<String, dynamic>)[
                    'label'] as String?
                : null,
          )
          .whereType<String>()
          .join(', ');
      final questionText =
          q['question'] as String? ?? '';
      answers[questionText] = labels;
    }

    try {
      final permission = widget.tool['permission']
          as Map<String, dynamic>?;
      final permId = permission?['id'] as String?;
      if (permId != null) {
        // Include answers in updatedInput so the CLI
        // receives them via the permission response.
        await sync.sessionAllow(
          widget.sessionId!,
          permId,
          updatedInput: <String, dynamic>{
            ...input,
            'answers': answers,
          },
        );
      } else {
        // Fallback: send as a chat message if there
        // is no permission to approve.
        final lines = answers.entries
            .map((e) => '${e.key}: ${e.value}')
            .toList();
        await sync.sendMessage(
          widget.sessionId!,
          lines.join('\n'),
        );
      }
    } catch (e) {
      logger.warning('Failed to submit answer: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _QuestionSection extends StatelessWidget {

  const _QuestionSection({
    required this.question,
    required this.questionIndex,
    required this.selectedOptions,
    required this.isInteractive,
    required this.onToggle,
  });
  final Question question;
  final int questionIndex;
  final Set<int> selectedOptions;
  final bool isInteractive;
  final ValueChanged<int> onToggle;

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

              return _OptionChip(
                option: option,
                isSelected: isSelected,
                isMultiSelect: question.multiSelect,
                isInteractive: isInteractive,
                onTap: () => onToggle(index),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatefulWidget {

  const _OptionChip({
    required this.option,
    required this.isSelected,
    required this.isMultiSelect,
    required this.isInteractive,
    required this.onTap,
  });
  final QuestionOption option;
  final bool isSelected;
  final bool isMultiSelect;
  final bool isInteractive;
  final VoidCallback onTap;

  @override
  State<_OptionChip> createState() =>
      _OptionChipState();
}

class _OptionChipState extends State<_OptionChip>
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
                ? primary.withAlpha(28)
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
                      color: primary.withAlpha(40),
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
            .withAlpha(120);

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
