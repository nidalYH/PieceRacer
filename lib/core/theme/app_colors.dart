import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Neon Gaming Palette ──────────────────────────────────────────────────
  static const Color neonCyan    = Color(0xFF00E5FF);
  static const Color neonPurple  = Color(0xFFBF5AF2);
  static const Color neonGreen   = Color(0xFF30D158);
  static const Color neonOrange  = Color(0xFFFF9F0A);
  static const Color neonPink    = Color(0xFFFF375F);

  // ── Glow tints (pre-baked for BoxShadow) ────────────────────────────────
  static const Color glowCyan    = Color(0x5500E5FF);  // 33 %
  static const Color glowPurple  = Color(0x55BF5AF2);
  static const Color glowGreen   = Color(0x5530D158);
  static const Color glowOrange  = Color(0x55FF9F0A);
  static const Color glowPink    = Color(0x55FF375F);

  // ── Dark backgrounds ─────────────────────────────────────────────────────
  static const Color bgDark      = Color(0xFF080C1A);   // deeper navy
  static const Color bgDeep      = Color(0xFF050810);   // for orbs / vignette
  static const Color bgCard      = Color(0xFF111627);
  static const Color bgCardLight = Color(0xFF1A2240);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textWhite   = Color(0xFFF2F2F7);
  static const Color textGray    = Color(0xFF8E8E93);
  static const Color textMuted   = Color(0xFF515169);

  // ── Legacy compat ────────────────────────────────────────────────────────
  static const Color primary        = neonCyan;
  static const Color success        = neonGreen;
  static const Color danger         = neonPink;
  static const Color warning        = neonOrange;
  static const Color background     = bgDark;
  static const Color surface        = bgCard;
  static const Color textBase       = textWhite;
  static const Color textSecondary  = textGray;

  static const List<Color> puzzleTileColors = [
    Color(0xFF1C2340),
    Color(0xFF1E293B),
    Color(0xFF162032),
    Color(0xFF0F1629),
  ];
}
