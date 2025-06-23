import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Import for debugPrint

class UserDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a user to Firestore when they register or log in for the first time
  Future<void> addUserToFirestore(User user, {String? phoneNumber, String? firstName, String? lastName, List<String>? childrenNames}) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    try {
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        // User doesn't exist in Firestore, create a new entry with ALL initial fields
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? user.email?.split('@')[0], // Use email prefix if no displayName
          'phoneNumber': phoneNumber ?? '',
          'firstName': firstName ?? '',
          'lastName': lastName ?? '',
          'childrenNames': childrenNames ?? [],
          'bio': '', // New field: default empty bio
          'birthday': null, // New field: default null for birthday
          'profileImageUrl': '', // New field: default empty for profile image URL
          'allowCommentsOnProfile': true, // New field: default true
          'isAdmin': false, // Default to false for new users
          'assignedGroups': [],
          'assignedSubgroups': [],
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(), // Initialize lastLoginAt on creation
          'unreadMessageCount': 0, // Initialize unread message count to 0 for new users
          'unreadAnnouncementCount': 0, // NEW: Initialize unread announcement count to 0
          'troupeAnnouncementPushNotifications': true, // New field: default true
          'chatPushNotifications': true, // New field: default true
          'emailNotifications': true, // New field: default true
          'showOnlineStatus': true, // New field: default true
        });
        debugPrint('Firestore: New user ${user.uid} created successfully with all initial fields.');
      } else {
        // User exists, update last login time and potentially other fields for consistency
        await userRef.update({
          'lastLoginAt': FieldValue.serverTimestamp(),
          // Ensure these fields exist or are updated if they were missing from older docs
          'unreadMessageCount': userDoc.data()?['unreadMessageCount'] ?? 0, // Ensures it exists and keeps value
          'unreadAnnouncementCount': userDoc.data()?['unreadAnnouncementCount'] ?? 0, // NEW: Ensures it exists and keeps value
          'troupeAnnouncementPushNotifications': userDoc.data()?['troupeAnnouncementPushNotifications'] ?? true,
          'chatPushNotifications': userDoc.data()?['chatPushNotifications'] ?? true,
          'emailNotifications': userDoc.data()?['emailNotifications'] ?? true,
          'showOnlineStatus': userDoc.data()?['showOnlineStatus'] ?? true,
          'bio': userDoc.data()?['bio'] ?? '',
          'birthday': userDoc.data()?['birthday'],
          'profileImageUrl': userDoc.data()?['profileImageUrl'] ?? '',
          'allowCommentsOnProfile': userDoc.data()?['allowCommentsOnProfile'] ?? true,
        });
        debugPrint('Firestore: User ${user.uid} last login and default settings updated.');
      }
    } catch (e) {
      // Log any error that occurs during Firestore operation
      debugPrint('Firestore Error: Failed to add/update user ${user.uid}: $e');
      // You might want to show a SnackBar or an alert to the user here in a real app
    }
  }

  // Check if a user is an admin
  Future<bool> isUserAdmin(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists) {
      return userDoc.data()?['isAdmin'] ?? false;
    }
    return false;
  }

  // Get user data stream
  Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }
}
