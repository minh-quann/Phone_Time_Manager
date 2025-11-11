import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.loadPrefs();
  final initialModeString = PreferencesService.themeMode;
  final initialMode = _mapStringToThemeMode(initialModeString);
  runApp(MyApp(initialMode: initialMode));
}

ThemeMode _mapStringToThemeMode(String v) {
  switch (v) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String _mapThemeModeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

class MyApp extends StatefulWidget {
  final ThemeMode initialMode;
  const MyApp({super.key, required this.initialMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialMode;
  }

  ThemeData _buildLightTheme() {
    const primary = Color(0xFF16A34A);
    const secondary = Color(0xFF0EA5E9);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: const Color(0xFFF7F7F7),
      ),
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const surface = Color(0xFF0F1115);
    const container = Color(0xFF1A1D24);
    const primary = Color(0xFF22C55E);
    const secondary = Color(0xFF06B6D4);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        surfaceContainerHighest: container,
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
      ),
      scaffoldBackgroundColor: surface,
      cardTheme: const CardThemeData(
        color: container,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
    );
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await PreferencesService.saveThemeMode(_mapThemeModeToString(mode));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý thời gian',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: HomePage(
        onChangeThemeMode: _setThemeMode,
        currentThemeMode: _themeMode,
      ),
    );
  }
}
