import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class TroupeSelectionPage extends StatefulWidget {
  const TroupeSelectionPage({super.key});

  @override
  State<TroupeSelectionPage> createState() => _TroupeSelectionPageState();
}

class _TroupeSelectionPageState extends State<TroupeSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedParentTroupeId;
  String? _selectedParentTroupeName;
  String? _selectedSubTroupeId;
  String? _selectedSubTroupeName;

  // Track if a user wants to post to a parent troupe only
  bool _postToParentOnly = false; // This flag is primarily for the UI feedback on this page.
                                // The actual logic for "parent only" is determined by
                                // whether _selectedSubTroupeId is null when parent is selected.

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
        title: const Text('Select Troupe(s) for Announcement'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a parent troupe and/or a sub-troupe to target your announcement. If no selection is made, the announcement will be global (Dashboard).',
                  style: TextStyle(fontSize: 16, color: textOnBackground),
                ),
                const SizedBox(height: 20),
                Text(
                  'Selected Target:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 10),
                if (_selectedParentTroupeName == null && _selectedSubTroupeName == null)
                  Text('No Troupe Selected (Global/Dashboard)',
                      style: TextStyle(fontSize: 14, color: textOnBackground.withOpacity(0.8)))
                else if (_selectedSubTroupeName != null)
                  Text('Parent: $_selectedParentTroupeName\nSub-Troupe: $_selectedSubTroupeName',
                      style: TextStyle(fontSize: 14, color: textOnBackground.withOpacity(0.8)))
                else
                  Text('Parent Troupe: $_selectedParentTroupeName (Only)',
                      style: TextStyle(fontSize: 14, color: textOnBackground.withOpacity(0.8))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Return current selection to previous page
                          Navigator.pop(context, {
                            'parentTroupeId': _selectedParentTroupeId,
                            'parentTroupeName': _selectedParentTroupeName,
                            'subTroupeId': _selectedSubTroupeId,
                            'subTroupeName': _selectedSubTroupeName,
                          });
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm Selection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    if (_selectedParentTroupeId != null) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedParentTroupeId = null;
                            _selectedParentTroupeName = null;
                            _selectedSubTroupeId = null;
                            _selectedSubTroupeName = null;
                            _postToParentOnly = false; // Reset this flag too
                            debugPrint('TroupeSelectionPage: Cleared all troupe selections.');
                          });
                          _showSnackBar('Selection cleared.');
                        },
                        icon: Icon(Icons.clear, color: primaryColor),
                        tooltip: 'Clear selection',
                      ),
                    ],
                  ],
                ),
                // Option to post to parent only if a parent is selected and no sub-troupe
                // This checkbox is for visual clarification on this page, the actual
                // determination is based on whether _selectedSubTroupeId is null when parent is selected.
                if (_selectedParentTroupeId != null && _selectedSubTroupeId == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _postToParentOnly,
                          onChanged: (bool? value) {
                            setState(() {
                              _postToParentOnly = value ?? false;
                              // If checked, ensure no sub-troupe is implicitly selected.
                              // This logic is mostly for UX on this page.
                              if (_postToParentOnly) {
                                _selectedSubTroupeId = null;
                                _selectedSubTroupeName = null;
                              }
                            });
                          },
                          activeColor: primaryColor,
                        ),
                        Text('Post to Parent Troupe Only', style: TextStyle(color: textOnBackground)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('troupes')
                  .where('isParentTroupe', isEqualTo: true) // Only show parent troupes
                  .orderBy('order', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('TroupeSelectionPage Error: ${snapshot.error}');
                  return Center(child: Text('Error loading troupes: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No troupes found.', style: TextStyle(color: textOnBackground)));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot parentDoc = snapshot.data!.docs[index];
                    Map<String, dynamic> parentData = parentDoc.data() as Map<String, dynamic>;
                    final String parentId = parentDoc.id;
                    final String parentName = parentData['name'] ?? 'Unnamed Troupe';

                    // Check if this parent troupe is currently selected
                    final bool isParentSelected = _selectedParentTroupeId == parentId;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      color: isParentSelected ? primaryColor.withOpacity(0.1) : backgroundColor,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.school, color: primaryColor),
                            title: Text(
                              parentName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isParentSelected ? primaryColor : textOnBackground,
                              ),
                            ),
                            trailing: isParentSelected
                                ? Icon(Icons.check_circle, color: primaryColor)
                                : null,
                            onTap: () {
                              setState(() {
                                // If already selected, deselect it and any sub-troupe
                                if (isParentSelected) {
                                  _selectedParentTroupeId = null;
                                  _selectedParentTroupeName = null;
                                  _selectedSubTroupeId = null;
                                  _selectedSubTroupeName = null;
                                  _postToParentOnly = false; // Reset this flag too
                                } else {
                                  // Select this parent troupe, clear any sub-troupe selection
                                  _selectedParentTroupeId = parentId;
                                  _selectedParentTroupeName = parentName;
                                  _selectedSubTroupeId = null; // Always clear sub-troupe when parent changes
                                  _selectedSubTroupeName = null;
                                  _postToParentOnly = false; // Default to not "parent only" when a new parent is selected
                                }
                              });
                            },
                          ),
                          // Display sub-troupes if this parent is selected
                          if (isParentSelected)
                            StreamBuilder<QuerySnapshot>(
                              stream: _firestore
                                  .collection('troupes')
                                  .where('isParentTroupe', isEqualTo: false)
                                  .where('parentTroupeId', isEqualTo: parentId)
                                  .orderBy('order', descending: false)
                                  .snapshots(),
                              builder: (context, subSnapshot) {
                                if (subSnapshot.hasError) {
                                  return Text('Error loading sub-troupes: ${subSnapshot.error}', style: TextStyle(color: primaryColor));
                                }
                                if (subSnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (!subSnapshot.hasData || subSnapshot.data!.docs.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 20.0, bottom: 8.0),
                                    child: Text('No sub-troupes.', style: TextStyle(color: textOnBackground.withOpacity(0.7))),
                                  );
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: subSnapshot.data!.docs.length,
                                  itemBuilder: (context, subIndex) {
                                    DocumentSnapshot subDoc = subSnapshot.data!.docs[subIndex];
                                    Map<String, dynamic> subData = subDoc.data() as Map<String, dynamic>;
                                    final String subId = subDoc.id;
                                    final String subName = subData['name'] ?? 'Unnamed Sub-Troupe';

                                    // Check if this sub-troupe is currently selected
                                    final bool isSubSelected = _selectedSubTroupeId == subId;

                                    return ListTile(
                                      contentPadding: const EdgeInsets.only(left: 40.0, right: 16.0),
                                      leading: Icon(Icons.group, color: primaryColor.withOpacity(0.7)),
                                      title: Text(
                                        subName,
                                        style: TextStyle(
                                          color: isSubSelected ? primaryColor : textOnBackground,
                                        ),
                                      ),
                                      trailing: isSubSelected
                                          ? Icon(Icons.check_circle, color: primaryColor)
                                          : null,
                                      onTap: () {
                                        setState(() {
                                          if (isSubSelected) {
                                            _selectedSubTroupeId = null;
                                            _selectedSubTroupeName = null;
                                          } else {
                                            _selectedSubTroupeId = subId;
                                            _selectedSubTroupeName = subName;
                                            _postToParentOnly = false; // If sub-troupe selected, this option is irrelevant
                                          }
                                        });
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
