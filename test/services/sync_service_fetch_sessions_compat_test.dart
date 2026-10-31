import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/api_client.dart';
import 'package:happy_flutter/core/encryption/encryption_manager.dart';
import 'package:happy_flutter/core/encryption/session_encryption.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

class _FakeSessionEncryption implements SessionEncryption {
  _FakeSessionEncryption({
    required this.metadata,
    required this.agentState,
    this.onDecryptMetadata,
  });

  final Map<String, dynamic>? metadata;
  final Map<String, dynamic> agentState;
  final void Function()? onDecryptMetadata;

  @override
  Future<Map<String, dynamic>?> decryptMetadata(
    int version,
    String encrypted,
  ) async {
    onDecryptMetadata?.call();
    return metadata;
  }

  @override
  Future<Map<String, dynamic>> decryptAgentState(
    int version,
    String? encrypted,
  ) async {
    return agentState;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeEncryption implements Encryption {
  _FakeEncryption(this.sessionEncryption);

  final SessionEncryption sessionEncryption;

  @override
  Future<void> initializeSessions(Map<String, Uint8List?> sessions) async {}

  @override
  SessionEncryption? getSessionEncryption(String sessionId) {
    return sessionEncryption;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Sync.fetchSessions compatibility', () {
    late Sync instance;

    setUp(() async {
      instance = Sync();
      instance.testSessions.clear();
      instance.testLastSessionsFetchedAt = null;
      instance.testSessionsCatalogWatermarkMs = null;
      instance.testLastFullSessionsCatalogAtMs = null;
      instance.testForceFullFetchNext = false;
      instance.testIsInitialized = true;

      instance.encryption = _FakeEncryption(
        _FakeSessionEncryption(
          metadata: <String, dynamic>{
            'path': '/legacy/project',
            'host': null,
            'summary': <String, dynamic>{
              'text': 'Legacy summary',
              'updatedAt': 'not-an-int',
            },
            'tools': <dynamic>['bash', 7],
          },
          agentState: <String, dynamic>{},
        ),
      );

      await ApiClient().initialize(serverUrl: 'http://localhost');
    });

    tearDown(() {
      ApiClient().dispose();
      instance.testSessions.clear();
      instance.testLastSessionsFetchedAt = null;
      instance.testSessionsCatalogWatermarkMs = null;
      instance.testLastFullSessionsCatalogAtMs = null;
      instance.testForceFullFetchNext = false;
      instance.testIsInitialized = false;
    });

    test('failed forced full fetch remains forced on retry', () async {
      instance.testLastSessionsFetchedAt = 123456;
      instance.testForceFullFetchNext = true;
      final queries = <Map<String, dynamic>>[];
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            queries.add(Map<String, dynamic>.from(options.queryParameters));
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: queries.length == 1 ? 400 : 200,
                data: queries.length == 1
                    ? <String, dynamic>{}
                    : <String, dynamic>{'sessions': [], 'hasNext': false},
              ),
            );
          },
        ),
      );

      await expectLater(instance.fetchSessions(), throwsA(isA<Exception>()));
      expect(instance.testForceFullFetchNext, isTrue);
      await instance.fetchSessions();
      expect(queries, hasLength(2));
      expect(
        queries.every((query) => !query.containsKey('changedSince')),
        isTrue,
      );
    });

    Session localSession(String id, {int seq = 1}) => Session(
      id: id,
      seq: seq,
      createdAt: 1700000000000,
      updatedAt: 1700000000000,
      active: false,
      activeAt: 1700000000000,
      metadataVersion: 1,
      agentStateVersion: 1,
      thinking: false,
      presence: 'offline',
    );

    Map<String, dynamic> wireSession(String id, {int seq = 1}) => {
      'id': id,
      'seq': seq,
      'createdAt': 1700000000000,
      'updatedAt': 1700000000000,
      'active': false,
      'activeAt': 1700000000000,
      'metadata': 'opaque-payload',
      'metadataVersion': 1,
      'agentStateVersion': 1,
    };

    test(
      'device clocks never filter catalog reads; deltas use server time',
      () async {
        instance.testLastSessionsFetchedAt = 9999999999999;
        final queries = <Map<String, dynamic>>[];
        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              queries.add(Map<String, dynamic>.from(options.queryParameters));
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'sessions': [
                      wireSession('server-clock', seq: queries.length),
                    ],
                    'hasNext': false,
                  },
                ),
              );
            },
          ),
        );

        await instance.fetchSessions();
        await instance.fetchSessions();

        expect(queries, hasLength(2));
        expect(queries.first.containsKey('changedSince'), isFalse);
        // The delta cursor is the server's updatedAt minus the overlap,
        // never the (advanced) device clock.
        expect(queries.last['changedSince'], 1700000000000 - 10 * 60 * 1000);
        expect(instance.sessions['server-clock']?.seq, 2);
      },
    );

    group('delta catalog reads', () {
      late List<Map<String, dynamic>> queries;
      late List<List<Map<String, dynamic>>> pages;

      setUp(() {
        queries = [];
        pages = [];
        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              queries.add(Map<String, dynamic>.from(options.queryParameters));
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'sessions': pages.isEmpty ? [] : pages.removeAt(0),
                    'hasNext': false,
                  },
                ),
              );
            },
          ),
        );
      });

      Map<String, dynamic> row(String id, int updatedAt, {int seq = 1}) => {
        ...wireSession(id, seq: seq),
        'updatedAt': updatedAt,
      };

      test('overlay changed rows and keep unchanged ones', () async {
        pages.add([row('a', 1700000000000), row('b', 1700000005000)]);
        await instance.fetchSessions();
        expect(instance.testSessionsCatalogWatermarkMs, 1700000005000);

        pages.add([row('b', 1700000009000, seq: 7), row('c', 1700000008000)]);
        await instance.fetchSessions();

        expect(queries.last['changedSince'], 1700000005000 - 10 * 60 * 1000);
        expect(instance.sessions.keys, containsAll(<String>['a', 'b', 'c']));
        expect(instance.sessions['b']?.seq, 7);
        expect(instance.testSessionsCatalogWatermarkMs, 1700000009000);
      });

      test('an empty delta leaves the catalog untouched', () async {
        pages.add([row('a', 1700000000000)]);
        await instance.fetchSessions();
        final before = instance.sessions['a'];

        await instance.fetchSessions();

        expect(queries.last.containsKey('changedSince'), isTrue);
        expect(instance.sessions['a'], same(before));
        expect(instance.testSessionsCatalogWatermarkMs, 1700000000000);
      });

      test(
        'forced and expired reconciliations read the full catalog',
        () async {
          pages.add([row('a', 1700000000000), row('gone', 1700000000000)]);
          await instance.fetchSessions();

          instance.testForceFullFetchNext = true;
          pages.add([row('a', 1700000000000)]);
          await instance.fetchSessions();
          expect(queries.last.containsKey('changedSince'), isFalse);
          expect(instance.sessions.containsKey('gone'), isFalse);

          instance.testLastFullSessionsCatalogAtMs =
              DateTime.now().millisecondsSinceEpoch - 25 * 60 * 60 * 1000;
          pages.add([row('a', 1700000000000)]);
          await instance.fetchSessions();
          expect(queries.last.containsKey('changedSince'), isFalse);
        },
      );

      test('a reset delta cursor falls back to a full read', () async {
        pages.add([row('a', 1700000000000)]);
        await instance.fetchSessions();

        instance.testLastSessionsFetchedAt = null;
        await instance.fetchSessions();

        expect(queries.last.containsKey('changedSince'), isFalse);
      });
    });

    for (final empty in [false, true]) {
      for (final duringDecrypt in [false, true]) {
        if (empty && duringDecrypt) continue;
        test('full catalog preserves in-flight changes '
            '(empty=$empty, duringDecrypt=$duringDecrypt)', () async {
          instance.testSessions.addAll({
            'updated': localSession('updated'),
            'deleted': localSession('deleted'),
            'omitted': localSession('omitted'),
          });
          final updated = localSession('updated', seq: 10);
          final added = localSession('added');
          var applied = false;
          void mutateCatalog() {
            if (applied) return;
            applied = true;
            instance.testSessions['updated'] = updated;
            instance.testSessions['added'] = added;
            instance.testSessions.remove('deleted');
            instance.testSessions['transient'] = localSession('transient');
            instance.testSessions.remove('transient');
          }

          if (duringDecrypt) {
            instance.encryption = _FakeEncryption(
              _FakeSessionEncryption(
                metadata: {'path': '/project', 'host': 'host'},
                agentState: {},
                onDecryptMetadata: mutateCatalog,
              ),
            );
          }
          ApiClient().testDio!.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                if (!duringDecrypt) mutateCatalog();
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'sessions': [
                        if (!empty) ...[
                          wireSession('updated'),
                          wireSession('deleted'),
                          wireSession('transient'),
                          wireSession('remote'),
                        ],
                      ],
                      'hasNext': false,
                    },
                  ),
                );
              },
            ),
          );

          await instance.fetchSessions();

          expect(applied, isTrue);
          expect(instance.sessions['updated'], same(updated));
          expect(instance.sessions['added'], same(added));
          expect(instance.sessions.containsKey('deleted'), isFalse);
          expect(instance.sessions.containsKey('transient'), isFalse);
          expect(instance.sessions.containsKey('omitted'), isFalse);
          expect(instance.sessions.containsKey('remote'), !empty);
        });
      }
    }

    for (final reset in [false, true]) {
      test('invalidated catalog journal retains live snapshot '
          '(reset=$reset)', () async {
        final live = localSession('live');
        instance.testSessions['live'] = live;
        var requests = 0;
        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (requests++ == 0) {
                if (reset) {
                  instance.testSessions.clear();
                  instance.testSessions['live'] = live;
                } else {
                  // Exceed the catalog's bounded 1024-entry change journal.
                  for (var i = 0; i < 1025; i++) {
                    instance.testSessions['transient'] = localSession(
                      'transient',
                    );
                    instance.testSessions.remove('transient');
                  }
                }
              }
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'sessions': [wireSession('remote')],
                    'hasNext': false,
                  },
                ),
              );
            },
          ),
        );

        await instance.fetchSessions();
        expect(instance.sessions.keys, ['live']);
        expect(instance.sessions['live'], same(live));

        // The abandoned read is not a full reconciliation, so the later
        // uncontended refresh reads the whole catalog again.
        await instance.fetchSessions();
        expect(instance.sessions.keys, ['remote']);
      });
    }

    test(
      'overlapping refreshes serialize so the later fetch can reconcile',
      () async {
        final firstStarted = Completer<void>();
        late RequestOptions firstOptions;
        late RequestInterceptorHandler firstHandler;
        var requests = 0;
        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (requests++ == 0) {
                firstOptions = options;
                firstHandler = handler;
                firstStarted.complete();
                return;
              }
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'sessions': [wireSession('newer')],
                    'hasNext': false,
                  },
                ),
              );
            },
          ),
        );

        final olderFetch = instance.fetchSessions();
        await firstStarted.future;
        // Deltas cannot remove rows; the later reconciling read is full.
        instance.testForceFullFetchNext = true;
        final newerFetch = instance.fetchSessions();
        await Future<void>.delayed(Duration.zero);
        expect(requests, 1, reason: 'the later fetch waits for the first');
        firstHandler.resolve(
          Response<dynamic>(
            requestOptions: firstOptions,
            statusCode: 200,
            data: {
              'sessions': [wireSession('older')],
              'hasNext': false,
            },
          ),
        );
        await olderFetch;
        await newerFetch;

        expect(instance.sessions.keys, ['newer']);
      },
    );

    test('routine full refresh retains live thinking state', () async {
      instance.testSessions['thinking'] = localSession(
        'thinking',
      ).copyWith(thinking: true, thinkingAt: 1700000000001);
      ApiClient().testDio!.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'sessions': [wireSession('thinking')],
                'hasNext': false,
              },
            ),
          ),
        ),
      );

      await instance.fetchSessions();

      expect(instance.sessions['thinking']?.thinking, isTrue);
      expect(instance.sessions['thinking']?.thinkingAt, 1700000000001);
    });

    for (final archived in [false, true]) {
      test('archive stays hidden across full and delta refresh '
          '(server archived=$archived)', () async {
        const id = 'archived-session';
        instance.markSessionArchived(id);
        addTearDown(() => instance.markSessionUnarchived(id));
        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: <String, dynamic>{
                    'sessions': [
                      {
                        'id': id,
                        'seq': 1,
                        'createdAt': 1700000000000,
                        'updatedAt': 1700000000001,
                        'active': false,
                        'archived': archived,
                        'activeAt': 1700000000001,
                        'metadata': 'opaque-payload',
                        'metadataVersion': 1,
                        'agentStateVersion': 1,
                      },
                    ],
                    'hasNext': false,
                  },
                ),
              );
            },
          ),
        );

        // Returning from chat refreshes the catalog repeatedly.
        for (var refresh = 0; refresh < 3; refresh++) {
          await instance.fetchSessions();
          expect(instance.sessions[id], isNotNull);
          expect(instance.isSessionOptimisticallyArchived(id), isTrue);
        }

        instance.markSessionUnarchived(id);
        expect(instance.isSessionOptimisticallyArchived(id), isFalse);
      });
    }

    test(
      'retains sessions when metadata payload has legacy-invalid fields',
      () async {
        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v2/sessions') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'sessions': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 'legacy-session-1',
                          'seq': 1,
                          'createdAt': 1700000000000,
                          'updatedAt': 1700000000001,
                          'active': false,
                          'activeAt': 1700000000001,
                          'metadata': 'opaque-payload',
                          'metadataVersion': 1,
                          'agentState': null,
                          'agentStateVersion': 1,
                          'dataEncryptionKey': null,
                          'lastSeq': 4,
                        },
                      ],
                      'hasNext': false,
                      'nextCursor': null,
                    },
                  ),
                );
                return;
              }

              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                  data: <String, dynamic>{},
                ),
              );
            },
          ),
        );

        await instance.fetchSessions();

        final session = instance.sessions['legacy-session-1'];
        expect(session, isNotNull);
        expect(session?.metadata, isNotNull);
        expect(session?.metadata?.host, '');
        expect(session?.metadata?.summary, isNull);
        expect(session?.metadata?.tools, <String>['bash']);
      },
    );

    test(
      'catalog fetch preserves existing timestamps when server omits them',
      () async {
        // Seed an existing session with known older timestamps. This
        // simulates a session that hasn't been touched in a while.
        const oldTimestamp = 1700000000000; // 2023-11-14
        instance.testSessions['delta-session'] = Session(
          id: 'delta-session',
          seq: 5,
          createdAt: oldTimestamp,
          updatedAt: oldTimestamp,
          active: false,
          activeAt: oldTimestamp,
          metadataVersion: 0,
          agentStateVersion: 0,
          thinking: false,
          presence: 'offline',
        );
        // A restored cache timestamp is local freshness telemetry only.
        instance.testLastSessionsFetchedAt = oldTimestamp + 1;

        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v2/sessions') {
                // Server returns a delta payload that omits the
                // timestamp fields entirely (only the fields that
                // changed are sent on the wire).
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'sessions': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 'delta-session',
                          'seq': 6,
                          // No createdAt / updatedAt / activeAt here —
                          // the server only sends fields that changed.
                          'metadata': 'opaque-payload',
                          'metadataVersion': 1,
                          'agentState': null,
                          'agentStateVersion': 1,
                          'dataEncryptionKey': null,
                          'lastSeq': 6,
                        },
                      ],
                      'hasNext': false,
                      'nextCursor': null,
                    },
                  ),
                );
                return;
              }

              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                  data: <String, dynamic>{},
                ),
              );
            },
          ),
        );

        await instance.fetchSessions();

        final session = instance.sessions['delta-session'];
        expect(session, isNotNull);
        // Critical: timestamps must not be stamped with DateTime.now().
        // If they were, the session would jump to the top of the list
        // and show "just now" until re-fetched individually.
        expect(session?.createdAt, oldTimestamp);
        expect(session?.updatedAt, oldTimestamp);
        expect(session?.activeAt, oldTimestamp);
      },
    );

    test(
      'does not emit message changes when permission enrichment is unchanged',
      () async {
        var messageChanges = 0;
        final sub = instance.onSessionMessagesChanged.listen((_) {
          messageChanges++;
        });
        addTearDown(sub.cancel);

        instance.testSetSessionMessages('existing-session', [
          <String, dynamic>{
            'id': 'message-1',
            'seq': 1,
            'role': 'user',
            'kind': 'text',
            'content': 'hello',
          },
        ]);

        ApiClient().testDio!.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/v2/sessions') {
                handler.resolve(
                  Response<dynamic>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <String, dynamic>{
                      'sessions': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'id': 'existing-session',
                          'seq': 1,
                          'createdAt': 1700000000000,
                          'updatedAt': 1700000000001,
                          'active': false,
                          'activeAt': 1700000000001,
                          'metadata': 'opaque-payload',
                          'metadataVersion': 1,
                          'agentState': null,
                          'agentStateVersion': 1,
                          'dataEncryptionKey': null,
                          'lastSeq': 1,
                        },
                      ],
                      'hasNext': false,
                      'nextCursor': null,
                    },
                  ),
                );
                return;
              }

              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 404,
                  data: <String, dynamic>{},
                ),
              );
            },
          ),
        );

        await instance.fetchSessions();

        expect(messageChanges, 0);
      },
    );
  });
}
