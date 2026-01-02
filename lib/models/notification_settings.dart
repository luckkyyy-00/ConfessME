import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  final bool enabled;
  final bool newConfessionAlerts;
  final bool reactionAlerts;
  final bool dailyReminders;
  final DateTime? lastNotificationTime;
  final int dailyNotificationCount;

  NotificationSettings({
    this.enabled = true,
    this.newConfessionAlerts = true,
    this.reactionAlerts = true,
    this.dailyReminders = true,
    this.lastNotificationTime,
    this.dailyNotificationCount = 0,
  });

  factory NotificationSettings.fromPrefs(SharedPreferences prefs) {
    final lastNotifStr = prefs.getString('notif_last_time');
    return NotificationSettings(
      enabled: prefs.getBool('notif_enabled') ?? true,
      newConfessionAlerts: prefs.getBool('notif_new_confession') ?? true,
      reactionAlerts: prefs.getBool('notif_reactions') ?? true,
      dailyReminders: prefs.getBool('notif_daily_reminder') ?? true,
      lastNotificationTime: lastNotifStr != null
          ? DateTime.parse(lastNotifStr)
          : null,
      dailyNotificationCount: prefs.getInt('notif_daily_count') ?? 0,
    );
  }

  Future<void> saveToPrefs(SharedPreferences prefs) async {
    await prefs.setBool('notif_enabled', enabled);
    await prefs.setBool('notif_new_confession', newConfessionAlerts);
    await prefs.setBool('notif_reactions', reactionAlerts);
    await prefs.setBool('notif_daily_reminder', dailyReminders);
    if (lastNotificationTime != null) {
      await prefs.setString(
        'notif_last_time',
        lastNotificationTime!.toIso8601String(),
      );
    }
    await prefs.setInt('notif_daily_count', dailyNotificationCount);
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? newConfessionAlerts,
    bool? reactionAlerts,
    bool? dailyReminders,
    DateTime? lastNotificationTime,
    int? dailyNotificationCount,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      newConfessionAlerts: newConfessionAlerts ?? this.newConfessionAlerts,
      reactionAlerts: reactionAlerts ?? this.reactionAlerts,
      dailyReminders: dailyReminders ?? this.dailyReminders,
      lastNotificationTime: lastNotificationTime ?? this.lastNotificationTime,
      dailyNotificationCount:
          dailyNotificationCount ?? this.dailyNotificationCount,
    );
  }

  /// Check if we can send a notification today (max 1 per day)
  bool canSendNotification() {
    if (!enabled) return false;

    if (lastNotificationTime == null) return true;

    final now = DateTime.now();
    final lastNotifDate = DateTime(
      lastNotificationTime!.year,
      lastNotificationTime!.month,
      lastNotificationTime!.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    // If last notification was on a different day, reset count
    if (lastNotifDate.isBefore(today)) {
      return true;
    }

    // Same day - check if we've already sent one
    return dailyNotificationCount < 1;
  }

  /// Record that a notification was sent
  NotificationSettings recordNotification() {
    final now = DateTime.now();
    final lastNotifDate = lastNotificationTime != null
        ? DateTime(
            lastNotificationTime!.year,
            lastNotificationTime!.month,
            lastNotificationTime!.day,
          )
        : null;
    final today = DateTime(now.year, now.month, now.day);

    // If it's a new day, reset count
    if (lastNotifDate == null || lastNotifDate.isBefore(today)) {
      return copyWith(lastNotificationTime: now, dailyNotificationCount: 1);
    }

    // Same day, increment count
    return copyWith(
      lastNotificationTime: now,
      dailyNotificationCount: dailyNotificationCount + 1,
    );
  }
}
