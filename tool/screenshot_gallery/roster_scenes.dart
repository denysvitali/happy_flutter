// Roster lane gallery scenes: every agent-identity shape, both as a large
// avatar and inside a real Mission Control row with its state dot, so the
// face/badge/dot geometry can be checked for all six silhouettes at once.

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/session_ui_state_notifier.dart';
import 'package:happy_flutter/core/ui/agent_identity.dart';
import 'package:happy_flutter/features/sessions/harness_logo.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_action_tile.dart';
import 'package:happy_flutter/features/sessions/widgets/mission_control_types.dart';

/// First seed `roster-shape-<n>` that yields [shape].
String _seedFor(AgentShape shape) {
  for (var i = 0; i < 500; i++) {
    final seed = 'roster-shape-$i';
    final id = agentIdentityForSeed(seed, brightness: Brightness.dark);
    if (id.shape == shape) return seed;
  }
  return 'roster-shape-0';
}

const _flavors = ['claude', 'codex', 'grok', 'opencode', 'claude', 'codex'];
const _lanes = [
  MissionLane.live,
  MissionLane.blocked,
  MissionLane.error,
  MissionLane.unread,
  MissionLane.live,
  MissionLane.quiet,
];

Session _rowSession(String id, AgentShape shape, String flavor) {
  final at = DateTime.now()
      .subtract(const Duration(minutes: 4))
      .millisecondsSinceEpoch;
  return Session(
    id: id,
    seq: 1,
    createdAt: at,
    updatedAt: at,
    active: true,
    activeAt: at,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: true,
    presence: 'online',
    lastMessageAt: at,
    metadata: Metadata(
      host: 'denys-mbp',
      flavor: flavor,
      path: '/Users/denys/git/happy_flutter',
      summary: Summary(text: 'Shape: ${shape.name}', updatedAt: at),
    ),
  );
}

/// All six shapes: big avatars on top, real rows (with state dots) below.
class RosterAvatarSheet extends StatelessWidget {
  const RosterAvatarSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final shapes = AgentShape.values;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 16,
              children: [
                for (var i = 0; i < shapes.length; i++)
                  AgentAvatar(
                    identity: agentIdentityForSeed(
                      _seedFor(shapes[i]),
                      brightness: brightness,
                      flavor: _flavors[i],
                    ),
                    size: 88,
                    providerBadge: (f, s) => HarnessLogo(flavor: f, size: s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < shapes.length; i++)
              MissionActionRow(
                session: _rowSession(
                  _seedFor(shapes[i]),
                  shapes[i],
                  _flavors[i],
                ),
                entry: SessionUiEntry(
                  lastMessagePreview:
                      '${_lanes[i].name}: avatar, badge and state dot',
                  lastMessageTimestamp: DateTime.now()
                      .subtract(const Duration(minutes: 4))
                      .millisecondsSinceEpoch,
                  unreadCount: _lanes[i] == MissionLane.unread ? 2 : 0,
                ),
                lane: _lanes[i],
                animateActivity: false,
                onTap: () {},
                onLongPress: () {},
              ),
          ],
        ),
      ),
    );
  }
}
