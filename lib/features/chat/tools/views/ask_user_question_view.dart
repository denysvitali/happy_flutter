import 'package:flutter/material.dart';
import '../../../../core/services/sync_service.dart';

/// Question option model.
class QuestionOption {
  final String label;
  final String description;

  QuestionOption({required this.label, required this.description});
}

/// Question model.
class Question {
  final String question;
  final String header;
  final List<QuestionOption> options;
  final bool multiSelect;

  Question({
    required this.question,
    required this.header,
    required this.options,
    required this.multiSelect,
  });
}

/// View for displaying AskUserQuestion tool with interactive options.
class AskUserQuestionView extends StatefulWidget {
  /// The tool data.
  final Map<String, dynamic> tool;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  /// The session ID for sending responses.
  final String? sessionId;

  const AskUserQuestionView({
    super.key,
    required this.tool,
    this.metadata,
    this.sessionId,
  });

  @override
  State<AskUserQuestionView> createState() => _AskUserQuestionViewState();
}

class _AskUserQuestionViewState extends State<AskUserQuestionView> {
  final Map<int, Set<int>> _selections = {};
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  Widget build(BuildContext context) {
    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final questions = input['questions'] as List?;
    final state = widget.tool['state'] as String? ?? 'running';

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

    final isCompleted =
        _isSubmitted || state == 'completed';

    if (isCompleted) {
      return _buildSubmittedView(context, parsedQuestions);
    }

    final isRunning = state == 'running';
    final canInteract = isRunning && !_isSubmitted;
    final allAnswered = parsedQuestions.asMap().entries.every(
      (e) {
        final s = _selections[e.key];
        return s != null && s.isNotEmpty;
      },
    );

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
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(80),
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
              const SizedBox(width: 6),
              Text(
                'Answered',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...questions.asMap().entries.map((entry) {
            final qIndex = entry.key;
            final q = entry.value;
            final selected = _selections[qIndex];
            final labels = selected != null
                ? selected
                    .map((i) =>
                        i < q.options.length
                            ? q.options[i].label
                            : '')
                    .where((l) => l.isNotEmpty)
                    .join(', ')
                : '-';

            return Padding(
              padding: EdgeInsets.only(
                top: qIndex > 0 ? 6 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${q.header}: ',
                    style:
                        theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color:
                          theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      labels,
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withAlpha(60),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color:
                  theme.colorScheme.primary.withAlpha(15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Question',
                  style:
                      theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Questions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...questions.asMap().entries.map((entry) {
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
                }),

                // Submit button
                if (canInteract) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: allAnswered &&
                              !_isSubmitting
                          ? _handleSubmit
                          : null,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              size: 16,
                            ),
                      label: Text(
                        _isSubmitting
                            ? 'Submitting...'
                            : 'Submit',
                      ),
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    if (_isSubmitting || widget.sessionId == null) return;

    setState(() {
      _isSubmitting = true;
      _isSubmitted = true;
    });

    final input =
        widget.tool['input'] as Map<String, dynamic>? ?? {};
    final questions = input['questions'] as List? ?? [];

    // Build response text
    final lines = <String>[];
    for (var qIdx = 0; qIdx < questions.length; qIdx++) {
      final q = questions[qIdx] as Map<String, dynamic>;
      final selected = _selections[qIdx];
      if (selected == null || selected.isEmpty) continue;
      final options = q['options'] as List? ?? [];
      final labels = selected
          .map((i) => i < options.length
              ? (options[i] as Map<String, dynamic>)['label']
                  as String?
              : null)
          .whereType<String>()
          .join(', ');
      final header = q['header'] as String? ?? 'Answer';
      lines.add('$header: $labels');
    }
    final responseText = lines.join('\n');

    try {
      // 1. Approve permission if present
      final permission =
          widget.tool['permission'] as Map<String, dynamic>?;
      final permId = permission?['id'] as String?;
      if (permId != null) {
        await sync.sessionAllow(
          widget.sessionId!,
          permId,
        );
      }
      // 2. Send the answer as a message
      await sync.sendMessage(
        widget.sessionId!,
        responseText,
      );
    } catch (e) {
      debugPrint('Failed to submit answer: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _QuestionSection extends StatelessWidget {
  final Question question;
  final int questionIndex;
  final Set<int> selectedOptions;
  final bool isInteractive;
  final ValueChanged<int> onToggle;

  const _QuestionSection({
    required this.question,
    required this.questionIndex,
    required this.selectedOptions,
    required this.isInteractive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(
        bottom: 16,
        top: questionIndex > 0 ? 8 : 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header chip
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              question.header.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    theme.colorScheme.onSecondaryContainer,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Question text
          Text(
            question.question,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          // Options
          ...question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected =
                selectedOptions.contains(index);

            return _OptionButton(
              option: option,
              isSelected: isSelected,
              isMultiSelect: question.multiSelect,
              isInteractive: isInteractive,
              onTap: () => onToggle(index),
            );
          }),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final QuestionOption option;
  final bool isSelected;
  final bool isMultiSelect;
  final bool isInteractive;
  final VoidCallback onTap;

  const _OptionButton({
    required this.option,
    required this.isSelected,
    required this.isMultiSelect,
    required this.isInteractive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInteractive ? onTap : null,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                      .withAlpha(80)
                  : Colors.transparent,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIndicator(theme),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              theme.colorScheme.onSurface,
                        ),
                      ),
                      if (option.description.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 2),
                          child: Text(
                            option.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme
                                  .onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicator(ThemeData theme) {
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    if (isMultiSelect) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(top: 1),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(4),
          color: isSelected
              ? theme.colorScheme.primary
              : Colors.transparent,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 14,
                color: theme.colorScheme.onPrimary,
              )
            : null,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 1),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
