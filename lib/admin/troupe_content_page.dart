import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:intl/intl.dart'; // For date/time formatting
import 'package:flutter/services.dart'; // For Clipboard

// CORRECTED IMPORTS based on your provided folder structure:
import '../user/user_data_service.dart'; // From lib/user/
import '../admin/add_post_page.dart'; // From lib/admin/
import '../user/edit_post_page.dart'; // From lib/user/
import '../user/post_detail_page.dart'; // From lib/user/
import '../user/direct_message_page.dart'; // From lib/user/


class TroupeContentPage extends StatefulWidget {
  final String troupeId;
  final String troupeName;

  const TroupeContentPage({
    super.key,
    required this.troupeId,
    required this.troupeName,
  });

  @override
  State<TroupeContentPage> createState() => _TroupeContentPageState();
}

class _TroupeContentPageState extends State<TroupeContentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();
  bool _isAdmin = false;
  bool _isMember = false; // New state to track if the current user is a member of this troupe
  int _memberCount = 0; // State to hold member count
  User? _currentUser; // To hold the current authenticated user

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser; // Get the current user
    debugPrint('TroupeContentPage: Initializing for Troupe ID: ${widget.troupeId}'); // Add this line
    _checkAdminAndMembershipStatus(); // Combined check
    _fetchMemberCount(); // Fetch member count on init
    _incrementTroupeViewCount(); // Increment view count when page is accessed
  }

  // Combines admin and membership status check
  Future<void> _checkAdminAndMembershipStatus() async {
    if (_currentUser != null) {
      final currentIsAdmin = await _userDataService.isUserAdmin(_currentUser!.uid);
      final currentIsMember = await _isUserMemberOfTroupe(_currentUser!.uid, widget.troupeId); // Check membership
      if (mounted) {
        setState(() {
          _isAdmin = currentIsAdmin;
          _isMember = currentIsMember; // Update _isMember state
        });
      }
    }
  }

  // Helper function to check if a user is a member of the given troupe
  Future<bool> _isUserMemberOfTroupe(String userId, String troupeId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final List<dynamic> assignedGroups = userData?['assignedGroups'] ?? [];
        final List<dynamic> assignedSubgroups = userData?['assignedSubgroups'] ?? [];
        return assignedGroups.contains(troupeId) || assignedSubgroups.contains(troupeId);
      }
    } catch (e) {
      debugPrint('Error checking user membership for troupe $troupeId: $e');
    }
    return false;
  }

  Future<void> _fetchMemberCount() async {
    try {
      // Query users where assignedGroups or assignedSubgroups contain this troupeId
      // Note: This approach might become inefficient for very large user bases.
      // A dedicated counter field on the troupe document, updated via Cloud Functions,
      // would be more scalable for highly active groups.
      final groupMembersQuery = await _firestore
          .collection('users')
          .where('assignedGroups', arrayContains: widget.troupeId)
          .get();

      final subgroupMembersQuery = await _firestore
          .collection('users')
          .where('assignedSubgroups', arrayContains: widget.troupeId)
          .get();

      final allMembers = <String>{}; // Use a Set to avoid counting duplicates
      groupMembersQuery.docs.forEach((doc) => allMembers.add(doc.id));
      subgroupMembersQuery.docs.forEach((doc) => allMembers.add(doc.id));

      if (mounted) {
        setState(() {
          _memberCount = allMembers.length;
        });
      }
      debugPrint('TroupeContentPage: Member count for ${widget.troupeName}: $_memberCount');
    } catch (e) {
      debugPrint('TroupeContentPage Error: Failed to fetch member count: $e');
    }
  }

  // Function to increment a troupe's view count (could be more sophisticated, e.g., unique views per user)
  Future<void> _incrementTroupeViewCount() async {
    try {
      final troupeRef = _firestore.collection('troupes').doc(widget.troupeId);
      // Use set with SetOptions.merge to only update 'viewCount' without overwriting other fields
      await troupeRef.set({
        'viewCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      debugPrint('TroupeContentPage: View count incremented for ${widget.troupeName}.');
    } catch (e) {
      _showSnackBar('Failed to increment troupe view count: $e');
      debugPrint('TroupeContentPage Error: Failed to increment view count: $e');
    }
  }

  // Function to handle post reactions (thumbsUp or heart)
  Future<void> _handleReaction(String postId, String reactionType) async {
    if (_currentUser == null) {
      _showSnackBar('You must be logged in to react to a post.');
      return;
    }

    final postRef = _firestore.collection('posts').doc(postId);

    try {
      // Get the current post document to check existing reactions
      final postDoc = await postRef.get();
      if (!postDoc.exists) {
        _showSnackBar('Post not found.');
        return;
      }

      Map<String, dynamic> currentReactions = Map<String, dynamic>.from(postDoc.data()?['reactions'] ?? {});
      List<dynamic> reactedBy = List<dynamic>.from(postDoc.data()?['reactedBy'] ?? []);

      final String userId = _currentUser!.uid;

      // Check if the user has already reacted with this type
      if (reactedBy.contains('$userId:$reactionType')) {
        // User is un-reacting
        currentReactions[reactionType] = (currentReactions[reactionType] ?? 1) - 1; // Decrement, ensure it doesn't go below 0
        reactedBy.remove('$userId:$reactionType');
        _showSnackBar('Your reaction to this post has been removed.');
        debugPrint('User $userId removed $reactionType reaction from post $postId.');
      } else {
        // User is reacting
        currentReactions[reactionType] = (currentReactions[reactionType] ?? 0) + 1; // Increment
        reactedBy.add('$userId:$reactionType');
        _showSnackBar('Your reaction to this post has been added!');
        debugPrint('User $userId added $reactionType reaction to post $postId.');
      }

      // Update the post in Firestore
      await postRef.update({
        'reactions': currentReactions,
        'reactedBy': reactedBy,
      });

    } catch (e) {
      _showSnackBar('Failed to update reaction: $e');
      debugPrint('TroupeContentPage Error: Failed to handle reaction for post $postId: $e');
    }
  }

  // Edit Post functionality - Now navigates to EditPostPage
  void _editPost(String postId, String currentContent) {
    debugPrint('TroupeContentPage: Navigating to EditPostPage for post $postId');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostPage(
          postId: postId,
          initialContent: currentContent,
        ),
      ),
    );
  }

  // Delete Post functionality
  Future<void> _deletePost(String postId) async {
    debugPrint('TroupeContentPage: Attempting to delete post $postId');
    try {
      await _firestore.collection('posts').doc(postId).delete();
      _showSnackBar('Post deleted successfully!');
      debugPrint('TroupeContentPage: Post $postId deleted.');
    } catch (e) {
      _showSnackBar('Failed to delete post: $e');
      debugPrint('TroupeContentPage Error: Failed to delete post $postId: $e');
    }
  }

  // Function to copy post content to clipboard
  void _copyPost(String content) {
    Clipboard.setData(ClipboardData(text: content));
    _showSnackBar('Post content copied to clipboard!');
    debugPrint('TroupeContentPage: Post content copied.');
  }

  // Bookmark Post functionality
  Future<void> _bookmarkPost(String postId) async {
    if (_currentUser == null) {
      _showSnackBar('You must be logged in to bookmark a post.');
      return;
    }

    final userRef = _firestore.collection('users').doc(_currentUser!.uid);

    try {
      final userDoc = await userRef.get();
      List<dynamic> bookmarks = userDoc.data()?['bookmarks'] ?? [];

      if (bookmarks.contains(postId)) {
        bookmarks.remove(postId);
        _showSnackBar('Post unbookmarked!');
        debugPrint('User ${_currentUser!.uid} unbookmarked post $postId.');
      } else {
        bookmarks.add(postId);
        _showSnackBar('Post bookmarked!');
        debugPrint('User ${_currentUser!.uid} bookmarked post $postId.');
      }

      await userRef.update({'bookmarks': bookmarks});

    } catch (e) {
      _showSnackBar('Failed to bookmark/unbookmark post: $e');
      debugPrint('TroupeContentPage Error: Failed to bookmark/unbookmark post $postId: $e');
    }
  }

  // Function to navigate to PostDetailPage and increment its view count
  void _viewPostDetails(String postId, String troupeId, String troupeName) async {
    debugPrint('TroupeContentPage: Navigating to PostDetailPage for post $postId.');
    // You might want to increment a post's view count here or on the detail page itself.
    // For now, let's just navigate.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          postId: postId,
          troupeId: troupeId, // Pass troupeId to PostDetailPage
          troupeName: troupeName, // Pass troupeName to PostDetailPage
        ),
      ),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.troupeName), // Group/Sub-Group Name on top left
        actions: [
          // Post button: visible if admin OR if current user is a member of this troupe
          if (_isAdmin || _isMember)
            IconButton(
              icon: const Icon(Icons.post_add),
              onPressed: () {
                debugPrint('TroupeContentPage: User wants to create a new post.');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddPostPage( // FIX: Changed parameter names to initialTroupeId and initialTroupeName
                      initialTroupeId: widget.troupeId,
                      initialTroupeName: widget.troupeName,
                    ),
                  ),
                );
              },
              tooltip: 'Create New Post',
            ),
          // Future: Search button
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              debugPrint('TroupeContentPage: Search posts (Future Feature)');
              _showSnackBar('Future feature: Search Posts');
            },
            tooltip: 'Search Posts',
          ),
          if (_isAdmin) // Admin-only invite button
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                debugPrint('TroupeContentPage: Admin wants to invite members.');
                _showSnackBar('Future feature: Invite Members Form');
              },
              tooltip: 'Invite Members',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Count Display
            Text(
              'Members: $_memberCount',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textOnBackground,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('posts')
                    .where('troupeId', isEqualTo: widget.troupeId) // Filter posts by current troupe
                    .orderBy('createdAt', descending: true) // Show latest posts first
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('TroupeContentPage Posts Error: ${snapshot.error}');
                    return Center(child: Text('Error loading posts: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.feed, size: 80, color: primaryColor.withOpacity(0.5)),
                          const SizedBox(height: 10),
                          Text(
                            'No posts yet. Be the first to share an update!',
                            style: TextStyle(fontSize: 18, color: textOnBackground.withOpacity(0.7)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot postDoc = snapshot.data!.docs[index];
                      Map<String, dynamic> postData = postDoc.data() as Map<String, dynamic>;

                      final String postId = postDoc.id; // Get post ID
                      final String content = postData['content'] ?? 'No content';
                      final String createdBy = postData['createdBy'] ?? ''; // Get UID of post creator
                      final String createdByEmail = postData['createdByEmail'] ?? 'Unknown User';
                      final Timestamp? createdAt = postData['createdAt'] as Timestamp?;
                      final int commentCount = postData['commentCount'] ?? 0;
                      final int viewCount = postData['viewCount'] ?? 0;
                      final Map<String, dynamic> reactions = postData['reactions'] ?? {};
                      final int thumbsUp = reactions['thumbsUp'] ?? 0;
                      final int heart = reactions['heart'] ?? 0;
                      final List<dynamic> reactedBy = postData['reactedBy'] ?? []; // List of user IDs who reacted

                      // Check if current user has reacted with thumbs up or heart
                      final bool hasThumbsUp = _currentUser != null && reactedBy.contains('${_currentUser!.uid}:thumbsUp');
                      final bool hasHeart = _currentUser != null && reactedBy.contains('${_currentUser!.uid}:heart');

                      // Determine if the current user is the author of the post
                      final bool isAuthor = _currentUser != null && _currentUser!.uid == createdBy;

                      final String formattedDate = createdAt != null ?
                      DateFormat('MMM dd,EEEE \'at\' hh:mm a').format(createdAt.toDate())
                          : 'Unknown Date';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 3,
                        color: backgroundColor,
                        child: InkWell( // Use InkWell to make the card tappable
                          onTap: () {
                            _viewPostDetails(postId, widget.troupeId, widget.troupeName);
                          },
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
                                    Expanded( // Use Expanded to give text space and push menu to the right
                                      child: Column(
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
                                    ),
                                    // Three-dot menu
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert, color: textOnBackground),
                                      onSelected: (String result) {
                                        if (result == 'edit') {
                                          _editPost(postId, content);
                                        } else if (result == 'delete') {
                                          _deletePost(postId);
                                        } else if (result == 'copy') {
                                          _copyPost(content);
                                        } else if (result == 'bookmark') {
                                          _bookmarkPost(postId);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                        if (isAuthor || _isAdmin) // Edit option for author or admin
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text('Edit Post', style: TextStyle(color: textOnBackground)),
                                          ),
                                        if (isAuthor || _isAdmin) // Delete option for author or admin
                                          PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text('Delete Post', style: TextStyle(color: textOnBackground)),
                                          ),
                                        PopupMenuItem<String>(
                                          value: 'copy',
                                          child: Text('Copy Post', style: TextStyle(color: textOnBackground)),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'bookmark',
                                          child: Text('Bookmark', style: TextStyle(color: textOnBackground)),
                                        ),
                                      ],
                                      color: backgroundColor, // Background of the popup menu
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
                                        // Thumbs Up
                                        IconButton(
                                          icon: Icon(
                                            Icons.thumb_up,
                                            color: hasThumbsUp ? primaryColor : textOnBackground.withOpacity(0.6),
                                          ),
                                          onPressed: () => _handleReaction(postId, 'thumbsUp'),
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
                                          onPressed: () => _handleReaction(postId, 'heart'),
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
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
