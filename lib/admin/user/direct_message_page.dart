import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class DirectMessagePage extends StatefulWidget {
  final String recipientUid;
  final String recipientEmail;
  final String? chatRoomId;

  const DirectMessagePage({
    super.key,
    required this.recipientUid,
    required this.recipientEmail,
    this.chatRoomId,
  });

  @override
  State<DirectMessagePage> createState() => _DirectMessagePageState();
}

class _DirectMessagePageState extends State<DirectMessagePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();

  User? _currentUser;
  String? _chatRoomId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;

    if (widget.chatRoomId != null && widget.chatRoomId!.isNotEmpty) {
      _chatRoomId = widget.chatRoomId!;
      _isLoading = false;
    } else {
      _initializeChatRoomId();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _generateChatRoomId(String uid1, String uid2) {
    final List<String> sorted = [uid1, uid2]..sort();
    return sorted.join('_');
  }

  Future<void> _initializeChatRoomId() async {
    if (_currentUser == null) {
      debugPrint('No logged-in user found.');
      if (mounted) Navigator.pop(context);
      return;
    }

    final generatedId =
    _generateChatRoomId(_currentUser!.uid, widget.recipientUid);
    setState(() {
      _chatRoomId = generatedId;
      _isLoading = false;
    });

    debugPrint('Initialized chat room ID: $_chatRoomId');
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      _showSnackBar('Message cannot be empty.');
      return;
    }

    if (_currentUser == null) {
      _showSnackBar('User not authenticated.');
      return;
    }

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendDirectMessage')
          .call({
        'recipientUid': widget.recipientUid,
        'content': content,
      });

      final chatRoomId = result.data['chatRoomId'];
      setState(() {
        _chatRoomId = chatRoomId;
      });

      _messageController.clear();
      debugPrint('Message sent to room: $chatRoomId');
    } catch (e) {
      debugPrint('Send message failed: $e');
      _showSnackBar('Failed to send message.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onBackground = Theme.of(context).colorScheme.onBackground;

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Direct Message')),
        body: Center(
          child: Text(
            'Please log in to send messages.',
            style: TextStyle(color: onBackground),
          ),
        ),
      );
    }

    if (_isLoading || _chatRoomId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Chat with ${widget.recipientEmail.split('@')[0]}'),
        ),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.recipientEmail.split('@')[0]}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chat_rooms')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: primaryColor),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hello to start the conversation!',
                      style: TextStyle(color: onBackground.withOpacity(0.6)),
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data()! as Map<String, dynamic>;
                    final isMe = data['senderUid'] == _currentUser!.uid;
                    final time = (data['timestamp'] as Timestamp?)?.toDate();
                    final formatted =
                    time != null ? DateFormat('hh:mm a').format(time) : '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? primaryColor : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['content'],
                              style: TextStyle(
                                color: isMe ? Colors.white : onBackground,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatted,
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white70
                                    : onBackground.withOpacity(0.6),
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
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  mini: true,
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
