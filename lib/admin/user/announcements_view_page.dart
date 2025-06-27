import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'dart:async'; // Required for StreamController and StreamSubscription

class AnnouncementsViewPage extends StatefulWidget {
  final List<String> assignedGroups;
  final List<String> assignedSubgroups;

  const AnnouncementsViewPage({
    super.key,
    required this.assignedGroups,
    required this.assignedSubgroups,
  });

  @override
  State<AnnouncementsViewPage> createState() => _AnnouncementsViewPageState();
}

class _AnnouncementsViewPageState extends State<AnnouncementsViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

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
    _setupAnnouncementStreams(); // Set up streams immediately
  }

  @override
  void didUpdateWidget(covariant AnnouncementsViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-setup streams if assigned groups/subgroups change (e.g., user joins a new troupe)
    if (oldWidget.assignedGroups != widget.assignedGroups ||
        oldWidget.assignedSubgroups != widget.assignedSubgroups) {
      _setupAnnouncementStreams();
    }
  }

  @override
  void dispose() {
    _cancelAllAnnouncementStreams(); // Cancel all announcement subscriptions
    _combinedAnnouncementsController.close(); // Close the controller
    super.dispose();
  }

  // Helper function to update the combined list and add to controller
  void _updateCombinedAnnouncements() {
    // Only emit if all streams have emitted at least once
    // This logic relies on _getExpectedAnnouncementStreamCount accurately reflecting active streams
    if (_latestAnnouncementsSnapshots.length == _getExpectedAnnouncementStreamCount()) {
      final List<DocumentSnapshot> allDocs = [];
      for (final snapshot in _latestAnnouncementsSnapshots.values) {
        allDocs.addAll(snapshot.docs);
      }
      // Sort the combined list by createdAt timestamp (latest first)
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
    return 1 + widget.assignedGroups.length + widget.assignedSubgroups.length;
  }

  // Setup listeners for all relevant announcement streams
  void _setupAnnouncementStreams() {
    _cancelAllAnnouncementStreams(); // Cancel existing first

    final List<Stream<QuerySnapshot>> streamsToListen = [];

    // Global announcements
    streamsToListen.add(_firestore.collection('announcements').snapshots());

    // Parent troupe announcements
    for (String groupId in widget.assignedGroups) {
      streamsToListen.add(_firestore.collection('troupes').doc(groupId).collection('announcements').snapshots());
    }

    // Sub-troupe announcements
    for (String subgroupId in widget.assignedSubgroups) {
      streamsToListen.add(_firestore.collection('troupes').doc(subgroupId).collection('announcements').snapshots());
    }

    // Subscribe to each stream and update the map
    for (int i = 0; i < streamsToListen.length; i++) {
      _announcementSubscriptions.add(streamsToListen[i].listen((snapshot) {
        _latestAnnouncementsSnapshots[i] = snapshot;
        _updateCombinedAnnouncements();
      }, onError: (error) {
        _combinedAnnouncementsController.addError(error);
        debugPrint('AnnouncementsViewPage Error: Announcement stream error: $error');
      }));
    }
  }

  // Cancel all active announcement stream subscriptions
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

  // Function to handle announcement tap (increment view count and navigate)
  Future<void> _handleAnnouncementTap(String announcementId, String collectionPath) async {
    try {
      debugPrint('AnnouncementsViewPage: Tapped on announcement ID: $announcementId. Incrementing view count in $collectionPath.');
      final docRef = _firestore.collection(collectionPath).doc(announcementId);
      await docRef.update({
        'viewCount': FieldValue.increment(1),
      });
      // Optionally navigate to a detail page after incrementing view count
      // Navigator.push(context, MaterialPageRoute(builder: (context) => AnnouncementDetailPage(announcementId: announcementId)));
    } catch (e) {
      debugPrint('AnnouncementsViewPage Error: Failed to increment view count for $announcementId: $e');
      // No snackbar here, as it's a background operation on tap.
    }
  }

  // Function to handle like/unlike for an announcement
  Future<void> _toggleLikeAnnouncement(String announcementId, String collectionPath, List<dynamic> likedBy) async {
    if (_currentUser == null) {
      _showSnackBar('Please log in to like announcements.');
      return;
    }

    final String userId = _currentUser!.uid;
    final docRef = _firestore.collection(collectionPath).doc(announcementId);

    try {
      if (likedBy.contains(userId)) {
        // User has already liked, so unlike it
        debugPrint('AnnouncementsViewPage: User $userId unliking announcement $announcementId in $collectionPath.');
        await docRef.update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([userId]),
        });
        _showSnackBar('Unliked!');
      } else {
        // User has not liked, so like it
        debugPrint('AnnouncementsViewPage: User $userId liking announcement $announcementId in $collectionPath.');
        await docRef.update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([userId]),
        });
        _showSnackBar('Liked!');
      }
    } catch (e) {
      debugPrint('AnnouncementsViewPage Error: Failed to toggle like for $announcementId: $e');
      _showSnackBar('Failed to update like status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    if (_currentUser == null) {
      return Center(
        child: Text(
          'Please log in to view announcements.',
          style: TextStyle(color: textOnBackground),
        ),
      );
    }

    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _combinedAnnouncementsController.stream, // Listen to the combined stream
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('AnnouncementsViewPage Announcements Error: ${snapshot.error}');
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
            final String announcementId = doc.id; // Get document ID

            // Determine the correct collection path for this announcement to use in updates
            String collectionPath;
            if (data['parentTroupeId'] != null && data['subTroupeId'] != null) {
              collectionPath = 'troupes/${data['subTroupeId']}/announcements';
            } else if (data['parentTroupeId'] != null) {
              collectionPath = 'troupes/${data['parentTroupeId']}/announcements';
            } else {
              collectionPath = 'announcements'; // Global announcement
            }

            final String title = data['title'] ?? 'No Title';
            final String content = data['content'] ?? 'No Content';
            final Timestamp? createdAt = data['createdAt'] as Timestamp?;
            final String createdByEmail = data['createdByEmail'] ?? 'Unknown User';
            final String? parentTroupeName = data['parentTroupeName'];
            final String? subTroupeName = data['subTroupeName'];
            final int viewCount = data['viewCount'] ?? 0;
            final int likes = data['likes'] ?? 0;
            final List<dynamic> likedBy = data['likedBy'] ?? [];

            final bool isLikedByCurrentUser = _currentUser != null && likedBy.contains(_currentUser!.uid);

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
                  debugPrint('AnnouncementsViewPage: Tapped on announcement: $title');
                  _handleAnnouncementTap(announcementId, collectionPath);
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
                                onPressed: () => _toggleLikeAnnouncement(announcementId, collectionPath, likedBy),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
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
    );
  }
}
