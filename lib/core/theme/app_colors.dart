import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Neon Gaming Palette
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonPurple = Color(0xFFBF5AF2);
  static const Color neonGreen = Color(0xFF30D158);
  static const Color neonOrange = Color(0xFFFF9F0A);
  static const Color neonPink = Color(0xFFFF375F);
  
  // Dark backgrounds
  static const Color bgDark = Color(0xFF0A0E21);
  static const Color bgCard = Color(0xFF141A2E);
  static const Color bgCardLight = Color(0xFF1C2340);
  
  // Text
  static const Color textWhite = Color(0xFFF2F2F7);
  static const Color textGray = Color(0xFF8E8E93);
  
  // Legacy compat
  static const Color primary = neonCyan;
  static const Color success = neonGreen;
  static const Color danger = neonPink;
  static const Color warning = neonOrange;
  static const Color background = bgDark;
  static const Color surface = bgCard;
  static const Color textBase = textWhite;
  static const Color textSecondary = textGray;

  static const List<Color> puzzleTileColors = [
    Color(0xFF1C2340),
    Color(0xFF1E293B),
    Color(0xFF162032),
    Color(0xFF0F1629),
  ];
}
