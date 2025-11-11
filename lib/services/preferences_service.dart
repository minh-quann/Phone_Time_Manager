import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static SharedPreferences? prefs;
  static double targetHours = 6.87; // 6 giờ 52 phút
  static int consecutiveDays = 0;
  static String themeMode = 'system'; // 'system' | 'light' | 'dark'

  static Future<void> loadPrefs() async {
    prefs = await SharedPreferences.getInstance();
    targetHours = prefs?.getDouble('targetHours') ?? 6.87; // 6 giờ 52 phút
    consecutiveDays = prefs?.getInt('consecutiveDays') ?? 0;
    themeMode = prefs?.getString('themeMode') ?? 'system';
  }

  static Future<void> saveTargetHours(double value) async {
    targetHours = value;
    await prefs?.setDouble('targetHours', value);
  }

  static Future<void> saveConsecutiveDays() async {
    await prefs?.setInt('consecutiveDays', consecutiveDays);
  }

  static Future<void> saveThemeMode(String mode) async {
    // Accepted values: 'system', 'light', 'dark'
    themeMode = mode;
    await prefs?.setString('themeMode', mode);
  }
}
