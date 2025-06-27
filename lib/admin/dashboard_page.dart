import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import for date/time formatting
import 'package:flutter/foundation.dart'; // For debugPrint

// Corrected Imports (assuming these files exist in your lib/ folder or subfolders as indicated)
import 'user/login_page.dart';
import 'user/user_data_service.dart';
import 'user/ssd_hub_page.dart'; // The main SSD Hub Page
import 'widgets/main_drawer.dart'; // MainDrawer
import 'widgets/custom_app_bar.dart'; // CustomAppBar

import 'dart:async'; // Import for StreamSubscription

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
  int _unreadJoinRequestCount = 0; // NEW: State to hold unread join request count for admins
  int _totalUnreadCount = 0; // NEW: Total for the bell icon
  String? _profileImageUrl; // NEW: State to hold profile image URL

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
          'unreadJoinRequestCount': userDoc.data()?['unreadJoinRequestCount'] ?? 0, // NEW: Ensure it exists, keep current value
          'profileImageUrl': userDoc.data()?['profileImageUrl'], // Keep existing profile image URL
        }, SetOptions(merge: true));
        debugPrint('Firestore: User ${user.uid} last login and unread counters ensured.');
      } else {
        // If document does NOT exist, create it using UserDataService
        // This scenario should primarily happen for newly registered users,
        // but this ensures robustness.
        await _userDataService.updateUserData(user);
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
        final int newUnreadJoinRequestCount = userData?['unreadJoinRequestCount'] ?? 0; // NEW
        final String? newProfileImageUrl = userData?['profileImageUrl']; // NEW: Get profile image URL

        final int newTotalUnread = newUnreadMessageCount + newUnreadAnnouncementCount + newUnreadJoinRequestCount; // NEW: Sum them

        if (newIsAdmin != _isAdmin || newTotalUnread != _totalUnreadCount ||
            newUnreadMessageCount != _unreadMessageCount || newUnreadAnnouncementCount != _unreadAnnouncementCount ||
            newUnreadJoinRequestCount != _unreadJoinRequestCount || newProfileImageUrl != _profileImageUrl) { // NEW: Check new count and image URL
          debugPrint('Dashboard Listener: User data snapshot received.');
          debugPrint('  isAdmin from Firestore: $newIsAdmin');
          debugPrint('  Unread Messages: $newUnreadMessageCount');
          debugPrint('  Unread Announcements: $newUnreadAnnouncementCount');
          debugPrint('  Unread Join Requests: $newUnreadJoinRequestCount'); // NEW
          debugPrint('  Total Unread: $newTotalUnread');
          debugPrint('  Profile Image URL: $newProfileImageUrl');
          setState(() {
            _isAdmin = newIsAdmin;
            _unreadMessageCount = newUnreadMessageCount;
            _unreadAnnouncementCount = newUnreadAnnouncementCount;
            _unreadJoinRequestCount = newUnreadJoinRequestCount; // NEW
            _totalUnreadCount = newTotalUnread;
            _profileImageUrl = newProfileImageUrl; // Update profile image URL
          });
        } else {
          debugPrint('Dashboard Listener: isAdmin and Unread Count values unchanged.');
        }
      }
    }, onError: (error) {
      debugPrint('Dashboard Listener Error: Failed to listen to user data: $error');
      // Handle error, e.g., show a snackbar
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

  // NEW: Function to handle announcement tap (increment view count and navigate)
  Future<void> _handleAnnouncementTap(String announcementId) async {
    try {
      debugPrint('Dashboard: Tapped on announcement ID: $announcementId. Incrementing view count.');
      final docRef = _firestore.collection('announcements').doc(announcementId);
      await docRef.update({
        'viewCount': FieldValue.increment(1),
      });
      // Optionally navigate to a detail page after incrementing view count
      // Navigator.push(context, MaterialPageRoute(builder: (context) => AnnouncementDetailPage(announcementId: announcementId)));
    } catch (e) {
      debugPrint('Dashboard Error: Failed to increment view count for $announcementId: $e');
      // No snackbar here, as it's a background operation on tap.
    }
  }

  // NEW: Function to handle like/unlike for an announcement
  Future<void> _toggleLikeAnnouncement(String announcementId, List<dynamic> likedBy) async {
    if (_currentUser == null) {
      _showSnackBar('Please log in to like announcements.');
      return;
    }

    final String userId = _currentUser!.uid;
    final docRef = _firestore.collection('announcements').doc(announcementId);

    try {
      if (likedBy.contains(userId)) {
        // User has already liked, so unlike it
        debugPrint('Dashboard: User $userId unliking announcement $announcementId.');
        await docRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
        _showSnackBar('Unliked!');
      } else {
        // User has not liked, so like it
        debugPrint('Dashboard: User $userId liking announcement $announcementId.');
        await docRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        _showSnackBar('Liked!');
      }
    } catch (e) {
      debugPrint('Dashboard Error: Failed to toggle like for $announcementId: $e');
      _showSnackBar('Failed to update like status: $e');
    }
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

    debugPrint('Dashboard build method: _isAdmin is currently: $_isAdmin');

    return Scaffold(
      appBar: CustomAppBar(
        // CHANGED: Title is now a Column to stack the two text elements
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Center text horizontally
          mainAxisAlignment: MainAxisAlignment.center, // Center text vertically
          children: [
            Text(
              'Welcome to the Barre!',
              style: TextStyle(
                fontFamily: 'SSDHeader',
                fontSize: 18, // Adjust font size to fit AppBar
                fontWeight: FontWeight.bold,
                color: textOnPrimary, // Text color for AppBar title
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              'Welcome, ${_currentUser?.email?.split('@')[0] ?? 'User'}!',
              style: TextStyle(
                fontSize: 14, // Smaller font size for username
                color: textOnPrimary.withOpacity(0.8), // Slightly faded
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        showNotificationsIcon: true, // Show bell icon on Dashboard
        totalUnreadCount: _totalUnreadCount,
        onNotificationsTap: () {
          debugPrint('Dashboard: Navigating to SSDHubPage (Messages tab) from CustomAppBar.');
          // Navigate to SSDHubPage and set initial tab to Messages (index 2)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SSDHubPage(initialTabIndex: 0)),
          );
        },
        isAdmin: _isAdmin, // Pass isAdmin to CustomAppBar for MainDrawer
        onLogout: _logout, // Pass logout callback to CustomAppBar for MainDrawer
        leadingWidget: CircleAvatar( // Add profile picture to leading
          backgroundColor: Colors.transparent, // Background of avatar in AppBar
          child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
              ? ClipOval(
            child: Image.network(
              _profileImageUrl!,
              width: 40, // Adjust size as needed
              height: 40, // Adjust size as needed
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading profile image in AppBar: $error');
                return Icon(Icons.account_circle, size: 40, color: textOnPrimary); // Fallback icon
              },
            ),
          )
              : Icon(Icons.account_circle, size: 40, color: textOnPrimary), // Default icon
        ), title: '',
      ),
      endDrawer: MainDrawer( // The MainDrawer itself.
        isAdmin: _isAdmin,
        onLogout: _logout,
        // When a MainDrawer item is tapped, navigate to SSDHubPage and animate to the correct tab.
        onNavigateToHubTab: (index) {
          Navigator.pop(context); // Close the drawer
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SSDHubPage(initialTabIndex: index)),
          );
        },
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
                    final String announcementId = doc.id; // Get document ID

                    final String title = data['title'] ?? 'No Title';
                    final String content = data['content'] ?? 'No Content';
                    final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                    final String createdByEmail = data['createdByEmail'] ?? 'Unknown User'; // FIX: Get email directly from document
                    final int viewCount = data['viewCount'] ?? 0; // NEW: Get view count
                    final int likes = data['likes'] ?? 0; // NEW: Get likes count
                    final List<dynamic> likedBy = data['likedBy'] ?? []; // NEW: Get likedBy array

                    final bool isLikedByCurrentUser = _currentUser != null && likedBy.contains(_currentUser!.uid); // NEW: Check if current user liked

                    final String formattedDate = createdAt != null
                        ? DateFormat('MMM dd,EEE').format(createdAt.toDate())
                        : 'Unknown Date';

                    // NO LONGER NEED FutureBuilder to fetch poster email
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 3,
                      color: backgroundColor, // White card background
                      child: InkWell(
                        onTap: () {
                          debugPrint('Dashboard: Tapped on announcement: $title');
                          _handleAnnouncementTap(announcementId); // Increment view count
                          // Optionally navigate to a detailed announcement page
                          // Navigator.push(
                          //   context,
                          //   MaterialPageRoute(builder: (context) => AnnouncementDetailPage(
                          //     title: title,
                          //     content: content,
                          //     date: formattedDate,
                          //     poster: createdByEmail.split('@')[0], // Use directly from doc
                          //   )),
                          // );
                          _showSnackBar('Announcement: $title (Views: ${viewCount + 1})'); // Show updated views in snackbar
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
                                '$formattedDate by ${createdByEmail.split('@')[0]}', // Display username part of email
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: textOnBackground.withOpacity(0.6), // Even lighter black
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.visibility, size: 18, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text('$viewCount views', style: TextStyle(color: Colors.grey[600])),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                                          color: isLikedByCurrentUser ? Colors.red : Colors.grey[600],
                                          size: 20,
                                        ),
                                        onPressed: () => _toggleLikeAnnouncement(announcementId, likedBy),
                                        padding: EdgeInsets.zero, // Remove default padding
                                        constraints: const BoxConstraints(), // Remove default constraints
                                      ),
                                      Text('$likes likes', style: TextStyle(color: Colors.grey[600])),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            Center( // NEW: See More Announcements Button
              child: ElevatedButton(
                onPressed: () {
                  debugPrint('Dashboard: Navigating to SSDHubPage (Announcements tab) via See More.');
                  // Navigate to SSDHubPage and set initial tab to Announcements (index 1)
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SSDHubPage(initialTabIndex: 1)),
                  );
                },
                child: const Text('See More Announcements'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: textOnPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 30), // Extra space before events
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
                        ? DateFormat('MMM dd, EEE').format(eventDate.toDate())
                        : 'Unknown Date';
                    final String formattedTime = eventDate != null
                        ? DateFormat('hh:mm a').format(eventDate.toDate())
                        : ''; // Format time if present

                    // Fetch user email for display
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(createdBy).get(),
                      builder: (context, userDocSnapshot) {
                        String posterLabel = 'Unknown';
                        if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator(); // optional
                        }

                        if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                          final data = userDocSnapshot.data!.data() as Map<
                              String,
                              dynamic>?;

                          if (data != null) {
                            if (data.containsKey('email') &&
                                data['email'] != null && data['email']
                                .toString()
                                .isNotEmpty) {
                              posterLabel = data['email'];
                            } else if (data.containsKey('displayName') &&
                                data['displayName'] != null &&
                                data['displayName']
                                    .toString()
                                    .isNotEmpty) {
                              posterLabel = data['displayName'];
                            } else if ((data['first'] != null && data['first']
                                .toString()
                                .isNotEmpty) ||
                                (data['last'] != null && data['last']
                                    .toString()
                                    .isNotEmpty)) {
                              String first = data['first'] ?? '';
                              String last = data['last'] ?? '';
                              posterLabel = '$first $last'.trim();
                            }
                          }
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
                                    '$formattedDate ${formattedTime.isNotEmpty ? 'at $formattedTime' : ''} ${location.isNotEmpty ? 'at $location' : ''}',
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
