import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'announcements_view_page.dart';
import 'posts_view_page.dart';
import '../admin/events_list_page.dart';

import '../widgets/main_drawer.dart';
import '../widgets/custom_app_bar.dart';
import '../user/login_page.dart';

class SSDHubPage extends StatefulWidget {
  final int initialTabIndex;
  const SSDHubPage({super.key, this.initialTabIndex = 0});

  @override
  State<SSDHubPage> createState() => _SSDHubPageState();
}

class _SSDHubPageState extends State<SSDHubPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _currentUser;
  bool _isAdmin = false;
  bool _isTeacher = false;
  int _totalUnreadCount = 0;
  String? _profileImageUrl;

  List<String> _assignedGroups = [];
  List<String> _assignedSubgroups = [];

  late TabController _tabController;
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _listenToUserData(_currentUser!.uid);
    }
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _listenToUserData(String uid) {
    _userDataSubscription?.cancel();
    _userDataSubscription = _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        setState(() {
          _isAdmin = data['isAdmin'] ?? false;
          _isTeacher = data['isTeacher'] ?? false;
          _assignedGroups = List<String>.from(data['assignedGroups'] ?? []);
          _assignedSubgroups = List<String>.from(data['assignedSubgroups'] ?? []);
          _profileImageUrl = data['profileImageUrl'];
          _totalUnreadCount = (data['unreadMessageCount'] ?? 0) +
              (data['unreadAnnouncementCount'] ?? 0) +
              (data['unreadJoinRequestCount'] ?? 0);
        });
      } else {
        setState(() {
          _isAdmin = false;
          _isTeacher = false;
          _assignedGroups = [];
          _assignedSubgroups = [];
          _profileImageUrl = null;
          _totalUnreadCount = 0;
        });
      }
    }, onError: (error) {
      debugPrint('Error listening to user data: $error');
    });
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color textOnPrimary = Theme.of(context).colorScheme.onPrimary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('SSD Hub')),
        body: Center(
          child: Text('Please log in to view the SSD Hub.', style: TextStyle(color: textOnBackground)),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        titleWidget: const Text('SSD Hub'),
        isAdmin: _isAdmin,
        onLogout: _logout,
        showNotificationsIcon: true,
        totalUnreadCount: _totalUnreadCount,
        onNotificationsTap: () => _tabController.animateTo(0),
        leadingWidget: CircleAvatar(
          backgroundColor: Colors.transparent,
          child: _profileImageUrl?.isNotEmpty == true
              ? ClipOval(
            child: Image.network(
              _profileImageUrl!,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.account_circle, size: 40, color: textOnPrimary),
            ),
          )
              : Icon(Icons.account_circle, size: 40, color: textOnPrimary),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: textOnPrimary,
          unselectedLabelColor: textOnPrimary.withOpacity(0.7),
          indicatorColor: textOnPrimary,
          tabs: const [
            Tab(icon: Icon(Icons.campaign), text: 'Spotlight'),
            Tab(icon: Icon(Icons.event), text: 'Events'),
            Tab(icon: Icon(Icons.article), text: 'Posts'),
            // Tab(icon: Icon(Icons.mail), text: 'Messages'),
          ],
        ),
        title: '',
      ),
      endDrawer: MainDrawer(
        isAdmin: _isAdmin,
        onLogout: _logout,
        onNavigateToHubTab: (index) {
          Navigator.pop(context);
          _tabController.animateTo(index);
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          AnnouncementsViewPage(
            assignedGroups: _assignedGroups,
            assignedSubgroups: _assignedSubgroups,
          ),
          EventsListPage(),
          PostsViewPage(
            assignedGroups: _assignedGroups,
            assignedSubgroups: _assignedSubgroups,
            isTeacher: _isTeacher,
          ),
          // AllDirectMessagesPage(),
        ],
      ),
    );
  }
}
