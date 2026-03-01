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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const _VsAIConfigDialog(),
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
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => _LocalConfigDialog(initialGridSize: gridSize),
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

// ═══════════════════════════════════════════════════════════════════════════
// ── VS AI Config Dialog ──────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _VsAIConfigDialog extends StatefulWidget {
  const _VsAIConfigDialog();

  @override
  State<_VsAIConfigDialog> createState() => _VsAIConfigDialogState();
}

class _VsAIConfigDialogState extends State<_VsAIConfigDialog>
    with SingleTickerProviderStateMixin {
  int _gridSize = 3;
  Difficulty _difficulty = Difficulty.normal;
  final AIPersonality _personality = AIPersonality.calm;

  // Pulsing glow on the play button
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF151D35),
              const Color(0xFF0C1220),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.neonCyan.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: AppColors.neonCyan.withValues(alpha: 0.08),
              blurRadius: 60,
              offset: Offset.zero,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.neonPurple, Color(0xFF6C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.shadowNeon(AppColors.neonPurple, radius: 10),
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    'Configurar partida',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text('vs. Inteligencia Artificial',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
                ]),
              ]),

              const SizedBox(height: 28),
              _sectionLabel('Tamaño del tablero'),
              const SizedBox(height: 10),

              // ── Grid size chip picker ───────────────────────────────────
              _GridSizePicker(
                selected: _gridSize,
                onChanged: (v) => setState(() => _gridSize = v),
              ),

              // Hint text
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '${_gridSize}x$_gridSize · ${_gridSize * _gridSize} piezas · ${_difficultyHint(_gridSize)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _sectionLabel('Dificultad IA'),
              const SizedBox(height: 10),

              // ── Difficulty chip selector ────────────────────────────────
              _DifficultyPicker(
                selected: _difficulty,
                onChanged: (v) => setState(() => _difficulty = v),
              ),

              const SizedBox(height: 32),

              // ── Action buttons ──────────────────────────────────────────
              Row(children: [
                // Ghost cancel
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.textGray.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          )),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Pulsing play button
                Expanded(
                  flex: 2,
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, child) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonCyan.withValues(alpha: 0.55 * _glowAnim.value),
                            blurRadius: 24,
                            spreadRadius: -2,
                          ),
                          BoxShadow(
                            color: AppColors.neonPurple.withValues(alpha: 0.30 * _glowAnim.value),
                            blurRadius: 40,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, {
                        'gridSize': _gridSize,
                        'difficulty': _difficulty,
                        'personality': _personality,
                      }),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primaryButton,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 6),
                            Text('¡Jugar!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: 0.3,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.textGray,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );

  String _difficultyHint(int size) {
    if (size <= 3) return 'Principiante';
    if (size <= 5) return 'Intermedio';
    return 'Experto';
  }
}

// ── Grid size chip row ────────────────────────────────────────────────────

class _GridSizePicker extends StatelessWidget {
  const _GridSizePicker({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [3, 4, 5, 6, 7, 8].map((size) {
        final isActive = size == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(size);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: isActive
                  ? AppGradients.primaryButton
                  : null,
              color: isActive ? null : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppColors.neonCyan.withValues(alpha: 0.7)
                    : AppColors.textMuted.withValues(alpha: 0.3),
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive
                  ? AppShadows.shadowNeon(AppColors.neonCyan, radius: 12)
                  : [],
            ),
            alignment: Alignment.center,
            child: Text(
              '${size}x$size',
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textGray,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Difficulty chip selector ──────────────────────────────────────────────

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected, required this.onChanged});

  final Difficulty selected;
  final ValueChanged<Difficulty> onChanged;

  static const _config = <Difficulty, (String, String, Color)>{
    Difficulty.easy:   ('⚪', 'FÁCIL',   Color(0xFF4ADE80)),
    Difficulty.normal: ('🟡', 'NORMAL',  Color(0xFFFBBF24)),
    Difficulty.hard:   ('🔴', 'DIFÍCIL', Color(0xFFF87171)),
    Difficulty.expert: ('💀', 'EXPERTO', Color(0xFFBF5AF2)),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _config.entries.map((entry) {
        final d = entry.key;
        final (emoji, label, color) = entry.value;
        final isActive = d == selected;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(d);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 70,
            height: 68,
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.18)
                  : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive
                    ? color.withValues(alpha: 0.65)
                    : AppColors.textMuted.withValues(alpha: 0.25),
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive
                  ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 12)]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isActive ? color : AppColors.textGray,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Local Config Dialog ──────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _LocalConfigDialog extends StatefulWidget {
  const _LocalConfigDialog({this.initialGridSize = 4});
  final int initialGridSize;

  @override
  State<_LocalConfigDialog> createState() => _LocalConfigDialogState();
}

class _LocalConfigDialogState extends State<_LocalConfigDialog>
    with SingleTickerProviderStateMixin {
  late int _gridSize;

  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _gridSize = widget.initialGridSize;
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E1D2A), Color(0xFF0A1318)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.neonGreen.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 40, offset: const Offset(0, 16)),
            BoxShadow(color: AppColors.neonGreen.withValues(alpha: 0.07), blurRadius: 60),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.neonGreen, Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.shadowNeon(AppColors.neonGreen, radius: 10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tamaño del puzzle',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('Tu foto, tus reglas',
                      style: TextStyle(color: AppColors.textGray, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ]),

              const SizedBox(height: 28),
              const Text('TABLERO', style: TextStyle(
                color: AppColors.textGray, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 1.2,
              )),
              const SizedBox(height: 10),

              _GridSizePicker(
                selected: _gridSize,
                onChanged: (v) => setState(() => _gridSize = v),
              ),

              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '$_gridSize×$_gridSize · ${_gridSize * _gridSize} piezas',
                    style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.textGray.withValues(alpha: 0.25)),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, child) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonGreen.withValues(alpha: 0.55 * _glowAnim.value),
                            blurRadius: 24,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, _gridSize),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.neonGreen, Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text('¡Armar!',
                                style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w800,
                                  fontSize: 17, letterSpacing: 0.3,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
