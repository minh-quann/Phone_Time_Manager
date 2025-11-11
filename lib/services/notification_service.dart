import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);
  }

  static Future<void> showReachedNotification(double targetHours) async {
    const androidDetails = AndroidNotificationDetails(
      'target_channel',
      'Target reached',
      channelDescription: 'Thông báo khi đạt mục tiêu',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      0,
      'Mục tiêu đạt',
      'Bạn đã sử dụng ${targetHours.toStringAsFixed(1)} giờ hôm nay.',
      details,
    );
  }
}
