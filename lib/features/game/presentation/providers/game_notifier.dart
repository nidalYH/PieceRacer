import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/enums/puzzle_mode.dart';
import '../../../../core/enums/difficulty.dart';
import '../../data/room_repository.dart';
import '../../../lobby/data/auth_repository.dart';
import '../../ai/ai_controller.dart';
import '../../ai/ai_personality.dart';
import '../../models/puzzle_piece.dart';
import 'game_state.dart';

final gameNotifierProvider = StateNotifierProvider.family<GameNotifier, GameState, Map<String, dynamic>>((ref, params) {
  final mode = params['mode'] as PuzzleMode;
  final roomId = params['roomId'] as String;
  final numPieces = params['numPieces'] as int? ?? 9; 
  final aiDiff = params['aiDifficulty'] as Difficulty?;
  final aiPers = params['aiPersonality'] as AIPersonality?;

  return GameNotifier(
    mode: mode,
    roomId: roomId,
    totalPieces: numPieces,
    aiDifficulty: aiDiff,
    aiPersonality: aiPers,
    roomRepo: ref.watch(roomRepositoryProvider),
    authRepo: ref.watch(authRepositoryProvider),
  );
});

class GameNotifier extends StateNotifier<GameState> {
  GameNotifier({
    required PuzzleMode mode,
    required String roomId,
    required int totalPieces,
    required this.roomRepo,
    required this.authRepo,
    Difficulty? aiDifficulty,
    AIPersonality? aiPersonality,
  }) : super(GameState(mode: mode, roomId: roomId, totalPieces: totalPieces)) {
    if (mode == PuzzleMode.vsAI) {
      aiController = AIController(
        totalPieces: totalPieces,
        difficulty: aiDifficulty ?? Difficulty.normal,
        personality: aiPersonality ?? AIPersonality.calm,
        onProgressUpdated: (completed) {
          if (!mounted || state.isFinished) return;
          state = state.copyWith(aiProgress: completed);
          if (completed >= state.totalPieces) {
             _finishGame(false);
          }
        },
        onFinished: () {
          if (!mounted || state.isFinished) return;
          _finishGame(false);
        },
      );
    }
    _initGame();
  }

  final RoomRepository roomRepo;
  final AuthRepository authRepo;
  AIController? aiController;

  Timer? _gameTimer;
  Timer? _syncTimer;
  StreamSubscription? _roomSubscription;

  void _initGame() {
    _startGameTimer();
    
    if (state.mode == PuzzleMode.vsAI) {
      _startAI();
    } else if (state.mode == PuzzleMode.local) {
      // Local mode: just timer, no AI, no Firebase
    } else {
      _listenToRoom();
      _startSyncTimer();
    }
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || state.isFinished) {
        timer.cancel();
        return;
      }
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _startAI() {
    aiController?.start();
  }

  void _listenToRoom() {
    _roomSubscription = roomRepo.watchRoom(state.roomId).listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      // Handle opponent progress if needed
      // Check if opponent finished
      final results = List<Map<String, dynamic>>.from(data['results'] ?? []);
      final currentUid = authRepo.currentUser?.uid;
      
      if (results.isNotEmpty && !state.isFinished) {
        bool opponentFinished = false;
        for (final res in results) {
          if (res['uid'] != currentUid) {
             opponentFinished = true;
             // Update opponent visual progress immediately to max
             state = state.copyWith(aiProgress: state.totalPieces);
             break;
          }
        }
        
        if (opponentFinished) {
           _finishGame(false);
        }
      }
    });
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
       if (!mounted || state.isFinished) {
          timer.cancel();
          return;
       }
       final uid = authRepo.currentUser?.uid;
       if (uid != null) {
          try {
             await roomRepo.syncUserTime(state.roomId, uid, state.elapsedSeconds);
          } catch (e) {
             debugPrint('Silent sync error: $e');
          }
       }
    });
  }

  void setPieces(List<PuzzlePiece> initialPieces) {
    state = state.copyWith(pieces: initialPieces, isLoading: false);
  }

  void updatePiece(PuzzlePiece updatedPiece) {
    final updatedList = List<PuzzlePiece>.from(state.pieces);
    final index = updatedList.indexWhere((p) => p.id == updatedPiece.id);
    if (index != -1) {
      updatedList[index] = updatedPiece;
      state = state.copyWith(pieces: updatedList);
    }
    
    _checkWinCondition();
  }
  
  void updatePieces(List<PuzzlePiece> newPieces) {
    state = state.copyWith(pieces: newPieces);
    _checkWinCondition();
  }

  void _checkWinCondition() {
    if (state.isFinished) return;
    
    if (state.isPuzzleComplete) {
       _finishGame(true);
    }
  }

  Future<void> _finishGame(bool playerWon) async {
    if (state.isFinished) return;
    
    _gameTimer?.cancel();
    _syncTimer?.cancel();
    aiController?.stop();
    _roomSubscription?.cancel();

    state = state.copyWith(
      isFinished: true,
      finalTime: state.elapsedSeconds,
    );

    if (state.mode != PuzzleMode.vsAI && state.mode != PuzzleMode.local) {
      final uid = authRepo.currentUser?.uid;
      if (uid != null) {
         try {
           await roomRepo.submitResult(state.roomId, uid, state.elapsedSeconds);
         } catch (e) {
           state = state.copyWith(errorMessage: 'Failed saving results to server: $e');
         }
      }
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _syncTimer?.cancel();
    _roomSubscription?.cancel();
    aiController?.stop();
    super.dispose();
  }
}
