import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/enums/puzzle_mode.dart';
import '../../core/enums/difficulty.dart';
import '../game/ai/ai_personality.dart';
import '../game/ai/ai_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/design_system.dart';
import '../../core/utils/time_utils.dart';
import '../lobby/lobby_screen.dart';
import 'widgets/puzzle_board.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    required this.roomId,
    required this.mode,
    this.gridSize = 3,
    this.aiDifficulty,
    this.aiPersonality,
    this.galleryImageBytes,
    super.key,
  });

  static const String routePath = '/game';
  static const String routeName = 'game';

  final String roomId;
  final PuzzleMode mode;
  final int gridSize;
  final Difficulty? aiDifficulty;
  final AIPersonality? aiPersonality;
  final Uint8List? galleryImageBytes;

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  ui.Image? _puzzleImage;
  bool _isLoadingImage = true;
  String? _imageError;

  // Game state managed locally
  int _lockedCount = 0;
  int _totalPieces = 0;
  int _elapsedSeconds = 0;
  int _aiProgress = 0;
  bool _isFinished = false;
  Timer? _gameTimer;
  AIController? _aiController;

  late AudioPlayer _audioPlayer;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _totalPieces = widget.gridSize * widget.gridSize;
    _audioPlayer = AudioPlayer();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _loadPuzzleImage();
    _startTimer();
    _startAI();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _aiController?.stop();
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isFinished) return;
      setState(() => _elapsedSeconds++);
    });
  }

  void _startAI() {
    if (widget.mode != PuzzleMode.vsAI) return;
    _aiController = AIController(
      totalPieces: _totalPieces,
      difficulty: widget.aiDifficulty ?? Difficulty.normal,
      personality: widget.aiPersonality ?? AIPersonality.calm,
      onProgressUpdated: (completed) {
        if (!mounted || _isFinished) return;
        setState(() => _aiProgress = completed);
        if (completed >= _totalPieces) _finishGame(playerWon: false);
      },
      onFinished: () {
        if (!mounted || _isFinished) return;
        _finishGame(playerWon: false);
      },
    );
    _aiController!.start();
  }

  Future<void> _loadPuzzleImage() async {
    try {
      if (widget.galleryImageBytes != null) {
        _puzzleImage = await _decodeBytes(widget.galleryImageBytes!);
      } else {
        _puzzleImage = await _loadImage('assets/images/puzzle_1.png');
      }
      if (mounted) setState(() => _isLoadingImage = false);
    } catch (e) {
      if (mounted) setState(() { _imageError = '$e'; _isLoadingImage = false; });
    }
  }

  Future<ui.Image> _decodeBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<ui.Image> _loadImage(String path) async {
    final provider = path.startsWith('http')
        ? NetworkImage(path) as ImageProvider
        : AssetImage(path) as ImageProvider;
    final stream = provider.resolve(ImageConfiguration.empty);
    final completer = Completer<ui.Image>();
    late ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      completer.complete(info.image);
      stream.removeListener(listener);
    }, onError: (e, _) {
      completer.completeError(e);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future;
  }

  void _onPieceLocked(int locked, int total) {
    setState(() {
      _lockedCount = locked;
      _totalPieces = total;
    });
    try { _audioPlayer.play(AssetSource('audio/snap.wav'), volume: 0.5); } catch (_) {}
  }

  void _onSolved() {
    _finishGame(playerWon: true);
  }

  void _finishGame({required bool playerWon}) {
    if (_isFinished) return;
    setState(() => _isFinished = true);
    _gameTimer?.cancel();
    _aiController?.stop();
    if (playerWon) {
      _confettiController.play();
      try { _audioPlayer.play(AssetSource('audio/win.wav')); } catch (_) {}
    }
    _showFinishDialog(playerWon);
  }

  String get _modeLabel {
    switch (widget.mode) {
      case PuzzleMode.vsAI: return 'vs IA 🤖';
      case PuzzleMode.local: return 'Puzzle Local 📸';
      case PuzzleMode.oneVsOne: return '1v1 ⚔️';
      case PuzzleMode.twoVsTwo: return '2v2 🤝';
      case PuzzleMode.friends: return 'Amigos 🎉';
    }
  }

  bool get _showRival => widget.mode == PuzzleMode.vsAI;

  @override
  Widget build(BuildContext context) {
    if (_isLoadingImage) {
      return Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: AppColors.neonCyan, strokeWidth: 3)),
          const SizedBox(height: 16),
          Text('Cargando puzzle...', style: context.textTheme.bodyMedium),
        ])),
      );
    }
    if (_imageError != null) {
      return Scaffold(body: Center(child: Text('Error: $_imageError', style: const TextStyle(color: AppColors.neonPink))));
    }

    final double progress = _totalPieces == 0 ? 0 : _lockedCount / _totalPieces;

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textGray),
                  onPressed: () => context.goNamed(LobbyScreen.routeName),
                ),
                Expanded(child: Column(children: [
                  Text(_modeLabel, style: context.textTheme.titleMedium),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.timer_outlined, size: 16, color: AppColors.neonCyan),
                    const SizedBox(width: 4),
                    Text(TimeUtils.formatSeconds(_elapsedSeconds),
                      style: context.textTheme.titleLarge?.copyWith(color: AppColors.neonCyan, fontWeight: FontWeight.w800)),
                  ]),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$_lockedCount/$_totalPieces',
                    style: const TextStyle(color: AppColors.neonGreen, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ]),
            ),
            // Progress bars
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress, backgroundColor: AppColors.bgCardLight,
                  valueColor: const AlwaysStoppedAnimation(AppColors.neonGreen), minHeight: 4,
                ),
              ),
            ),
            if (_showRival) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _totalPieces == 0 ? 0 : _aiProgress / _totalPieces,
                    backgroundColor: AppColors.bgCardLight,
                    valueColor: const AlwaysStoppedAnimation(AppColors.neonPink), minHeight: 4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            // Puzzle board
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PuzzleBoard(
                  image: _puzzleImage!,
                  rows: widget.gridSize,
                  cols: widget.gridSize,
                  onPieceLocked: _onPieceLocked,
                  onSolved: _onSolved,
                ),
              ),
            ),
          ]),
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 5, minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 30, gravity: 0.2,
            ),
          ),
        ]),
      ),
    );
  }

  void _showFinishDialog(bool won) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(won ? '🎉 ¡Ganaste!' : '😢 Perdiste', textAlign: TextAlign.center),
        content: Text(
          won ? 'Tiempo: ${TimeUtils.formatSeconds(_elapsedSeconds)}' : 'La IA terminó primero. ¡Inténtalo de nuevo!',
          textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGray),
        ),
        actions: [
          FilledButton(
            onPressed: () => context.goNamed(LobbyScreen.routeName),
            child: const Text('Volver al menú'),
          ),
        ],
      ),
    );
  }
}
