import 'package:flutter/material.dart';
import '../core/theme/design_system.dart';

class BadgeRank extends StatelessWidget {
  const BadgeRank({
    required this.rank,
    required this.icon,
    this.glowColor,
    super.key,
  });

  final String rank;
  final String icon;

  /// Optional neon accent — drives border + shadow color.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final accent = glowColor ?? AppColors.neonCyan;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            AppColors.bgCard,
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.20),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            rank,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textWhite,
            ),
          ),
        ],
      ),
    );
  }
}
