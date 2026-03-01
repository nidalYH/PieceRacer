import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/design_system.dart';

/// A dark-tinted frosted-glass card with optional neon glow border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppSpacing.radiusXl,
    this.sigma = 10.0,
    this.glowColor,
    super.key,
  });

  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double sigma;

  /// Optional neon accent glow applied to the card border shadow.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final glow = glowColor;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            // Dark tinted glass — correct for a dark gaming UI
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.bgCardLight.withValues(alpha: 0.75),
                AppColors.bgCard.withValues(alpha: 0.60),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              ...AppShadows.shadowMd,
              if (glow != null) ...AppShadows.shadowNeon(glow, radius: 18),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
