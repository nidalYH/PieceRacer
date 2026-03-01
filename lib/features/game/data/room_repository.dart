import 'dart:io';
import 'dart:math';
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

  // ── Friends Mode: Room Codes ──────────────────────────────────────────────

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1

  /// Generate a unique 6-character room code.
  String generateRoomCode() {
    final random = Random();
    return List.generate(6, (_) => _codeChars[random.nextInt(_codeChars.length)]).join();
  }

  /// Create a private Friends room with an invite code.
  Future<DocumentReference<Map<String, dynamic>>> createPrivateRoom({
    required String uid,
    required int gridSize,
    required int totalRounds,
    String? customImageUrl,
  }) async {
    final code = generateRoomCode();
    final puzzleSeed = DateTime.now().millisecondsSinceEpoch;
    final imageUrl = customImageUrl ?? deterministicImageUrl(puzzleSeed);

    return await _rooms.add({
      'status': 'waiting',
      'mode': PuzzleMode.friends.name,
      'gridSize': gridSize,
      'maxPlayers': 4,
      'roomCode': code,
      'hostUid': uid,
      'players': <String>[uid],
      'puzzleData': <String, dynamic>{
        'imageUrl': imageUrl,
        'puzzleSeed': puzzleSeed,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'results': <Map<String, dynamic>>[],
      // Multi-round tracking
      'totalRounds': totalRounds,
      'currentRound': 1,
      'scores': <String, int>{uid: 0},
      // Photo queue (list of imageUrls, one per round)
      'photoQueue': <String>[imageUrl],
    });
  }

  /// Join a private room by its invite code.
  /// Returns the room reference, or null if not found / full / already started.
  Future<DocumentReference<Map<String, dynamic>>?> joinByCode({
    required String code,
    required String uid,
  }) async {
    final snapshot = await _rooms
        .where('roomCode', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final docRef = snapshot.docs.first.reference;

    bool joined = false;
    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      final players = List<String>.from(data['players'] as List<dynamic>);
      final maxPlayers = data['maxPlayers'] as int? ?? 4;

      if (players.contains(uid) || players.length >= maxPlayers) return;

      players.add(uid);
      final scores = Map<String, int>.from(
        (data['scores'] as Map?)?.cast<String, int>() ?? {},
      );
      scores[uid] = 0;

      transaction.update(docRef, {
        'players': players,
        'scores': scores,
      });
      joined = true;
    });

    return joined ? docRef : null;
  }

  /// Start a Friends room (host action).
  Future<void> startFriendsRoom(String roomId) async {
    await _rooms.doc(roomId).update({
      'status': 'started',
      'startTime': FieldValue.serverTimestamp(),
    });
  }

  /// Advance to the next round in a Friends match.
  /// Returns false if all rounds are complete.
  Future<bool> advanceRound(String roomId, {String? nextImageUrl}) async {
    bool hasMore = false;

    await _firestore.runTransaction((transaction) async {
      final snap = await transaction.get(_rooms.doc(roomId));
      if (!snap.exists) return;

      final data = snap.data()!;
      final current = data['currentRound'] as int? ?? 1;
      final total = data['totalRounds'] as int? ?? 1;

      if (current >= total) {
        transaction.update(_rooms.doc(roomId), {'status': 'finished'});
        hasMore = false;
        return;
      }

      final nextSeed = DateTime.now().millisecondsSinceEpoch;
      final imageUrl = nextImageUrl ?? deterministicImageUrl(nextSeed);

      transaction.update(_rooms.doc(roomId), {
        'currentRound': current + 1,
        'puzzleData.imageUrl': imageUrl,
        'puzzleData.puzzleSeed': nextSeed,
        'results': <Map<String, dynamic>>[], // clear results for next round
      });
      hasMore = true;
    });

    return hasMore;
  }
}
