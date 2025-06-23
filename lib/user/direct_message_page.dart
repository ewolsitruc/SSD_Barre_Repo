import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class DirectMessagePage extends StatefulWidget {
  final String recipientUid;
  final String recipientEmail;

  const DirectMessagePage({
    super.key,
    required this.recipientUid,
    required this.recipientEmail,
  });

  @override
  State<DirectMessagePage> createState() => _DirectMessagePageState();
}

class _DirectMessagePageState extends State<DirectMessagePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    // When a user opens a chat, mark messages from this specific sender as read
    // or reset the global unread count if this is the primary way to clear it.
    // For simplicity, we reset the global unread count on entering ChatsListPage.
    // If you need per-chat unread counts, that would be a separate logic.
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Function to determine a consistent chat ID between two users
  // This ensures that messages between A and B are in the same conversation document,
  // regardless of who initiates the chat.
  String _getChatRoomId(String user1Uid, String user2Uid) {
    // Sort UIDs alphabetically to create a consistent ID
    List<String> uids = [user1Uid, user2Uid];
    uids.sort();
    return uids.join('_'); // e.g., 'uid1_uid2'
  }

  Future<void> _sendMessage() async {
    final messageContent = _messageController.text.trim();
    if (messageContent.isEmpty) {
      return;
    }

    if (_currentUser == null) {
      _showSnackBar('You must be logged in to send a message.');
      return;
    }

    final String chatRoomId = _getChatRoomId(_currentUser!.uid, widget.recipientUid);

    try {
      debugPrint('DirectMessagePage: Sending message to chat room: $chatRoomId');
      await _firestore.collection('chat_rooms').doc(chatRoomId).collection('messages').add({
        'senderUid': _currentUser!.uid,
        'senderEmail': _currentUser!.email,
        'recipientUid': widget.recipientUid,
        'recipientEmail': widget.recipientEmail,
        'content': messageContent,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the main chat_room document with last message info for easy overview
      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'lastMessage': messageContent,
        'lastMessageSenderUid': _currentUser!.uid,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'participants': [_currentUser!.uid, widget.recipientUid], // Ensure participants are always present
      }, SetOptions(merge: true)); // Use merge to avoid overwriting other fields

      // The recipient's unreadMessageCount is now incremented by a Firebase Cloud Function.
      // The following client-side increment logic has been REMOVED to prevent permission denied errors.
      // Removed block:
      // if (_currentUser!.uid != widget.recipientUid) {
      //   await _firestore.collection('users').doc(widget.recipientUid).update({
      //     'unreadMessageCount': FieldValue.increment(1),
      //   });
      //   debugPrint('DirectMessagePage: Incremented unread message count for recipient ${widget.recipientEmail}.');
      // }

      _messageController.clear();
    } catch (e) {
      _showSnackBar('Failed to send message: $e');
      debugPrint('DirectMessagePage Error: Failed to send message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;
    // Correctly get textOnPrimary from the theme
    final Color textOnPrimary = Theme.of(context).colorScheme.onPrimary;

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Message ${widget.recipientEmail}')),
        body: Center(
          child: Text(
            'Please log in to send messages.',
            style: TextStyle(color: textOnBackground),
          ),
        ),
      );
    }

    final String chatRoomId = _getChatRoomId(_currentUser!.uid, widget.recipientUid);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.recipientEmail}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Show latest messages at the bottom
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading messages: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hello to ${widget.recipientEmail}!',
                      style: TextStyle(color: textOnBackground.withOpacity(0.7)),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true, // Display latest messages at the bottom
                  padding: const EdgeInsets.all(16.0),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot messageDoc = snapshot.data!.docs[index];
                    Map<String, dynamic> messageData = messageDoc.data() as Map<String, dynamic>;

                    final String senderUid = messageData['senderUid'] ?? '';
                    final String senderEmail = messageData['senderEmail'] ?? 'Unknown Sender';
                    final String content = messageData['content'] ?? '';
                    final Timestamp? timestamp = messageData['timestamp'] as Timestamp?;

                    final bool isMe = senderUid == _currentUser!.uid;
                    final String formattedTime = timestamp != null ?
                        DateFormat('hh:mm a').format(timestamp.toDate())
                        : '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: isMe ? primaryColor.withOpacity(0.9) : backgroundColor.withOpacity(0.9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(15),
                            topRight: Radius.circular(15),
                            bottomLeft: isMe ? Radius.circular(15) : Radius.circular(0),
                            bottomRight: isMe ? Radius.circular(0) : Radius.circular(15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? 'You' : senderEmail.split('@')[0], // Show 'You' or just username part of email
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isMe ? textOnPrimary : primaryColor, // White for "You", Red for others
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              content,
                              style: TextStyle(
                                color: isMe ? textOnPrimary : textOnBackground, // White for "You", Black for others
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe ? textOnPrimary.withOpacity(0.7) : textOnBackground.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      filled: true,
                      fillColor: backgroundColor,
                    ),
                    maxLines: null,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  mini: false,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
