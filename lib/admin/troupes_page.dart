import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:ssd_barre_new/user/user_data_service.dart'; // From lib/user/
import 'package:ssd_barre_new/admin/add_troupe_page.dart'; // From lib/admin/ - Now also used for editing
import 'package:ssd_barre_new/admin/sub_troupes_page.dart'; // From lib/admin/
import 'package:ssd_barre_new/admin/troupe_content_page.dart'; // From lib/admin/


// Helper class to hold combined status information for a troupe
class TroupeOverallStatus {
  final String status; // 'joined', 'pending', 'join'
  final bool hasSubTroupes;

  TroupeOverallStatus({required this.status, required this.hasSubTroupes});
}

class TroupesPage extends StatefulWidget {
  const TroupesPage({super.key});

  @override
  State<TroupesPage> createState() => _TroupesPageState();
}

class _TroupesPageState extends State<TroupesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();
  bool _isAdmin = false;
  User? _currentUser; // To hold the current authenticated user

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser; // Get current user on init
    _checkAdminStatus();
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

  // Function to determine the overall status for a troupe (join status + has sub-troupes)
  Future<TroupeOverallStatus> _getTroupeOverallStatus(String troupeId, User? user) async {
    // 1. Determine join status ('joined', 'pending', 'join')
    String joinStatus = 'join';
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final List<dynamic> assignedGroups = userData?['assignedGroups'] ?? [];
        final List<dynamic> assignedSubgroups = userData?['assignedSubgroups'] ?? [];
        // Check if the user is already assigned to this troupe (parent or sub-troupe)
        if (assignedGroups.contains(troupeId) || assignedSubgroups.contains(troupeId)) {
          joinStatus = 'joined';
        }
      }
      if (joinStatus == 'join') { // Only check pending if not already joined
        final querySnapshot = await _firestore
            .collection('joinRequests')
            .where('userId', isEqualTo: user.uid)
            .where('requestedTroupeId', isEqualTo: troupeId)
            .where('status', isEqualTo: 'pending')
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          joinStatus = 'pending';
        }
      }
    }

    // 2. Check if this parent troupe has any sub-troupes
    bool hasSubTroupes = false;
    try {
      final subTroupesSnapshot = await _firestore
          .collection('troupes')
          .where('isParentTroupe', isEqualTo: false)
          .where('parentTroupeId', isEqualTo: troupeId)
          .limit(1) // Only need to know if at least one exists
          .get();
      hasSubTroupes = subTroupesSnapshot.docs.isNotEmpty;
      debugPrint('TroupesPage - _getTroupeOverallStatus: Troupe $troupeId has sub-troupes: $hasSubTroupes');
    } catch (e) {
      debugPrint('TroupesPage - _getTroupeOverallStatus Error checking sub-troupes for $troupeId: $e');
    }

    return TroupeOverallStatus(status: joinStatus, hasSubTroupes: hasSubTroupes);
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
      debugPrint('TroupesPage - _sendJoinRequest: User not logged in.');
      return;
    }

    // Prevent multiple pending requests for the same troupe/sub-troupe
    final TroupeOverallStatus currentOverallStatus = await _getTroupeOverallStatus(requestedTroupeId, user);
    final String currentStatus = currentOverallStatus.status; // Use the status from the combined object

    if (currentStatus == 'pending') {
      _showSnackBar('Your request to join "$requestedTroupeName" is already pending.');
      debugPrint('TroupesPage - _sendJoinRequest: Already pending for $requestedTroupeName.');
      return;
    }
    if (currentStatus == 'joined') {
      _showSnackBar('You are already a member of "$requestedTroupeName".');
      debugPrint('TroupesPage - _sendJoinRequest: Already joined $requestedTroupeName.');
      return;
    }

    debugPrint('TroupesPage - _sendJoinRequest: Attempting to send join request for troupe $requestedTroupeName (ID: $requestedTroupeId) by user ${user.email} (UID: ${user.uid}).');
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
        'parentOfRequestedTroupeId': parentOfRequestedTroupeId, // Will be null for parent troupe requests
        'status': 'pending', // 'pending', 'approved', 'rejected'
        'requestedAt': FieldValue.serverTimestamp(),
      });
      _showSnackBar('Request to join "$requestedTroupeName" sent successfully! Awaiting admin approval.');
      debugPrint('TroupesPage - _sendJoinRequest: Join request document created with ID: ${docRef.id}.');
      setState(() {
        // Trigger a rebuild to re-evaluate FutureBuilder and update the button state to 'pending'
      });
    } catch (e) {
      _showSnackBar('Failed to send join request: $e');
      debugPrint('TroupesPage - _sendJoinRequest Error: Failed to send join request for $requestedTroupeName: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // NEW: Function to handle editing a troupe
  void _editTroupe(String troupeId, Map<String, dynamic> troupeData) {
    debugPrint('TroupesPage: Admin wants to edit troupe: ${troupeData['name']} (ID: $troupeId)');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTroupePage( // Reusing AddTroupePage for editing
          troupeToEditId: troupeId,
          initialName: troupeData['name'],
          initialDescription: troupeData['description'],
          initialOrder: troupeData['order'],
          parentTroupeId: troupeData['parentTroupeId'], // Pass existing parent ID if it's a sub-troupe
          parentTroupeName: null, // We might not have parent name here easily, AddTroupePage can handle null
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
        title: const Text('Troupes'),
        actions: [
          if (_isAdmin) // Show "Add New" button only if user is an admin
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                debugPrint('TroupesPage: Admin wants to add a new Parent Troupe');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddTroupePage()),
                );
              },
              tooltip: 'Add New Troupe',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Browse available troupes and join to access their content.',
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
                    .where('isParentTroupe', isEqualTo: true) // Filter for parent troupes
                    .orderBy('order', descending: false) // Order them by the 'order' field
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('TroupesPage Error: ${snapshot.error}');
                    return Center(child: Text('Error loading troupes: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No troupes found yet.', style: TextStyle(color: textOnBackground)));
                  }

                  // Build the list of parent troupes, showing all to authenticated users.
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot doc = snapshot.data!.docs[index];
                      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                      final String troupeName = data['name'] ?? 'Unnamed Troupe';
                      final String troupeId = doc.id;

                      // Use FutureBuilder to get the combined status (join status + has sub-troupes)
                      return FutureBuilder<TroupeOverallStatus>(
                        future: _getTroupeOverallStatus(troupeId, _currentUser),
                        builder: (context, statusSnapshot) {
                          if (statusSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: primaryColor));
                          }
                          // Safely get the data, providing defaults if null
                          final TroupeOverallStatus overallStatus = statusSnapshot.data ?? TroupeOverallStatus(status: 'join', hasSubTroupes: false);
                          final String joinStatus = overallStatus.status;
                          final bool hasSubTroupes = overallStatus.hasSubTroupes;
                          final bool isJoined = joinStatus == 'joined';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 3,
                            color: backgroundColor,
                            child: InkWell(
                              onTap: () {
                                debugPrint('TroupesPage: Tapped on troupe: $troupeName (ID: $troupeId)');
                                // Navigate to SubTroupesPage or TroupeContentPage based on join status
                                if (isJoined || _isAdmin) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SubTroupesPage(parentTroupeId: troupeId, parentTroupeName: troupeName),
                                    ),
                                  );
                                } else {
                                  _showSnackBar('Join this troupe to view its content and sub-troupes!');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.school, color: primaryColor, size: 30),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            troupeName,
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
                                        onPressed: () => _editTroupe(troupeId, data),
                                        tooltip: 'Edit Troupe',
                                      ),
                                    // Pass hasSubTroupes to the button builder
                                    _buildJoinButton(joinStatus, troupeId, troupeName, hasSubTroupes),
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

  // Modified _buildJoinButton to consider hasSubTroupes
  Widget _buildJoinButton(String status, String troupeId, String troupeName, bool hasSubTroupes) {
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
      // If the parent troupe has sub-troupes, navigate to the sub-troupes page
        if (hasSubTroupes) {
          return ElevatedButton(
            onPressed: () {
              debugPrint('TroupesPage - Navigating to SubTroupesPage for parent: $troupeName (ID: $troupeId)');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubTroupesPage(parentTroupeId: troupeId, parentTroupeName: troupeName),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary, // Use secondary color (black) for "View Sub-Troupes"
              foregroundColor: Theme.of(context).colorScheme.onSecondary, // Use onSecondary (white)
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('View Sub-Troupes'), // Changed text to indicate navigation
          );
        } else {
          // If no sub-troupes, send a join request for the parent troupe
          return ElevatedButton(
            onPressed: () {
              debugPrint('TroupesPage - Join button pressed for parent troupe (no sub-troupes): $troupeName (ID: $troupeId)');
              _sendJoinRequest(
                requestedTroupeId: troupeId,
                requestedTroupeName: troupeName,
                isRequestForSubTroupe: false,
                parentOfRequestedTroupeId: null,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor, // Use primary red for "Join" button
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Join'),
          );
        }
    }
  }
}
