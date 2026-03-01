import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Service that syncs piece movements in real-time for 2v2 co-op mode
/// using Firebase Realtime Database (RTDB) for low-latency updates.
///
/// Data structure in RTDB:
/// ```
/// rooms/{roomId}/pieces/{pieceId} = {
///   x: double,
///   y: double,
///   rotation: double,
///   locked: bool,
///   lockedBy: String?, // uid of player who locked it
///   heldBy: String?,   // uid of player currently dragging it
/// }
/// ```
class RealtimeSyncService {
  RealtimeSyncService({
    required this.roomId,
    required this.uid,
  });

  final String roomId;
  final String uid;

  DatabaseReference get _roomRef =>
      FirebaseDatabase.instance.ref('rooms/$roomId');

  DatabaseReference get _piecesRef => _roomRef.child('pieces');

  StreamSubscription? _piecesSubscription;

  // ── Callbacks ───────────────────────────────────────────────────────────

  /// Called when a remote player moves or locks a piece.
  void Function(int pieceId, Map<String, dynamic> data)? onPieceUpdated;

  /// Called when a remote player grabs or releases a piece.
  void Function(int pieceId, String? heldBy)? onPieceHeldChanged;

  // ── Lifecycle ───────────────────────────────────────────────────────────

  /// Start listening for piece changes from other players.
  void startListening() {
    _piecesSubscription?.cancel();
    _piecesSubscription = _piecesRef.onChildChanged.listen((event) {
      final key = event.snapshot.key;
      final value = event.snapshot.value;
      if (key == null || value == null) return;

      final pieceId = int.tryParse(key);
      if (pieceId == null) return;

      final data = Map<String, dynamic>.from(value as Map);

      // Ignore our own updates
      final heldBy = data['heldBy'] as String?;
      final lockedBy = data['lockedBy'] as String?;

      // Only process updates from OTHER players
      if (heldBy == uid || lockedBy == uid) return;

      onPieceUpdated?.call(pieceId, data);
    });
  }

  void stopListening() {
    _piecesSubscription?.cancel();
    _piecesSubscription = null;
  }

  // ── Piece Operations ──────────────────────────────────────────────────

  /// Try to grab a piece. Returns true if we successfully claimed it.
  Future<bool> tryGrabPiece(int pieceId) async {
    final pieceRef = _piecesRef.child('$pieceId');

    // Use transaction to atomically claim the piece
    final result = await pieceRef.runTransaction((currentData) {
      if (currentData == null) {
        return Transaction.success({'heldBy': uid});
      }

      final data = Map<String, dynamic>.from(currentData as Map);
      final currentHolder = data['heldBy'] as String?;

      // Piece is free or already ours
      if (currentHolder == null || currentHolder == uid) {
        data['heldBy'] = uid;
        return Transaction.success(data);
      }

      // Someone else is holding it — abort
      return Transaction.abort();
    });

    return result.committed;
  }

  /// Update piece position while dragging (high frequency, fire-and-forget).
  void movePiece(int pieceId, double x, double y) {
    _piecesRef.child('$pieceId').update({
      'x': x,
      'y': y,
      'heldBy': uid,
    });
  }

  /// Release a piece (player stops dragging).
  Future<void> releasePiece(int pieceId, double x, double y) async {
    await _piecesRef.child('$pieceId').update({
      'x': x,
      'y': y,
      'heldBy': null,
    });
  }

  /// Lock a piece into its correct position (permanent).
  Future<void> lockPiece(int pieceId, double x, double y) async {
    await _piecesRef.child('$pieceId').set({
      'x': x,
      'y': y,
      'rotation': 0.0,
      'locked': true,
      'lockedBy': uid,
      'heldBy': null,
    });
  }

  /// Initialize all pieces in RTDB with their scattered positions.
  /// Should be called by the FIRST player who enters the game.
  Future<void> initializePieces(Map<int, Map<String, double>> positions) async {
    final updates = <String, dynamic>{};
    for (final entry in positions.entries) {
      updates['${entry.key}'] = {
        'x': entry.value['x'],
        'y': entry.value['y'],
        'rotation': 0.0,
        'locked': false,
        'lockedBy': null,
        'heldBy': null,
      };
    }
    await _piecesRef.set(updates);
  }

  /// Read current state of all pieces from RTDB.
  Future<Map<int, Map<String, dynamic>>?> readPieceStates() async {
    final snapshot = await _piecesRef.get();
    if (!snapshot.exists || snapshot.value == null) return null;

    final raw = Map<String, dynamic>.from(snapshot.value as Map);
    final result = <int, Map<String, dynamic>>{};
    for (final entry in raw.entries) {
      final id = int.tryParse(entry.key);
      if (id != null && entry.value != null) {
        result[id] = Map<String, dynamic>.from(entry.value as Map);
      }
    }
    return result;
  }

  /// Clean up RTDB data when the match ends.
  Future<void> cleanup() async {
    stopListening();
    try {
      await _roomRef.remove();
    } catch (e) {
      debugPrint('RTDB cleanup error: $e');
    }
  }

  void dispose() {
    stopListening();
  }
}
