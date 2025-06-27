import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../admin/troupe_selection_page.dart';

class AssignTeacherToTroupePage extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const AssignTeacherToTroupePage({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<AssignTeacherToTroupePage> createState() => _AssignTeacherToTroupePageState();
}

class _AssignTeacherToTroupePageState extends State<AssignTeacherToTroupePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> _assignedGroups = [];
  List<String> _assignedSubgroups = [];

  // Maps to resolve IDs to names for display
  Map<String, String> _groupNames = {};
  Map<String, String> _subgroupNames = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    final userDoc = await _firestore.collection('users').doc(widget.teacherId).get();
    final userData = userDoc.data();

    final assignedGroups = List<String>.from(userData?['assignedGroups'] ?? []);
    final assignedSubgroups = List<String>.from(userData?['assignedSubgroups'] ?? []);

    // Fetch names for groups and subgroups
    final groupDocs = await _firestore
        .collection('troupes')
        .where(FieldPath.documentId, whereIn: assignedGroups.isEmpty ? ['dummy'] : assignedGroups)
        .get();

    final subgroupDocs = await _firestore
        .collection('troupes')
        .where(FieldPath.documentId, whereIn: assignedSubgroups.isEmpty ? ['dummy'] : assignedSubgroups)
        .get();

    setState(() {
      _assignedGroups = assignedGroups;
      _assignedSubgroups = assignedSubgroups;

      _groupNames = {
        for (var doc in groupDocs.docs) doc.id: (doc.data()['name'] ?? 'Unnamed Troupe') as String,
      };

      _subgroupNames = {
        for (var doc in subgroupDocs.docs) doc.id: (doc.data()['name'] ?? 'Unnamed Sub-Troupe') as String,
      };

      _isLoading = false;
    });
  }

  void _openTroupePicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TroupeSelectionPage()),
    );

    if (result != null && result is Map<String, dynamic>) {
      final parentId = result['parentTroupeId'] as String?;
      final subId = result['subTroupeId'] as String?;

      if (parentId == null) return;

      setState(() {
        if (!_assignedGroups.contains(parentId)) {
          _assignedGroups.add(parentId);
          _groupNames[parentId] = 'Loading...'; // Temporary placeholder
          _fetchTroupeName(parentId, false);
        }
        if (subId != null && !_assignedSubgroups.contains(subId)) {
          _assignedSubgroups.add(subId);
          _subgroupNames[subId] = 'Loading...';
          _fetchTroupeName(subId, true);
        }
      });
    }
  }

  Future<void> _fetchTroupeName(String id, bool isSub) async {
    try {
      final doc = await _firestore.collection('troupes').doc(id).get();
      final name = doc.data()?['name'] ?? 'Unnamed';

      setState(() {
        if (isSub) {
          _subgroupNames[id] = name;
        } else {
          _groupNames[id] = name;
        }
      });
    } catch (e) {
      // Ignore errors for now, keep "Loading..."
    }
  }

  Future<void> _saveAssignments() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _firestore.collection('users').doc(widget.teacherId).update({
        'assignedGroups': _assignedGroups,
        'assignedSubgroups': _assignedSubgroups,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Troupes assigned successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving assignments: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _removeTroupe(String id, bool isSub) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Troupe'),
        content: const Text('Are you sure you want to remove this troupe assignment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      if (isSub) {
        _assignedSubgroups.remove(id);
        _subgroupNames.remove(id);
      } else {
        _assignedGroups.remove(id);
        _groupNames.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text('Assign ${widget.teacherName} to Troupes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.school),
              label: const Text('Select Troupe'),
              onPressed: _openTroupePicker,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Assigned Parent Troupes',
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _assignedGroups
                  .map((id) => Chip(
                label: Text(_groupNames[id] ?? id),
                onDeleted: () => _removeTroupe(id, false),
              ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Assigned Sub-Troupes',
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _assignedSubgroups
                  .map((id) => Chip(
                label: Text(_subgroupNames[id] ?? id),
                onDeleted: () => _removeTroupe(id, true),
              ))
                  .toList(),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAssignments,
              icon: _isSaving
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.save),
              label: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
