import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'user_data_service.dart'; // To get user email for comments
import 'package:flutter/foundation.dart'; // For debugPrint
import 'direct_message_page.dart'; // Import the new DirectMessagePage

class PostDetailPage extends StatefulWidget {
  final String postId;
  final String troupeId; // Passed for potential future use (e.g., related posts)
  final String troupeName; // Passed for display in AppBar

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.troupeId,
    required this.troupeName,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();
  final TextEditingController _commentController = TextEditingController();
  User? _currentUser;
  bool _isLoadingComment = false;
  bool _isAdmin = false; // Add _isAdmin state

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _checkAdminStatus(); // Check admin status on init
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Check admin status for conditional UI
  Future<void> _checkAdminStatus() async {
    if (_currentUser != null) {
      final currentIsAdmin = await _userDataService.isUserAdmin(_currentUser!.uid);
      if (mounted) {
        setState(() {
          _isAdmin = currentIsAdmin;
        });
      }
    }
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _addComment() async {
    final commentContent = _commentController.text.trim();
    if (commentContent.isEmpty) {
      _showSnackBar('Comment cannot be empty.');
      return;
    }

    if (_currentUser == null) {
      _showSnackBar('You must be logged in to comment.');
      return;
    }

    setState(() {
      _isLoadingComment = true;
    });

    try {
      // Add comment to the 'comments' subcollection of the post
      await _firestore.collection('posts').doc(widget.postId).collection('comments').add({
        'content': commentContent,
        'createdBy': _currentUser!.uid,
        'createdByEmail': _currentUser!.email, // Store email for display
        'createdAt': FieldValue.serverTimestamp(),
        'reactions': {     // Initialize reaction counts for comments
          'emoji': 0, // Using 'emoji' as a generic reaction type for comments
        },
        'reactedBy': [], // Initialize list of users who reacted to this comment
      });

      // Increment commentCount on the parent post
      await _firestore.collection('posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(1),
      });

      _commentController.clear();
      _showSnackBar('Comment added!');
    } catch (e) {
      _showSnackBar('Failed to add comment: $e');
      debugPrint('PostDetailPage Error: Failed to add comment: $e');
    } finally {
      setState(() {
        _isLoadingComment = false;
      });
    }
  }

  // Duplicate handleReaction from TroupeContentPage for consistency within this page
  // This can be refactored into a shared service later if needed across many pages.
  Future<void> _handleReaction(String postId, String reactionType) async {
    if (_currentUser == null) {
      _showSnackBar('You must be logged in to react to a post.');
      return;
    }

    final postRef = _firestore.collection('posts').doc(postId);

    try {
      final postDoc = await postRef.get();
      if (!postDoc.exists) {
        _showSnackBar('Post not found.');
        return;
      }

      Map<String, dynamic> currentReactions = Map<String, dynamic>.from(postDoc.data()?['reactions'] ?? {});
      List<dynamic> reactedBy = List<dynamic>.from(postDoc.data()?['reactedBy'] ?? []);

      final String userId = _currentUser!.uid;

      if (reactedBy.contains('$userId:$reactionType')) {
        currentReactions[reactionType] = (currentReactions[reactionType] ?? 1) - 1;
        reactedBy.remove('$userId:$reactionType');
        _showSnackBar('Your reaction to this post has been removed.');
      } else {
        currentReactions[reactionType] = (currentReactions[reactionType] ?? 0) + 1;
        reactedBy.add('$userId:$reactionType');
        _showSnackBar('Your reaction to this post has been added!');
      }

      await postRef.update({
        'reactions': currentReactions,
        'reactedBy': reactedBy,
      });

    } catch (e) {
      _showSnackBar('Failed to update reaction: $e');
      debugPrint('PostDetailPage Error: Failed to handle reaction for post $postId: $e');
    }
  }

  // NEW: Implement Handle reactions on individual comments
  Future<void> _handleCommentReaction(String commentId, String reactionType) async {
    if (_currentUser == null) {
      _showSnackBar('You must be logged in to react to a comment.');
      return;
    }

    final commentRef = _firestore.collection('posts').doc(widget.postId).collection('comments').doc(commentId);

    try {
      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) {
        _showSnackBar('Comment not found.');
        return;
      }

      Map<String, dynamic> currentReactions = Map<String, dynamic>.from(commentDoc.data()?['reactions'] ?? {});
      List<dynamic> reactedBy = List<dynamic>.from(commentDoc.data()?['reactedBy'] ?? []);

      final String userId = _currentUser!.uid;

      // Check if the user has already reacted with this type
      if (reactedBy.contains('$userId:$reactionType')) {
        // User is un-reacting
        currentReactions[reactionType] = (currentReactions[reactionType] ?? 1) - 1;
        reactedBy.remove('$userId:$reactionType');
        _showSnackBar('Your reaction to this comment has been removed.');
        debugPrint('User $userId removed $reactionType reaction from comment $commentId.');
      } else {
        // User is reacting
        currentReactions[reactionType] = (currentReactions[reactionType] ?? 0) + 1;
        reactedBy.add('$userId:$reactionType');
        _showSnackBar('Your reaction to this comment has been added!');
        debugPrint('User $userId added $reactionType reaction to comment $commentId.');
      }

      // Update the comment in Firestore
      await commentRef.update({
        'reactions': currentReactions,
        'reactedBy': reactedBy,
      });

    } catch (e) {
      _showSnackBar('Failed to update comment reaction: $e');
      debugPrint('PostDetailPage Error: Failed to handle comment reaction for comment $commentId: $e');
    }
  }

  // Updated: Handle direct message to comment author
  void _directMessageUser(String recipientUid, String recipientEmail) {
    if (_currentUser == null) {
      _showSnackBar('You must be logged in to send a direct message.');
      return;
    }
    if (_currentUser!.uid == recipientUid) {
      _showSnackBar('You cannot send a direct message to yourself.');
      return;
    }
    debugPrint('Direct messaging user $recipientEmail (UID: $recipientUid). Navigating to DirectMessagePage.');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DirectMessagePage(
          recipientUid: recipientUid,
          recipientEmail: recipientEmail,
        ),
      ),
    );
  }

  // NEW: Implement Delete Comment functionality
  Future<void> _deleteComment(String commentId) async {
    if (_currentUser == null) {
      _showSnackBar('You must be logged in to delete a comment.');
      return;
    }

    try {
      debugPrint('PostDetailPage: Attempting to delete comment $commentId from post ${widget.postId}.');
      await _firestore.collection('posts').doc(widget.postId).collection('comments').doc(commentId).delete();

      // Decrement commentCount on the parent post
      await _firestore.collection('posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(-1),
      });

      _showSnackBar('Comment deleted successfully!');
      debugPrint('PostDetailPage: Comment $commentId deleted.');
    } catch (e) {
      _showSnackBar('Failed to delete comment: $e');
      debugPrint('PostDetailPage Error: Failed to delete comment $commentId: $e');
    }
  }

  // NEW: Implement Edit Comment functionality using a dialog
  Future<void> _editComment(String commentId, String currentContent) async {
    if (_currentUser == null) {
      _showSnackBar('You must be logged in to edit a comment.');
      return;
    }

    TextEditingController editController = TextEditingController(text: currentContent);

    // Show a dialog to edit the comment
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Comment'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(labelText: 'Comment'),
            maxLines: null, // Allow multiline input
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newContent = editController.text.trim();
                if (newContent.isEmpty) {
                  _showSnackBar('Comment cannot be empty.');
                  return;
                }
                try {
                  debugPrint('PostDetailPage: Attempting to update comment $commentId.');
                  await _firestore.collection('posts').doc(widget.postId).collection('comments').doc(commentId).update({
                    'content': newContent,
                    'updatedAt': FieldValue.serverTimestamp(), // Add an updatedAt field
                  });
                  _showSnackBar('Comment updated successfully!');
                  debugPrint('PostDetailPage: Comment $commentId updated.');
                  if (mounted) {
                    Navigator.pop(context); // Close the dialog
                  }
                } catch (e) {
                  _showSnackBar('Failed to update comment: $e');
                  debugPrint('PostDetailPage Error: Failed to update comment $commentId: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    editController.dispose(); // Dispose the controller after dialog is closed
  }


  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.troupeName} Post'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('posts').doc(widget.postId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading post: ${snapshot.error}', style: TextStyle(color: primaryColor)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Post not found.', style: TextStyle(color: textOnBackground)));
          }

          Map<String, dynamic> postData = snapshot.data!.data() as Map<String, dynamic>;

          final String content = postData['content'] ?? 'No content';
          final String createdByEmail = postData['createdByEmail'] ?? 'Unknown User';
          final Timestamp? createdAt = postData['createdAt'] as Timestamp?;
          final int commentCount = postData['commentCount'] ?? 0;
          final int viewCount = postData['viewCount'] ?? 0;
          final Map<String, dynamic> reactions = postData['reactions'] ?? {};
          final int thumbsUp = reactions['thumbsUp'] ?? 0;
          final int heart = reactions['heart'] ?? 0;
          final List<dynamic> reactedBy = postData['reactedBy'] ?? [];

          final String formattedDate = createdAt != null ?
              DateFormat('MMM dd,EEEE \'at\' hh:mm a').format(createdAt.toDate())
              : 'Unknown Date';

          // Check if current user has reacted for displaying colored icons
          final bool hasThumbsUp = _currentUser != null && reactedBy.contains('${_currentUser!.uid}:thumbsUp');
          final bool hasHeart = _currentUser != null && reactedBy.contains('${_currentUser!.uid}:heart');


          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post Content Card (Similar to TroupeContentPage)
                      Card(
                        margin: EdgeInsets.zero, // No margin for the main post card
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 3,
                        color: backgroundColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: primaryColor.withOpacity(0.2),
                                    child: Icon(Icons.person, color: primaryColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        createdByEmail,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: primaryColor,
                                        ),
                                      ),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textOnBackground.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                content,
                                style: TextStyle(fontSize: 15, color: textOnBackground),
                              ),
                              const SizedBox(height: 10),
                              // Post Stats and Reactions
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$commentCount Comments • $viewCount Views',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textOnBackground.withOpacity(0.7),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Thumbs Up (Reactions can be handled here too if desired,
                                      // but the prompt focused on the main page for reactions)
                                      IconButton(
                                        icon: Icon(
                                          Icons.thumb_up,
                                          color: hasThumbsUp ? primaryColor : textOnBackground.withOpacity(0.6),
                                        ),
                                        onPressed: _currentUser != null ? () {
                                          // Call reaction handler if user is logged in
                                          _handleReaction(widget.postId, 'thumbsUp');
                                        } : null, // Disable if not logged in
                                        tooltip: 'Like',
                                      ),
                                      Text('$thumbsUp', style: TextStyle(color: textOnBackground)),
                                      const SizedBox(width: 10),
                                      // Heart
                                      IconButton(
                                        icon: Icon(
                                          Icons.favorite,
                                          color: hasHeart ? primaryColor : textOnBackground.withOpacity(0.6),
                                        ),
                                        onPressed: _currentUser != null ? () {
                                          // Call reaction handler if user is logged in
                                          _handleReaction(widget.postId, 'heart');
                                        } : null, // Disable if not logged in
                                        tooltip: 'Love',
                                      ),
                                      Text('$heart', style: TextStyle(color: textOnBackground)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textOnBackground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // StreamBuilder for Comments
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('posts')
                            .doc(widget.postId)
                            .collection('comments')
                            .orderBy('createdAt', descending: false) // Show oldest comments first
                            .snapshots(),
                        builder: (context, commentSnapshot) {
                          if (commentSnapshot.hasError) {
                            return Text('Error loading comments: ${commentSnapshot.error}', style: TextStyle(color: primaryColor));
                          }
                          if (commentSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: primaryColor));
                          }
                          if (!commentSnapshot.hasData || commentSnapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Text(
                                'No comments yet. Be the first to comment!',
                                style: TextStyle(color: textOnBackground.withOpacity(0.7)),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true, // Important for nested ListViews
                            physics: const NeverScrollableScrollPhysics(), // Disable scrolling of this inner list
                            itemCount: commentSnapshot.data!.docs.length,
                            itemBuilder: (context, commentIndex) {
                              DocumentSnapshot commentDoc = commentSnapshot.data!.docs[commentIndex];
                              Map<String, dynamic> commentData = commentDoc.data() as Map<String, dynamic>;

                              final String commentContent = commentData['content'] ?? 'No content';
                              final String commentAuthorUid = commentData['createdBy'] ?? ''; // Get UID
                              final String commentAuthorEmail = commentData['createdByEmail'] ?? 'Unknown User';
                              final Timestamp? commentCreatedAt = commentData['createdAt'] as Timestamp?;
                              final Map<String, dynamic> commentReactions = commentData['reactions'] ?? {};
                              final int emojiCount = commentReactions['emoji'] ?? 0;
                              final List<dynamic> commentReactedBy = commentData['reactedBy'] ?? [];


                              final String formattedCommentDate = commentCreatedAt != null ?
                                  DateFormat('MMM dd,EEEE \'at\' hh:mm a').format(commentCreatedAt.toDate())
                                  : 'Unknown Date';

                              // Determine if current user is the author of this comment
                              final bool isCommentAuthor = _currentUser != null && _currentUser!.uid == commentAuthorUid;
                              // Check if current user has reacted to this comment
                              final bool hasEmojiReaction = _currentUser != null && commentReactedBy.contains('${_currentUser!.uid}:emoji');


                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                elevation: 1,
                                color: backgroundColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                commentAuthorEmail,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: primaryColor,
                                                ),
                                              ),
                                              Text(
                                                formattedCommentDate,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: textOnBackground.withOpacity(0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Emoji and Direct Message Icons
                                          Row(
                                            children: [
                                              // Emoji icon for comment reactions
                                              IconButton(
                                                icon: Icon(
                                                  Icons.emoji_emotions_outlined,
                                                  color: hasEmojiReaction ? primaryColor : textOnBackground.withOpacity(0.6),
                                                ),
                                                onPressed: _currentUser != null ? () {
                                                  _handleCommentReaction(commentDoc.id, 'emoji');
                                                } : null,
                                                tooltip: 'React to comment',
                                              ),
                                              Text('$emojiCount', style: TextStyle(color: textOnBackground)), // Display emoji count
                                              const SizedBox(width: 10),
                                              // Direct Message icon (show only if not own comment)
                                              if (_currentUser != null && _currentUser!.uid != commentAuthorUid)
                                                IconButton(
                                                  icon: Icon(Icons.chat_bubble_outline, color: textOnBackground.withOpacity(0.6)),
                                                  onPressed: () {
                                                    _directMessageUser(commentAuthorUid, commentAuthorEmail);
                                                  },
                                                  tooltip: 'Direct Message',
                                                ),
                                              // Three-dot menu for comments (future: edit/delete own comment)
                                              PopupMenuButton<String>(
                                                icon: Icon(Icons.more_vert, color: textOnBackground.withOpacity(0.6)),
                                                onSelected: (String result) {
                                                  if (result == 'delete_comment') {
                                                    _deleteComment(commentDoc.id); // Call delete function
                                                  } else if (result == 'edit_comment') {
                                                    _editComment(commentDoc.id, commentContent); // Call edit function
                                                  }
                                                },
                                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                                  if (isCommentAuthor) // Option to edit own comment
                                                    PopupMenuItem<String>(
                                                      value: 'edit_comment',
                                                      child: Text('Edit Comment', style: TextStyle(color: textOnBackground)),
                                                    ),
                                                  if (isCommentAuthor || _isAdmin) // Option to delete own or any comment if admin
                                                    PopupMenuItem<String>(
                                                      value: 'delete_comment',
                                                      child: Text('Delete Comment', style: TextStyle(color: textOnBackground)),
                                                    ),
                                                ],
                                                color: backgroundColor, // Background of the popup menu
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        commentContent,
                                        style: TextStyle(fontSize: 14, color: textOnBackground),
                                      ),
                                    ],
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
              ),
              // Comment Input Field
              if (_currentUser != null) // Only show comment input if user is logged in
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            labelText: 'Add a comment...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null, // Allow multiline input
                          minLines: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _isLoadingComment
                          ? CircularProgressIndicator(color: primaryColor)
                          : FloatingActionButton(
                              onPressed: _addComment,
                              backgroundColor: primaryColor,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              mini: true,
                              child: const Icon(Icons.send),
                            ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
