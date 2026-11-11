import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/ui/agent_identity.dart';
import 'package:happy_flutter/core/ui/avatars/avatar_palette.dart';

Session _session(String id, {String? flavor}) => Session(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: true,
  activeAt: 1,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  presence: 'online',
  metadata: Metadata(host: 'devbox', path: '/repo', flavor: flavor),
);

void main() {
  group('project colour seed', () {
    tearDown(() => agentColorSeedResolver = null);

    test('sessions sharing a colour seed share a colour, not a shape', () {
      // Pick two ids whose own identities differ in both colour and shape.
      final plain = [
        for (var i = 0; i < 40; i++)
          agentIdentityForSeed('session-$i', brightness: Brightness.light),
      ];
      final a = plain.first;
      final b = plain.firstWhere(
        (x) => x.color != a.color && x.shape != a.shape,
      );

      agentColorSeedResolver = (seed) => 'repo:example/project';
      final groupedA = agentIdentityForSeed(a.seed, brightness: a.brightness);
      final groupedB = agentIdentityForSeed(b.seed, brightness: b.brightness);

      expect(groupedA.color, groupedB.color);
      expect(groupedA.ink, groupedB.ink);
      expect(
        groupedA.color,
        agentAccentForSeed('repo:example/project', Brightness.light),
      );
      // The silhouette still tells conversations of one project apart.
      expect(groupedA.shape, a.shape);
      expect(groupedB.shape, b.shape);
      expect(groupedA.seed, a.seed);
    });

    test('an unresolved session keeps its own colour', () {
      final own = agentIdentityForSeed('lonely', brightness: Brightness.dark);
      agentColorSeedResolver = (seed) => null;
      expect(
        agentIdentityForSeed('lonely', brightness: Brightness.dark).color,
        own.color,
      );
    });
  });

  group('agentIdentityFor', () {
    test('is deterministic per session and theme', () {
      for (final b in Brightness.values) {
        final a = agentIdentityFor(_session('s-1', flavor: 'codex'), b);
        final again = agentIdentityFor(_session('s-1', flavor: 'codex'), b);
        expect(again.color, a.color);
        expect(again.shape, a.shape);
        expect(again.ink, a.ink);
        expect(a.seed, 's-1');
        expect(a.flavor, 'codex');
        expect(a.brightness, b);
      }
    });

    test('shares the avatar palette hue and varies across sessions', () {
      final colors = <Color>{};
      final shapes = <AgentShape>{};
      for (var i = 0; i < 64; i++) {
        final id = agentIdentityForSeed(
          'session-$i',
          brightness: Brightness.light,
        );
        colors.add(id.color);
        shapes.add(id.shape);
        expect(
          HSLColor.fromColor(id.color).hue,
          closeTo(avatarHue('session-$i'), 1),
        );
      }
      expect(colors.length, greaterThan(6));
      expect(shapes, AgentShape.values.toSet());
    });

    test('keeps readable ink and visible fills in both themes', () {
      for (final b in Brightness.values) {
        final surface = b == Brightness.dark
            ? const Color(0xFF111318)
            : const Color(0xFFF8F9FF);
        for (var i = 0; i < 48; i++) {
          final id = agentIdentityForSeed('seed-$i', brightness: b);
          expect(avatarContrast(id.onColor, id.color), greaterThan(4.5));
          expect(avatarContrast(id.ink, surface), greaterThan(4.5));
          // WCAG non-text contrast for the blob silhouette.
          expect(avatarContrast(id.color, surface), greaterThan(3.0));
        }
      }
    });
  });

  test('every shape fully contains the face', () {
    const size = 40.0;
    final face = agentFaceRect(size);
    for (final shape in AgentShape.values) {
      final path = agentShapePath(shape, size);
      for (final point in [
        face.topLeft,
        face.topRight,
        face.bottomLeft,
        face.bottomRight,
        face.center,
      ]) {
        expect(path.contains(point), isTrue, reason: '$shape at $point');
      }
    }
  });

  testWidgets('avatar paints at its size with an optional provider badge', (
    tester,
  ) async {
    final identity = agentIdentityForSeed(
      'badge',
      brightness: Brightness.light,
      flavor: 'claude',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AgentAvatar(
            identity: identity,
            size: 40,
            providerBadge: (f, s) => Text(f, key: const Key('badge')),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AgentAvatar)), const Size(40, 40));
    expect(find.byKey(const Key('badge')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: AgentAvatar(
            identity: identity,
            showProviderBadge: false,
            providerBadge: (f, s) => Text(f, key: const Key('badge')),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('badge')), findsNothing);
  });
}
