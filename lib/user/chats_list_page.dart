import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'direct_message_page.dart'; // Import DirectMessagePage to navigate to it
import '../admin/announcement_detail_page.dart'; // Import AnnouncementDetailPage
import 'dart:async'; // Required for StreamController and StreamSubscription

class ChatsListPage extends StatefulWidget {
  const ChatsListPage({super.key});

  @override
  State<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends State<ChatsListPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  late TabController _tabController;

  List<String> _assignedGroups = [];
  List<String> _assignedSubgroups = [];

  // Map to hold the latest QuerySnapshot for each announcement stream (index -> snapshot)
  final Map<int, QuerySnapshot> _latestAnnouncementsSnapshots = {};
  // List to hold subscriptions for announcement streams
  final List<StreamSubscription> _announcementSubscriptions = [];
  // StreamController to emit combined list of announcements
  final StreamController<List<DocumentSnapshot>> _combinedAnnouncementsController =
      StreamController<List<DocumentSnapshot>>.broadcast();


  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _tabController = TabController(length: 2, vsync: this);

    // Add a listener to the TabController to mark announcements as read
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        // If the Announcements tab is selected
        _markAllAnnouncementsAsRead();
      }
    });

    if (_currentUser != null) {
      _fetchUserTroupeAssignments(); // Fetch user's assigned troupes
      _markAllMessagesAsRead(); // Mark all messages as read upon entering the page
      // Announcements will be marked read when their tab is selected
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cancelAllAnnouncementStreams(); // Cancel all announcement subscriptions
    _combinedAnnouncementsController.close(); // Close the controller
    super.dispose();
  }

  // Helper function to update the combined list and add to controller
  void _updateCombinedAnnouncements() {
    // Only emit if all streams have emitted at least once
    // Alternatively, emit what's available and handle potentially empty lists in builder
    if (_latestAnnouncementsSnapshots.length == _getExpectedAnnouncementStreamCount()) {
      final List<DocumentSnapshot> allDocs = [];
      for (final snapshot in _latestAnnouncementsSnapshots.values) {
        allDocs.addAll(snapshot.docs);
      }
      // Sort the combined list by createdAt timestamp
      allDocs.sort((a, b) {
        final Timestamp? aTime = a.data() != null ? (a.data()! as Map<String, dynamic>)['createdAt'] as Timestamp? : null;
        final Timestamp? bTime = b.data() != null ? (b.data()! as Map<String, dynamic>)['createdAt'] as Timestamp? : null;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1; // Nulls last
        if (bTime == null) return -1; // Nulls last
        return bTime.compareTo(aTime);
      });
      _combinedAnnouncementsController.add(allDocs);
    }
  }

  // Helper to get the expected number of announcement streams
  int _getExpectedAnnouncementStreamCount() {
    // 1 (global) + assignedGroups.length + assignedSubgroups.length
    return 1 + _assignedGroups.length + _assignedSubgroups.length;
  }

  // Function to mark all unread messages for the current user as read
  Future<void> _markAllMessagesAsRead() async {
    if (_currentUser == null) return;

    try {
      debugPrint('ChatsListPage: Marking all messages as read for user ${_currentUser!.uid}.');
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'unreadMessageCount': 0,
      });
      debugPrint('ChatsListPage: Unread message count reset to 0.');
    } catch (e) {
      debugPrint('ChatsListPage Error: Failed to reset unread message count: $e');
    }
  }

  // NEW: Function to mark all unread announcements for the current user as read
  Future<void> _markAllAnnouncementsAsRead() async {
    if (_currentUser == null) return;

    try {
      debugPrint('ChatsListPage: Marking all announcements as read for user ${_currentUser!.uid}.');
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'unreadAnnouncementCount': 0,
      });
      debugPrint('ChatsListPage: Unread announcement count reset to 0.');
    } catch (e) {
      debugPrint('ChatsListPage Error: Failed to reset unread announcement count: $e');
    }
  }

  // NEW: Fetch user's assigned groups and subgroups and set up announcement listeners
  Future<void> _fetchUserTroupeAssignments() async {
    if (_currentUser == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _assignedGroups = List<String>.from(userData?['assignedGroups'] ?? []);
          _assignedSubgroups = List<String>.from(userData?['assignedSubgroups'] ?? []);
        });
        debugPrint('ChatsListPage: User ${_currentUser!.uid} assigned to groups: $_assignedGroups, subgroups: $_assignedSubgroups');
        _setupAnnouncementStreams(); // Set up streams AFTER fetching assignments
      }
    } catch (e) {
      debugPrint('ChatsListPage Error: Failed to fetch user troupe assignments: $e');
    }
  }

  // NEW: Setup listeners for all relevant announcement streams
  void _setupAnnouncementStreams() {
    _cancelAllAnnouncementStreams(); // Cancel existing first

    final List<Stream<QuerySnapshot>> streamsToListen = [];

    // Global announcements
    streamsToListen.add(_firestore.collection('announcements').snapshots());

    // Parent troupe announcements
    for (String groupId in _assignedGroups) {
      streamsToListen.add(_firestore.collection('troupes').doc(groupId).collection('announcements').snapshots());
    }

    // Sub-troupe announcements
    for (String subgroupId in _assignedSubgroups) {
      streamsToListen.add(_firestore.collection('troupes').doc(subgroupId).collection('announcements').snapshots());
    }

    // Subscribe to each stream and update the map
    for (int i = 0; i < streamsToListen.length; i++) {
      _announcementSubscriptions.add(streamsToListen[i].listen((snapshot) {
        _latestAnnouncementsSnapshots[i] = snapshot;
        _updateCombinedAnnouncements();
      }, onError: (error) {
        _combinedAnnouncementsController.addError(error);
        debugPrint('ChatsListPage Error: Announcement stream error: $error');
      }));
    }
  }

  // NEW: Cancel all active announcement stream subscriptions
  void _cancelAllAnnouncementStreams() {
    for (var sub in _announcementSubscriptions) {
      sub.cancel();
    }
    _announcementSubscriptions.clear();
    _latestAnnouncementsSnapshots.clear(); // Clear cached snapshots as well
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
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.onPrimary, // White for selected tab
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7), // Lighter white for unselected
          indicatorColor: Theme.of(context).colorScheme.onPrimary, // White indicator
          tabs: const [
            Tab(text: 'Messages'),
            Tab(text: 'Announcements'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Direct Messages List
          _buildDirectMessagesList(primaryColor, textOnBackground, backgroundColor),
          // Tab 2: Announcements List
          _buildAnnouncementsList(primaryColor, textOnBackground, backgroundColor),
        ],
      ),
    );
  }

  Widget _buildDirectMessagesList(Color primaryColor, Color textOnBackground, Color backgroundColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chat_rooms')
          .where('participants', arrayContains: _currentUser!.uid)
          .orderBy('lastMessageTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ChatsListPage Direct Messages Error: ${snapshot.error}');
          return Center(child: Text('Error loading chats: ${snapshot.error}', style: TextStyle(color: primaryColor)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No direct messages yet. Start a conversation from a post!',
              style: TextStyle(fontSize: 16, color: textOnBackground.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot chatRoomDoc = snapshot.data!.docs[index];
            Map<String, dynamic> chatRoomData = chatRoomDoc.data() as Map<String, dynamic>;

            final List<dynamic> participants = chatRoomData['participants'] ?? [];
            String otherParticipantUid = participants.firstWhere(
              (uid) => uid != _currentUser!.uid,
              orElse: () => '', // Should not happen in a valid 2-person chat
            );

            final String lastMessage = chatRoomData['lastMessage'] ?? 'No messages yet';
            final Timestamp? lastMessageTimestamp = chatRoomData['lastMessageTimestamp'] as Timestamp?;
            final String formattedTime = lastMessageTimestamp != null ?
                DateFormat('MMM dd, hh:mm a').format(lastMessageTimestamp.toDate())
                : 'No Date';

            // Fetch the other participant's display name or email for the chat list tile
            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(otherParticipantUid).get(),
              builder: (context, userDocSnapshot) {
                String chatDisplayName = 'Unknown User';
                if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                  final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
                  chatDisplayName = userData['displayName'] ?? userData['email'] ?? 'Unknown User';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: backgroundColor,
                  child: InkWell(
                    onTap: () async {
                      debugPrint('ChatsListPage: Tapped on chat with $chatDisplayName (UID: $otherParticipantUid).');
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DirectMessagePage(
                            recipientUid: otherParticipantUid,
                            recipientEmail: chatDisplayName,
                          ),
                        ),
                      );
                      // On return from chat, mark all messages as read again.
                      // This ensures the badge updates if new messages arrived while in chat
                      // or if user navigated directly.
                      _markAllMessagesAsRead();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: primaryColor.withOpacity(0.2),
                            radius: 25,
                            child: Icon(Icons.person, color: primaryColor),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chatDisplayName.split('@')[0], // Show username part of email
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastMessage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textOnBackground.withOpacity(0.8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textOnBackground.withOpacity(0.6),
                                ),
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
        );
      },
    );
  }

  // NEW: Widget to build the Announcements list
  Widget _buildAnnouncementsList(Color primaryColor, Color textOnBackground, Color backgroundColor) {
    if (_assignedGroups.isEmpty && _assignedSubgroups.isEmpty) {
      return Center(
        child: Text(
          'You are not assigned to any troupes or sub-troupes to see specific announcements.',
          style: TextStyle(fontSize: 16, color: textOnBackground.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
      );
    }

    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _combinedAnnouncementsController.stream, // Listen to the combined stream
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ChatsListPage Announcements Error: ${snapshot.error}');
          return Center(child: Text('Error loading announcements: ${snapshot.error}', style: TextStyle(color: primaryColor)));
        }
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.data == null) {
          // Show loading if waiting or if data is null (streams haven't emitted yet)
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        final List<DocumentSnapshot> allAnnouncementDocs = snapshot.data!;

        if (allAnnouncementDocs.isEmpty) {
          return Center(
            child: Text(
              'No announcements found for your assigned troupes.',
              style: TextStyle(fontSize: 16, color: textOnBackground.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: allAnnouncementDocs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot doc = allAnnouncementDocs[index];
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

            final String title = data['title'] ?? 'No Title';
            final String content = data['content'] ?? 'No Content';
            final Timestamp? createdAt = data['createdAt'] as Timestamp?;
            final String createdByEmail = data['createdByEmail'] ?? 'Unknown User'; // Get email from saved data
            final String? parentTroupeName = data['parentTroupeName'];
            final String? subTroupeName = data['subTroupeName'];

            final String formattedDate = createdAt != null
                ? DateFormat('MMM dd, EEEE \'at\' hh:mm a').format(createdAt.toDate())
                : 'Unknown Date';

            String postedTo = 'Global Dashboard';
            if (parentTroupeName != null && subTroupeName != null) {
              postedTo = '$parentTroupeName > $subTroupeName';
            } else if (parentTroupeName != null) {
              postedTo = parentTroupeName;
            }

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 3,
              color: backgroundColor,
              child: InkWell(
                onTap: () {
                  debugPrint('ChatsListPage: Tapped on announcement: $title');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AnnouncementDetailPage(
                        title: title,
                        content: content,
                        date: formattedDate,
                        poster: createdByEmail.split('@')[0], // Pass username part of email
                      ),
                    ),
                  );
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
                        content,
                        style: TextStyle(
                          fontSize: 14,
                          color: textOnBackground.withOpacity(0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Posted to: $postedTo by ${createdByEmail.split('@')[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: textOnBackground.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        formattedDate,
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
  }
}
