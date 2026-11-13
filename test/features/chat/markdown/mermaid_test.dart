import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/code_block_widget.dart';
import 'package:happy_flutter/features/chat/markdown/markdown.dart';
import 'package:happy_flutter/features/chat/markdown/mermaid/mermaid_layout.dart';
import 'package:happy_flutter/features/chat/markdown/mermaid/mermaid_model.dart';
import 'package:happy_flutter/features/chat/markdown/mermaid/mermaid_parser.dart';
import 'package:happy_flutter/features/chat/markdown/mermaid/mermaid_scene.dart';

const _colorfulFlowchart = '''
flowchart LR
  %% A comment
  subgraph client [Client side]
    app([Flutter app]):::ui --> cache[(Local cache)]
  end
  app -->|HTTPS| api{Auth ok?}
  api -- yes --> db[(Postgres)]
  api -.->|no| err>Reject]
  db ==> done((Done)) & log[[Audit log]]
  classDef ui fill:#4f46e5,stroke:#312e81,color:#fff
  class db,done ok
  classDef ok fill:lightgreen
  style err fill:#fee2e2,stroke:#dc2626
  linkStyle 0 stroke:#f59e0b,stroke-width:3px
''';

const _sequence = '''
sequenceDiagram
  autonumber
  actor U as User
  participant A as App
  participant S as Server
  U->>A: Tap send
  rect rgb(191, 223, 255)
    A->>+S: POST /messages
    alt accepted
      S-->>A: 200 OK
    else rejected
      S--xA: 409 Conflict
    end
  end
  loop every 30s
    A-)S: heartbeat
  end
  Note over A,S: Socket stays open
  S->>S: fan out
''';

MermaidTheme _theme({bool dark = false}) => MermaidTheme.of(
  dark ? ThemeData.dark() : ThemeData.light(),
  TextScaler.noScaling,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseMermaid flowchart', () {
    test('MermaidParser_Flowchart_ParsesShapesEdgesAndStyles', () {
      final d = parseMermaid(_colorfulFlowchart) as FlowchartDiagram;
      expect(d.direction, MermaidDirection.leftRight);
      expect(d.nodes['app']!.shape, MermaidNodeShape.stadium);
      expect(d.nodes['app']!.label, 'Flutter app');
      expect(d.nodes['cache']!.shape, MermaidNodeShape.cylinder);
      expect(d.nodes['api']!.shape, MermaidNodeShape.rhombus);
      expect(d.nodes['err']!.shape, MermaidNodeShape.asymmetric);
      expect(d.nodes['done']!.shape, MermaidNodeShape.circle);
      expect(d.nodes['log']!.shape, MermaidNodeShape.subroutine);
      expect(d.nodes['app']!.subgraph, 'client');
      expect(d.nodes['api']!.subgraph, isNull);
      expect(d.subgraphs['client']!.title, 'Client side');

      final labels = d.edges.map((e) => '${e.from}>${e.to}:${e.label}');
      expect(
        labels,
        containsAll([
          'app>cache:null',
          'app>api:HTTPS',
          'api>db:yes',
          'api>err:no',
          'db>done:null',
          'db>log:null',
        ]),
      );
      final dotted = d.edges.firstWhere((e) => e.to == 'err');
      expect(dotted.line, FlowEdgeLine.dotted);
      final thick = d.edges.firstWhere((e) => e.to == 'done');
      expect(thick.line, FlowEdgeLine.thick);

      final ui = d.styleOf(d.nodes['app']!);
      expect(ui.fill, const Color(0xFF4F46E5));
      expect(ui.color, const Color(0xFFFFFFFF));
      expect(d.styleOf(d.nodes['db']!).fill, const Color(0xFF90EE90));
      expect(d.styleOf(d.nodes['err']!).stroke, const Color(0xFFDC2626));
      expect(d.edgeStyleOf(0).stroke, const Color(0xFFF59E0B));
      expect(d.edgeStyleOf(0).strokeWidth, 3);
    });

    test('MermaidParser_Flowchart_HandlesTextArrowsAndSemicolons', () {
      final d =
          parseMermaid(
                'graph TD; A["Start <br/> here"] -- go on --> B; B --- C',
              )
              as FlowchartDiagram;
      expect(d.direction, MermaidDirection.topDown);
      expect(d.nodes['A']!.label, 'Start\nhere');
      expect(d.edges.first.label, 'go on');
      expect(d.edges.last.endMarker, FlowEdgeMarker.none);
    });

    test('MermaidParser_Flowchart_RedirectsSubgraphEndpoints', () {
      final d =
          parseMermaid('''
flowchart TB
  subgraph one
    a1 --> a2
  end
  subgraph two
    b1
  end
  one --> two
''')
              as FlowchartDiagram;
      expect(d.nodes.containsKey('one'), isFalse);
      expect(d.nodes.containsKey('two'), isFalse);
      expect(d.edges.any((e) => e.from == 'a2' && e.to == 'b1'), isTrue);
    });

    test('MermaidParser_Unsupported_Throws', () {
      expect(
        () => parseMermaid('gantt\n  title Plan'),
        throwsA(
          isA<MermaidParseException>().having(
            (e) => e.unsupported,
            'unsupported',
            isTrue,
          ),
        ),
      );
      expect(
        () => parseMermaid('flowchart TD\n  A --> '),
        throwsA(isA<MermaidParseException>()),
      );
    });
  });

  group('parseMermaid sequence and pie', () {
    test('MermaidParser_Sequence_ParsesParticipantsAndBlocks', () {
      final d = parseMermaid(_sequence) as SequenceDiagram;
      expect(d.participants.map((p) => p.id), ['U', 'A', 'S']);
      expect(d.participants.first.isActor, isTrue);
      expect(d.participants[1].label, 'App');
      final messages = d.events.whereType<SequenceMessage>().toList();
      expect(messages, hasLength(6));
      expect(messages.first.number, 1);
      expect(messages[2].dotted, isTrue);
      expect(messages[3].arrow, SequenceArrow.cross);
      expect(messages[4].arrow, SequenceArrow.async);
      expect(messages.last.from, messages.last.to);
      final starts = d.events.whereType<SequenceBlockStart>().toList();
      expect(starts.map((s) => s.kind), [
        SequenceBlockKind.rect,
        SequenceBlockKind.alt,
        SequenceBlockKind.loop,
      ]);
      expect(starts.first.color, const Color(0xFFBFDFFF));
      expect(d.events.whereType<SequenceBlockEnd>(), hasLength(starts.length));
    });

    test('MermaidParser_Pie_ParsesSlices', () {
      final d =
          parseMermaid(
                'pie showData\n  title Pets\n  "Dogs" : 386\n  "Cats" : 85.5',
              )
              as PieDiagram;
      expect(d.title, 'Pets');
      expect(d.showData, isTrue);
      expect(d.slices.map((s) => s.value), [386, 85.5]);
    });
  });

  group('parseMermaidColor', () {
    test('MermaidColor_Parse_SupportsCssForms', () {
      expect(parseMermaidColor('#f00'), const Color(0xFFFF0000));
      expect(parseMermaidColor('#00ff0080'), const Color(0x8000FF00));
      expect(parseMermaidColor('rgba(0, 0, 255, 0.5)')!.b, 1);
      expect(parseMermaidColor('Orange'), const Color(0xFFFFA500));
      expect(parseMermaidColor('nonsense'), isNull);
    });
  });

  group('buildMermaidScene', () {
    for (final dark in [false, true]) {
      test('MermaidLayout_Build_ProducesFiniteScenes (dark: $dark)', () {
        for (final source in [
          _colorfulFlowchart,
          _sequence,
          'pie\n "A" : 1\n "B" : 3',
          // Cycles, self loops and long edges.
          'graph LR\n a-->b-->c-->a\n a-->a\n a-->d\n b-->d\n c-->d-->e-->f\n a-->f',
        ]) {
          final scene = buildMermaidScene(
            parseMermaid(source),
            _theme(dark: dark),
          );
          expect(scene.size.isFinite, isTrue, reason: source);
          expect(scene.size.width, greaterThan(0), reason: source);
          expect(scene.size.height, greaterThan(0), reason: source);
          expect(scene.ops, isNotEmpty);
          scene.dispose();
        }
      });
    }

    test('MermaidLayout_Flowchart_NodesDoNotOverlap', () {
      final scene = buildMermaidScene(
        parseMermaid(
          'flowchart TD\n A-->B & C & D\n B-->E\n C-->E\n D-->E\n A-->E',
        ),
        _theme(),
      );
      // Node label rectangles must be pairwise disjoint.
      final rects = [
        for (final op in scene.ops.whereType<MermaidTextOp>()) op.bounds,
      ];
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          expect(rects[i].overlaps(rects[j]), isFalse);
        }
      }
      scene.dispose();
    });
  });

  group('MermaidDiagramView', () {
    Future<void> pump(WidgetTester tester, String markdown) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownView(markdown: markdown),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('MermaidDiagramView_Render_DrawsDiagramForMermaidFence', (
      tester,
    ) async {
      await pump(tester, 'Here:\n\n```mermaid\n$_colorfulFlowchart```\n');
      expect(find.byType(MermaidDiagramView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MermaidDiagramView),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
      expect(find.byType(CodeBlockWidget), findsNothing);

      await tester.tap(find.byTooltip('Show diagram source'));
      await tester.pumpAndSettle();
      expect(find.byType(CodeBlockWidget), findsOneWidget);
    });

    testWidgets('MermaidDiagramView_Unsupported_FallsBackToCodeBlock', (
      tester,
    ) async {
      await pump(tester, '```mermaid\ngantt\n  title Plan\n```\n');
      expect(find.byType(CodeBlockWidget), findsOneWidget);
      expect(find.textContaining("isn't supported yet"), findsOneWidget);
    });

    testWidgets('MermaidDiagramView_FullScreen_OpensZoomableViewer', (
      tester,
    ) async {
      await pump(tester, '```mermaid\n$_sequence```\n');
      await tester.tap(find.byTooltip('Open diagram full screen'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    });
  });
}
