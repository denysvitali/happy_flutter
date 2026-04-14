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

/// Android notification channel for permission requests.
const _kPermissionChannelId = 'happy_permissions';
const _kPermissionChannelName = 'Permission Requests';
const _kPermissionChannelDesc =
    'Notifications when Claude needs permission to proceed';

/// iOS notification category for permission requests.
const _kPermissionCategory = 'permission_request';

/// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Background messages are handled by the system notification tray.
  // No additional processing needed.
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

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(defaultChannel);
      await androidPlugin?.createNotificationChannel(permissionChannel);

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
