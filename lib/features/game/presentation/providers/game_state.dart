import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/puzzle_piece.dart';
import '../../../../core/enums/puzzle_mode.dart';

part 'game_state.freezed.dart';

@freezed
abstract class GameState with _$GameState {
  const factory GameState({
    @Default(true) bool isLoading,
    @Default(false) bool isFinished,
    @Default(0) int elapsedSeconds,
    @Default([]) List<PuzzlePiece> pieces,
    @Default(0) int aiProgress,
    int? finalTime,
    String? errorMessage,
    required PuzzleMode mode,
    required int totalPieces,
    required String roomId,
  }) = _GameState;

  const GameState._();
  
  int get completedPieces => pieces.where((p) => p.isLocked).length;
  bool get isPuzzleComplete => pieces.isNotEmpty && completedPieces == totalPieces;
}
