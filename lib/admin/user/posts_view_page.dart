import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../user/user_data_service.dart';
import '../admin/add_post_page.dart'; // Make sure this path is correct

class PostsViewPage extends StatefulWidget {
  final List<String> assignedGroups;
  final List<String> assignedSubgroups;
  final bool showAssignedTroupesOnly;
  final bool isTeacher;

  const PostsViewPage({
    super.key,
    required this.assignedGroups,
    required this.assignedSubgroups,
    this.showAssignedTroupesOnly = false,
    required this.isTeacher,
  });

  @override
  State<PostsViewPage> createState() => _PostsViewPageState();
}

class _PostsViewPageState extends State<PostsViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();

  User? _currentUser;
  bool _isAdmin = false;

  final Map<int, QuerySnapshot> _latestPostsSnapshots = {};
  final List<StreamSubscription> _postSubscriptions = [];
  final StreamController<List<DocumentSnapshot>> _combinedPostsController =
  StreamController<List<DocumentSnapshot>>.broadcast();

  final Map<String, Map<String, dynamic>> _troupesCache = {};
  bool _isTroupesCacheLoaded = false;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _checkAdminStatus().then((_) {
      _fetchAllTroupeNames().then((_) {
        _setupPostStreams();
      });
    });
  }

  @override
  void dispose() {
    _cancelAllPostStreams();
    _combinedPostsController.close();
    super.dispose();
  }

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

  Future<void> _fetchAllTroupeNames() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('troupes').get();
      for (var doc in snapshot.docs) {
        _troupesCache[doc.id] = doc.data() as Map<String, dynamic>;
      }
      if (mounted) setState(() => _isTroupesCacheLoaded = true);
    } catch (e) {
      if (mounted) {
        setState(() => _isTroupesCacheLoaded = true);
      }
      _showSnackBar('Failed to load troupe information.');
    }
  }

  int _getExpectedPostStreamCount() {
    if (_isAdmin) return 1;
    return widget.assignedGroups.length + widget.assignedSubgroups.length;
  }

  void _setupPostStreams() {
    _cancelAllPostStreams();
    List<Stream<QuerySnapshot>> streamsToListen = [];

    if (_isAdmin) {
      streamsToListen.add(_firestore.collection('posts').snapshots());
    } else {
      for (var id in [...widget.assignedGroups, ...widget.assignedSubgroups]) {
        streamsToListen.add(
          _firestore.collection('posts').where('troupeId', isEqualTo: id).snapshots(),
        );
      }
    }

    for (int i = 0; i < streamsToListen.length; i++) {
      _postSubscriptions.add(streamsToListen[i].listen((snapshot) {
        _latestPostsSnapshots[i] = snapshot;
        _updateCombinedPosts();
      }, onError: (error) {
        _combinedPostsController.addError(error);
      }));
    }
  }

  void _cancelAllPostStreams() {
    for (var sub in _postSubscriptions) {
      sub.cancel();
    }
    _postSubscriptions.clear();
    _latestPostsSnapshots.clear();
  }

  void _updateCombinedPosts() {
    if (_latestPostsSnapshots.length == _getExpectedPostStreamCount() && _isTroupesCacheLoaded) {
      List<DocumentSnapshot> allDocs = [];
      for (var snapshot in _latestPostsSnapshots.values) {
        allDocs.addAll(snapshot.docs);
      }
      allDocs.sort((a, b) {
        final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      _combinedPostsController.add(allDocs);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _navigateToAddPostPage() {
    List<String>? allowedTroupes =
    _isAdmin ? null : [...widget.assignedGroups, ...widget.assignedSubgroups];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPostPage(
          allowedTroupeIds: allowedTroupes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Studio Posts')),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddPostPage,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<DocumentSnapshot>>(
        stream: _combinedPostsController.stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data!;

          if (posts.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final data = posts[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(data['content'] ?? 'No content'),
                subtitle: Text(data['createdByEmail'] ?? 'Unknown'),
              );
            },
          );
        },
      ),
    );
  }
}