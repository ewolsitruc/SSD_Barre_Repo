import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:ssd_barre_new/user/user_data_service.dart'; // From lib/user/
import 'package:ssd_barre_new/admin/add_troupe_page.dart'; // From lib/admin/
import 'package:ssd_barre_new/admin/troupe_content_page.dart'; // From lib/admin/


// This page displays sub-troupes for a given parent troupe.
class SubTroupesPage extends StatefulWidget {
  final String parentTroupeId;
  final String parentTroupeName;

  const SubTroupesPage({
    super.key,
    required this.parentTroupeId,
    required this.parentTroupeName,
  });

  @override
  State<SubTroupesPage> createState() => _SubTroupesPageState();
}

class _SubTroupesPageState extends State<SubTroupesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService(); // Instance of UserDataService
  bool _isAdmin = false; // State to hold admin status
  User? _currentUser; // Keep track of the current user to pass to _getJoinStatus

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser; // Get current user on init
    _checkAdminStatus(); // Check admin status on init
  }

  // Function to check and update admin status
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

  // Function to determine the status of the join button for a troupe/sub-troupe
  // Returns 'joined', 'pending', or 'join'
  Future<String> _getJoinStatus(String troupeId, User? user) async {
    if (user == null) return 'join'; // Not logged in, can only join

    // 1. Check if the user is already assigned to this troupe/sub-troupe
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      final List<dynamic> assignedGroups = userData?['assignedGroups'] ?? [];
      final List<dynamic> assignedSubgroups = userData?['assignedSubgroups'] ?? [];

      // Check if the current troupeId is in either assignedGroups or assignedSubgroups
      if (assignedGroups.contains(troupeId) || assignedSubgroups.contains(troupeId)) {
        debugPrint('SubTroupesPage - _getJoinStatus: User ${user.uid} is already JOINED to $troupeId.');
        return 'joined';
      }
    }

    // 2. Check if there's a pending join request for this troupe/sub-troupe
    final querySnapshot = await _firestore
        .collection('joinRequests')
        .where('userId', isEqualTo: user.uid)
        .where('requestedTroupeId', isEqualTo: troupeId) // Use the new field name
        .where('status', isEqualTo: 'pending')
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      debugPrint('SubTroupesPage - _getJoinStatus: User ${user.uid} has a PENDING request for $troupeId.');
      return 'pending';
    }

    debugPrint('SubTroupesPage - _getJoinStatus: User ${user.uid} can JOIN $troupeId.');
    return 'join'; // No existing membership or pending request
  }

  // Function to handle sending a join request
  Future<void> _sendJoinRequest({
    required String requestedTroupeId,
    required String requestedTroupeName,
    required bool isRequestForSubTroupe,
    String? parentOfRequestedTroupeId, // Null if it's a parent troupe request
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('You must be logged in to send a join request.');
      debugPrint('SubTroupesPage - _sendJoinRequest: User not logged in.');
      return;
    }

    // Prevent multiple pending requests for the same troupe
    final currentStatus = await _getJoinStatus(requestedTroupeId, user); // Pass user to the helper function
    if (currentStatus == 'pending') {
      _showSnackBar('Your request to join "$requestedTroupeName" is already pending.');
      debugPrint('SubTroupesPage - _sendJoinRequest: Already pending for $requestedTroupeName.');
      return;
    }
    if (currentStatus == 'joined') {
      _showSnackBar('You are already a member of "$requestedTroupeName".');
      debugPrint('SubTroupesPage - _sendJoinRequest: Already joined $requestedTroupeName.');
      return;
    }

    debugPrint('SubTroupesPage - _sendJoinRequest: Attempting to send join request for troupe $requestedTroupeName (ID: $requestedTroupeId) by user ${user.email} (UID: ${user.uid}).');
    debugPrint('  Is request for sub-troupe: $isRequestForSubTroupe');
    if (parentOfRequestedTroupeId != null) {
      debugPrint('  Parent of requested troupe: $parentOfRequestedTroupeId');
    }

    try {
      final docRef = await _firestore.collection('joinRequests').add({
        'userId': user.uid,
        'userEmail': user.email, // Store email for easier admin review
        'requestedTroupeId': requestedTroupeId,
        'requestedTroupeName': requestedTroupeName,
        'isRequestForSubTroupe': isRequestForSubTroupe,
        'parentOfRequestedTroupeId': parentOfRequestedTroupeId, // Will be widget.parentTroupeId for sub-troupe requests
        'status': 'pending', // 'pending', 'approved', 'rejected'
        'requestedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Request to join "$requestedTroupeName" sent successfully! Awaiting admin approval.');
      debugPrint('SubTroupesPage - _sendJoinRequest: Join request document created with ID: ${docRef.id}.');
      setState(() {
        // Trigger a rebuild to update the button state
      });
    } catch (e) {
      _showSnackBar('Failed to send join request: $e');
      debugPrint('SubTroupesPage - _sendJoinRequest Error: Failed to send join request for $requestedTroupeName: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // NEW: Function to handle editing a sub-troupe
  void _editSubTroupe(String subTroupeId, Map<String, dynamic> subTroupeData) {
    debugPrint('SubTroupesPage: Admin wants to edit sub-troupe: ${subTroupeData['name']} (ID: $subTroupeId)');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTroupePage( // Reusing AddTroupePage for editing
          troupeToEditId: subTroupeId,
          initialName: subTroupeData['name'],
          initialDescription: subTroupeData['description'],
          initialOrder: subTroupeData['order'],
          parentTroupeId: subTroupeData['parentTroupeId'], // Pass the sub-troupe's existing parent ID
          parentTroupeName: widget.parentTroupeName, // Pass the parent troupe's name for display
        ),
      ),
    ).then((_) {
      // Optional: Refresh data after returning from edit page
      // No explicit refresh needed as StreamBuilder will update automatically
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.parentTroupeName} Sub-Troupes'),
        actions: [
          if (_isAdmin) // Show "Add New" button only if user is an admin
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                debugPrint('SubTroupesPage: Admin wants to add a new Sub-Troupe');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTroupePage(
                      parentTroupeId: widget.parentTroupeId,
                      parentTroupeName: widget.parentTroupeName,
                    ),
                  ),
                );
              },
              tooltip: 'Add New Sub-Troupe',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore the sub-troupes within ${widget.parentTroupeName}.',
              style: TextStyle(
                fontSize: 16,
                color: textOnBackground,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('troupes')
                    .where('isParentTroupe', isEqualTo: false) // Filter for sub-troupes
                    .where('parentTroupeId', isEqualTo: widget.parentTroupeId) // Filter by parent
                    .orderBy('order', descending: false) // Order them by the 'order' field
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('SubTroupesPage Error: ${snapshot.error}');
                    return Center(child: Text('Error loading sub-troupes: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No sub-troupes found for this group yet.', style: TextStyle(color: textOnBackground)));
                  }

                  // Build the list of sub-troupes, showing all to authenticated users
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot doc = snapshot.data!.docs[index];
                      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                      final String subTroupeName = data['name'] ?? 'Unnamed Sub-Troupe';
                      final String subTroupeId = doc.id;

                      // Use FutureBuilder to get the join status for each sub-troupe
                      return FutureBuilder<String>(
                        future: _getJoinStatus(subTroupeId, _currentUser),
                        builder: (context, statusSnapshot) {
                          if (statusSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final String joinStatus = statusSnapshot.data ?? 'join';

                          // Always display the troupe card to authenticated users.
                          // The content page is only accessible if 'joined'.
                          // The Join button handles the request.

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 3,
                            color: backgroundColor,
                            child: InkWell(
                              // Only allow tap to content page if user is joined or is admin
                              onTap: (_isAdmin || joinStatus == 'joined')
                                  ? () {
                                debugPrint('SubTroupesPage: Tapped on sub-troupe: $subTroupeName (ID: $subTroupeId)');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TroupeContentPage(troupeId: subTroupeId, troupeName: subTroupeName),
                                  ),
                                );
                              }
                                  : null, // Disable tap if not admin and not joined
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.group, color: primaryColor, size: 30),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            subTroupeName,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                          if (data['description'] != null && data['description'].isNotEmpty)
                                            Text(
                                              data['description'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: textOnBackground.withOpacity(0.8),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    // NEW: Edit button for admins
                                    if (_isAdmin)
                                      IconButton(
                                        icon: Icon(Icons.edit, color: textOnBackground.withOpacity(0.7)),
                                        onPressed: () => _editSubTroupe(subTroupeId, data),
                                        tooltip: 'Edit Sub-Troupe',
                                      ),
                                    _buildJoinButton(joinStatus, subTroupeId, subTroupeName),
                                  ],
                                ),
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

  Widget _buildJoinButton(String status, String troupeId, String troupeName) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    if (_auth.currentUser == null) {
      return const SizedBox.shrink(); // Hide button if not logged in
    }

    // Admins don't need a join button as they have full access
    if (_isAdmin) {
      return const SizedBox.shrink();
    }

    switch (status) {
      case 'joined':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Joined',
            style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold),
          ),
        );
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Pending',
            style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.bold),
          ),
        );
      case 'join':
      default:
        return ElevatedButton(
          onPressed: () {
            debugPrint('SubTroupesPage - Join button pressed for sub-troupe: $troupeName (ID: $troupeId)');
            // For a sub-troupe, isRequestForSubTroupe is true, and parentOfRequestedTroupeId is widget.parentTroupeId
            _sendJoinRequest(
              requestedTroupeId: troupeId,
              requestedTroupeName: troupeName,
              isRequestForSubTroupe: true,
              parentOfRequestedTroupeId: widget.parentTroupeId,
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor, // Red button
            foregroundColor: Colors.white, // White text
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Join'),
        );
    }
  }
}
