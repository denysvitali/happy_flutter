import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_tokens.dart';

/// Terminal emulator screen — displays terminal output with a dark
/// background and allows entering commands.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final List<String> lines = ['Terminal connected.'];
  final _commandController = TextEditingController();
  final _scrollController = ScrollController();

  static const _terminalTextStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 13,
    color: Color(0xFFD4D4D4),
    height: 1.5,
  );

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitCommand(String command) {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      return;
    }
    setState(() {
      lines
        ..add('> $trimmed')
        ..add('[output pending]');
    });
    _commandController.clear();
    // Scroll to bottom after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmDisconnect() {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text(
          'Are you sure you want to disconnect from the terminal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    ).then((confirmed) {
      if ((confirmed ?? false) && mounted) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        foregroundColor: const Color(0xFFD4D4D4),
        title: const Row(
          children: [
            Icon(Icons.terminal, size: 18),
            SizedBox(width: AppSpacing.sm),
            Text('Terminal'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: 'Disconnect',
            onPressed: _confirmDisconnect,
          ),
        ],
      ),
      body: Column(
        children: [
          // Terminal output area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                final isCommand = line.startsWith('> ');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    line,
                    style: _terminalTextStyle.copyWith(
                      color: isCommand
                          ? const Color(0xFF569CD6)
                          : const Color(0xFFD4D4D4),
                    ),
                  ),
                );
              },
            ),
          ),

          // Command input bar
          Container(
            color: const Color(0xFF2D2D2D),
            padding: EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              bottom: AppSpacing.sm + bottomInset,
            ),
            child: Row(
              children: [
                const Text(
                  r'$ ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Color(0xFF4EC94E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: _terminalTextStyle,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Enter command...',
                      hintStyle: TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                    cursorColor: const Color(0xFFD4D4D4),
                    textInputAction: TextInputAction.send,
                    autocorrect: false,
                    onSubmitted: _submitCommand,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.send,
                    color: Color(0xFF4EC94E),
                    size: 20,
                  ),
                  onPressed: () => _submitCommand(_commandController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
