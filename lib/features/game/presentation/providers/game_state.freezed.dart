// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'game_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GameState {
  bool get isLoading;
  bool get isFinished;
  int get elapsedSeconds;
  List<PuzzlePiece> get pieces;
  int get aiProgress;
  int? get finalTime;
  String? get errorMessage;
  PuzzleMode get mode;
  int get totalPieces;
  String get roomId;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GameStateCopyWith<GameState> get copyWith =>
      _$GameStateCopyWithImpl<GameState>(this as GameState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GameState &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isFinished, isFinished) ||
                other.isFinished == isFinished) &&
            (identical(other.elapsedSeconds, elapsedSeconds) ||
                other.elapsedSeconds == elapsedSeconds) &&
            const DeepCollectionEquality().equals(other.pieces, pieces) &&
            (identical(other.aiProgress, aiProgress) ||
                other.aiProgress == aiProgress) &&
            (identical(other.finalTime, finalTime) ||
                other.finalTime == finalTime) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.totalPieces, totalPieces) ||
                other.totalPieces == totalPieces) &&
            (identical(other.roomId, roomId) || other.roomId == roomId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isLoading,
      isFinished,
      elapsedSeconds,
      const DeepCollectionEquality().hash(pieces),
      aiProgress,
      finalTime,
      errorMessage,
      mode,
      totalPieces,
      roomId);

  @override
  String toString() {
    return 'GameState(isLoading: $isLoading, isFinished: $isFinished, elapsedSeconds: $elapsedSeconds, pieces: $pieces, aiProgress: $aiProgress, finalTime: $finalTime, errorMessage: $errorMessage, mode: $mode, totalPieces: $totalPieces, roomId: $roomId)';
  }
}

/// @nodoc
abstract mixin class $GameStateCopyWith<$Res> {
  factory $GameStateCopyWith(GameState value, $Res Function(GameState) _then) =
      _$GameStateCopyWithImpl;
  @useResult
  $Res call(
      {bool isLoading,
      bool isFinished,
      int elapsedSeconds,
      List<PuzzlePiece> pieces,
      int aiProgress,
      int? finalTime,
      String? errorMessage,
      PuzzleMode mode,
      int totalPieces,
      String roomId});
}

/// @nodoc
class _$GameStateCopyWithImpl<$Res> implements $GameStateCopyWith<$Res> {
  _$GameStateCopyWithImpl(this._self, this._then);

  final GameState _self;
  final $Res Function(GameState) _then;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? isFinished = null,
    Object? elapsedSeconds = null,
    Object? pieces = null,
    Object? aiProgress = null,
    Object? finalTime = freezed,
    Object? errorMessage = freezed,
    Object? mode = null,
    Object? totalPieces = null,
    Object? roomId = null,
  }) {
    return _then(_self.copyWith(
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isFinished: null == isFinished
          ? _self.isFinished
          : isFinished // ignore: cast_nullable_to_non_nullable
              as bool,
      elapsedSeconds: null == elapsedSeconds
          ? _self.elapsedSeconds
          : elapsedSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      pieces: null == pieces
          ? _self.pieces
          : pieces // ignore: cast_nullable_to_non_nullable
              as List<PuzzlePiece>,
      aiProgress: null == aiProgress
          ? _self.aiProgress
          : aiProgress // ignore: cast_nullable_to_non_nullable
              as int,
      finalTime: freezed == finalTime
          ? _self.finalTime
          : finalTime // ignore: cast_nullable_to_non_nullable
              as int?,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      mode: null == mode
          ? _self.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as PuzzleMode,
      totalPieces: null == totalPieces
          ? _self.totalPieces
          : totalPieces // ignore: cast_nullable_to_non_nullable
              as int,
      roomId: null == roomId
          ? _self.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [GameState].
extension GameStatePatterns on GameState {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_GameState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GameState() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_GameState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GameState():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_GameState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GameState() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            bool isLoading,
            bool isFinished,
            int elapsedSeconds,
            List<PuzzlePiece> pieces,
            int aiProgress,
            int? finalTime,
            String? errorMessage,
            PuzzleMode mode,
            int totalPieces,
            String roomId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GameState() when $default != null:
        return $default(
            _that.isLoading,
            _that.isFinished,
            _that.elapsedSeconds,
            _that.pieces,
            _that.aiProgress,
            _that.finalTime,
            _that.errorMessage,
            _that.mode,
            _that.totalPieces,
            _that.roomId);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            bool isLoading,
            bool isFinished,
            int elapsedSeconds,
            List<PuzzlePiece> pieces,
            int aiProgress,
            int? finalTime,
            String? errorMessage,
            PuzzleMode mode,
            int totalPieces,
            String roomId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GameState():
        return $default(
            _that.isLoading,
            _that.isFinished,
            _that.elapsedSeconds,
            _that.pieces,
            _that.aiProgress,
            _that.finalTime,
            _that.errorMessage,
            _that.mode,
            _that.totalPieces,
            _that.roomId);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            bool isLoading,
            bool isFinished,
            int elapsedSeconds,
            List<PuzzlePiece> pieces,
            int aiProgress,
            int? finalTime,
            String? errorMessage,
            PuzzleMode mode,
            int totalPieces,
            String roomId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GameState() when $default != null:
        return $default(
            _that.isLoading,
            _that.isFinished,
            _that.elapsedSeconds,
            _that.pieces,
            _that.aiProgress,
            _that.finalTime,
            _that.errorMessage,
            _that.mode,
            _that.totalPieces,
            _that.roomId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _GameState extends GameState {
  const _GameState(
      {this.isLoading = true,
      this.isFinished = false,
      this.elapsedSeconds = 0,
      final List<PuzzlePiece> pieces = const [],
      this.aiProgress = 0,
      this.finalTime,
      this.errorMessage,
      required this.mode,
      required this.totalPieces,
      required this.roomId})
      : _pieces = pieces,
        super._();

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isFinished;
  @override
  @JsonKey()
  final int elapsedSeconds;
  final List<PuzzlePiece> _pieces;
  @override
  @JsonKey()
  List<PuzzlePiece> get pieces {
    if (_pieces is EqualUnmodifiableListView) return _pieces;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pieces);
  }

  @override
  @JsonKey()
  final int aiProgress;
  @override
  final int? finalTime;
  @override
  final String? errorMessage;
  @override
  final PuzzleMode mode;
  @override
  final int totalPieces;
  @override
  final String roomId;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GameStateCopyWith<_GameState> get copyWith =>
      __$GameStateCopyWithImpl<_GameState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GameState &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isFinished, isFinished) ||
                other.isFinished == isFinished) &&
            (identical(other.elapsedSeconds, elapsedSeconds) ||
                other.elapsedSeconds == elapsedSeconds) &&
            const DeepCollectionEquality().equals(other._pieces, _pieces) &&
            (identical(other.aiProgress, aiProgress) ||
                other.aiProgress == aiProgress) &&
            (identical(other.finalTime, finalTime) ||
                other.finalTime == finalTime) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.totalPieces, totalPieces) ||
                other.totalPieces == totalPieces) &&
            (identical(other.roomId, roomId) || other.roomId == roomId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isLoading,
      isFinished,
      elapsedSeconds,
      const DeepCollectionEquality().hash(_pieces),
      aiProgress,
      finalTime,
      errorMessage,
      mode,
      totalPieces,
      roomId);

  @override
  String toString() {
    return 'GameState(isLoading: $isLoading, isFinished: $isFinished, elapsedSeconds: $elapsedSeconds, pieces: $pieces, aiProgress: $aiProgress, finalTime: $finalTime, errorMessage: $errorMessage, mode: $mode, totalPieces: $totalPieces, roomId: $roomId)';
  }
}

/// @nodoc
abstract mixin class _$GameStateCopyWith<$Res>
    implements $GameStateCopyWith<$Res> {
  factory _$GameStateCopyWith(
          _GameState value, $Res Function(_GameState) _then) =
      __$GameStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool isLoading,
      bool isFinished,
      int elapsedSeconds,
      List<PuzzlePiece> pieces,
      int aiProgress,
      int? finalTime,
      String? errorMessage,
      PuzzleMode mode,
      int totalPieces,
      String roomId});
}

/// @nodoc
class __$GameStateCopyWithImpl<$Res> implements _$GameStateCopyWith<$Res> {
  __$GameStateCopyWithImpl(this._self, this._then);

  final _GameState _self;
  final $Res Function(_GameState) _then;

  /// Create a copy of GameState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? isLoading = null,
    Object? isFinished = null,
    Object? elapsedSeconds = null,
    Object? pieces = null,
    Object? aiProgress = null,
    Object? finalTime = freezed,
    Object? errorMessage = freezed,
    Object? mode = null,
    Object? totalPieces = null,
    Object? roomId = null,
  }) {
    return _then(_GameState(
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isFinished: null == isFinished
          ? _self.isFinished
          : isFinished // ignore: cast_nullable_to_non_nullable
              as bool,
      elapsedSeconds: null == elapsedSeconds
          ? _self.elapsedSeconds
          : elapsedSeconds // ignore: cast_nullable_to_non_nullable
              as int,
      pieces: null == pieces
          ? _self._pieces
          : pieces // ignore: cast_nullable_to_non_nullable
              as List<PuzzlePiece>,
      aiProgress: null == aiProgress
          ? _self.aiProgress
          : aiProgress // ignore: cast_nullable_to_non_nullable
              as int,
      finalTime: freezed == finalTime
          ? _self.finalTime
          : finalTime // ignore: cast_nullable_to_non_nullable
              as int?,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      mode: null == mode
          ? _self.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as PuzzleMode,
      totalPieces: null == totalPieces
          ? _self.totalPieces
          : totalPieces // ignore: cast_nullable_to_non_nullable
              as int,
      roomId: null == roomId
          ? _self.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
