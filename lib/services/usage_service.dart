import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'notification_service.dart';
import 'preferences_service.dart';
import '../pages/celebration_page.dart';

class UsageService {
  static const platform = MethodChannel('com.example.screen_time');

  static Future<Duration> getTodayUsage() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final result = await platform.invokeMethod('getUsageForPeriod', {
        'start': startOfDay,
        'end': now.millisecondsSinceEpoch,
      });
      return Duration(milliseconds: (result as num).toInt());
    } catch (e) {
      print('Lỗi lấy usage: $e');
      return Duration.zero;
    }
  }

  static Future<Duration> getUsageForDay(DateTime day) async {
    try {
      final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;
      final result = await platform.invokeMethod('getUsageForPeriod', {
        'start': start,
        'end': end,
      });
      return Duration(milliseconds: (result as num).toInt());
    } catch (e) {
      print('Lỗi lấy usage theo ngày: $e');
      return Duration.zero;
    }
  }

  static Future<void> openUsageSettings() async {
    try {
      await platform.invokeMethod('openUsageSettings');
    } catch (e) {
      print('Lỗi mở Usage Settings: $e');
    }
  }

  static Future<void> checkTargetAndNotify(Duration usage, double targetHours) async {
    final usedHours = usage.inMinutes / 60.0;
    final now = DateTime.now();
    final notifiedKey = 'notified_${now.toIso8601String().substring(0, 10)}';

    final notified = PreferencesService.prefs?.getBool(notifiedKey) ?? false;
    if (usedHours >= targetHours && !notified) {
      await NotificationService.showReachedNotification(targetHours);
      await PreferencesService.prefs?.setBool(notifiedKey, true);
    }
  }

  static Future<void> checkYesterdayAndUpdate(
    double targetHours,
    BuildContext context,
    ConfettiController? controller,
  ) async {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));

    final start = DateTime(yesterday.year, yesterday.month, yesterday.day).millisecondsSinceEpoch;
    final end = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59).millisecondsSinceEpoch;

    try {
      final result = await platform.invokeMethod('getUsageForPeriod', {'start': start, 'end': end});
      final hours = (result as num).toInt() / 1000 / 3600;

      final dateKey = "counted_${yesterday.year}-${yesterday.month}-${yesterday.day}";
      final alreadyCounted = PreferencesService.prefs?.getBool(dateKey) ?? false;

      if (!alreadyCounted) {
        if (hours <= targetHours) {
          PreferencesService.consecutiveDays++;
          if (PreferencesService.consecutiveDays % 3 == 0) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CelebrationPage(controller: controller!),
              ),
            );
            controller?.play();
          }
        } else {
          PreferencesService.consecutiveDays = 0;
        }

        await PreferencesService.prefs?.setBool(dateKey, true);
        await PreferencesService.saveConsecutiveDays();
      }
    } catch (e) {
      print('Lỗi checkYesterday: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getAppUsageList(DateTime start, DateTime end) async {
    try {
      final startMs = start.millisecondsSinceEpoch;
      final endMs = end.millisecondsSinceEpoch;
      final result = await platform.invokeMethod('getAppUsageList', {
        'start': startMs,
        'end': endMs,
      });
      return List<Map<String, dynamic>>.from(result as List);
    } catch (e) {
      print('Lỗi lấy danh sách app: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAppUsageForDay(DateTime day) async {
    try {
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59);
      final data = await getAppUsageList(start, end);
      // Chỉ thống kê app có thời gian >= 1 phút
      return data.where((e) {
        final usageMs = (e['usageTime'] as num?)?.toInt() ?? 0;
        return usageMs >= 60000;
      }).toList();
    } catch (e) {
      print('Lỗi lấy danh sách app theo ngày: $e');
      return [];
    }
  }
}
