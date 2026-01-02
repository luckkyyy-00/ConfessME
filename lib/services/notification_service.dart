import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart'
    hide NotificationSettings;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_settings.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // debugPrint('Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationSettings? _settings;
  String? _fcmToken;
  String? _userId;

  /// Initialize the notification service
  Future<void> initialize({String? userId}) async {
    _userId = userId;

    // Load settings
    final prefs = await SharedPreferences.getInstance();
    _settings = NotificationSettings.fromPrefs(prefs);

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Initialize FCM
    await _initializeFCM();

    // Set up message handlers
    _setupMessageHandlers();
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (!kIsWeb && Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'confessme_notifications',
        'ConfessMe',
        description: 'Notifications for new confessions and reactions',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFCM() async {
    if (kIsWeb) return; // FCM not fully supported on web for this use case

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get FCM token
    _fcmToken = await _messaging.getToken();
    debugPrint('FCM Token: $_fcmToken');

    // Save token to Firestore if user is authenticated
    if (_fcmToken != null && _userId != null) {
      await _saveFCMToken(_fcmToken!);
    }

    // Subscribe to confessions topic for group notifications
    if (_settings?.newConfessionAlerts ?? true) {
      await _messaging.subscribeToTopic('confessions');
      debugPrint('Subscribed to confessions topic');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      if (_userId != null) {
        _saveFCMToken(newToken);
      }
    });

    // Schedule daily reminder
    await scheduleDailyReminder();
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    if (_userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': Platform.operatingSystem,
      }, SetOptions(merge: true));
      debugPrint('FCM token saved to Firestore');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Set up message handlers for foreground and background
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message received: ${message.notification?.title}');
      _handleMessage(message, inForeground: true);
    });

    // Message opened from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message opened app: ${message.notification?.title}');
      _handleNotificationTap(message.data);
    });

    // Check if app was opened from a notification (terminated state)
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint(
          'App opened from notification: ${message.notification?.title}',
        );
        _handleNotificationTap(message.data);
      }
    });
  }

  /// Handle incoming message
  Future<void> _handleMessage(
    RemoteMessage message, {
    bool inForeground = false,
  }) async {
    // Check daily limit (1 per day)
    if (!_settings!.canSendNotification()) {
      debugPrint(
        'Daily notification limit reached. Blocking incoming message.',
      );
      return;
    }

    // Check notification type preference
    final notifType = message.data['type'] as String?;
    if (notifType == 'new_confession' && !_settings!.newConfessionAlerts) {
      return;
    }
    if (notifType == 'reaction' && !_settings!.reactionAlerts) {
      return;
    }
    if (notifType == 'daily_reminder' && !_settings!.dailyReminders) {
      return;
    }

    // Display notification if in foreground
    if (inForeground) {
      await _showLocalNotification(message);
    }

    // Record notification locally to maintain the 1/day limit
    _settings = _settings!.recordNotification();
    final prefs = await SharedPreferences.getInstance();
    await _settings!.saveToPrefs(prefs);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'confessme_notifications',
      'ConfessMe',
      channelDescription: 'Notifications for new confessions and reactions',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // TODO: Navigate to appropriate screen based on notification type
  }

  /// Handle notification tap from FCM
  void _handleNotificationTap(Map<String, dynamic> data) {
    final notifType = data['type'] as String?;
    debugPrint('Notification tap type: $notifType');
    // TODO: Navigate based on type (home, confession detail, etc.)
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized;

    if (granted) {
      debugPrint('Notification permission granted');

      // Update settings to enabled
      final prefs = await SharedPreferences.getInstance();
      _settings = (_settings ?? NotificationSettings()).copyWith(enabled: true);
      await _settings!.saveToPrefs(prefs);

      // Get and save FCM token if not already done
      if (_fcmToken == null) {
        _fcmToken = await _messaging.getToken();
        if (_fcmToken != null && _userId != null) {
          await _saveFCMToken(_fcmToken!);
        }
      }
    } else {
      debugPrint('Notification permission denied');
    }

    return granted;
  }

  /// Schedule daily reminder at 8 PM local time
  Future<void> scheduleDailyReminder() async {
    if (kIsWeb) return;
    if (_settings == null || !_settings!.dailyReminders) {
      await _localNotifications.cancel(888); // Cancel if disabled
      return;
    }

    // Only schedule if user hasn't received a notification today
    if (!_settings!.canSendNotification()) {
      debugPrint('No reminder scheduled: notification already sent today');
      return;
    }

    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      20,
      0,
    ); // 8:00 PM

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Gentle prompts to share anonymously',
      importance: Importance.low, // Lower priority as it's a reminder
      priority: Priority.low,
      icon: 'ic_notification',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      888,
      'Holding something inside?',
      'You\'re not alone. Share anonymously.',
      details,
    );
  }

  /// Check if reaction counts have changed since last visit
  Future<void> checkReactionChanges(List<dynamic> confessions) async {
    if (_settings == null || !_settings!.reactionAlerts) return;
    if (!_settings!.canSendNotification()) return;

    final prefs = await SharedPreferences.getInstance();
    final hasBaseline = prefs.containsKey('last_total_reactions');
    final lastTotalReactions = prefs.getInt('last_total_reactions') ?? 0;

    int currentTotalReactions = 0;
    for (var c in confessions) {
      final counts = c.reactionCounts as Map<String, dynamic>? ?? {};
      counts.forEach((key, value) {
        currentTotalReactions += (value as int);
      });
    }

    // Only show notification if we have a baseline and it increased
    if (hasBaseline && currentTotalReactions > lastTotalReactions) {
      // Show local notification
      await _showLocalNotification(
        const RemoteMessage(
          notification: RemoteNotification(
            title: 'Your words resonated',
            body: 'Someone reacted to your confession.',
          ),
          data: {'type': 'reaction'},
        ),
      );

      // Record it
      _settings = _settings!.recordNotification();
      await _settings!.saveToPrefs(prefs);
    }

    // Save current count for next check
    await prefs.setInt('last_total_reactions', currentTotalReactions);
  }

  /// Check if permission is granted
  Future<bool> isPermissionGranted() async {
    if (kIsWeb) return false;

    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// Update notification settings
  Future<void> updateSettings(NotificationSettings newSettings) async {
    _settings = newSettings;
    final prefs = await SharedPreferences.getInstance();
    await _settings!.saveToPrefs(prefs);

    // Update Firestore (Internal sync, but we rely on local logic for 'free' behavior)
    if (_userId != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(_userId).set({
          'notificationSettings': {
            'enabled': newSettings.enabled,
            'newConfessionAlerts': newSettings.newConfessionAlerts,
            'reactionAlerts': newSettings.reactionAlerts,
            'dailyReminders': newSettings.dailyReminders,
          },
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error updating notification settings: $e');
      }
    }

    // Manage Topic Subscription based on setting
    if (newSettings.newConfessionAlerts) {
      await _messaging.subscribeToTopic('confessions');
    } else {
      await _messaging.unsubscribeFromTopic('confessions');
    }

    // Update Daily Reminder schedule
    await scheduleDailyReminder();
  }

  /// Get current settings
  NotificationSettings get settings => _settings ?? NotificationSettings();

  /// Get FCM token
  String? get fcmToken => _fcmToken;

  /// Send a test notification (for debugging)
  Future<void> sendTestNotification() async {
    final message = RemoteMessage(
      notification: const RemoteNotification(
        title: 'Test Notification',
        body: 'This is a test notification from ConfessMe',
      ),
      data: {'type': 'test'},
    );

    await _showLocalNotification(message);
  }
}
