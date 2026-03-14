import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'logger_service.dart';

/// Top-level background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
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

  Future<void> initialize({GoRouter? router}) async {
    if (_initialized) return;
    if (kIsWeb) return;

    _router = router;

    try {
      // Initialize local notifications for foreground display
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create notification channel for Android
      const channel = AndroidNotificationChannel(
        'happy_default',
        'Happy Notifications',
        description: 'Default notification channel for Happy',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Set up FCM message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

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
      logger.warning('NotificationService.initialize() failed: $e');
    }
  }

  /// Call this once the [GoRouter] instance is available (after [runApp]).
  void updateRouter(GoRouter router) {
    _router = router;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    logger.info('Foreground notification: ${notification.title}');

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
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

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data =
          json.decode(response.payload!) as Map<String, dynamic>;
      _navigateFromData(data);
    } catch (e) {
      logger.warning('Failed to parse notification payload: $e');
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
