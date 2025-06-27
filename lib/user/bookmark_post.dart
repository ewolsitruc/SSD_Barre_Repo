import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class BookmarkPage extends StatefulWidget {
  const BookmarkPage({super.key});

  @override
  State<BookmarkPage> createState() => _BookmarkPageState();
}

class _BookmarkPageState extends State<BookmarkPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
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

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bookmarked Posts')),
        body: Center(
          child: Text(
            'Please log in to view your bookmarked posts.',
            style: TextStyle(color: textOnBackground),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarked Posts'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your saved posts:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textOnBackground,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('users').doc(_currentUser!.uid).snapshots(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasError) {
                    debugPrint('BookmarkPage User Stream Error: ${userSnapshot.error}');
                    return Center(child: Text('Error loading bookmarks: ${userSnapshot.error}', style: TextStyle(color: primaryColor)));
                  }
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return Center(child: Text('User data not found.', style: TextStyle(color: textOnBackground)));
                  }

                  final List<dynamic> bookmarkedPostIds = userSnapshot.data!.data()?['bookmarks'] ?? [];

                  if (bookmarkedPostIds.isEmpty) {
                    return Center(
                      child: Text(
                        'You haven\'t bookmarked any posts yet.',
                        style: TextStyle(fontSize: 16, color: textOnBackground.withOpacity(0.7)),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  // To display the actual posts, we need to fetch them by their IDs.
                  // This is a basic implementation. For many bookmarks, consider
                  // batched reads or a Cloud Function to pre-aggregate data.
                  return FutureBuilder<List<DocumentSnapshot>>(
                    future: _fetchBookmarkedPosts(bookmarkedPostIds.cast<String>()),
                    builder: (context, postsSnapshot) {
                      if (postsSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: primaryColor));
                      }
                      if (postsSnapshot.hasError) {
                        debugPrint('BookmarkPage Posts Fetch Error: ${postsSnapshot.error}');
                        return Center(child: Text('Error loading bookmarked posts: ${postsSnapshot.error}', style: TextStyle(color: primaryColor)));
                      }
                      if (!postsSnapshot.hasData || postsSnapshot.data!.isEmpty) {
                        return Center(child: Text('No bookmarked posts found.', style: TextStyle(color: textOnBackground)));
                      }

                      return ListView.builder(
                        itemCount: postsSnapshot.data!.length,
                        itemBuilder: (context, index) {
                          DocumentSnapshot postDoc = postsSnapshot.data![index];
                          Map<String, dynamic> postData = postDoc.data() as Map<String, dynamic>;

                          final String content = postData['content'] ?? 'No content';
                          final String createdByEmail = postData['createdByEmail'] ?? 'Unknown User';
                          final Timestamp? createdAt = postData['createdAt'] as Timestamp?;
                          final String formattedDate;
                          if (createdAt != null) {
                            formattedDate = DateFormat('MMM dd, yyyy \'at\' hh:mm a').format(createdAt.toDate());
                          } else {
                            formattedDate = 'Unknown Date';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 3,
                            color: Theme.of(context).colorScheme.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content,
                                    style: TextStyle(fontSize: 15, color: textOnBackground),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'By: $createdByEmail on $formattedDate',
                                    style: TextStyle(fontSize: 12, color: textOnBackground.withOpacity(0.7)),
                                  ),
                                  // Add more post details or interaction buttons if needed
                                ],
                              ),
                            ),
                          );
                        },
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

  // Helper function to fetch bookmarked posts
  Future<List<DocumentSnapshot>> _fetchBookmarkedPosts(List<String> postIds) async {
    if (postIds.isEmpty) return [];
    
    List<DocumentSnapshot> posts = [];
    // Firestore `whereIn` limit is 10. For more, you'd need multiple queries or Cloud Function.
    // For simplicity, this assumes a relatively small number of bookmarks.
    if (postIds.isNotEmpty) {
      final querySnapshot = await _firestore.collection('posts').where(FieldPath.documentId, whereIn: postIds).get();
      posts = querySnapshot.docs;
    }
    return posts;
  }
}

extension on Object? {
  void operator [](String other) {}
}
