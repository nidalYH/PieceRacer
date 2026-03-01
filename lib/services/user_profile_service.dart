import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  UserProfile({
    required this.uid,
    required this.displayName,
  });

  final String uid;
  final String displayName;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    final name = data['displayName'] as String? ?? 'Jugador';
    return UserProfile(uid: uid, displayName: name);
  }
}

final CollectionReference<Map<String, dynamic>> _usersCollection =
    FirebaseFirestore.instance.collection('users');

Future<UserProfile> ensureUserProfile(User firebaseUser) async {
  final uid = firebaseUser.uid;
  final DocumentReference<Map<String, dynamic>> docRef =
      _usersCollection.doc(uid);
  final DocumentSnapshot<Map<String, dynamic>> snapshot = await docRef.get();
  if (snapshot.exists) {
    final data = snapshot.data() as Map<String, dynamic>;
    return UserProfile.fromMap(uid, data);
  }

  final generatedName = 'Jugador ${uid.substring(0, 5)}';
  await docRef.set({
    'displayName': generatedName,
    'createdAt': FieldValue.serverTimestamp(),
  });
  return UserProfile(uid: uid, displayName: generatedName);
}

Future<String> fetchDisplayName(String uid) async {
  final DocumentSnapshot<Map<String, dynamic>> snapshot =
      await _usersCollection.doc(uid).get();
  if (!snapshot.exists) {
    return 'Oponente';
  }
  final data = snapshot.data() as Map<String, dynamic>;
  final name = data['displayName'] as String?;
  if (name == null || name.isEmpty) {
    return 'Oponente';
  }
  return name;
}

