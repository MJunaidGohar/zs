import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const String _boxName = "notification_settings";

  /// Initialize plugin
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();

    const initSettings = InitializationSettings(android: android, iOS: iOS);

    await _notifications.initialize(initSettings);

    // ✅ Create notification channel to match Manifest
    const AndroidNotificationChannel dailyReminderChannel =
    AndroidNotificationChannel(
      'daily_reminder_channel', // must match Manifest
      'Daily Reminder',
      description: 'Reminds user to study daily',
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(dailyReminderChannel);

    // Init timezone (needed for zonedSchedule)
    tz.initializeTimeZones();

    // Ensure Hive box exists
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }

    // Restore saved reminder after restart
    final savedTime = await loadReminderTime();
    if (savedTime != null) {
      await scheduleDailyReminder(savedTime.hour, savedTime.minute);
    }

    // Request notification permissions (iOS & macOS only)
    await _notifications
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notifications
        .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Request Android 13+ POST_NOTIFICATIONS using permission_handler
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Save reminder time (hour & minute) to Hive
  static Future<void> saveReminderTime(TimeOfDay time) async {
    final box = Hive.box(_boxName);
    await box.put('reminderHour', time.hour);
    await box.put('reminderMinute', time.minute);

    await scheduleDailyReminder(time.hour, time.minute);
  }

  /// Load reminder time from Hive
  static Future<TimeOfDay?> loadReminderTime() async {
    final box = Hive.box(_boxName);
    final hour = box.get('reminderHour') as int?;
    final minute = box.get('reminderMinute') as int?;
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Schedule daily reminder at given time
  static Future<void> scheduleDailyReminder(int hour, int minute) async {
    // Cancel previous reminders first
    await cancelAll();

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel', // must match channel ID
      'Daily Reminder',
      channelDescription: 'Reminds user to study daily',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iOSDetails = DarwinNotificationDetails();
    const details =
    NotificationDetails(android: androidDetails, iOS: iOSDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If time already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      0,
      "Study Reminder",
      "It's time to study dude ;)!",
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
  }

  /// Cancel all reminders
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
