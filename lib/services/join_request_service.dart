// lib/services/join_request_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinRequestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Sends a join request for a troupe or sub-troupe.
  ///
  /// If [parentTroupeId] is provided, it indicates this request is for a sub-troupe
  /// and the parent troupe ID is recorded as well.
  static Future<void> sendJoinRequest({
    required String troupeId,
    String? parentTroupeId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Optional: check if there's an existing pending request for this troupe
    final existingRequests = await _firestore
        .collection('joinRequests')
        .where('userId', isEqualTo: user.uid)
        .where('requestedTroupeId', isEqualTo: troupeId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingRequests.docs.isNotEmpty) {
      throw Exception('A pending join request already exists for this troupe.');
    }

    await _firestore.collection('joinRequests').add({
      'userId': user.uid,
      'userEmail': user.email,
      'requestedTroupeId': troupeId,
      'parentTroupeId': parentTroupeId, // null if joining a parent troupe directly
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }
}