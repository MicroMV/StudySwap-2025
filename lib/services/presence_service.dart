import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> setOnline() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).update({
      'presence': {'online': true, 'lastSeen': FieldValue.serverTimestamp()},
    });
  }

  static Future<void> setOffline() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).update({
      'presence': {'online': false, 'lastSeen': FieldValue.serverTimestamp()},
    });
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> presenceStream(
    String userId,
  ) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
