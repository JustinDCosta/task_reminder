import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones(); // Setup timezones

    // Android Settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/Mac Settings (Standard permissions)
    const DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await notificationsPlugin.initialize(settings);
  }

  Future<void> scheduleNotification(
      int id, String title, DateTime scheduledTime) async {
    
    // Convert time to TimeZone aware time
    final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    // Notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'task_channel', // Channel ID
      'Task Reminders', // Channel Name
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // Schedule it!
    await notificationsPlugin.zonedSchedule(
      id,
      'Task Reminder!',
      'Don\'t forget: $title',
      tzTime,
      details,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}