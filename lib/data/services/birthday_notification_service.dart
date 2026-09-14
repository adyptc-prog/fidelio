import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/customer_record.dart';
import '../../domain/services/birthday_service.dart';

/// Schedules local, yearly-recurring notifications reminding the business
/// when a customer has a birthday. Best-effort: any platform/permission
/// failure is swallowed, since this is a UX nicety, not core app logic.
class BirthdayNotificationService {
  BirthdayNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'birthday_reminders';
  static const _channelName = 'Birthday reminders';
  static const _channelDescription =
      'Reminders when a customer has a birthday.';

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    try {
      tz_data.initializeTimeZones();
      try {
        final localTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      } on Object {
        // Fall back to whatever default location the timezone package uses.
      }

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.high,
            ),
          );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      _initialized = true;
    } on Object {
      // Notifications are best-effort; never block app startup on this.
    }
  }

  /// (Re)schedules a yearly-recurring reminder for every customer in
  /// [customers] that has a birthday set. Safe to call repeatedly (e.g. on
  /// every app start or whenever the customer list changes).
  Future<void> scheduleBirthdayReminders(List<CustomerRecord> customers) async {
    await _ensureInitialized();
    if (!_initialized) {
      return;
    }
    try {
      final now = DateTime.now();
      for (final customer in customers) {
        final month = customer.birthMonth;
        final day = customer.birthDay;
        if (month == null || day == null) {
          continue;
        }
        final id = _notificationId(customer.customerId);
        await _plugin.cancel(id: id);

        final occurrence = nextBirthdayOccurrence(
          month: month,
          day: day,
          from: now,
        );
        final scheduledDate = tz.TZDateTime.from(occurrence, tz.local);

        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: scheduledDate,
          title: "It's ${customer.displayName}'s birthday!",
          body: 'Open Fidelio to offer a birthday reward.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
    } on Object {
      // Best-effort: the in-app check on dashboard open still catches it.
    }
  }

  static int _notificationId(String customerId) {
    return customerId.hashCode & 0x7fffffff;
  }
}
