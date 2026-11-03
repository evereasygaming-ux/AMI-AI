import 'package:flutter/material.dart';

class AmiColors {
  static const bg = Color(0xFF05070E);
  static const bgAlt = Color(0xFF0A1020);
  static const panel = Color(0xFF0D1526);
  static const panelSoft = Color(0xFF121C31);
  static const cyan = Color(0xFF35E6FF);
  static const violet = Color(0xFF8B5CFF);
  static const pink = Color(0xFFFF5C8A);
  static const mint = Color(0xFF4DFFC3);
  static const text = Color(0xFFEAF3FF);
  static const muted = Color(0xFF8FA3C0);
  static const line = Color(0xFF1D2942);
}

ThemeData buildAmiTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AmiColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AmiColors.cyan,
      secondary: AmiColors.violet,
      tertiary: AmiColors.pink,
      surface: AmiColors.panel,
      onSurface: AmiColors.text,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AmiColors.text,
      displayColor: Colors.white,
    ),
    splashColor: AmiColors.cyan.withValues(alpha: .08),
    highlightColor: AmiColors.cyan.withValues(alpha: .04),
    dividerTheme: const DividerThemeData(color: AmiColors.line, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AmiColors.panel,
      hintStyle: const TextStyle(color: AmiColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AmiColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AmiColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AmiColors.cyan.withValues(alpha: .6)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AmiColors.panelSoft,
      contentTextStyle: const TextStyle(color: AmiColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

BoxDecoration glassPanel({Color? color, double radius = 22}) => BoxDecoration(
      color: color ?? AmiColors.panel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: .06)),
    );
