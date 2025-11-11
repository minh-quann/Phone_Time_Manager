import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý thời gian',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.green,
          secondary: Colors.teal,
          surface: Color(0xFF1E1E1E),
          surfaceContainerHighest: Color(0xFF2D2D2D),
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white70,
        ),
        scaffoldBackgroundColor: Colors.black,
        cardTheme: CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2D2D2D),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
