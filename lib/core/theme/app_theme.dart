import 'package:flutter/material.dart';

/// Colors copied from the Grid web page.
class GridColors {
  const GridColors._();

  static const screen = Color(0xFF0B0E17);
  static const panel = Color(0xFF151A28);
  static const line = Color(0xFF232A3D);
  static const text = Color(0xFFEEF1F8);
  static const soft = Color(0xFF9AA3B8);
  static const accent = Color(0xFF6A5CFF);
  static const accent2 = Color(0xFF1FD1C1);
  static const warn = Color(0xFFFFB454);
  static const bad = Color(0xFFFF6B7A);
  static const page = Color(0xFF05070C);
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: GridColors.screen,
    colorScheme: base.colorScheme.copyWith(
      primary: GridColors.accent,
      secondary: GridColors.accent2,
      surface: GridColors.panel,
      error: GridColors.bad,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: GridColors.text,
      displayColor: GridColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GridColors.screen,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GridColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GridColors.line),
      ),
    ),
  );
}
