import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import 'dart:developer' as developer;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static const String _boxName = "notification_settings";
  static bool _startupPermissionRequested = false;

  // [TEMP] Check if running on web - notifications not supported on web
  static bool get _isWeb => kIsWeb;

  static AndroidFlutterLocalNotificationsPlugin?
  _androidPlugin() => _isWeb ? null : _notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<bool> _ensureAndroidNotificationPermission() async {
    if (_isWeb) return false; // [TEMP] Notifications not supported on web
    if (!Platform.isAndroid) return true;

    final androidPlugin = _androidPlugin();
    final enabled = await androidPlugin?.areNotificationsEnabled() ?? true;
    if (!enabled) return false;

    // Prefer plugin permission API when available.
    final requested = await androidPlugin?.requestNotificationsPermission() ?? true;
    if (!requested) return false;

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    return !(await Permission.notification.isDenied);
  }

  static Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (_isWeb) return AndroidScheduleMode.inexactAllowWhileIdle; // [TEMP] Web stub
    if (!Platform.isAndroid) return AndroidScheduleMode.inexactAllowWhileIdle;

    final androidPlugin = _androidPlugin();

    // If the API exists and exact alarms are not allowed, try requesting.
    final canExact = await androidPlugin?.canScheduleExactNotifications() ?? false;
    if (!canExact) {
      await androidPlugin?.requestExactAlarmsPermission();
    }

    final canExactAfter = await androidPlugin?.canScheduleExactNotifications() ?? false;
    return canExactAfter
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Initialize plugin
  static Future<void> init() async {
    if (_isWeb) {
      developer.log('[TEMP] Notifications: Skipped initialization on web');
      return; // [TEMP] Skip notification init on web
    }
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
    tz_data.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));

    // Check if user has a saved reminder and request permission proactively
    // Only do this once per app session to avoid spam
    // DEFERRED: We use WidgetsBinding to wait for first frame before requesting
    if (!_startupPermissionRequested) {
      _startupPermissionRequested = true;
      
      // Defer permission check until after first frame is rendered
      // This is required for Android permission dialogs to show properly
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _handleStartupPermissionCheck();
      });
    }
  }

  /// Handle permission check after first frame is rendered
  static Future<void> _handleStartupPermissionCheck() async {
    try {
      final savedTime = await loadReminderTime();
      if (savedTime != null) {
        debugPrint('🔔 User has saved reminder at ${savedTime.hour}:${savedTime.minute}, checking permissions...');
        // Check current permission status without showing dialog yet
        final hasPermission = await _checkNotificationPermissionStatus();
        if (!hasPermission) {
          debugPrint('🔔 Permission not granted, requesting...');
          // Small delay to ensure UI is fully ready
          await Future.delayed(const Duration(milliseconds: 500));
          await requestNotificationPermissions();
        } else {
          debugPrint('🔔 Permission already granted, scheduling reminder...');
          await _scheduleWithoutPermissionRequest(savedTime.hour, savedTime.minute);
        }
      } else {
        // No reminder set yet - still check if we should ask for permission
        // This ensures users are prompted on first app launch
        debugPrint('🔔 No saved reminder, checking if we should request permission for first-time user...');
        final hasPermission = await _checkNotificationPermissionStatus();
        if (!hasPermission) {
          // First-time user without notification permission - ask proactively
          debugPrint('🔔 First launch detected, requesting notification permission...');
          try {
            await Future.delayed(const Duration(milliseconds: 800));
            final result = await requestNotificationPermissions();
            debugPrint('🔔 First launch permission result: $result');
          } catch (e) {
            debugPrint('🔔 Error requesting permission on first launch: $e');
          }
        } else {
          debugPrint('🔔 Permission already granted on first launch check');
        }
      }
    } catch (e) {
      debugPrint('🔔 Error in _handleStartupPermissionCheck: $e');
    }
  }

  /// Call this from first screen's initState to ensure permission dialog shows
  /// Use this instead of relying solely on addPostFrameCallback from service init
  static Future<void> checkPermissionFromScreen() async {
    debugPrint('🔔 checkPermissionFromScreen called');
    if (_startupPermissionRequested) {
      debugPrint('🔔 Already requested this session, skipping');
      return;
    }
    _startupPermissionRequested = true;
    await _handleStartupPermissionCheck();
  }

  /// Check if notification permission is granted without requesting
  static Future<bool> _checkNotificationPermissionStatus() async {
    if (_isWeb) return false; // [TEMP] Notifications not supported on web
    if (!Platform.isAndroid) return true;
    
    // On Android 13+, explicitly check the POST_NOTIFICATIONS permission status
    // areNotificationsEnabled() can return true initially even without permission
    final status = await Permission.notification.status;
    debugPrint('🔔 _checkNotificationPermissionStatus: $status');
    return status.isGranted;
  }

  /// Public method to check if notification permission is granted
  static Future<bool> hasNotificationPermission() async {
    return await _checkNotificationPermissionStatus();
  }

  /// Save reminder time (hour & minute) to Hive
  static Future<bool> saveReminderTime(TimeOfDay time) async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    final box = Hive.box(_boxName);
    await box.put('reminderHour', time.hour);
    await box.put('reminderMinute', time.minute);

    return await scheduleDailyReminder(time.hour, time.minute);
  }

  /// Load reminder time from Hive
  static Future<TimeOfDay?> loadReminderTime() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    final box = Hive.box(_boxName);
    final hour = box.get('reminderHour') as int?;
    final minute = box.get('reminderMinute') as int?;
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Check if user has previously set a reminder time
  static Future<bool> hasReminderTimeSet() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    final box = Hive.box(_boxName);
    final hour = box.get('reminderHour') as int?;
    final minute = box.get('reminderMinute') as int?;
    return hour != null && minute != null;
  }

  /// Request notification permissions (to be called when user first selects time)
  static Future<bool> requestNotificationPermissions() async {
    if (_isWeb) {
      debugPrint('[TEMP] Notifications: Permission request skipped on web');
      return false; // [TEMP] Notifications not supported on web
    }
    debugPrint('🔔 ===== REQUESTING NOTIFICATION PERMISSION =====');
    
    try {
      if (!Platform.isAndroid) {
        // For iOS, request permissions directly
        final iOSResult = await _notifications
            .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        
        final macOSResult = await _notifications
            .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        
        final result = iOSResult ?? macOSResult ?? true;
        debugPrint('🔔 iOS/macOS permission result: $result');
        return result;
      }

      // For Android - use permission_handler for explicit request
      debugPrint('🔔 Checking Android notification permission status...');
      
      // Check current status first
      final currentStatus = await Permission.notification.status;
      debugPrint('🔔 Current permission status: $currentStatus');
      
      if (currentStatus.isGranted) {
        debugPrint('🔔 Permission already granted');
        return true;
      }
      
      if (currentStatus.isPermanentlyDenied) {
        debugPrint('🔔 Permission permanently denied');
        return false;
      }
      
      // Request permission explicitly
      debugPrint('🔔 Requesting permission dialog...');
      final result = await Permission.notification.request();
      debugPrint('🔔 Permission request result: $result');
      
      return result.isGranted;
    } catch (e, stackTrace) {
      debugPrint('🔔 ERROR requesting permission: $e');
      debugPrint('🔔 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Internal: Schedule without requesting permissions (used during init for restore)
  static Future<bool> _scheduleWithoutPermissionRequest(int hour, int minute) async {
    if (_isWeb) return false; // [TEMP] Notifications not supported on web
    // Check if permissions are already granted
    if (Platform.isAndroid) {
      final androidPlugin = _androidPlugin();
      final enabled = await androidPlugin?.areNotificationsEnabled() ?? false;
      if (!enabled) return false;
    }

    final androidScheduleMode = await _resolveAndroidScheduleMode();

    // Cancel previous reminders first
    await cancelAll();

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminder',
      channelDescription: 'Reminds user to study daily',
      importance: Importance.max,
      priority: Priority.high,
    );

    const iOSDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iOSDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _notifications.zonedSchedule(
        0,
        "📚 Time to Study!",
        "Keep up your learning streak - let's practice now!",
        scheduled,
        details,
        androidScheduleMode: androidScheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
      return false;
    }
  }

  /// Check if exact alarm permission is granted (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    if (_isWeb) return false; // [TEMP] Not supported on web
    if (!Platform.isAndroid) return true;
    final androidPlugin = _androidPlugin();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  /// Open system settings to enable exact alarms
  static Future<void> openExactAlarmSettings() async {
    if (_isWeb) return; // [TEMP] Not supported on web
    if (!Platform.isAndroid) return;
    final androidPlugin = _androidPlugin();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  /// Schedule daily reminder at given time
  static Future<bool> scheduleDailyReminder(int hour, int minute) async {
    if (_isWeb) {
      debugPrint('[TEMP] Notifications: Scheduling skipped on web');
      return false; // [TEMP] Notifications not supported on web
    }
    final enabled = await _ensureAndroidNotificationPermission();
    if (!enabled) return false;

    // Check exact alarm permission for Android 12+
    if (Platform.isAndroid) {
      final canExact = await canScheduleExactAlarms();
      if (!canExact) {
        // Will use inexact scheduling as fallback
        debugPrint('Exact alarm permission not granted, using inexact scheduling');
      }
    }

    final androidScheduleMode = await _resolveAndroidScheduleMode();

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

    try {
      await _notifications.zonedSchedule(
        0,
        "📚 Time to Study!",
        "Keep up your learning streak - let's practice now!",
        scheduled,
        details,
        androidScheduleMode: androidScheduleMode,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily
      );
      debugPrint('✅ Notification scheduled successfully for ${hour}:${minute}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to schedule notification: $e');
      return false;
    }
  }

  /// Cancel all reminders
  static Future<void> cancelAll() async {
    if (_isWeb) return; // [TEMP] Not supported on web
    await _notifications.cancelAll();
  }
}
