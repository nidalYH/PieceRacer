import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/enums/puzzle_mode.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository(
    FirebaseFirestore.instance,
    FirebaseStorage.instance,
  );
});

class RoomRepository {
  RoomRepository(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection('rooms');

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the number of players required to start a match for [mode].
  static int maxPlayersFor(PuzzleMode mode) {
    switch (mode) {
      case PuzzleMode.oneVsOne: return 2;
      case PuzzleMode.twoVsTwo: return 4;
      case PuzzleMode.friends: return 4; // 3-4 players, configurable
      case PuzzleMode.vsAI: return 1;
      case PuzzleMode.local: return 1;
    }
  }

  /// Deterministic image URL from a seed (same seed → same image).
  static String deterministicImageUrl(int seed) =>
      'https://picsum.photos/seed/$seed/800/800';

  // ── Watch / Get ───────────────────────────────────────────────────────────

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getRoom(String roomId) {
    return _rooms.doc(roomId).get();
  }

  // ── Image Upload ──────────────────────────────────────────────────────────

  Future<String?> uploadCustomImage(XFile image) async {
    try {
      final storageRef = _storage.ref().child(
          'puzzle_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(File(image.path));
      return await storageRef.getDownloadURL();
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  // ── Matchmaking (transaction-safe) ────────────────────────────────────────

  /// Atomically find a waiting room or create a new one.
  ///
  /// Uses a Firestore transaction to prevent race conditions where two players
  /// both see the same waiting room and both try to join simultaneously.
  Future<DocumentReference<Map<String, dynamic>>> findOrCreateRoom({
    required String uid,
    required PuzzleMode mode,
    required int gridSize,
    String? customImageUrl,
  }) async {
    final int maxPlayers = maxPlayersFor(mode);
    final int puzzleSeed = DateTime.now().millisecondsSinceEpoch;
    final String imageUrl =
        customImageUrl ?? deterministicImageUrl(puzzleSeed);

    // Query for a waiting room with matching config
    final QuerySnapshot<Map<String, dynamic>> waitingSnapshot = await _rooms
        .where('status', isEqualTo: 'waiting')
        .where('mode', isEqualTo: mode.name)
        .where('gridSize', isEqualTo: gridSize)
        .orderBy('createdAt', descending: false)
        .limit(1)
        .get();

    if (waitingSnapshot.docs.isEmpty) {
      // No room available → create a new one
      return await _rooms.add({
        'status': 'waiting',
        'mode': mode.name,
        'gridSize': gridSize,
        'maxPlayers': maxPlayers,
        'players': <String>[uid],
        'puzzleData': <String, dynamic>{
          'imageUrl': imageUrl,
          'puzzleSeed': puzzleSeed,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'results': <Map<String, dynamic>>[],
      });
    }

    // Room exists → try to join atomically via transaction
    final docRef = waitingSnapshot.docs.first.reference;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final players = List<String>.from(data['players'] as List<dynamic>);
      final roomMax = data['maxPlayers'] as int? ?? 2;
      final status = data['status'] as String;

      // Safety: don't join if already a member, or room is full, or already started
      if (players.contains(uid) || status != 'waiting') return;
      if (players.length >= roomMax) return;

      players.add(uid);

      final Map<String, dynamic> update = {
        'players': players,
      };

      // If room is now full → start the match
      if (players.length >= roomMax) {
        update['status'] = 'started';
        update['startTime'] = FieldValue.serverTimestamp();
      }

      transaction.update(docRef, update);
    });

    return docRef;
  }

  // ── Cancel / Leave ────────────────────────────────────────────────────────

  Future<void> cancelRoomSearch(String roomId, String uid) async {
    final roomRef = _rooms.doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final players = List<String>.from(data['players'] as List<dynamic>? ?? []);
      final status = data['status'] as String? ?? '';

      if (status != 'waiting' || !players.contains(uid)) return;

      if (players.length <= 1) {
        transaction.delete(roomRef);
      } else {
        players.remove(uid);
        transaction.update(roomRef, {'players': players});
      }
    });
  }

  // ── Sync & Results ────────────────────────────────────────────────────────

  Future<void> syncUserTime(String roomId, String uid, int elapsedSeconds) async {
    await _rooms.doc(roomId).update({
      'currentTimers.$uid': elapsedSeconds,
      'heartbeat.$uid': FieldValue.serverTimestamp(),
    });
  }

  /// Submit player result. Returns true if THIS player is the first finisher (winner).
  Future<bool> submitResult(String roomId, String uid, int elapsedSeconds) async {
    bool isWinner = false;

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(_rooms.doc(roomId));
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final results = List<Map<String, dynamic>>.from(
        (data['results'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
      );

      // Prevent duplicate submissions
      if (results.any((r) => r['uid'] == uid)) return;

      final newResult = <String, dynamic>{
        'uid': uid,
        'time': elapsedSeconds,
        'submittedAt': DateTime.now().millisecondsSinceEpoch,
      };

      results.add(newResult);

      // First result with this uid → they're the winner if none existed before
      isWinner = results.length == 1;

      final Map<String, dynamic> update = {
        'results': results,
      };

      // Set winner if this is the first submission
      if (isWinner) {
        update['winnerId'] = uid;
      }

      transaction.update(_rooms.doc(roomId), update);
    });

    return isWinner;
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Delete stale rooms older than [maxAge] that are still waiting.
  Future<int> cleanupStaleRooms({Duration maxAge = const Duration(minutes: 5)}) async {
    final cutoff = Timestamp.fromDate(DateTime.now().subtract(maxAge));
    final stale = await _rooms
        .where('status', isEqualTo: 'waiting')
        .where('createdAt', isLessThan: cutoff)
        .limit(50)
        .get();

    int deleted = 0;
    for (final doc in stale.docs) {
      await doc.reference.delete();
      deleted++;
    }
    return deleted;
  }
}
