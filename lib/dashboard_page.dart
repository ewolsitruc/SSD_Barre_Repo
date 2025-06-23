import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for date/time formatting
import 'user/login_page.dart';
import 'admin/dev_tools_screen.dart'; // Corrected import path
import 'user/user_data_service.dart';
import 'admin/announcements_list_page.dart'; // Corrected import path
import 'admin/add_announcement_page.dart'; // Corrected import path
import 'admin/announcement_detail_page.dart'; // Corrected import path
import 'admin/add_event_page.dart'; // Import the new AddEventPage
import 'admin/event_detail_page.dart'; // Import the new EventDetailPage
import 'admin/troupes_page.dart'; // Import the new TroupesPage
import 'package:flutter/foundation.dart'; // For debugPrint
import 'user/chats_list_page.dart'; // Corrected import path to ChatsListPage
import 'widgets/main_drawer.dart'; // Corrected import path to MainDrawer
import 'dart:async'; // Import for StreamSubscription
import 'dart:math'; // Import for min/max functions

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDataService _userDataService = UserDataService(); // Instantiate the service
  User? _currentUser;
  bool _isAdmin = false;
  int _unreadMessageCount = 0; // State to hold the unread message count
  int _unreadAnnouncementCount = 0; // NEW: State to hold unread announcement count
  int _totalUnreadCount = 0; // NEW: Total for the bell icon

  // Stream subscription for user data
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    debugPrint('Dashboard initState: User is: ${_currentUser?.email}');

    // Listen to auth state changes to ensure user is logged in
    _auth.authStateChanges().listen((user) {
      if (user == null && mounted) {
        // If user logs out, navigate back to LoginPage
        debugPrint('Dashboard: User logged out, navigating to LoginPage.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      } else if (user != null && mounted) {
        _currentUser = user; // Update current user
        _addOrUpdateUserToFirestore(user); // Add/Update user details in Firestore
        _listenToUserAdminAndUnreadStatus(user.uid); // Listen to user's admin status and unread counts
      }
    });

    // Initial check in case user is already logged in on app start
    if (_currentUser != null) {
      _addOrUpdateUserToFirestore(_currentUser!);
      _listenToUserAdminAndUnreadStatus(_currentUser!.uid);
    }
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel(); // Cancel the subscription to avoid memory leaks
    super.dispose();
  }

  // Add or update user details in Firestore
  Future<void> _addOrUpdateUserToFirestore(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    try {
      debugPrint('Dashboard: Current user detected: ${user.email}. Attempting to add/update to Firestore and listen for admin status.');
      final userDoc = await userRef.get(); // Get the document first

      if (userDoc.exists) {
        // If document exists, update only the lastLoginAt and ensure unread counters exist
        await userRef.set({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'unreadMessageCount': userDoc.data()?['unreadMessageCount'] ?? 0, // Ensure it exists, keep current value
          'unreadAnnouncementCount': userDoc.data()?['unreadAnnouncementCount'] ?? 0, // NEW: Ensure it exists, keep current value
        }, SetOptions(merge: true));
        debugPrint('Firestore: User ${user.uid} last login and unread counters ensured.');
      } else {
        // If document does NOT exist, create it using UserDataService
        // This scenario should primarily happen for newly registered users,
        // but this ensures robustness.
        await _userDataService.addUserToFirestore(user);
        debugPrint('Firestore: User ${user.uid} document created via Dashboard page logic.');
      }
    } catch (e) {
      debugPrint('Firestore Error: Failed to add/update user ${user.uid}: $e');
      // Handle error, e.g., show a snackbar
    }
  }

  // Listen to user's admin status and unread message/announcement counts
  void _listenToUserAdminAndUnreadStatus(String uid) {
    _userDataSubscription?.cancel(); // Cancel any existing subscription first
    _userDataSubscription = _firestore.collection('users').doc(uid).snapshots().listen((snapshot) async {
      if (snapshot.exists && mounted) {
        final userData = snapshot.data();
        final bool newIsAdmin = userData?['isAdmin'] ?? false;
        final int newUnreadMessageCount = userData?['unreadMessageCount'] ?? 0;
        final int newUnreadAnnouncementCount = userData?['unreadAnnouncementCount'] ?? 0; // NEW

        final int newTotalUnread = newUnreadMessageCount + newUnreadAnnouncementCount; // NEW: Sum them

        if (newIsAdmin != _isAdmin || newTotalUnread != _totalUnreadCount ||
            newUnreadMessageCount != _unreadMessageCount || newUnreadAnnouncementCount != _unreadAnnouncementCount) {
          debugPrint('Dashboard Listener: User data snapshot received.');
          debugPrint('  isAdmin from Firestore: $newIsAdmin');
          debugPrint('  Unread Messages: $newUnreadMessageCount');
          debugPrint('  Unread Announcements: $newUnreadAnnouncementCount');
          debugPrint('  Total Unread: $newTotalUnread');
          setState(() {
            _isAdmin = newIsAdmin;
            _unreadMessageCount = newUnreadMessageCount;
            _unreadAnnouncementCount = newUnreadAnnouncementCount;
            _totalUnreadCount = newTotalUnread;
          });
        } else {
          debugPrint('Dashboard Listener: isAdmin and Unread Count values unchanged.');
        }
      }
    }, onError: (error) {
      debugPrint('Dashboard Listener Error: Failed to listen to user data: $error');
      // Handle error, e.g., show an error message
    });
  }

  Future<void> _logout() async {
    debugPrint('Dashboard: Logging out user...');
    await _auth.signOut();
    debugPrint('Dashboard: Logged out and navigated to LoginPage.');
    // Navigation handled by authStateChanges listener in initState
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get colors from the global theme
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnPrimary = Theme.of(context).colorScheme.onPrimary; // White
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground; // Black
    final Color backgroundColor = Theme.of(context).colorScheme.background; // White

    // Get screen width for responsive font size
    final double screenWidth = MediaQuery.of(context).size.width;
    // Calculate responsive font size for "Welcome to the Barre!"
    // Scales down from 18.0 based on screen width, but not smaller than 14.0
    final double responsiveTitleFontSize = min(18.0, max(14.0, screenWidth * 0.045));

    debugPrint('Dashboard build method: _isAdmin is currently: $_isAdmin');

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80, // Keep increased height for more content
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: CircleAvatar(
            backgroundColor: textOnPrimary, // White circle
            radius: 20,
            child: Icon(
              Icons.person, // Generic person icon
              color: primaryColor, // Red icon
              size: 30,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align column content to the start (left)
          children: [
            Text(
              'Welcome to the Barre!',
              style: TextStyle(
                fontFamily: 'SSDHeader',
                fontSize: responsiveTitleFontSize, // Use responsive font size
                fontWeight: FontWeight.bold,
                color: textOnPrimary, // White text on red app bar
              ),
              // textAlign property is not needed here as parent column handles alignment
              maxLines: 1, // Prevent text from wrapping
              overflow: TextOverflow.ellipsis, // Add ellipsis if it still overflows
            ),
            // No need for Align or Padding here as parent Column.start handles alignment
            Text(
              'Welcome, ${_currentUser?.email?.split('@')[0] ?? 'User'}!',
              style: TextStyle(
                fontFamily: 'SSDBody',
                fontSize: 16, // Smaller font for user name
                color: textOnPrimary, // White text
              ),
            ),
          ],
        ),
        centerTitle: false, // Ensure title is NOT centered, aligns after leading widget
        actions: [
          // Bell Icon for Chats/Notifications
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () {
                  debugPrint('Dashboard: Navigating to Chats/Notifications Page.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatsListPage()),
                  );
                },
                tooltip: 'Chats & Notifications',
                color: textOnPrimary, // White icon
              ),
              if (_totalUnreadCount > 0) // NEW: Use _totalUnreadCount for the badge
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$_totalUnreadCount', // Display total unread count
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Hamburger Menu (Drawer) icon
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu), // Hamburger icon
              onPressed: () {
                Scaffold.of(context).openEndDrawer(); // Open the EndDrawer (hamburger menu)
              },
              tooltip: 'Menu',
              color: textOnPrimary, // White icon
            ),
          ),
        ],
      ),
      // Use the new MainDrawer widget here
      endDrawer: MainDrawer(
        isAdmin: _isAdmin,
        onLogout: _logout,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Your logo, centered at the top of the body
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0), // Add some space below the logo
                child: Image.asset(
                  'assets/ssd_logo.jpeg',
                  width: 150, // Adjust size as needed
                  height: 150, // Adjust size as needed
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error loading ssd_logo.jpeg in body: $error');
                    return Icon(Icons.error, color: primaryColor, size: 100);
                  },
                ),
              ),
            ),
            Text(
              'Latest Announcements',
              style: TextStyle(
                fontFamily: 'SSDHeader',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textOnBackground,
              ),
            ),
            const SizedBox(height: 10),
            // Announcements StreamBuilder
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('announcements')
                  .orderBy('createdAt', descending: true)
                  .limit(3) // Show only the 3 most recent announcements
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading announcements: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No announcements yet.', style: TextStyle(color: textOnBackground)));
                }

                return ListView.builder(
                  shrinkWrap: true, // Important: Makes ListView take only required space
                  physics: const NeverScrollableScrollPhysics(), // Disable scrolling of this inner ListView
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot doc = snapshot.data!.docs[index];
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                    final String title = data['title'] ?? 'No Title';
                    final String content = data['content'] ?? 'No Content';
                    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                    final String createdBy = data['createdBy'] ?? '';

                    final String formattedDate = createdAt != null
                        ? DateFormat('MMM dd, yyyy').format(createdAt.toDate()) // Fixed Japanese character
                        : 'Unknown Date';

                    // Fetch user email for display
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(createdBy).get(),
                      builder: (context, userDocSnapshot) {
                        String posterEmail = 'Unknown';
                        if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                          posterEmail = userDocSnapshot.data!['email'] ?? 'Unknown'; // Corrected data access
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 3,
                          color: backgroundColor, // White card background
                          child: InkWell(
                            onTap: () {
                              debugPrint('Dashboard: Tapped on announcement: $title');
                              // Navigate to a detailed announcement page (future feature)
                              // For now, show a snackbar or simple dialog
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(builder: (context) => AnnouncementDetailPage(
                              //     title: title,
                              //     content: content,
                              //     date: formattedDate,
                              //     poster: posterEmail,
                              //   )),
                              // );
                              _showSnackBar('Announcement: $title');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor, // Red title
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textOnBackground.withOpacity(0.8), // Lighter black content
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$formattedDate by ${posterEmail.split('@')[0]}', // Display username part of email
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: textOnBackground.withOpacity(0.6), // Even lighter black
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Upcoming Events',
              style: TextStyle(
                fontFamily: 'SSDHeader',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textOnBackground,
              ),
            ),
            const SizedBox(height: 10),
            // Events StreamBuilder
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('events')
                  .where('eventDate', isGreaterThanOrEqualTo: Timestamp.now()) // Only future events
                  .orderBy('eventDate', descending: false)
                  .limit(3) // Show only the 3 nearest upcoming events
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading events: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No upcoming events.', style: TextStyle(color: textOnBackground)));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot doc = snapshot.data!.docs[index];
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                    final String title = data['title'] ?? 'No Title';
                    final String description = data['description'] ?? 'No Description';
                    final String location = data['location'] ?? 'Not specified';
                    final Timestamp? eventDate = data['eventDate'] as Timestamp?;
                    final String createdBy = data['createdBy'] ?? '';

                    final String formattedDate = eventDate != null
                        ? DateFormat('MMM dd, yyyy hh:mm a').format(eventDate.toDate()) // Fixed Japanese character
                        : 'Unknown Date';

                    // Fetch user email for display
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(createdBy).get(),
                      builder: (context, userDocSnapshot) {
                        String posterEmail = 'Unknown';
                        if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                          posterEmail = userDocSnapshot.data!['email'] ?? 'Unknown'; // Corrected data access
                        }
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 3,
                          color: backgroundColor,
                          child: InkWell(
                            onTap: () {
                              debugPrint('Dashboard: Tapped on event: $title');
                              // Navigate to a detailed event page (future feature)
                              // For now, show a snackbar or simple dialog
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(builder: (context) => EventDetailPage(
                              //     title: title,
                              //     description: description,
                              //     date: formattedDate,
                              //     time: 'N/A', // Time not separately stored, needs extraction or specific field
                              //     location: location,
                              //     poster: posterEmail,
                              //   )),
                              // );
                              _showSnackBar('Event: $title on $formattedDate');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textOnBackground.withOpacity(0.8),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '$formattedDate ${location.isNotEmpty ? 'at $location' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: textOnBackground.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
