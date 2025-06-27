import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:intl/intl.dart';

// Your app imports (adjust paths if needed)
import '../user/direct_message_page.dart';
import '../user/select_recipient_page.dart';

class AllDirectMessagesPage extends StatefulWidget {
  const AllDirectMessagesPage({super.key});

  @override
  State<AllDirectMessagesPage> createState() => _AllDirectMessagesPageState();
}

class _AllDirectMessagesPageState extends State<AllDirectMessagesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  // Stream that fetches and processes the user's chat metadata and chat room info
  Stream<List<Map<String, dynamic>>>? _chatRoomsStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      debugPrint('AllDirectMessagesPage: No current user, navigation needed.');
      // Handle navigation to login if desired
    } else {
      _setupChatRoomsStream(_currentUser!.uid);
    }
  }

  void _setupChatRoomsStream(String uid) {
    debugPrint('AllDirectMessagesPage: Setting up user_chats listener for $uid');

    _chatRoomsStream = _firestore
        .collection('users')
        .doc(uid)
        .collection('user_chats')
        .snapshots()
        .asyncMap((userChatsSnapshot) async {
      debugPrint('AllDirectMessagesPage: user_chats snapshot with ${userChatsSnapshot.docs.length} docs');

      // For each chatRoomId in user_chats, fetch detailed chat_room data
      final futures = userChatsSnapshot.docs.map((userChatDoc) async {
        final chatRoomId = userChatDoc.id;
        debugPrint('AllDirectMessagesPage: Processing chatRoomId $chatRoomId');

        final chatRoomDoc = await _firestore.collection('chat_rooms').doc(chatRoomId).get();

        if (!chatRoomDoc.exists) {
          debugPrint('AllDirectMessagesPage: chat_room $chatRoomId does not exist');
          return <String, dynamic>{};
        }

        final chatRoomData = chatRoomDoc.data()!;
        final List<dynamic> participants = chatRoomData['participants'] ?? [];

        // Find the other participant UID (not current user)
        final otherParticipantUid = participants.firstWhere(
              (uidCandidate) => uidCandidate != uid,
          orElse: () => uid, // fallback to self if no other participant found
        );

        // Fetch other participant user data
        String otherParticipantEmail = 'Unknown User';
        try {
          final otherUserDoc = await _firestore.collection('users').doc(otherParticipantUid).get();
          if (otherUserDoc.exists) {
            otherParticipantEmail = otherUserDoc.data()?['email'] ?? 'Unknown User';
          }
        } catch (e) {
          debugPrint('AllDirectMessagesPage: Failed to fetch other user $otherParticipantUid data: $e');
        }

        // Use updated field names from chat_rooms doc for last message
        final String lastMessageContent = chatRoomData['lastMessageContent'] ?? 'No messages yet.';
        final Timestamp? lastMessageTimestamp = chatRoomData['lastMessageAt'] as Timestamp?;

        return {
          'chatRoomId': chatRoomId,
          'otherParticipantUid': otherParticipantUid,
          'otherParticipantEmail': otherParticipantEmail,
          'displayName': otherParticipantEmail.split('@')[0],
          'lastMessageContent': lastMessageContent,
          'lastMessageTimestamp': lastMessageTimestamp,
        };
      }).toList();

      final results = await Future.wait(futures);
      return results.where((map) => map.isNotEmpty).toList();
    });

    if (mounted) {
      setState(() {}); // Trigger rebuild to listen to stream
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Direct Messages')),
        body: Center(
          child: Text(
            'Please log in to view your direct messages.',
            style: TextStyle(color: textOnBackground),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Direct Messages')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Your current direct message conversations:',
              style: TextStyle(fontSize: 16, color: textOnBackground),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatRoomsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('AllDirectMessagesPage Stream Error: ${snapshot.error}');
                  return Center(child: Text('Error loading chat rooms: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No direct messages yet. Tap the + button to start a new conversation!',
                      style: TextStyle(fontSize: 16, color: textOnBackground.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                // Sort chats by last message timestamp descending
                final chatRooms = snapshot.data!;
                chatRooms.sort((a, b) {
                  final aTime = a['lastMessageTimestamp'] as Timestamp?;
                  final bTime = b['lastMessageTimestamp'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  itemCount: chatRooms.length,
                  itemBuilder: (context, index) {
                    final chat = chatRooms[index];
                    final chatRoomId = chat['chatRoomId'] as String;
                    final displayName = chat['displayName'] as String;
                    final otherParticipantUid = chat['otherParticipantUid'] as String;
                    final otherParticipantEmail = chat['otherParticipantEmail'] as String;
                    final lastMessageContent = chat['lastMessageContent'] as String;
                    final lastMessageTimestamp = chat['lastMessageTimestamp'] as Timestamp?;

                    final formattedTime = lastMessageTimestamp != null
                        ? DateFormat('MMM dd, hh:mm a').format(lastMessageTimestamp.toDate())
                        : 'No messages';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 3,
                      color: backgroundColor,
                      child: InkWell(
                        onTap: () {
                          debugPrint('Navigating to chatRoomId $chatRoomId');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DirectMessagePage(
                                recipientUid: otherParticipantUid,
                                recipientEmail: otherParticipantEmail,
                                chatRoomId: chatRoomId,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textOnBackground.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                lastMessageContent,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textOnBackground.withOpacity(0.8),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          debugPrint('Navigating to SelectRecipientPage');
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SelectRecipientPage()),
          );
        },
        backgroundColor: primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        tooltip: 'Start a new direct message',
        child: const Icon(Icons.add),
      ),
    );
  }
}
