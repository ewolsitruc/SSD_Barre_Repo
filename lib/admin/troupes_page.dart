import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Still potentially useful for context
import 'package:flutter/foundation.dart'; // For debugPrint
import '../user/user_data_service.dart'; // Import UserDataService
import 'troupe_announcements_page.dart'; // NEW: Import the page to display troupe announcements

class TroupesPage extends StatefulWidget {
  const TroupesPage({super.key});

  @override
  State<TroupesPage> createState() => _TroupesPageState();
}

class _TroupesPageState extends State<TroupesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDataService _userDataService = UserDataService();
  final FirebaseAuth _auth = FirebaseAuth.instance; // For user context if needed
  
  String? _selectedParentTroupeId;
  String? _selectedParentTroupeName;
  String? _selectedSubTroupeId;
  String? _selectedSubTroupeName;

  List<DocumentSnapshot> _parentTroupes = [];
  List<DocumentSnapshot> _subTroupes = [];
  bool _isLoadingTroupes = true;

  @override
  void initState() {
    super.initState();
    _fetchParentTroupes();
  }

  Future<void> _fetchParentTroupes() async {
    setState(() {
      _isLoadingTroupes = true;
    });
    try {
      final snapshot = await _firestore
          .collection('troupes')
          .where('isParentTroupe', isEqualTo: true)
          .orderBy('order', descending: false)
          .get();
      setState(() {
        _parentTroupes = snapshot.docs;
        _isLoadingTroupes = false;
      });
      debugPrint('TroupesPage: Fetched ${snapshot.docs.length} parent troupes.');
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
      final snapshot = await _firestore
          .collection('troupes')
          .where('isParentTroupe', isEqualTo: false)
          .where('parentTroupeId', isEqualTo: parentTroupeId)
          .orderBy('order', descending: false)
          .get();
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
