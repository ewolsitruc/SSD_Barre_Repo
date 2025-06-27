import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class UserDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Public getter for the currently signed-in user
  User? get currentUser => _auth.currentUser;

  /// Returns a realtime stream of the user document.
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Adds or updates the user's document in Firestore after sign-in/registration or profile update.
  Future<void> updateUserData(
      User user, {
        String? fcmToken,
        String? firstName,
        String? lastName,
        String? childrenNames,
        String? email,
        String? phoneNumber,
        String? displayName,
        String? bio,
        DateTime? birthday,
        bool? allowCommentsOnProfile,
        String? profileImageUrl,
      }) async {
    final userRef = _firestore.collection('users').doc(user.uid);

    try {
      final userDoc = await userRef.get();
      final isNewUser = !userDoc.exists;

      // Helper to lowercase and trim safely
      String toLowerSafe(String? s) => (s ?? '').toLowerCase().trim();

      Map<String, dynamic> userData = <String, dynamic>{
        'uid': user.uid,
        'email': email ?? user.email ?? '',
        'emailLowercase': toLowerSafe(email ?? user.email),
        'lastLogin': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken ?? '',
        'lastTokenUpdate': FieldValue.serverTimestamp(),
        'firstName': firstName ?? '',
        'firstNameLowercase': toLowerSafe(firstName),
        'lastName': lastName ?? '',
        'lastNameLowercase': toLowerSafe(lastName),
        'childrenNames': _parseChildrenNames(childrenNames),
        'phoneNumber': phoneNumber ?? '',
        'displayName': displayName ?? '',
        'displayNameLowercase': toLowerSafe(displayName),
        'bio': bio ?? '',
        'birthday': birthday != null ? Timestamp.fromDate(birthday) : null,
        'allowCommentsOnProfile': allowCommentsOnProfile ?? true,
        'profileImageUrl': profileImageUrl ?? '',
      };

      if (isNewUser) {
        debugPrint('UserDataService: Creating new user doc for ${user.uid}');
        userData.addAll({
          'isAdmin': false,
          'isTeacher': false,
          'createdAt': FieldValue.serverTimestamp(),
          'assignedGroups': [],
          'assignedSubgroups': [],
          'unreadMessageCount': 0,
          'unreadAnnouncementCount': 0,
          'unreadJoinRequestCount': 0,
        });
        await userRef.set(userData);
        debugPrint('UserDataService: New user doc created for ${user.uid}');
      } else {
        debugPrint('UserDataService: Updating existing user doc for ${user.uid}');
        Map<String, dynamic> updateData = {
          'lastLogin': FieldValue.serverTimestamp(),
        };

        if (fcmToken != null && userDoc.data()?['fcmToken'] != fcmToken) {
          updateData['fcmToken'] = fcmToken;
          updateData['lastTokenUpdate'] = FieldValue.serverTimestamp();
          debugPrint('UserDataService: Updated FCM token for ${user.uid}');
        }

        void addIfNotNull(String key, dynamic value) {
          if (value != null) updateData[key] = value;
        }

        addIfNotNull('firstName', firstName);
        addIfNotNull('firstNameLowercase', toLowerSafe(firstName));
        addIfNotNull('lastName', lastName);
        addIfNotNull('lastNameLowercase', toLowerSafe(lastName));
        addIfNotNull('childrenNames', _parseChildrenNames(childrenNames));
        addIfNotNull('phoneNumber', phoneNumber);
        addIfNotNull('displayName', displayName);
        addIfNotNull('displayNameLowercase', toLowerSafe(displayName));
        addIfNotNull('bio', bio);
        addIfNotNull('birthday', birthday != null ? Timestamp.fromDate(birthday) : null);
        addIfNotNull('allowCommentsOnProfile', allowCommentsOnProfile);
        addIfNotNull('profileImageUrl', profileImageUrl);

        await userRef.set(updateData, SetOptions(merge: true));
        debugPrint('UserDataService: User doc updated for ${user.uid}');
      }
    } catch (e) {
      debugPrint('UserDataService: Error updating user doc for ${user.uid}: $e');
      rethrow;
    }
  }

  /// Converts comma-separated string into a clean list of names
  List<String> _parseChildrenNames(String? names) {
    if (names == null || names.trim().isEmpty) return [];
    return names
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Checks if a user is an admin.
  Future<bool> isUserAdmin(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists && (doc.data()?['isAdmin'] == true);
    } catch (e) {
      debugPrint('UserDataService: Error checking admin status for $uid: $e');
      return false;
    }
  }

  Future<bool> isUserTeacher(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists && (doc.data()?['isTeacher'] == true);
    } catch (e) {
      debugPrint('UserDataService: Error checking teacher status for $uid: $e');
      return false;
    }
  }

  /// Resets unread join request count for admins.
  Future<void> resetUnreadJoinRequestCount(String adminUid) async {
    try {
      await _firestore.collection('users').doc(adminUid).update({
        'unreadJoinRequestCount': 0,
      });
      debugPrint('UserDataService: Reset unread join request count for $adminUid');
    } catch (e) {
      debugPrint('UserDataService: Error resetting join request count for $adminUid: $e');
    }
  }
}
