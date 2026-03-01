import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/enums/puzzle_mode.dart';
import '../../core/enums/difficulty.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_system.dart';
import '../auth/auth_screen.dart';
import '../game/ai/ai_personality.dart';
import '../game/game_screen.dart';
import '../matchmaking/matchmaking_screen.dart';
import 'data/auth_repository.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  static const String routePath = '/lobby';
  static const String routeName = 'lobby';

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with SingleTickerProviderStateMixin {

  // Shimmer controller for the title
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0)
        .animate(CurvedAnimation(parent: _shimmerController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    if (mounted) context.goNamed(AuthScreen.routeName);
  }

  Future<void> _startVsAI() async {
    int gridSize = 3;
    Difficulty difficulty = Difficulty.normal;
    AIPersonality personality = AIPersonality.calm;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('⚙️ Configurar partida', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Tamaño: ${gridSize}x$gridSize',
                style: const TextStyle(color: AppColors.textGray)),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.neonCyan,
                thumbColor: AppColors.neonCyan,
                inactiveTrackColor: AppColors.bgCardLight,
                overlayColor: AppColors.neonCyan.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: gridSize.toDouble(), min: 3, max: 8, divisions: 5,
                onChanged: (v) => setDialogState(() => gridSize = v.toInt())),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Difficulty>(
              value: difficulty,
              dropdownColor: AppColors.bgCard,
              decoration: InputDecoration(
                labelText: 'Dificultad IA',
                labelStyle: const TextStyle(color: AppColors.textGray),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.textGray.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.neonCyan),
                ),
              ),
              items: Difficulty.values
                  .map((d) => DropdownMenuItem(value: d, child: Text(d.name.toUpperCase())))
                  .toList(),
              onChanged: (v) { if (v != null) setDialogState(() => difficulty = v); },
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textGray)),
            ),
            _GradientDialogButton(
              label: '¡Jugar!',
              onPressed: () => Navigator.pop(ctx, {
                'gridSize': gridSize, 'difficulty': difficulty, 'personality': personality,
              }),
            ),
          ],
        );
      }),
    );
    if (result == null || !mounted) return;
    context.goNamed(GameScreen.routeName, extra: {
      'roomId': 'ai_${DateTime.now().millisecondsSinceEpoch}',
      'mode': PuzzleMode.vsAI,
      'gridSize': result['gridSize'],
      'aiDifficulty': result['difficulty'],
      'aiPersonality': result['personality'],
    });
  }

  Future<void> _startLocal() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 90);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    int gridSize = 4;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('📸 Tamaño del puzzle', textAlign: TextAlign.center),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${gridSize}x$gridSize (${gridSize * gridSize} piezas)',
                style: const TextStyle(color: AppColors.textGray)),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.neonGreen,
                thumbColor: AppColors.neonGreen,
                inactiveTrackColor: AppColors.bgCardLight,
                overlayColor: AppColors.neonGreen.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: gridSize.toDouble(), min: 3, max: 8, divisions: 5,
                onChanged: (v) => setDialogState(() => gridSize = v.toInt())),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textGray)),
            ),
            _GradientDialogButton(
              label: '¡Armar!',
              gradient: const LinearGradient(
                colors: [AppColors.neonGreen, Color(0xFF059669)],
              ),
              onPressed: () => Navigator.pop(ctx, gridSize),
            ),
          ],
        );
      }),
    );
    if (result == null || !mounted) return;
    context.goNamed(GameScreen.routeName, extra: {
      'roomId': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'mode': PuzzleMode.local,
      'gridSize': result,
      'galleryImageBytes': bytes,
    });
  }

  void _startOnlineMode(PuzzleMode mode) {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Inicia sesión con Google para jugar online'),
        backgroundColor: AppColors.neonPink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
      return;
    }
    context.goNamed(MatchmakingScreen.routeName, extra: {'mode': mode});
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final String greeting = user?.displayName ?? 'Jugador';

    return Scaffold(
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.background),
          ),

          // ── Decorative orbs ─────────────────────────────────────────────
          Positioned(
            top: -60, right: -80,
            child: _Orb(color: AppColors.neonCyan, size: 280, opacity: 0.11),
          ),
          Positioned(
            bottom: -120, left: -60,
            child: _Orb(color: AppColors.neonPurple, size: 300, opacity: 0.09),
          ),

          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 12),

                // ── Top bar ──────────────────────────────────────────────
                Row(children: [
                  // Avatar with neon ring
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.neonCyan, AppColors.neonPurple],
                      ),
                      boxShadow: AppShadows.shadowNeon(AppColors.neonCyan, radius: 10),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.bgCard,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null
                          ? const Icon(Icons.person, color: AppColors.neonCyan, size: 22)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hola, $greeting 👋', style: context.textTheme.titleMedium),
                      Text('¿Listo para competir?', style: context.textTheme.bodySmall),
                    ]),
                  ),
                  // Sign out button
                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgCardLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.textGray.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppColors.textGray, size: 20),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Shimmer title ────────────────────────────────────────
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (_, __) => ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
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
                      '🧩  PieceRacer',
                      textAlign: TextAlign.center,
                      style: context.textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Mode cards ───────────────────────────────────────────
                Expanded(
                  child: ListView(children: [
                    _ModeCard(
                      icon: Icons.smart_toy_outlined,
                      title: '1 vs IA',
                      subtitle: 'Compite contra la máquina',
                      gradient: [AppColors.neonPurple, const Color(0xFF6C3AED)],
                      onTap: _startVsAI,
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: Icons.photo_library_outlined,
                      title: 'Local',
                      subtitle: 'Tu foto → tu puzzle',
                      gradient: [AppColors.neonGreen, const Color(0xFF059669)],
                      onTap: _startLocal,
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: Icons.flash_on,
                      title: '1 vs 1',
                      subtitle: 'Rival online en tiempo real',
                      gradient: [AppColors.neonOrange, const Color(0xFFDC2626)],
                      onTap: () => _startOnlineMode(PuzzleMode.oneVsOne),
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: Icons.groups_outlined,
                      title: '2 vs 2',
                      subtitle: 'Armen el puzzle en equipo',
                      gradient: [AppColors.neonCyan, const Color(0xFF2563EB)],
                      onTap: () => _startOnlineMode(PuzzleMode.twoVsTwo),
                    ),
                    const SizedBox(height: 12),
                    _ModeCard(
                      icon: Icons.celebration_outlined,
                      title: 'Amigos',
                      subtitle: '3-4 jugadores, primero gana',
                      gradient: [AppColors.neonPink, const Color(0xFFBE185D)],
                      onTap: () => _startOnlineMode(PuzzleMode.friends),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mode card with press animation ─────────────────────────────────────────

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _arrowSlide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _arrowSlide = Tween<double>(begin: 0.0, end: 5.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _ctrl.forward();
    HapticFeedback.selectionClick();
  }

  void _onTapUp(TapUpDetails _) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final accent = widget.gradient[0];

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.gradient[0].withValues(alpha: 0.22),
                widget.gradient[1].withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(children: [
            // Icon badge
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.gradient,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    )),
                const SizedBox(height: 3),
                Text(widget.subtitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppColors.textGray,
                    )),
              ]),
            ),
            // Animated chevron
            AnimatedBuilder(
              animation: _arrowSlide,
              builder: (_, chev) => Transform.translate(
                offset: Offset(_arrowSlide.value, 0),
                child: chev,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  color: accent.withValues(alpha: 0.70), size: 16),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Gradient dialog button ─────────────────────────────────────────────────

class _GradientDialogButton extends StatelessWidget {
  const _GradientDialogButton({
    required this.label,
    required this.onPressed,
    this.gradient,
  });

  final String label;
  final VoidCallback onPressed;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient ?? AppGradients.primaryButton,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppShadows.shadowNeon(AppColors.neonCyan, radius: 12),
        ),
        child: Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            )),
      ),
    );
  }
}

// ── Background orb ────────────────────────────────────────────────────────

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size, height: size,
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
