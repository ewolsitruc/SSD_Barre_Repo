import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/join_request_service.dart';

class JoinTroupePage extends StatefulWidget {
  const JoinTroupePage({super.key});

  @override
  State<JoinTroupePage> createState() => _JoinTroupePageState();
}

class _JoinTroupePageState extends State<JoinTroupePage> {
  final Map<String, bool> _expandedTroupes = {};
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Set<String> _pendingRequests = {};
  Set<String> _joinedTroupes = {};
  bool _isLoading = true;
  late Stream<QuerySnapshot> _parentTroupeStream;

  @override
  void initState() {
    super.initState();
    _parentTroupeStream = _firestore
        .collection('troupes')
        .where('isParentTroupe', isEqualTo: true)
        .orderBy('order')
        .snapshots();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final joinReqs = await _firestore
          .collection('joinRequests')
          .where('userId', isEqualTo: user.uid)
          .get();

      final pending = <String>{};
      final joined = <String>{};

      for (var doc in joinReqs.docs) {
        final data = doc.data();

        // Safely get fields as nullable strings
        final status = data['status'] as String?;
        final troupeId = data['requestedTroupeId'] as String?;

        if (status == 'pending' && troupeId != null) {
          pending.add(troupeId);
        } else if (status == 'approved' && troupeId != null) {
          joined.add(troupeId);
        }
      }

      setState(() {
        _pendingRequests = pending;
        _joinedTroupes = joined;
        _isLoading = false;
      });
    } catch (e, stacktrace) {
      // Log the error, optionally set _isLoading = false here
      print('Error loading join requests: $e');
      print(stacktrace);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleJoinRequest({
    required String troupeId,
    String? parentTroupeId,
  }) async {
    await JoinRequestService.sendJoinRequest(
      troupeId: troupeId,
      parentTroupeId: parentTroupeId,
    );
    await _loadUserData();
  }

  Widget _buildJoinButton(String troupeId, {String? parentTroupeId}) {
    if (_joinedTroupes.contains(troupeId)) {
      return const Text('Joined', style: TextStyle(color: Colors.green));
    } else if (_pendingRequests.contains(troupeId)) {
      return const Text('Pending', style: TextStyle(color: Colors.orange));
    } else {
      return ElevatedButton(
        onPressed: () => _handleJoinRequest(
          troupeId: troupeId,
          parentTroupeId: parentTroupeId,
        ),
        child: const Text('Join'),
      );
    }
  }

  Widget _buildParentTroupeTile(DocumentSnapshot parentDoc) {
    final parentId = parentDoc.id;
    final data = parentDoc.data() as Map<String, dynamic>? ?? {};
    final parentName = data['name'] ?? 'Unnamed';
    final isExpanded = _expandedTroupes[parentId] ?? false;

    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('troupes')
          .where('isParentTroupe', isEqualTo: false)
          .where('parentTroupeId', isEqualTo: parentId)
          .get(),
      builder: (context, snapshot) {
        final subTroupes = snapshot.data?.docs ?? [];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(parentName, style: const TextStyle(fontSize: 18)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildJoinButton(parentId),
                    if (subTroupes.isNotEmpty)
                      IconButton(
                        icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                        onPressed: () {
                          setState(() {
                            _expandedTroupes[parentId] = !isExpanded;
                          });
                        },
                      ),
                  ],
                ),
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                  child: Column(
                    children: subTroupes.map<Widget>((subDoc) {
                      final subId = subDoc.id;
                      final subData = subDoc.data() as Map<String, dynamic>? ?? {};
                      final subName = subData['name'] ?? 'Unnamed Subgroup';
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(subName),
                        trailing: _buildJoinButton(subId, parentTroupeId: parentId),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Troupe'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: _parentTroupeStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading troupes'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final parents = snapshot.data?.docs ?? [];

          if (parents.isEmpty) {
            return const Center(child: Text('No troupes found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: parents.length,
            itemBuilder: (context, index) {
              return _buildParentTroupeTile(parents[index]);
            },
          );
        },
      ),
    );
  }
}
