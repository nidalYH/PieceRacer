import 'package:flutter/material.dart';

import 'app_colors.dart';

export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_typography.dart';

extension DesignSystemContext on BuildContext {
  ThemeData get theme      => Theme.of(this);
  TextTheme  get textTheme => theme.textTheme;
  ColorScheme get colors   => theme.colorScheme;
}

// ── Shadows ──────────────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.6),
      blurRadius: 32,
      offset: const Offset(0, 10),
    ),
  ];

  // Neon glow for buttons / icon badges
  static List<BoxShadow> shadowNeon(Color color, {double radius = 20, double spread = 0}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.55),
      blurRadius: radius,
      spreadRadius: spread,
      offset: Offset.zero,
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.25),
      blurRadius: radius * 2.5,
      spreadRadius: -2,
      offset: const Offset(0, 4),
    ),
  ];
}

// ── Gradients ─────────────────────────────────────────────────────────────────

class AppGradients {
  AppGradients._();

  /// Main screen background — deep navy with faint blue tinge
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A0F20), AppColors.bgDark, Color(0xFF060910)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Primary CTA button — cyan → purple
  static const LinearGradient primaryButton = LinearGradient(
    colors: [AppColors.neonCyan, Color(0xFF7B61FF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Secondary / accent — purple → pink
  static const LinearGradient accentButton = LinearGradient(
    colors: [AppColors.neonPurple, AppColors.neonPink],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Title shimmer sweep
  static const LinearGradient titleShimmer = LinearGradient(
    colors: [AppColors.neonCyan, AppColors.neonPurple, AppColors.neonCyan],
  );
}
