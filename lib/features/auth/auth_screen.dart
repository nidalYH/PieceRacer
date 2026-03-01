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

class _AuthScreenState extends ConsumerState<AuthScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (user != null && mounted) context.goNamed(LobbyScreen.routeName);
      else if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  void _skipToOffline() => context.goNamed(LobbyScreen.routeName);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bgDark,
              const Color(0xFF0D1B2A),
              AppColors.bgDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(children: [
              const Spacer(flex: 3),
              // Animated logo
              ScaleTransition(
                scale: _pulseAnimation,
                child: const Text('🧩', style: TextStyle(fontSize: 80)),
              ),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.neonCyan, AppColors.neonPurple],
                ).createShader(bounds),
                child: Text('PieceRacer',
                  style: context.textTheme.displayLarge?.copyWith(color: Colors.white, fontSize: 36)),
              ),
              const SizedBox(height: 8),
              Text('Rompecabezas competitivo',
                style: context.textTheme.bodyMedium?.copyWith(color: AppColors.textGray, letterSpacing: 1)),
              const Spacer(flex: 3),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.neonPink.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neonPink.withOpacity(0.3)),
                  ),
                  child: Text(_errorMessage!, textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.neonPink, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // Google Sign-In
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.neonCyan, AppColors.neonPurple]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: AppColors.neonCyan.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    label: Text(_isLoading ? 'Conectando...' : 'Iniciar con Google',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : _skipToOffline,
                child: Text('Jugar sin cuenta',
                  style: TextStyle(color: AppColors.textGray, fontSize: 14)),
              ),
              const Spacer(),
            ]),
          ),
        ),
      ),
    );
  }
}
