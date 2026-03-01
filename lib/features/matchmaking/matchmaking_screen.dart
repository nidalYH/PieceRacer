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
      } else {
        // Fast 1v1 mode
        imageUrl = 'https://picsum.photos/800/800'; // Random public image
      }

      final roomRepo = ref.read(roomRepositoryProvider);
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
        if (data == null) {
          return;
        }
        final String status = data['status'] as String? ?? '';
        if (status == 'started' && !_navigatedToGame) {
          _navigateToGame(roomRef.id);
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

  Widget _buildConfigScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Configuración',
          style: context.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dificultad (Filas x Columnas): ${_gridSize.toInt()}x${_gridSize.toInt()}', style: context.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Slider(
                value: _gridSize,
                min: 3,
                max: 10,
                divisions: 7,
                label: '${_gridSize.toInt()}x${_gridSize.toInt()}',
                activeColor: context.colors.primary,
                onChanged: (val) {
                  setState(() {
                    _gridSize = val;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              if (widget.mode == PuzzleMode.vsAI) ...[
                Text('Nivel de la IA', style: context.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<Difficulty>(
                  value: _aiDifficulty,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  ),
                  items: Difficulty.values.map((d) {
                    return DropdownMenuItem(value: d, child: Text(d.name.toUpperCase()));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _aiDifficulty = val);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Personalidad de la IA', style: context.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<AIPersonality>(
                  value: _aiPersonality,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  ),
                  items: AIPersonality.values.map((p) {
                    return DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _aiPersonality = val);
                  },
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _beginSearch,
          style: FilledButton.styleFrom(
            backgroundColor: context.colors.primary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
          ),
          child: const Text('Comenzar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => context.goNamed(LobbyScreen.routeName),
          child: const Text('Volver'),
        ),
      ],
    );
  }

  Widget _buildSearchingScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Text(
          _statusMessage,
          style: context.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        ScaleTransition(
          scale: _pulseAnimation,
          child: Text(
            '⏳ ${TimeUtils.formatSeconds(_elapsedSeconds)}',
            style: context.textTheme.displayLarge?.copyWith(
              color: context.colors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _ShimmerPreviewPuzzle(mode: widget.mode, gridSize: _gridSize.toInt()),
        const SizedBox(height: AppSpacing.xl),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _tips[_currentTipIndex],
            key: ValueKey<int>(_currentTipIndex),
            style: context.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: OutlinedButton.icon(
            onPressed: _onCancelPressed,
            icon: const Icon(Icons.close),
            label: const Text('Cancelar Búsqueda'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.error,
              side: BorderSide(color: context.colors.error.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: _isConfiguring ? _buildConfigScreen() : _buildSearchingScreen(),
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
