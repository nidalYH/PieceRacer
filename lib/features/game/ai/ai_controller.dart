import 'dart:async';
import 'dart:math';
import '../../../core/enums/difficulty.dart';
import 'ai_personality.dart';

class AIController {
  AIController({
    required this.totalPieces,
    required this.difficulty,
    required this.onProgressUpdated,
    required this.onFinished,
    this.initialCompletedPieces = 0,
    this.personality = AIPersonality.calm,
  }) : _completedPieces = initialCompletedPieces;

  final int totalPieces;
  final Difficulty difficulty;
  final void Function(int completedPieces) onProgressUpdated;
  final void Function() onFinished;
  final int initialCompletedPieces;
  final AIPersonality personality;

  Timer? _timer;
  bool _running = false;
  int _completedPieces;
  int _playerCompletedPieces = 0;
  
  // Human-like AI state
  int _movesInRow = 0;
  DateTime? _lastPlayerMoveTime;
  bool _playerLastMoveFast = false;
  final StreamController<String> _tauntController = StreamController<String>.broadcast();

  int get completedPieces => _completedPieces;
  Stream<String> get tauntStream => _tauntController.stream;

  void updatePlayerProgress(int playerCompleted) {
    if (_lastPlayerMoveTime != null) {
      final elapsed = DateTime.now().difference(_lastPlayerMoveTime!);
      _playerLastMoveFast = elapsed.inMilliseconds < 2000; // Fast if < 2 seconds
    }
    _lastPlayerMoveTime = DateTime.now();
    _playerCompletedPieces = playerCompleted;
  }

  Duration get _adaptiveInterval {
    // If we have totalPieces, let's calculate ratios.
    if (totalPieces == 0) return const Duration(seconds: 2);

    final playerRatio = _playerCompletedPieces / totalPieces;
    final aiRatio = _completedPieces / totalPieces;

    // Base interval per difficulty
    Duration baseInterval;
    switch (difficulty) {
      case Difficulty.easy:
        baseInterval = const Duration(seconds: 4);
        break;
      case Difficulty.normal:
        baseInterval = const Duration(seconds: 3);
        break;
      case Difficulty.hard:
        baseInterval = const Duration(seconds: 2);
        break;
      case Difficulty.expert:
        baseInterval = const Duration(milliseconds: 1500);
        break;
    }

    // Adaptive speed adjustment based on winning state
    if (playerRatio > aiRatio) {
      // Player is winning, speed up base logic
      baseInterval = Duration(milliseconds: (baseInterval.inMilliseconds * 0.7).round());
    } else if (playerRatio < aiRatio - 0.2) {
      // AI is winning strongly, slow down
      baseInterval = Duration(milliseconds: (baseInterval.inMilliseconds * 1.5).round());
    }

    // Personality modifications
    if (personality == AIPersonality.aggressive && playerRatio > aiRatio) {
      // Aggressive gets even faster when losing
      baseInterval = Duration(milliseconds: (baseInterval.inMilliseconds * 0.8).round());
    } else if (personality == AIPersonality.calm) {
      // Calm stays relatively steady (closer to base interval)
      baseInterval = Duration(milliseconds: (baseInterval.inMilliseconds * 1.1).round());
    }

    // React to player's speed
    if (_playerLastMoveFast && personality != AIPersonality.troll) {
      // If player is moving fast, AI tries to keep up
      baseInterval = Duration(milliseconds: (baseInterval.inMilliseconds * 0.8).round());
    }

    return baseInterval;
  }

  void start() {
    if (_running) return;
    _running = true;
    _scheduleNextMove();
  }

  void _scheduleNextMove() {
    if (!_running) return;
    
    _timer?.cancel();

    // AI Fatigue
    int fatigueDelayMs = 0;
    if (_movesInRow > 5) {
      fatigueDelayMs = 2000; // 2 seconds rest
      _movesInRow = 0;
      _emitTaunt("Ouf, necesito un segundo... 😴");
    }

    // AI Think micro-pause (makes it feel human)
    final thinkPauseMs = Random().nextInt(400);

    final totalDelay = _adaptiveInterval + 
                       Duration(milliseconds: thinkPauseMs) + 
                       Duration(milliseconds: fatigueDelayMs);

    _timer = Timer(totalDelay, () {
      _makeMove();
      if (_running) {
        _scheduleNextMove();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _running = false;
  }

  void _emitTaunt(String message) {
    if (!_tauntController.isClosed) {
      _tauntController.add(message);
    }
  }

  bool _shouldFail() {
    double baseFail = 0.0;
    switch (difficulty) {
      case Difficulty.easy: baseFail = 0.4; break;
      case Difficulty.normal: baseFail = 0.15; break;
      case Difficulty.hard: baseFail = 0.05; break;
      case Difficulty.expert: baseFail = 0.02; break;
    }

    final playerRatio = totalPieces > 0 ? _playerCompletedPieces / totalPieces : 0;
    final aiRatio = totalPieces > 0 ? _completedPieces / totalPieces : 0;

    // Nervous mistakes when losing
    if (playerRatio > aiRatio) {
      baseFail += 0.2; // Increase fail chance by 20%
      if (Random().nextDouble() < 0.2) {
        _emitTaunt("¡Maldición, me equivoqué! 😰");
      }
    }

    // Troll personality mistakes
    if (personality == AIPersonality.troll && aiRatio > playerRatio + 0.1) {
      baseFail += 0.2; // Fails on purpose
      if (Random().nextDouble() < 0.3) {
        _emitTaunt("Uy, se me resbaló... 😜");
      }
    }

    return Random().nextDouble() < baseFail;
  }

  void _makeMove() {
    if (_completedPieces >= totalPieces) {
      stop();
      return;
    }

    if (_shouldFail()) {
      _movesInRow = 0;
      return; // Skip this turn (simulating a human mistake)
    }

    _completedPieces++;
    _movesInRow++;
    onProgressUpdated(_completedPieces);

    // Occasional random taunts when doing well
    if (_movesInRow == 3 && Random().nextDouble() < 0.3) {
      if (personality == AIPersonality.aggressive) {
        _emitTaunt("¡Demasiado lento! 🔥");
      } else if (personality == AIPersonality.calm) {
        _emitTaunt("Paso a paso... 🧘");
      }
    }

    if (_completedPieces >= totalPieces) {
      stop();
      onFinished();
    }
  }

  void dispose() {
    stop();
    _tauntController.close();
  }
}
