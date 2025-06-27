import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:ssd_barre_new/user/user_data_service.dart'; // From lib/user/
import 'package:ssd_barre_new/admin/troupe_content_page.dart'; // To navigate to content for sub-troupes
import 'package:ssd_barre_new/admin/sub_troupes_page.dart'; // To navigate to sub-troupe list for parent troupes

class MyTroupesPage extends StatefulWidget {
  const MyTroupesPage({super.key});

  @override
  State<MyTroupesPage> createState() => _MyTroupesPageState();
}

class _MyTroupesPageState extends State<MyTroupesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService();
  User? _currentUser;
  List<String> _assignedParentTroupeIds = [];
  List<String> _assignedSubTroupeIds = [];
  bool _isLoading = true;
  bool _isAdmin = false; // To determine if admin access is needed for navigation

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      _isLoading = false; // No user, no data to load
      debugPrint('MyTroupesPage: No current user logged in.');
    } else {
      _fetchAssignedTroupesAndAdminStatus();
    }
  }

  Future<void> _fetchAssignedTroupesAndAdminStatus() async {
    if (_currentUser == null) return;

    try {
      // Fetch user's assigned troupes and admin status
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _assignedParentTroupeIds = List<String>.from(userData?['assignedGroups'] ?? []);
          _assignedSubTroupeIds = List<String>.from(userData?['assignedSubgroups'] ?? []);
          _isAdmin = userData?['isAdmin'] ?? false;
          _isLoading = false;
        });
        debugPrint('MyTroupesPage: User ${_currentUser!.uid} assigned to groups: $_assignedParentTroupeIds, subgroups: $_assignedSubTroupeIds. Is Admin: $_isAdmin');
      } else {
        setState(() {
          _isLoading = false;
        });
        debugPrint('MyTroupesPage: User document not found for ${_currentUser!.uid}.');
      }
    } catch (e) {
      debugPrint('MyTroupesPage Error: Failed to fetch user assignments or admin status: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Failed to load your troupe assignments.');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Troupes'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : (_assignedParentTroupeIds.isEmpty && _assignedSubTroupeIds.isEmpty)
              ? Center(
                  child: Text(
                    'You are not yet assigned to any troupes.',
                    style: TextStyle(fontSize: 16, color: textOnBackground.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Display Parent Troupes the user is assigned to
                    if (_assignedParentTroupeIds.isNotEmpty) ...[
                      Text(
                        'My Parent Troupes:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('troupes')
                            .where(FieldPath.documentId, whereIn: _assignedParentTroupeIds)
                            .orderBy('order', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            debugPrint('MyTroupesPage Parent Stream Error: ${snapshot.error}');
                            return Center(child: Text('Error loading parent troupes.', style: TextStyle(color: primaryColor)));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: primaryColor));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(child: Text('No parent troupes assigned.', style: TextStyle(color: textOnBackground.withOpacity(0.7))));
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              DocumentSnapshot doc = snapshot.data!.docs[index];
                              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                              final String troupeName = data['name'] ?? 'Unnamed Troupe';
                              final String troupeId = doc.id;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 3,
                                color: backgroundColor,
                                child: InkWell(
                                  onTap: () {
                                    // Navigate to the SubTroupesPage for this parent troupe
                                    debugPrint('MyTroupesPage: Tapped on assigned parent troupe: $troupeName');
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SubTroupesPage(parentTroupeId: troupeId, parentTroupeName: troupeName),
                                      ),
                                    );
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
                                                  fontSize: 18,
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
                                        const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                    // Display Sub-Troupes the user is assigned to
                    if (_assignedSubTroupeIds.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      Text(
                        'My Sub-Troupes:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('troupes')
                            .where(FieldPath.documentId, whereIn: _assignedSubTroupeIds)
                            .orderBy('order', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            debugPrint('MyTroupesPage Sub Stream Error: ${snapshot.error}');
                            return Center(child: Text('Error loading sub-troupes.', style: TextStyle(color: primaryColor)));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator(color: primaryColor));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(child: Text('No sub-troupes assigned.', style: TextStyle(color: textOnBackground.withOpacity(0.7))));
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: snapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              DocumentSnapshot doc = snapshot.data!.docs[index];
                              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                              final String subTroupeName = data['name'] ?? 'Unnamed Sub-Troupe';
                              final String subTroupeId = doc.id;
                              final String parentTroupeId = data['parentTroupeId'] ?? ''; // Get parent ID

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8.0),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 3,
                                color: backgroundColor,
                                child: InkWell(
                                  onTap: () {
                                    // Navigate directly to the TroupeContentPage for this sub-troupe
                                    debugPrint('MyTroupesPage: Tapped on assigned sub-troupe: $subTroupeName');
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TroupeContentPage(troupeId: subTroupeId, troupeName: subTroupeName),
                                      ),
                                    );
                                  },
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
                                                  fontSize: 18,
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
                                        const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
    );
  }
}
