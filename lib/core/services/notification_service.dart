import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../utils/permission_description.dart';
import 'logger_service.dart';
import 'sync_service.dart';

/// Notification action ID for allowing a permission request.
const _kActionAllow = 'permission_allow';

/// Notification action ID for denying a permission request.
const _kActionDeny = 'permission_deny';

/// Notification action ID for an inline-reply.
///
/// Used both on permission notifications (so the user can answer the
/// agent's question without unlocking the phone) and on the live
/// "agent thinking" activity notification.
const _kActionReply = 'inline_reply';

/// Android notification channel for permission requests.
const _kPermissionChannelId = 'happy_permissions';
const _kPermissionChannelName = 'Permission Requests';
const _kPermissionChannelDesc =
    'Notifications when Claude needs permission to proceed';

/// Android notification channel for the live session activity
/// (ongoing notification that shows the running tool + elapsed time).
const _kActivityChannelId = 'happy_session_activity';
const _kActivityChannelName = 'Session Activity';
const _kActivityChannelDesc =
    'Ongoing notification while a Claude session is running';

/// iOS notification category for permission requests.
const _kPermissionCategory = 'permission_request';

/// iOS notification category for inline-reply on session activity.
const _kActivityCategory = 'session_activity';

/// Reserved Android notification ID base for activity notifications.
/// Each session occupies a slot derived from `sessionId.hashCode`.
const int _kActivityIdBase = 0x5A50_0000;

/// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Background messages are handled by the system notification tray.
  // No additional processing needed.
}

/// Result of parsing an inline-reply notification action.
///
/// Exposed so tests can verify payload/input parsing without spinning up
/// the full plugin or hitting the Sync singleton.
class InlineReplyData {
  const InlineReplyData({
    required this.sessionId,
    required this.text,
    this.permissionId,
  });

  final String sessionId;
  final String text;

  /// Set when the reply originated from a permission notification —
  /// the caller should auto-deny the original permission so the agent
  /// isn't left blocked.
  final String? permissionId;
}

/// Parses a notification payload + inline-reply input into a structured
/// result, returning `null` when the payload is missing/invalid or the
/// input is empty.
///
/// This function is intentionally pure so it can be exercised by unit
/// tests with no plugin/storage dependencies.
InlineReplyData? parseReplyAction({
  required String? payload,
  required String? input,
}) {
  if (payload == null) return null;
  final trimmed = (input ?? '').trim();
  if (trimmed.isEmpty) return null;
  try {
    final data = json.decode(payload) as Map<String, dynamic>;
    final sessionId = data['sessionId'] as String?;
    if (sessionId == null || sessionId.isEmpty) return null;
    final permissionId = data['permissionId'] as String?;
    return InlineReplyData(
      sessionId: sessionId,
      text: trimmed,
      permissionId: permissionId,
    );
  } catch (_) {
    return null;
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  GoRouter? _router;
  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  Future<void> initialize({GoRouter? router}) async {
    if (_initialized) return;
    if (kIsWeb) return;

    _router = router;

    try {
      // Initialize local notifications for foreground display
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final darwinSettings = DarwinInitializationSettings(
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _kPermissionCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _kActionAllow,
                'Allow',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(
                _kActionDeny,
                'Deny',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.destructive,
                },
              ),
              DarwinNotificationAction.text(
                _kActionReply,
                'Reply',
                buttonTitle: 'Send',
                placeholder: 'Reply to agent…',
              ),
            ],
          ),
          DarwinNotificationCategory(
            _kActivityCategory,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.text(
                _kActionReply,
                'Reply',
                buttonTitle: 'Send',
                placeholder: 'Reply to agent…',
              ),
            ],
          ),
        ],
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Create default notification channel for Android
      const defaultChannel = AndroidNotificationChannel(
        'happy_default',
        'Happy Notifications',
        description: 'Default notification channel for Happy',
        importance: Importance.high,
      );

      // Create permission-specific channel with max importance
      const permissionChannel = AndroidNotificationChannel(
        _kPermissionChannelId,
        _kPermissionChannelName,
        description: _kPermissionChannelDesc,
        importance: Importance.max,
      );

      // Create the live "session activity" channel — low importance so
      // the ongoing notification doesn't make a sound every update.
      const activityChannel = AndroidNotificationChannel(
        _kActivityChannelId,
        _kActivityChannelName,
        description: _kActivityChannelDesc,
        importance: Importance.low,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(defaultChannel);
      await androidPlugin?.createNotificationChannel(permissionChannel);
      await androidPlugin?.createNotificationChannel(activityChannel);

      // Set up FCM message handlers
      _foregroundSub =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp
          .listen(_handleMessageOpenedApp);

      // Check if app was opened from a terminated state via notification
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      _initialized = true;
      logger.info('NotificationService initialized');
    } catch (e) {
      // Firebase may not be available (e.g. missing google-services.json).
      // Gracefully degrade — push notifications simply won't work.
      logger.warning(
        'NotificationService.initialize() failed: $e',
      );
    }
  }

  /// Call this once the [GoRouter] instance is available
  /// (after [runApp]).
  void updateRouter(GoRouter router) {
    _router = router;
  }

  /// Cancel Firebase stream subscriptions. Call on logout or
  /// app teardown.
  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    _foregroundSub = null;
    _openedAppSub = null;
    _initialized = false;
  }

  // -----------------------------------------------------------
  // Permission notifications
  // -----------------------------------------------------------

  /// Show a local notification for a pending permission request
  /// with Allow / Deny action buttons.
  Future<void> showPermissionNotification({
    required String sessionId,
    required String permissionId,
    required String toolName,
    Map<String, dynamic>? toolInput,
    String? sessionName,
  }) async {
    if (!_initialized) return;

    final body = describePermissionAction(toolName, toolInput);
    final title = sessionName != null
        ? 'Permission required \u2014 $sessionName'
        : 'Permission required';

    final payload = json.encode(<String, String>{
      'type': 'permission',
      'sessionId': sessionId,
      'permissionId': permissionId,
    });

    const androidActions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        _kActionAllow,
        'Allow',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        _kActionDeny,
        'Deny',
        showsUserInterface: false,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        _kActionReply,
        'Reply',
        showsUserInterface: false,
        cancelNotification: true,
        inputs: <AndroidNotificationActionInput>[
          AndroidNotificationActionInput(
            label: 'Reply to agent…',
          ),
        ],
      ),
    ];

    const androidDetails = AndroidNotificationDetails(
      _kPermissionChannelId,
      _kPermissionChannelName,
      channelDescription: _kPermissionChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      actions: androidActions,
    );

    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: _kPermissionCategory,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      id: permissionId.hashCode,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Cancel a permission notification when the request is resolved.
  Future<void> cancelPermissionNotification(
    String permissionId,
  ) async {
    await _localNotifications.cancel(id: permissionId.hashCode);
  }

  // -----------------------------------------------------------
  // Session activity notifications (live progress + inline reply)
  // -----------------------------------------------------------

  int _activityIdFor(String sessionId) =>
      _kActivityIdBase ^ (sessionId.hashCode & 0xFFFF);

  /// Show or update an ongoing notification reflecting an active
  /// agent session. The notification is silent (importance.low) and
  /// stays pinned (`ongoing: true`) until [cancelSessionActivityNotification]
  /// is called or the session leaves the running state.
  ///
  /// On Android this becomes a foreground-style ongoing notification with
  /// progress bar + Reply action. On iOS it surfaces as a regular
  /// notification with the inline-reply category. (True iOS Live Activities
  /// require a Swift target — see `LiveActivityService` for that stub.)
  Future<void> showSessionActivityNotification({
    required String sessionId,
    required String toolName,
    required DateTime startedAt,
    String? sessionName,
    int? progressPercent,
  }) async {
    if (!_initialized) return;

    final elapsed = DateTime.now().difference(startedAt);
    final elapsedLabel = _formatElapsed(elapsed);
    final title = sessionName != null
        ? 'Running — $sessionName'
        : 'Agent running';
    final body = '$toolName • $elapsedLabel';

    final payload = json.encode(<String, String>{
      'type': 'activity',
      'sessionId': sessionId,
    });

    const androidActions = <AndroidNotificationAction>[
      AndroidNotificationAction(
        _kActionReply,
        'Reply',
        showsUserInterface: false,
        cancelNotification: false,
        inputs: <AndroidNotificationActionInput>[
          AndroidNotificationActionInput(
            label: 'Reply to agent…',
          ),
        ],
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      _kActivityChannelId,
      _kActivityChannelName,
      channelDescription: _kActivityChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      silent: true,
      showProgress: progressPercent != null,
      maxProgress: 100,
      progress: progressPercent ?? 0,
      indeterminate: progressPercent == null,
      category: AndroidNotificationCategory.progress,
      actions: androidActions,
    );

    const darwinDetails = DarwinNotificationDetails(
      categoryIdentifier: _kActivityCategory,
      // Default interruption — don't preempt while running.
      presentSound: false,
      presentBanner: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _localNotifications.show(
      id: _activityIdFor(sessionId),
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Cancel the ongoing session activity notification (e.g. when the
  /// agent stops thinking or the user opens the chat screen).
  Future<void> cancelSessionActivityNotification(String sessionId) async {
    if (!_initialized) return;
    await _localNotifications.cancel(id: _activityIdFor(sessionId));
  }

  static String _formatElapsed(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes < 60) return '${minutes}m ${seconds}s';
    final hours = d.inHours;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  // -----------------------------------------------------------
  // FCM handlers
  // -----------------------------------------------------------

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    logger.info('Foreground notification: ${notification.title}');

    _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'happy_default',
          'Happy Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: json.encode(message.data),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    logger.info('Notification opened app: ${message.data}');
    _navigateFromData(message.data);
  }

  // -----------------------------------------------------------
  // Notification response handling
  // -----------------------------------------------------------

  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;

    // Inline reply action carries an `input` value.
    if (actionId == _kActionReply) {
      _handleReplyAction(response.payload, response.input);
      return;
    }

    // Action button tapped (Allow / Deny).
    if (actionId != null && actionId.isNotEmpty) {
      _handlePermissionAction(actionId, response.payload);
      return;
    }

    // Notification body tapped — navigate to the session.
    if (response.payload == null) return;
    try {
      final data = json.decode(response.payload!)
          as Map<String, dynamic>;

      // Permission notification body tap → navigate to chat.
      if (data['type'] == 'permission') {
        final sessionId = data['sessionId'] as String?;
        if (sessionId != null) {
          _navigateFromData(<String, dynamic>{
            'sessionId': sessionId,
          });
        }
        return;
      }

      _navigateFromData(data);
    } catch (e) {
      logger.warning('Failed to parse notification payload: $e');
    }
  }

  Future<void> _handlePermissionAction(
    String actionId,
    String? payload,
  ) async {
    if (payload == null) return;

    try {
      final data =
          json.decode(payload) as Map<String, dynamic>;
      final sessionId = data['sessionId'] as String?;
      final permissionId = data['permissionId'] as String?;
      if (sessionId == null || permissionId == null) return;

      if (actionId == _kActionAllow) {
        await Sync().sessionAllow(sessionId, permissionId);
        logger.info(
          'Permission allowed via notification: '
          '$permissionId',
        );
      } else if (actionId == _kActionDeny) {
        await Sync().sessionDeny(sessionId, permissionId);
        logger.info(
          'Permission denied via notification: '
          '$permissionId',
        );
      }
    } on StateError catch (e) {
      // Permission expired or session restarted — expected race.
      logger.warning(
        'Permission action from notification failed: $e',
      );
    } catch (e) {
      logger.warning(
        'Permission action from notification failed: $e',
      );
    }
  }

  /// Handle an inline-reply notification action.
  ///
  /// The reply text is sent through [Sync.sendMessage] which produces
  /// exactly one canonical `localId` for the message — preserving the
  /// `one tap → one localId` invariant required by the chat send path.
  Future<void> _handleReplyAction(
    String? payload,
    String? input,
  ) async {
    final result = parseReplyAction(payload: payload, input: input);
    if (result == null) {
      logger.warning(
        'Inline reply received without a session/text payload',
      );
      return;
    }
    try {
      // Sync.sendMessage creates a fresh canonical localId when none
      // is supplied — exactly one localId for this notification tap.
      await Sync().sendMessage(
        result.sessionId,
        result.text,
        displayText: result.text,
      );
      logger.info(
        'Inline reply sent via notification: '
        'session=${result.sessionId} chars=${result.text.length}',
      );
      // For permission notifications, also auto-deny so the agent isn't
      // blocked waiting on the original prompt — the user replied
      // instead. (Allow would risk running the un-approved tool.)
      final permissionId = result.permissionId;
      if (permissionId != null) {
        try {
          await Sync().sessionDeny(result.sessionId, permissionId);
        } on StateError {
          // Permission expired — that's fine.
        }
      }
    } on StateError catch (e) {
      logger.warning(
        'Inline reply send aborted (sync not initialized): $e',
      );
    } catch (e, st) {
      logger.warning(
        'Inline reply send failed: $e',
        e,
        st,
      );
    }
  }

  void _navigateFromData(Map<String, dynamic> data) {
    if (_router == null) return;

    final sessionId = data['sessionId'] as String?;
    if (sessionId != null) {
      _router!.goNamed(
        'chat',
        pathParameters: {'sessionId': sessionId},
      );
    }
  }
}
