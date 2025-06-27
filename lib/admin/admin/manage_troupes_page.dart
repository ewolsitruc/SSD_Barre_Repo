import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import '../user/user_data_service.dart'; // Import UserDataService
import 'troupe_announcements_page.dart'; // Import the page to display troupe announcements
import 'dart:async'; // Required for StreamSubscription

class TroupesPage extends StatefulWidget {
  const TroupesPage({super.key});

  @override
  State<TroupesPage> createState() => _TroupesPageState();
}

class _TroupesPageState extends State<TroupesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDataService _userDataService = UserDataService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedParentTroupeId;
  String? _selectedParentTroupeName;
  String? _selectedSubTroupeId;
  String? _selectedSubTroupeName;

  List<DocumentSnapshot> _parentTroupes = [];
  List<DocumentSnapshot> _subTroupes = [];
  bool _isLoadingTroupes = true;

  // User's assigned groups and subgroups
  List<String> _userAssignedGroups = [];
  List<String> _userAssignedSubgroups = [];
  bool _isAdmin = false; // To determine if the user can see all troupes

  // Stream subscription for user data to get assigned groups
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  User? _currentUser; // FIXED: Declare _currentUser here

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _listenToUserAssignments(_currentUser!.uid);
      _resetUnreadAnnouncementCount(); // NEW: Reset unread announcement count when TroupesPage is accessed
    } else {
      // If no user, can't fetch assignments, so set loading to false.
      setState(() {
        _isLoadingTroupes = false;
      });
    }
  }

  @override
  void dispose() {
    _userDataSubscription?.cancel(); // Cancel the subscription
    super.dispose();
  }

  // NEW: Function to reset the current user's unreadAnnouncementCount to 0 in Firestore
  Future<void> _resetUnreadAnnouncementCount() async {
    if (_currentUser == null) {
      debugPrint('TroupesPage: Cannot reset unread announcement count, no user logged in.');
      return;
    }

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'unreadAnnouncementCount': 0,
      });
      debugPrint('TroupesPage: Unread announcement count reset to 0 for user ${_currentUser!.uid}.');
      // No need to call setState here, as the stream listener in ChatsListPage (or Dashboard)
      // will pick up this change from Firestore and update the UI automatically.
    } catch (e) {
      debugPrint('TroupesPage Error: Failed to reset unread announcement count: $e');
      _showSnackBar('Failed to clear unread announcement count: $e');
    }
  }

  // Listen to user's assigned groups and subgroups and admin status
  void _listenToUserAssignments(String uid) {
    _userDataSubscription?.cancel(); // Cancel any existing subscription
    _userDataSubscription = _firestore.collection('users').doc(uid).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final userData = snapshot.data();
        final List<String> newAssignedGroups = List<String>.from(userData?['assignedGroups'] ?? []);
        final List<String> newAssignedSubgroups = List<String>.from(userData?['assignedSubgroups'] ?? []);
        final bool newIsAdmin = userData?['isAdmin'] ?? false;

        // Only update state and re-fetch if assignments or admin status have changed
        if (!listEquals(_userAssignedGroups, newAssignedGroups) ||
            !listEquals(_userAssignedSubgroups, newAssignedSubgroups) ||
            _isAdmin != newIsAdmin) {
          setState(() {
            _userAssignedGroups = newAssignedGroups;
            _userAssignedSubgroups = newAssignedSubgroups;
            _isAdmin = newIsAdmin;
          });
          _fetchParentTroupes(); // Re-fetch troupes based on new assignments
        }
      }
    }, onError: (error) {
      debugPrint('TroupesPage User Assignments Listener Error: $error');
      _showSnackBar('Failed to load user assignments.');
      setState(() {
        _isLoadingTroupes = false;
      });
    });
  }

  // Helper to compare lists (since listEquals requires flutter/foundation)
  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == b) return true; // Handles both null, or same instance
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _fetchParentTroupes() async {
    setState(() {
      _isLoadingTroupes = true;
    });
    try {
      Query query = _firestore
          .collection('troupes')
          .where('isParentTroupe', isEqualTo: true)
          .orderBy('order', descending: false);

      // If not an admin, filter by assigned groups
      if (!_isAdmin && _userAssignedGroups.isNotEmpty) {
        query = query.where(FieldPath.documentId, whereIn: _userAssignedGroups);
      } else if (!_isAdmin && _userAssignedGroups.isEmpty) {
        // If not admin and no assigned groups, show no parent troupes.
        // This avoids querying with an empty 'whereIn' which can cause issues.
        setState(() {
          _parentTroupes = [];
          _isLoadingTroupes = false;
        });
        return;
      }

      final snapshot = await query.get();
      setState(() {
        _parentTroupes = snapshot.docs;
        _isLoadingTroupes = false;
      });
      debugPrint('TroupesPage: Fetched ${_parentTroupes.length} parent troupes.');
    } catch (e) {
      debugPrint('TroupesPage Error: Failed to fetch parent troupes: $e');
      _showSnackBar('Failed to load parent troupes.');
      setState(() {
        _isLoadingTroupes = false;
      });
    }
  }

  Future<void> _fetchSubTroupes(String parentTroupeId) async {
    setState(() {
      _subTroupes = []; // Clear previous sub-troupes
      _selectedSubTroupeId = null; // Clear selected sub-troupe
      _selectedSubTroupeName = null;
    });
    try {
      Query query = _firestore
          .collection('troupes')
          .where('isParentTroupe', isEqualTo: false)
          .where('parentTroupeId', isEqualTo: parentTroupeId)
          .orderBy('order', descending: false);

      // If not an admin, filter by assigned subgroups for the selected parent's subgroups
      if (!_isAdmin && _userAssignedSubgroups.isNotEmpty) {
        query = query.where(FieldPath.documentId, whereIn: _userAssignedSubgroups);
      } else if (!_isAdmin && _userAssignedSubgroups.isEmpty) {
         // If not admin and no assigned subgroups, show no sub troupes.
         setState(() {
            _subTroupes = [];
         });
         return;
      }

      final snapshot = await query.get();
      setState(() {
        _subTroupes = snapshot.docs;
      });
      debugPrint('TroupesPage: Fetched ${snapshot.docs.length} sub-troupes for $parentTroupeId.');
    } catch (e) {
      debugPrint('TroupesPage Error: Failed to fetch sub-troupes for $parentTroupeId: $e');
      _showSnackBar('Failed to load sub-troupes.');
    }
  }

  void _navigateToAnnouncements() {
    String? targetTroupeId;
    String? targetTroupeName;

    if (_selectedSubTroupeId != null) {
      targetTroupeId = _selectedSubTroupeId;
      targetTroupeName = _selectedSubTroupeName;
      debugPrint('TroupesPage: Navigating to Sub-Troupe Announcements: $targetTroupeName (ID: $targetTroupeId)');
    } else if (_selectedParentTroupeId != null) {
      targetTroupeId = _selectedParentTroupeId;
      targetTroupeName = _selectedParentTroupeName;
      debugPrint('TroupesPage: Navigating to Parent Troupe Announcements: $targetTroupeName (ID: $targetTroupeId)');
    } else {
      _showSnackBar('Please select a troupe or sub-troupe first.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TroupeAnnouncementsPage(
          troupeId: targetTroupeId!,
          troupeName: targetTroupeName!,
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

    // Check if user data (and thus assignments) has been loaded
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Troupe & Announcement Viewer')),
        body: Center(child: Text('Please log in to view troupes.', style: TextStyle(color: textOnBackground))),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Troupe & Announcement Viewer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a troupe to view its specific announcements.',
              style: TextStyle(fontSize: 16, color: textOnBackground),
            ),
            const SizedBox(height: 20),
            _isLoadingTroupes
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : (_parentTroupes.isEmpty && !_isAdmin)
                  ? Center(
                      child: Text(
                        'No troupes assigned to you.',
                        style: TextStyle(fontSize: 16, color: textOnBackground.withOpacity(0.7)),
                      ),
                    )
                  : Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 3,
                    color: backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Parent Troupe:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _selectedParentTroupeId,
                            hint: Text('Choose a Parent Troupe', style: TextStyle(color: textOnBackground.withOpacity(0.7))),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            items: _parentTroupes.map((doc) {
                              final data = doc.data() as Map<String, dynamic>; // Explicit cast
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['name'] ?? 'Unnamed Parent', style: TextStyle(color: textOnBackground)),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedParentTroupeId = newValue;
                                _selectedParentTroupeName = (newValue != null)
                                    ? (_parentTroupes
                                        .firstWhere((doc) => doc.id == newValue)
                                        .data() as Map<String, dynamic>)['name'] as String? // Corrected access
                                    : null;
                                _selectedSubTroupeId = null; // Clear sub-troupe selection
                                _selectedSubTroupeName = null;
                              });
                              if (newValue != null) {
                                _fetchSubTroupes(newValue);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          // Sub-troupe dropdown, only visible if a parent troupe is selected and has sub-troupes
                          if (_selectedParentTroupeId != null && _subTroupes.isNotEmpty) ...[
                            Text(
                              'Select Sub-Troupe (Optional):',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: _selectedSubTroupeId,
                              hint: Text('Choose a Sub-Troupe', style: TextStyle(color: textOnBackground.withOpacity(0.7))),
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: _subTroupes.map((doc) {
                                final data = doc.data() as Map<String, dynamic>; // Explicit cast
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(data['name'] ?? 'Unnamed Sub-Troupe', style: TextStyle(color: textOnBackground)),
                                );
                              }).toList(),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedSubTroupeId = newValue;
                                  _selectedSubTroupeName = (newValue != null)
                                      ? (_subTroupes
                                          .firstWhere((doc) => doc.id == newValue)
                                          .data() as Map<String, dynamic>)['name'] as String? // Corrected access
                                      : null;
                                });
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                          Center(
                            child: ElevatedButton(
                              onPressed: _navigateToAnnouncements,
                              child: const Text('View Announcements'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
