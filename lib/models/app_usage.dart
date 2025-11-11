import 'package:flutter/material.dart';

class CategoryUsage {
  final String name;
  final Duration duration;
  final Color color;

  CategoryUsage({
    required this.name,
    required this.duration,
    required this.color,
  });
}

class AppUsage {
  final String name;
  final String packageName;
  final Duration duration;
  final IconData icon;
  final Color iconColor;

  AppUsage({
    required this.name,
    required this.packageName,
    required this.duration,
    required this.icon,
    required this.iconColor,
  });
}

