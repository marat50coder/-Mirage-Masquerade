import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local-only daily reminder for the in-game "Bonus reminders" toggle.
/// No FCM / remote pushes.
class Reminders {
  Reminders._();
  static final Reminders instance = Reminders._();

  static const _id = 71;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> prepare() async {
    if (_ready) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<bool> setEnabled(bool enabled) async {
    await prepare();
    if (!enabled) {
      await _plugin.cancel(_id);
      return false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
    if (!granted) {
      await _plugin.cancel(_id);
      return false;
    }
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.cancel(_id);
    await _plugin.periodicallyShow(
      _id,
      'Mirage Masquerade',
      'New daily tasks are waiting behind the curtain.',
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }
}
