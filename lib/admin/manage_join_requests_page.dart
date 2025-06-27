import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:ssd_barre_new/user/user_data_service.dart'; // From lib/user/
import 'package:intl/intl.dart';

// No changes needed for this import based on your structure, but ensure it's there
import '../user/join_troupe_page.dart'; // For date formatting (likely unused directly here but common import)

class ManageJoinRequestsPage extends StatefulWidget {
  const ManageJoinRequestsPage({super.key});

  @override
  State<ManageJoinRequestsPage> createState() => _ManageJoinRequestsPageState();
}

class _ManageJoinRequestsPageState extends State<ManageJoinRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();
  String? _adminUid;

  @override
  void initState() {
    super.initState();
    _initializeAdminData(); // Call this async method
  }

  Future<void> _initializeAdminData() async {
    _adminUid = _auth.currentUser?.uid;
    if (_adminUid != null) {
      debugPrint('ManageJoinRequestsPage: Current admin UID from FirebaseAuth: $_adminUid'); // ADDED LOG

      // Fetch ID token and claims to confirm admin status at entry
      try {
        final idTokenResult = await _auth.currentUser?.getIdTokenResult(true); // Force refresh
        final isAdminFromToken = idTokenResult?.claims?['isAdmin'] == true;
        debugPrint('ManageJoinRequestsPage: Token refresh success. Has token: ${idTokenResult != null}');
        debugPrint('ManageJoinRequestsPage: Token claims: ${idTokenResult?.claims}');
        debugPrint('ManageJoinRequestsPage: Is admin claim from token: $isAdminFromToken');
      } catch (e) {
        debugPrint('ManageJoinRequestsPage: Error fetching ID token and claims: $e');
      }

      // Reset unread count for join requests when admin views this page
      await _userDataService.resetUnreadJoinRequestCount(_adminUid!);
      debugPrint('ManageJoinRequestsPage: Unread join request count reset to 0 for admin $_adminUid.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _approveRequest(DocumentSnapshot requestDoc) async {
    try {
      debugPrint('ManageJoinRequestsPage: Attempting to approve request: ${requestDoc.id}');
      await _firestore.collection('joinRequests').doc(requestDoc.id).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
      });
      _showSnackBar('Join request approved!');
      debugPrint('ManageJoinRequestsPage: Successfully approved request: ${requestDoc.id}');
    } catch (e) {
      debugPrint('ManageJoinRequestsPage: Error approving request ${requestDoc.id}: $e');
      _showSnackBar('Failed to approve request: $e'); // Show error to user
    }
  }

  Future<void> _rejectRequest(String requestId, String requestedTroupeName) async {
    try {
      debugPrint('ManageJoinRequestsPage: Attempting to reject request: $requestId');
      await _firestore.collection('joinRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
      });
      // If you prefer to delete rejected requests immediately, uncomment the line below
      // and comment out the .update() call above.
      // await _firestore.collection('joinRequests').doc(requestId).delete();
      _showSnackBar('Join request rejected!');
      debugPrint('ManageJoinRequestsPage: Successfully rejected request: $requestId');
    } catch (e) {
      debugPrint('ManageJoinRequestsPage: Error rejecting request $requestId: $e');
      _showSnackBar('Failed to reject request: $e'); // Show error to user
    }
  }


  @override
  Widget build(BuildContext context) {
    // You can optionally add a check for _adminUid here to show a loading spinner
    // or an access denied message if _adminUid is null or not an admin.
    // For now, we proceed assuming _initializeAdminData will handle this.

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Join Requests'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Review and manage incoming join requests.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('joinRequests')
                    .where('status', isEqualTo: 'pending')
                    .orderBy('requestedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('ManageJoinRequestsPage: Stream error: ${snapshot.error}');
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No pending join requests.'));
                  }

                  final requests = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final requestDoc = requests[index];
                      final requestData = requestDoc.data() as Map<String, dynamic>;

                      final String userEmail = requestData['userEmail'] ?? 'N/A';
                      final String? parentTroupeId = requestData['parentTroupeId'];
                      final String? parentTroupeName = requestData['parentTroupeName'];
                      final String? subTroupeId = requestData['subTroupeId'];
                      final String? subTroupeName = requestData['subTroupeName'];
                      final Timestamp? requestedAt = requestData['requestedAt'];

                      String requestedTroupeName = 'Global'; // Default
                      if (subTroupeName != null && subTroupeName.isNotEmpty) {
                        requestedTroupeName = subTroupeName;
                      } else if (parentTroupeName != null && parentTroupeName.isNotEmpty) {
                        requestedTroupeName = parentTroupeName;
                      }

                      String timeAgo = '';
                      if (requestedAt != null) {
                        final dateTime = requestedAt.toDate();
                        timeAgo = DateFormat('MMM dd, yyyy HH:mm').format(dateTime); // Format as desired
                        // You could also use a package like 'timeago' for "5 minutes ago" style
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Request from: $userEmail',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'For Troupe: $requestedTroupeName',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (parentTroupeId != null && parentTroupeName != null && subTroupeId != null && subTroupeName != null)
                                Text(
                                  'Parent: $parentTroupeName, Sub: $subTroupeName',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 5),
                              Text(
                                'Requested at: $timeAgo',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _approveRequest(requestDoc),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green, // Green for approve
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Approve'),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () => _rejectRequest(requestDoc.id, requestedTroupeName),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red, // Red for reject
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Reject'),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}