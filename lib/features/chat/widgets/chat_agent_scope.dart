import 'package:flutter/material.dart';

import '../../../core/models/machine.dart';
import '../../../core/models/session.dart';
import '../../../core/ui/agent_identity.dart';
import '../../../core/utils/session_utils.dart';
import '../../sessions/session_avatar.dart';

/// Who the user is talking to in the open chat, in display terms: the
/// agent's name, its identity colour, and where it runs.
///
/// Values only change when the session's flavor, machine, or path changes,
/// so dependents (user bubbles, permission cards) do not rebuild on every
/// streamed message.
@immutable
class ChatAgentContext {
  const ChatAgentContext({
    required this.agentName,
    required this.identity,
    this.machineLabel,
    this.workspaceLabel,
    this.workspacePath,
    this.avatarStyle,
  });

  /// Builds the context for [session]; [machine] supplies a friendlier
  /// host name when the machine is known.
  factory ChatAgentContext.fromSession(
    Session session, {
    required Brightness brightness,
    Machine? machine,
    AvatarStyle? avatarStyle,
  }) {
    final metadata = session.metadata;
    final host =
        _nonEmpty(machine?.metadata?.displayName) ??
        _nonEmpty(machine?.metadata?.host) ??
        _nonEmpty(metadata?.host);
    final path = _nonEmpty(metadata?.path);
    return ChatAgentContext(
      agentName: chatAgentDisplayName(metadata?.flavor),
      identity: agentIdentityFor(session, brightness),
      machineLabel: host,
      workspaceLabel: path == null
          ? null
          : formatPathRelativeToHome(path, homeDir: metadata?.homeDir),
      workspacePath: path,
      avatarStyle: avatarStyle,
    );
  }

  /// Short, human agent name ("Claude", "Codex"); null when unknown so the
  /// caller can use its localized fallback.
  final String? agentName;
  final AgentIdentity identity;
  final String? machineLabel;
  final String? workspaceLabel;
  final String? workspacePath;

  /// The user's chosen avatar style; null means the identity blob.
  final AvatarStyle? avatarStyle;

  /// The agent's face, resolved exactly like the header and roster rows.
  Widget avatar({required double size}) => SessionAvatar(
    id: identity.seed,
    flavor: identity.flavor,
    size: size,
    style: avatarStyle,
  );

  /// "mbp-denys · ~/git/happy", or null when neither is known.
  String? get whereLabel {
    final parts = [?machineLabel, ?workspaceLabel];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      other is ChatAgentContext &&
      other.agentName == agentName &&
      other.identity.seed == identity.seed &&
      other.identity.brightness == identity.brightness &&
      other.identity.color == identity.color &&
      other.machineLabel == machineLabel &&
      other.workspaceLabel == workspaceLabel &&
      other.workspacePath == workspacePath &&
      other.avatarStyle == avatarStyle;

  @override
  int get hashCode => Object.hash(
    agentName,
    identity.seed,
    identity.brightness,
    identity.color,
    machineLabel,
    workspaceLabel,
    workspacePath,
    avatarStyle,
  );

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Short display name for a provider flavor, or null when unknown.
String? chatAgentDisplayName(String? flavor) => switch (flavor) {
  null || '' => null,
  'claude' => 'Claude',
  'codex' => 'Codex',
  'opencode' => 'OpenCode',
  'agy' || 'gemini' => 'Gemini',
  'prime-agent' => 'Prime Agent',
  'grok' || 'grok-build' => 'Grok',
  'deepseek' => 'DeepSeek',
  'har' => 'Har',
  _ => null,
};

/// Provides [ChatAgentContext] to the open conversation.
class ChatAgentScope extends InheritedWidget {
  const ChatAgentScope({required this.value, required super.child, super.key});

  final ChatAgentContext? value;

  /// The nearest context, or null outside a chat (e.g. tool detail pages).
  static ChatAgentContext? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatAgentScope>()?.value;

  @override
  bool updateShouldNotify(ChatAgentScope oldWidget) => value != oldWidget.value;
}
