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

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getRoom(String roomId) {
    return _rooms.doc(roomId).get();
  }

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

  Future<DocumentReference<Map<String, dynamic>>> findOrCreateRoom({
    required String uid,
    required PuzzleMode mode,
    required int gridSize,
    String? customImageUrl,
  }) async {
    final String imageUrl = customImageUrl ?? 'https://picsum.photos/800/800';

    QuerySnapshot<Map<String, dynamic>> waitingSnapshot = await _rooms
        .where('status', isEqualTo: 'waiting')
        .where('mode', isEqualTo: mode.name)
        .where('gridSize', isEqualTo: gridSize)
        .orderBy('createdAt', descending: false)
        .limit(1)
        .get();

    if (waitingSnapshot.docs.isEmpty) {
      return await _rooms.add({
        'status': 'waiting',
        'mode': mode.name,
        'gridSize': gridSize,
        'players': <String>[uid],
        'puzzleData': <String, dynamic>{
          'imageUrl': imageUrl,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'results': <Map<String, dynamic>>[],
      });
    } else {
      final doc = waitingSnapshot.docs.first;
      final players = List<String>.from(doc.data()['players'] as List<dynamic>? ?? <dynamic>[]);
      
      if (!players.contains(uid)) {
        await doc.reference.update({
          'status': 'started',
          'players': FieldValue.arrayUnion(<String>[uid]),
          'startTime': FieldValue.serverTimestamp(),
        });
      }
      return doc.reference;
    }
  }

  Future<void> cancelRoomSearch(String roomId, String uid) async {
    final roomRef = _rooms.doc(roomId);
    final snapshot = await roomRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    final players = List<String>.from(data['players'] as List<dynamic>? ?? <dynamic>[]);
    final status = data['status'] as String? ?? '';

    if (status == 'waiting') {
      if (players.length <= 1 && players.contains(uid)) {
        await roomRef.delete();
      } else if (players.contains(uid)) {
        await roomRef.update({
          'players': FieldValue.arrayRemove(<String>[uid]),
        });
      }
    }
  }

  Future<void> syncUserTime(String roomId, String uid, int elapsedSeconds) async {
    await _rooms.doc(roomId).update({
      'currentTimers.$uid': elapsedSeconds,
    });
  }

  Future<void> submitResult(String roomId, String uid, int elapsedSeconds) async {
    await _rooms.doc(roomId).update({
      'results': FieldValue.arrayUnion(<Map<String, dynamic>>[
        <String, dynamic>{
          'uid': uid,
          'time': elapsedSeconds,
        },
      ]),
    });
  }
}
