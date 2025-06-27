import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:cloud_firestore/cloud_firestore.dart'; // For fetching unread counts
import '../user/all_direct_messages_page.dart'; // Corrected to relative import
import '../user/ssd_hub_page.dart'; // Import the new page for all announcements
import '../troupes_page.dart'; // Corrected import path for TroupesPage (for announcements selection)
import '../widgets/main_drawer.dart'; // Import MainDrawer
import '../widgets/custom_app_bar.dart'; // NEW: Import CustomAppBar
import '../user/login_page.dart'; // Import LoginPage for logout logic
import 'dart:async'; // Import for StreamSubscription

class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  bool _isAdmin = false; // State for admin status, needed for MainDrawer
  int _unreadMessageCount = 0;
  int _unreadAnnouncementCount = 0;

  // Stream subscription for user data to get unread counts
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _listenToUserUnreadCounts(_currentUser!.uid);
      _listenToUserAdminStatus(_currentUser!.uid); // NEW: Listen to admin status
    }
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel(); // Cancel the subscription
    super.dispose();
  }

  // Listen to user's unread message and announcement counts
  void _listenToUserUnreadCounts(String uid) {
    _userDataSubscription?.cancel(); // Cancel any existing subscription first
    _userDataSubscription = _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final userData = snapshot.data();
        final int newUnreadMessageCount = userData?['unreadMessageCount'] ?? 0;
        final int newUnreadAnnouncementCount = userData?['unreadAnnouncementCount'] ?? 0;

        if (newUnreadMessageCount != _unreadMessageCount || newUnreadAnnouncementCount != _unreadAnnouncementCount) {
          debugPrint('ChatsListPage: Unread counts updated - Messages: $newUnreadMessageCount, Announcements: $newUnreadAnnouncementCount');
          setState(() {
            _unreadMessageCount = newUnreadMessageCount;
            _unreadAnnouncementCount = newUnreadAnnouncementCount;
          });
        }
      }
    }, onError: (error) {
      debugPrint('ChatsListPage Listener Error: Failed to listen to user unread counts: $error');
      // Handle error, e.g., show an error message
    });
  }

  // NEW: Listen to user's admin status
  void _listenToUserAdminStatus(String uid) {
    _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final bool newIsAdmin = snapshot.data()?['isAdmin'] ?? false;
        if (newIsAdmin != _isAdmin) {
          setState(() {
            _isAdmin = newIsAdmin;
          });
          debugPrint('ChatsListPage: Admin status updated to $_isAdmin');
        }
      }
    }, onError: (error) {
      debugPrint('ChatsListPage Admin Listener Error: Failed to listen to admin status: $error');
    });
  }

  Future<void> _logout() async {
    debugPrint('ChatsListPage: Logging out user...');
    await _auth.signOut();
    debugPrint('ChatsListPage: Logged out and navigated to LoginPage.');
    // Navigate to LoginPage and clear all routes in the stack
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: Center(
          child: Text(
            'Please log in to view your notifications.',
            style: TextStyle(color: textOnBackground),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar( // Using CustomAppBar
        titleWidget: const Text('Notifications'), // CHANGED: Use titleWidget with Text widget
        isAdmin: _isAdmin, // Pass isAdmin status
        onLogout: _logout, // Pass logout function
        showNotificationsIcon: false, title: '', // Don't show bell icon on this sub-page
      ),
      endDrawer: MainDrawer( // Ensure MainDrawer is linked
        isAdmin: _isAdmin,
        onLogout: _logout, onNavigateToHubTab: (int ) {  },
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch cards to full width
          children: [
            // Messages Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: backgroundColor,
              child: InkWell(
                onTap: () {
                  debugPrint('ChatsListPage: Navigating to AllDirectMessagesPage.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AllDirectMessagesPage()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(Icons.mail, size: 40, color: primaryColor),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          'Messages',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textOnBackground,
                          ),
                        ),
                      ),
                      if (_unreadMessageCount > 0)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          child: Text(
                            '$_unreadMessageCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20), // Spacer between cards

            // Announcements Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              color: backgroundColor,
              child: InkWell(
                onTap: () {
                  // This navigates to TroupesPage where a user can select a troupe
                  // to view its specific announcements, or global announcements if no troupe is selected.
                  debugPrint('ChatsListPage: Navigating to AllAnnouncementsHubPage.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SSDHubPage()), // Changed to AllAnnouncementsHubPage
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Icon(Icons.campaign, size: 40, color: primaryColor),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          'Announcements',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textOnBackground,
                          ),
                        ),
                      ),
                      if (_unreadAnnouncementCount > 0)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 30,
                            minHeight: 30,
                          ),
                          child: Text(
                            '$_unreadAnnouncementCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
