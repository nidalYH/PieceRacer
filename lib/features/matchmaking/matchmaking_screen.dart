import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../game/data/room_repository.dart';
import '../lobby/data/auth_repository.dart';

import '../../core/theme/design_system.dart';
import '../../core/enums/puzzle_mode.dart';
import '../../core/enums/difficulty.dart';
import '../game/ai/ai_personality.dart';
import '../../core/utils/time_utils.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/glass_card.dart';
import '../game/game_screen.dart';
import '../lobby/lobby_screen.dart';

class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({required this.mode, super.key});

  static const String routePath = '/matchmaking';
  static const String routeName = 'matchmaking';

  final PuzzleMode mode;

  @override
  ConsumerState<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  
  // Configuration State
  bool _isConfiguring = true;
  double _gridSize = 3;
  Difficulty _aiDifficulty = Difficulty.normal;
  AIPersonality _aiPersonality = AIPersonality.calm;

  // Matchmaking State
  Timer? _timer;
  int _elapsedSeconds = 0;
  User? _currentUser;
  DocumentReference<Map<String, dynamic>>? _currentRoomRef;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _roomSubscription;
  bool _navigatedToGame = false;
  bool _isCancelling = false;
  String _statusMessage = 'Buscando rival...';

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  final List<String> _tips = [
    '💡 Mueve las piezas con un solo dedo',
    '💡 Resuelve las esquinas primero',
    '💡 Fíjate en los colores de las piezas',
  ];
  int _currentTipIndex = 0;
  Timer? _tipTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.8, end: 1.0).animate(_pulseController);
  }

  void _beginSearch() {
    setState(() {
      _isConfiguring = false;
    });
    _startTimer();
    _startMatchmaking();
    _startTipRotation();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds += 1;
        });
      }
    });
  }

  void _startTipRotation() {
    _tipTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _tips.length;
        });
      }
    });
  }

  Future<void> _startMatchmaking() async {
    try {
      final authRepo = ref.read(authRepositoryProvider);
      User? user = authRepo.currentUser;
      user ??= await authRepo.signInAnonymously();
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo autenticar al usuario.'),
            backgroundColor: context.colors.error,
          ),
        );
        return;
      }
      _currentUser = user;
      await ensureUserProfile(user);

      String? imageUrl;

      // Handle custom image uploads for multiplayer mode
      if (widget.mode == PuzzleMode.friends) {
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Elige una imagen de tu galería...';
        });
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
        
        if (image == null) {
          // User cancelled image selection, return to lobby
          if (mounted) context.goNamed(LobbyScreen.routeName);
          return;
        }

        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Subiendo imagen...'), backgroundColor: context.colors.primary),
            );
            setState(() {
              _statusMessage = 'Subiendo imagen...';
            });
        }

        final roomRepo = ref.read(roomRepositoryProvider);
        imageUrl = await roomRepo.uploadCustomImage(image);
        
        if (mounted) {
          setState(() {
            _statusMessage = 'Buscando rival...';
          });
        }
      }

      final roomRepo = ref.read(roomRepositoryProvider);

      // Best-effort cleanup of stale rooms
      try { await roomRepo.cleanupStaleRooms(); } catch (_) {}

      final DocumentReference<Map<String, dynamic>> roomRef = await roomRepo.findOrCreateRoom(
        uid: user.uid,
        mode: widget.mode,
        gridSize: _gridSize.toInt(),
        customImageUrl: imageUrl,
      );

      _currentRoomRef = roomRef;
      _listenToRoomChanges(roomRef);
      
      // If it's vs AI, we can just artificially "start" immediately
      if (widget.mode == PuzzleMode.vsAI) {
        await roomRef.update({'status': 'started'});
      }
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al unirse: $e. Reintentando...'),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  void _listenToRoomChanges(
    DocumentReference<Map<String, dynamic>> roomRef,
  ) {
    _roomSubscription?.cancel();
    _roomSubscription = roomRef.snapshots().listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic>? data = snapshot.data();
        if (data == null) return;

        final String status = data['status'] as String? ?? '';
        if (status == 'started' && !_navigatedToGame) {
          _navigateToGame(roomRef.id);
          return;
        }

        // Show player count for multi-player rooms
        if (status == 'waiting' && mounted) {
          final players = data['players'] as List<dynamic>? ?? [];
          final maxPlayers = data['maxPlayers'] as int? ?? 2;
          setState(() {
            _statusMessage = 'Jugadores ${players.length}/$maxPlayers — esperando...';
          });
        }
      },
    );
  }

  void _navigateToGame(String roomId) {
    _navigatedToGame = true;
    _timer?.cancel();
    _roomSubscription?.cancel();
    if (!mounted) return;
    context.goNamed(
      GameScreen.routeName,
      extra: {
        'roomId': roomId, 
        'mode': widget.mode,
        'gridSize': _gridSize.toInt(),
        'aiDifficulty': _aiDifficulty,
        'aiPersonality': _aiPersonality,
      },
    );
  }

  Future<void> _cancelCurrentRoom() async {
    _timer?.cancel();
    final DocumentReference<Map<String, dynamic>>? roomRef = _currentRoomRef;
    final User? user = _currentUser;
    if (roomRef == null || user == null) {
      return;
    }
    try {
      await ref.read(roomRepositoryProvider).cancelRoomSearch(roomRef.id, user.uid);
    } catch (e) {
      debugPrint('Error cancelling room: $e');
    }
  }

  Future<void> _onCancelPressed() async {
    _isCancelling = true;
    await _cancelCurrentRoom();
    if (!mounted) return;
    context.goNamed(LobbyScreen.routeName);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tipTimer?.cancel();
    _pulseController.dispose();
    _roomSubscription?.cancel();
    if (!_navigatedToGame && !_isCancelling) {
      _cancelCurrentRoom();
    }
    super.dispose();
  }

  /// Returns the accent colour for the current mode (matches lobby card colours)
  Color get _modeAccent {
    switch (widget.mode) {
      case PuzzleMode.oneVsOne: return AppColors.neonOrange;
      case PuzzleMode.twoVsTwo: return AppColors.neonCyan;
      case PuzzleMode.friends:  return AppColors.neonPink;
      default:                  return AppColors.neonCyan;
    }
  }

  IconData get _modeIcon {
    switch (widget.mode) {
      case PuzzleMode.oneVsOne: return Icons.flash_on;
      case PuzzleMode.twoVsTwo: return Icons.groups_outlined;
      case PuzzleMode.friends:  return Icons.celebration_outlined;
      default:                  return Icons.gamepad_outlined;
    }
  }

  String get _modeLabel {
    switch (widget.mode) {
      case PuzzleMode.oneVsOne: return '1 vs 1';
      case PuzzleMode.twoVsTwo: return '2 vs 2';
      case PuzzleMode.friends:  return 'Amigos';
      default:                  return widget.mode.displayName;
    }
  }

  String get _modeSubtitle {
    switch (widget.mode) {
      case PuzzleMode.oneVsOne: return 'Rival online en tiempo real';
      case PuzzleMode.twoVsTwo: return 'Armen el puzzle en equipo';
      case PuzzleMode.friends:  return '3-4 jugadores, primero gana';
      default:                  return '';
    }
  }

  Widget _buildConfigScreen() {
    final accent = _modeAccent;

    return Stack(
      children: [
        // Orbs
        Positioned(
          top: -60, right: -80,
          child: _ScreenOrb(color: accent, size: 280, opacity: 0.12),
        ),
        Positioned(
          bottom: -100, left: -60,
          child: _ScreenOrb(color: AppColors.neonPurple, size: 260, opacity: 0.09),
        ),

        // Content
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // ── Mode header ─────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.shadowNeon(accent, radius: 14),
                ),
                child: Icon(_modeIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_modeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    )),
                Text(_modeSubtitle,
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    )),
              ]),
              const Spacer(),
              // Ghost back button
              GestureDetector(
                onTap: () => context.goNamed(LobbyScreen.routeName),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.textGray.withValues(alpha: 0.20)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textGray, size: 18),
                ),
              ),
            ]),

            const SizedBox(height: 28),

            // ── Config card ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [const Color(0xFF141C30), const Color(0xFF0C111F)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 32, offset: const Offset(0, 12)),
                  BoxShadow(color: accent.withValues(alpha: 0.06), blurRadius: 40),
                ],
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section label
                  const Text('TAMAÑO DEL TABLERO', style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  )),
                  const SizedBox(height: 12),

                  // Grid chip row — reusing same widget as dialogs
                  _GridSizeRow(
                    selected: _gridSize.toInt(),
                    accent: accent,
                    onChanged: (v) => setState(() => _gridSize = v.toDouble()),
                  ),

                  // Hint
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(
                      child: Text(
                        '${_gridSize.toInt()}×${_gridSize.toInt()} · ${(_gridSize * _gridSize).toInt()} piezas',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // ── Comenzar button (pulsing glow) ───────────────────────────
            _PulsingButton(
              label: 'Comenzar',
              icon: Icons.play_arrow_rounded,
              accent: accent,
              onTap: _beginSearch,
            ),
            const SizedBox(height: 14),

            // Ghost volver
            GestureDetector(
              onTap: () => context.goNamed(LobbyScreen.routeName),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.textGray.withValues(alpha: 0.20)),
                ),
                child: const Text('Volver',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    )),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchingScreen() {
    final accent = _modeAccent;

    return Stack(
      children: [
        // Orbs
        Positioned(top: -60, right: -80,
          child: _ScreenOrb(color: accent, size: 260, opacity: 0.10)),
        Positioned(bottom: -100, left: -60,
          child: _ScreenOrb(color: AppColors.neonPurple, size: 240, opacity: 0.08)),

        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),

            // Status text
            Text(
              _statusMessage,
              style: const TextStyle(
                color: AppColors.textGray,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Timer with neon glow
            ScaleTransition(
              scale: _pulseAnimation,
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [accent, AppColors.neonPurple],
                ).createShader(bounds),
                child: Text(
                  '⏳ ${TimeUtils.formatSeconds(_elapsedSeconds)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
            _ShimmerPreviewPuzzle(mode: widget.mode, gridSize: _gridSize.toInt()),
            const SizedBox(height: 24),

            // Rotating tip
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.2), end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Container(
                key: ValueKey<int>(_currentTipIndex),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.15)),
                ),
                child: Text(
                  _tips[_currentTipIndex],
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const Spacer(),

            // Cancel button
            GestureDetector(
              onTap: _onCancelPressed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.35)),
                  color: AppColors.neonPink.withValues(alpha: 0.08),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close_rounded, color: AppColors.neonPink.withValues(alpha: 0.8), size: 18),
                    const SizedBox(width: 8),
                    Text('Cancelar búsqueda',
                        style: TextStyle(
                          color: AppColors.neonPink.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: _isConfiguring ? _buildConfigScreen() : _buildSearchingScreen(),
          ),
        ),
      ),
    );
  }
}

// ── Screen-level background orb ──────────────────────────────────────────────

class _ScreenOrb extends StatelessWidget {
  const _ScreenOrb({required this.color, required this.size, required this.opacity});
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

// ── Grid size chip row (inline) ───────────────────────────────────────────────

class _GridSizeRow extends StatelessWidget {
  const _GridSizeRow({
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  final int selected;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [3, 4, 5, 6, 7, 8].map((size) {
        final isActive = size == selected;
        return GestureDetector(
          onTap: () => onChanged(size),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(colors: [accent, accent.withValues(alpha: 0.6)])
                  : null,
              color: isActive ? null : AppColors.bgCardLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? accent.withValues(alpha: 0.75) : AppColors.textMuted.withValues(alpha: 0.30),
                width: isActive ? 1.5 : 1,
              ),
              boxShadow: isActive ? AppShadows.shadowNeon(accent, radius: 12) : [],
            ),
            alignment: Alignment.center,
            child: Text('${size}x$size',
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textGray,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              )),
          ),
        );
      }).toList(),
    );
  }
}

// ── Pulsing CTA button ────────────────────────────────────────────────────────

class _PulsingButton extends StatefulWidget {
  const _PulsingButton({
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_PulsingButton> createState() => _PulsingButtonState();
}

class _PulsingButtonState extends State<_PulsingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.accent.withValues(alpha: 0.55 * _glow.value),
              blurRadius: 26,
              spreadRadius: -2,
            ),
            BoxShadow(
              color: AppColors.neonPurple.withValues(alpha: 0.25 * _glow.value),
              blurRadius: 44,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.accent, AppColors.neonPurple],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerPreviewPuzzle extends StatefulWidget {
  const _ShimmerPreviewPuzzle({required this.mode, required this.gridSize});

  final PuzzleMode mode;
  final int gridSize;

  @override
  State<_ShimmerPreviewPuzzle> createState() => _ShimmerPreviewPuzzleState();
}

class _ShimmerPreviewPuzzleState extends State<_ShimmerPreviewPuzzle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int items = widget.gridSize * widget.gridSize;
    return Column(
      children: [
        Text(
          '🎯 Modo de juego: ${widget.mode.displayName}',
          style: context.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GlassCard(
          width: 240,
          height: 240,
          sigma: 8,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: 0.5 + (_controller.value * 0.5),
                child: GridView.count(
                  crossAxisCount: widget.gridSize,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  physics: const NeverScrollableScrollPhysics(),
                  children: List<Widget>.generate(items, (int index) {
                    return Container(
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: index == (items ~/ 2)
                            ? Colors.transparent
                            : AppColors.puzzleTileColors[index % AppColors.puzzleTileColors.length]
                                .withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
