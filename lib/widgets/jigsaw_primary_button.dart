import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/design_system.dart';

/// Primary CTA button with gradient fill, neon glow, and press-scale animation.
class JigsawPrimaryButton extends StatefulWidget {
  const JigsawPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient,
    this.glowColor,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Override gradient (defaults to cyan → purple CTA)
  final Gradient? gradient;

  /// Override glow color (defaults to neonCyan)
  final Color? glowColor;

  @override
  State<JigsawPrimaryButton> createState() => _JigsawPrimaryButtonState();
}

class _JigsawPrimaryButtonState extends State<JigsawPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _glowOpacity = Tween<double>(begin: 1.0, end: 0.35)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.isLoading || widget.onPressed == null) return;
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? AppGradients.primaryButton;
    final glowColor = widget.glowColor ?? AppColors.neonCyan;
    final isDisabled = widget.isLoading || widget.onPressed == null;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Transform.scale(
          scale: _scale.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: isDisabled ? null : widget.onPressed,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: isDisabled
                    ? LinearGradient(
                        colors: [
                          AppColors.textMuted,
                          AppColors.textMuted.withValues(alpha: 0.7),
                        ],
                      )
                    : gradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                boxShadow: isDisabled
                    ? []
                    : [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.55 * _glowOpacity.value),
                          blurRadius: 24,
                          spreadRadius: -2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.20 * _glowOpacity.value),
                          blurRadius: 48,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: widget.isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, size: 24, color: Colors.white),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
