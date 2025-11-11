import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static SharedPreferences? prefs;
  static double targetHours = 6.87; // 6 giờ 52 phút
  static int consecutiveDays = 0;

  static Future<void> loadPrefs() async {
    prefs = await SharedPreferences.getInstance();
    targetHours = prefs?.getDouble('targetHours') ?? 6.87; // 6 giờ 52 phút
    consecutiveDays = prefs?.getInt('consecutiveDays') ?? 0;
  }

  static Future<void> saveTargetHours(double value) async {
    targetHours = value;
    await prefs?.setDouble('targetHours', value);
  }

  static Future<void> saveConsecutiveDays() async {
    await prefs?.setInt('consecutiveDays', consecutiveDays);
  }
}
