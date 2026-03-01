import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/design_system.dart';
import '../lobby/data/auth_repository.dart';
import '../lobby/lobby_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  static const String routePath = '/auth';
  static const String routeName = 'auth';

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;

  // Logo pulse
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Title shimmer
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  // Google button press
  late final AnimationController _btnController;
  late final Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0)
        .animate(CurvedAnimation(parent: _shimmerController, curve: Curves.linear));

    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _btnScale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _btnController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _btnController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user != null && mounted) context.goNamed(LobbyScreen.routeName);
      else if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _skipToOffline() => context.goNamed(LobbyScreen.routeName);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background ────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.background),
          ),

          // ── Decorative orbs ──────────────────────────────────────────────
          Positioned(
            top: -80, right: -60,
            child: _Orb(color: AppColors.neonCyan, size: 300, opacity: 0.12),
          ),
          Positioned(
            bottom: -100, left: -80,
            child: _Orb(color: AppColors.neonPurple, size: 320, opacity: 0.10),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.45,
            right: -40,
            child: _Orb(color: AppColors.neonPink, size: 160, opacity: 0.07),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(children: [
                const Spacer(flex: 3),

                // Glow ring + logo
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.shadowNeon(AppColors.neonCyan, radius: 40, spread: 6),
                        gradient: RadialGradient(
                          colors: [
                            AppColors.neonCyan.withValues(alpha: 0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Logo pulse
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: const Text('🧩', style: TextStyle(fontSize: 72)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Shimmer title
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (_, __) {
                    return ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: const [
                          AppColors.neonCyan,
                          Colors.white,
                          AppColors.neonPurple,
                          AppColors.neonCyan,
                        ],
                        stops: [
                          (_shimmerAnimation.value - 0.6).clamp(0.0, 1.0),
                          (_shimmerAnimation.value - 0.1).clamp(0.0, 1.0),
                          (_shimmerAnimation.value + 0.1).clamp(0.0, 1.0),
                          (_shimmerAnimation.value + 0.6).clamp(0.0, 1.0),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'PieceRacer',
                        style: context.textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),

                Text(
                  'ROMPECABEZAS COMPETITIVO',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: AppColors.neonCyan.withValues(alpha: 0.65),
                    letterSpacing: 3.5,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),

                const Spacer(flex: 3),

                // Error banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.neonPink.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.35)),
                      boxShadow: AppShadows.shadowNeon(AppColors.neonPink, radius: 12),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.neonPink, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Google Sign-In button
                GestureDetector(
                  onTapDown: _isLoading ? null : (_) => _btnController.forward(),
                  onTapUp: _isLoading ? null : (_) => _btnController.reverse(),
                  onTapCancel: () => _btnController.reverse(),
                  onTap: _isLoading ? null : _signInWithGoogle,
                  child: AnimatedBuilder(
                    animation: _btnScale,
                    builder: (_, child) => Transform.scale(
                      scale: _btnScale.value,
                      child: child,
                    ),
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.neonCyan, Color(0xFF7B61FF)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: AppShadows.shadowNeon(AppColors.neonCyan, radius: 24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          else ...[
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text('G', style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white,
                              )),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Iniciar con Google',
                              style: context.textTheme.titleMedium?.copyWith(
                                color: Colors.white, fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Skip button
                GestureDetector(
                  onTap: _isLoading ? null : _skipToOffline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.20)),
                    ),
                    child: Text(
                      'Jugar sin cuenta',
                      style: TextStyle(
                        color: AppColors.neonCyan.withValues(alpha: 0.75),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decorative blurred orb ───────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
