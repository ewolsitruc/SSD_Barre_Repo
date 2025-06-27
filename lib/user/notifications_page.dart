import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:ssd_barre_new/user/user_data_service.dart'; // For unread count management
import 'package:ssd_barre_new/admin/announcement_detail_page.dart'; // To show announcement details
import 'package:ssd_barre_new/admin/troupe_content_page.dart'; // To navigate to troupe content if needed
import 'package:ssd_barre_new/user/direct_message_page.dart'; // NEW IMPORT: To navigate to DirectMessagePage
import 'dart:async';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();
  User? _currentUser;

  List<String> _assignedParentTroupeIds = [];
  List<String> _assignedSubTroupeIds = [];

  // Map to hold the latest QuerySnapshot for each announcement stream (index -> snapshot)
  final Map<int, QuerySnapshot> _latestAnnouncementsSnapshots = {};
  // List to hold subscriptions for announcement streams
  final List<StreamSubscription> _announcementSubscriptions = [];
  // StreamController to emit combined list of announcements
  final StreamController<List<DocumentSnapshot>> _combinedAnnouncementsController =
  StreamController<List<DocumentSnapshot>>.broadcast();

  // StreamController for messages, if integrated here
  final StreamController<List<DocumentSnapshot>> _combinedMessagesController =
  StreamController<List<DocumentSnapshot>>.broadcast();
  List<StreamSubscription> _messageSubscriptions = [];
  final Map<String, QuerySnapshot> _latestMessagesSnapshots = {}; // Changed key to String (chatRoomId)


  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      debugPrint('NotificationsPage: No current user logged in.');
    } else {
      _fetchUserTroupeAssignments(); // Fetch user's assigned troupes to set up relevant streams
      _markAllNotificationsAsRead(); // Mark all notifications as read when entering the page
    }
  }

  @override
  void dispose() {
    _cancelAllAnnouncementStreams();
    _combinedAnnouncementsController.close();
    _cancelAllMessageStreams();
    _combinedMessagesController.close();
    super.dispose();
  }

  // --- Utility Functions for Notifications ---
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Function to mark all unread counts for the current user as read
  Future<void> _markAllNotificationsAsRead() async {
    if (_currentUser == null) return;

    try {
      debugPrint('NotificationsPage: Marking all notifications as read for user ${_currentUser!.uid}.');
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'unreadMessageCount': 0,
        'unreadAnnouncementCount': 0,
        'unreadJoinRequestCount': 0, // In case admin logs in as user and wants to clear their own
      });
      debugPrint('NotificationsPage: All unread counts reset to 0.');
    } catch (e) {
      debugPrint('NotificationsPage Error: Failed to reset unread counts: $e');
    }
  }

  // --- Announcement Stream Management ---

  // Helper to get the expected number of announcement streams
  int _getExpectedAnnouncementStreamCount() {
    return 1 + _assignedParentTroupeIds.length + _assignedSubTroupeIds.length;
  }

  // Helper function to update the combined announcement list and add to controller
  void _updateCombinedAnnouncements() {
    final List<DocumentSnapshot> allDocs = [];
    for (final snapshot in _latestAnnouncementsSnapshots.values) {
      allDocs.addAll(snapshot.docs);
    }
    // Sort the combined list by createdAt timestamp (latest first)
    allDocs.sort((a, b) {
      final Timestamp? aTime = a.data() != null ? (a.data()! as Map<String, dynamic>)['createdAt'] as Timestamp? : null;
      final Timestamp? bTime = b.data() != null ? (b.data()! as Map<String, dynamic>)['createdAt'] as Timestamp? : null;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    _combinedAnnouncementsController.add(allDocs);
  }

  // Setup listeners for all relevant announcement streams
  void _setupAnnouncementStreams() {
    _cancelAllAnnouncementStreams(); // Cancel existing first

    final List<Stream<QuerySnapshot>> streamsToListen = [];

    // Global announcements
    streamsToListen.add(_firestore.collection('announcements').snapshots());

    // Parent troupe announcements
    for (String groupId in _assignedParentTroupeIds) {
      streamsToListen.add(_firestore.collection('troupes').doc(groupId).collection('announcements').snapshots());
    }

    // Sub-troupe announcements
    for (String subgroupId in _assignedSubTroupeIds) {
      streamsToListen.add(_firestore.collection('troupes').doc(subgroupId).collection('announcements').snapshots());
    }

    for (int i = 0; i < streamsToListen.length; i++) {
      _announcementSubscriptions.add(streamsToListen[i].listen((snapshot) {
        _latestAnnouncementsSnapshots[i] = snapshot;
        _updateCombinedAnnouncements();
      }, onError: (error) {
        _combinedAnnouncementsController.addError(error);
        debugPrint('NotificationsPage Error: Announcement stream error: $error');
      }));
    }
    debugPrint('NotificationsPage: Set up ${streamsToListen.length} announcement streams.');
  }

  // Cancel all active announcement stream subscriptions
  void _cancelAllAnnouncementStreams() {
    for (var sub in _announcementSubscriptions) {
      sub.cancel();
    }
    _announcementSubscriptions.clear();
    _latestAnnouncementsSnapshots.clear();
    debugPrint('NotificationsPage: Cancelled all announcement streams.');
  }

  // --- Message Stream Management ---

  // Helper to get a consistent chat room ID (already exists, but kept for clarity)
  String _getChatRoomId(String user1Uid, String user2Uid) {
    List<String> uids = [user1Uid, user2Uid];
    uids.sort();
    return uids.join('_');
  }

  // Helper function to update the combined message list
  void _updateCombinedMessages() {
    final List<DocumentSnapshot> allMessages = [];
    for (final snapshot in _latestMessagesSnapshots.values) {
      allMessages.addAll(snapshot.docs);
    }
    allMessages.sort((a, b) {
      final Timestamp? aTime = a.data() != null ? (a.data()! as Map<String, dynamic>)['timestamp'] as Timestamp? : null;
      final Timestamp? bTime = b.data() != null ? (b.data()! as Map<String, dynamic>)['timestamp'] as Timestamp? : null;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    _combinedMessagesController.add(allMessages);
  }

  // Setup listeners for direct messages using the new user_chats subcollection
  void _setupMessageStreams() {
    _cancelAllMessageStreams();

    if (_currentUser == null) return;

    // Listen to the user_chats subcollection to get all chatRoomIds the current user is part of
    _messageSubscriptions.add(
      _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('user_chats')
          .snapshots()
          .listen((userChatsSnapshot) {
        // Clear previous message snapshots and subscriptions
        _cancelAllMessageStreams(excludeUserChatsStream: true); // Exclude the current user_chats stream

        List<Stream<QuerySnapshot>> chatMessageStreams = [];
        for (var chatRoomRefDoc in userChatsSnapshot.docs) {
          final String chatRoomId = chatRoomRefDoc.id; // The document ID is the chatRoomId
          chatMessageStreams.add(
            _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').snapshots(),
          );
        }

        // Now, set up listeners for each of these chat message streams
        for (int i = 0; i < chatMessageStreams.length; i++) {
          _messageSubscriptions.add(chatMessageStreams[i].listen((messageSnapshot) {
            _latestMessagesSnapshots[userChatsSnapshot.docs[i].id] = messageSnapshot; // Use chatRoomId as key
            _updateCombinedMessages();
          }, onError: (error) {
            _combinedMessagesController.addError(error);
            debugPrint('NotificationsPage Error: Message stream error: $error');
          }));
        }
        debugPrint('NotificationsPage: Set up ${chatMessageStreams.length} message streams based on user_chats.');
      }, onError: (error) {
        debugPrint('NotificationsPage Error: User chats stream error: $error');
      }),
    );
  }

  void _cancelAllMessageStreams({bool excludeUserChatsStream = false}) {
    // Cancel all subscriptions except the first one (which is for user_chats) if exclude is true
    for (int i = 0; i < _messageSubscriptions.length; i++) {
      if (excludeUserChatsStream && i == 0) { // Assuming the first subscription is always user_chats
        continue;
      }
      _messageSubscriptions[i].cancel();
    }
    // If excluding user_chats, keep its subscription in the list
    if (excludeUserChatsStream && _messageSubscriptions.isNotEmpty) {
      _messageSubscriptions = [_messageSubscriptions.first];
    } else {
      _messageSubscriptions.clear();
    }
    _latestMessagesSnapshots.clear();
    debugPrint('NotificationsPage: Cancelled all message streams (excludeUserChatsStream: $excludeUserChatsStream).');
  }

  // --- Fetch User Assignments & Setup All Streams ---
  Future<void> _fetchUserTroupeAssignments() async {
    if (_currentUser == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _assignedParentTroupeIds = List<String>.from(userData?['assignedGroups'] ?? []);
          _assignedSubTroupeIds = List<String>.from(userData?['assignedSubgroups'] ?? []);
        });
        debugPrint('NotificationsPage: User ${_currentUser!.uid} assigned to groups: $_assignedParentTroupeIds, subgroups: $_assignedSubTroupeIds');
        _setupAnnouncementStreams(); // Set up streams AFTER fetching assignments
        _setupMessageStreams(); // Set up message streams too
      }
    } catch (e) {
      debugPrint('NotificationsPage Error: Failed to fetch user troupe assignments: $e');
    }
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
      ),
      body: DefaultTabController(
        length: 2, // Tabs for Announcements and Messages
        child: Column(
          children: [
            TabBar(
              labelColor: primaryColor,
              unselectedLabelColor: textOnBackground.withOpacity(0.7),
              indicatorColor: primaryColor,
              tabs: const [
                Tab(text: 'Announcements', icon: Icon(Icons.announcement)),
                Tab(text: 'Messages', icon: Icon(Icons.message)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Announcements Tab Content
                  StreamBuilder<List<DocumentSnapshot>>(
                    stream: _combinedAnnouncementsController.stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        debugPrint('NotificationsPage Announcements Tab Error: ${snapshot.error}');
                        return Center(child: Text('Error loading announcements: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting || snapshot.data == null) {
                        return Center(child: CircularProgressIndicator(color: primaryColor));
                      }

                      final List<DocumentSnapshot> allAnnouncementDocs = snapshot.data!;

                      if (allAnnouncementDocs.isEmpty) {
                        return Center(
                          child: Text(
                            'No announcements yet.',
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
                          final String createdByEmail = data['createdByEmail'] ?? 'Unknown User';
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
                                debugPrint('NotificationsPage: Tapped on announcement: $title');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AnnouncementDetailPage(
                                      title: title,
                                      content: content,
                                      date: formattedDate,
                                      poster: createdByEmail.split('@')[0],
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
                  ),

                  // Messages Tab Content
                  StreamBuilder<List<DocumentSnapshot>>(
                    stream: _combinedMessagesController.stream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        debugPrint('NotificationsPage Messages Tab Error: ${snapshot.error}');
                        return Center(child: Text('Error loading messages: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting || snapshot.data == null) {
                        return Center(child: CircularProgressIndicator(color: primaryColor));
                      }

                      final List<DocumentSnapshot> allMessageDocs = snapshot.data!;

                      if (allMessageDocs.isEmpty) {
                        return Center(
                          child: Text(
                            'No messages yet.',
                            style: TextStyle(fontSize: 16, color: textOnBackground.withOpacity(0.7)),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      // Deduplicate messages by chat room to show only the latest message per chat
                      final Map<String, DocumentSnapshot> latestMessagesPerChat = {};
                      for (var msgDoc in allMessageDocs) {
                        final String chatRoomId = msgDoc.reference.parent.parent!.id; // Get chat_room ID
                        final Timestamp? currentTimestamp = msgDoc.data() != null ? (msgDoc.data()! as Map<String, dynamic>)['timestamp'] as Timestamp? : null;

                        if (latestMessagesPerChat.containsKey(chatRoomId)) {
                          final Timestamp? existingTimestamp = latestMessagesPerChat[chatRoomId]?.data() != null ? (latestMessagesPerChat[chatRoomId]?.data()! as Map<String, dynamic>)['timestamp'] as Timestamp? : null;
                          if (currentTimestamp != null && (existingTimestamp == null || currentTimestamp.compareTo(existingTimestamp) > 0)) {
                            latestMessagesPerChat[chatRoomId] = msgDoc;
                          }
                        } else {
                          latestMessagesPerChat[chatRoomId] = msgDoc;
                        }
                      }

                      final List<DocumentSnapshot> displayMessages = latestMessagesPerChat.values.toList();
                      displayMessages.sort((a, b) {
                        final Timestamp? aTime = a.data() != null ? (a.data()! as Map<String, dynamic>)['timestamp'] as Timestamp? : null;
                        final Timestamp? bTime = b.data() != null ? (b.data()! as Map<String, dynamic>)['timestamp'] as Timestamp? : null;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });


                      return ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: displayMessages.length,
                        itemBuilder: (context, index) {
                          DocumentSnapshot doc = displayMessages[index];
                          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                          final String senderUid = data['senderUid'] ?? '';
                          final String senderEmail = data['senderEmail'] ?? 'Unknown Sender';
                          final String content = data['content'] ?? '';
                          final Timestamp? timestamp = data['timestamp'] as Timestamp?;

                          final String chatPartnerEmail = senderUid == _currentUser!.uid
                              ? (data['recipientEmail'] ?? 'You')
                              : senderEmail;

                          final String formattedTime = timestamp != null
                              ? DateFormat('hh:mm a, MMM dd').format(timestamp.toDate())
                              : 'Unknown Time';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 3,
                            color: backgroundColor,
                            child: InkWell(
                              onTap: () async { // Made onTap async
                                debugPrint('NotificationsPage: Tapped on message from/to: $chatPartnerEmail');
                                // Retrieve the chat_room document to get participants
                                final String chatRoomId = doc.reference.parent.parent!.id;
                                final chatRoomDocSnapshot = await _firestore.collection('chat_rooms').doc(chatRoomId).get();

                                if (chatRoomDocSnapshot.exists && chatRoomDocSnapshot.data() != null) {
                                  final List<dynamic> participants = chatRoomDocSnapshot.data()!['participants'] ?? [];
                                  final String otherParticipantUid = participants.firstWhere((uid) => uid != _currentUser!.uid);

                                  // You'll need to fetch the recipient's email using their UID
                                  String actualRecipientEmail = chatPartnerEmail; // Default to existing
                                  if (otherParticipantUid != _currentUser!.uid) { // If the other participant is not the current user
                                    try {
                                      final otherUserDoc = await _firestore.collection('users').doc(otherParticipantUid).get();
                                      if (otherUserDoc.exists && otherUserDoc.data() != null) {
                                        actualRecipientEmail = otherUserDoc.data()!['email'] ?? chatPartnerEmail;
                                      }
                                    } catch (e) {
                                      debugPrint('NotificationsPage Error: Could not fetch recipient email: $e');
                                    }
                                  }


                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DirectMessagePage(
                                        recipientUid: otherParticipantUid,
                                        recipientEmail: actualRecipientEmail, chatRoomId: '',
                                      ),
                                    ),
                                  );
                                } else {
                                  debugPrint('NotificationsPage Error: Chat room document not found or invalid data for $chatRoomId');
                                  _showSnackBar('Could not open chat. Chat room data not found.');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderUid == _currentUser!.uid ? 'Message to: ${chatPartnerEmail.split('@')[0]}' : 'Message from: ${chatPartnerEmail.split('@')[0]}',
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
                                      formattedTime,
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
