import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageTimesheetPage extends StatefulWidget {
  final String teacherUid;

  const ManageTimesheetPage({super.key, required this.teacherUid});

  @override
  State<ManageTimesheetPage> createState() => _ManageTimesheetPageState();
}

class _ManageTimesheetPageState extends State<ManageTimesheetPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _deleteEntry(String entryId) async {
    await _firestore
        .collection('timesheets')
        .doc(widget.teacherUid)
        .collection('entries')
        .doc(entryId)
        .delete();
  }

  void _showDeleteDialog(String entryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteEntry(entryId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openEditModal(Map<String, dynamic> entryData, String entryId) {
    // Replace with actual modal if needed
    Navigator.pushNamed(context, '/editTimesheetEntry', arguments: {
      'teacherId': widget.teacherUid,
      'entryId': entryId,
      'entryData': entryData,
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color onBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Timesheet'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('timesheets')
            .doc(widget.teacherUid)
            .collection('entries')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final entries = snapshot.data!.docs;

          if (entries.isEmpty) {
            return const Center(child: Text('No timesheet entries found.'));
          }

          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final doc = entries[index];
              final data = doc.data() as Map<String, dynamic>;

              final date = (data['date'] as Timestamp).toDate();
              final hours = data['hours'] ?? 0;
              final type = data['type'] ?? 'unknown';
              final note = data['note'] ?? '';
              final formattedDate = DateFormat('MMM d, yyyy').format(date);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('$formattedDate • $hours hrs'),
                  subtitle: Text('$type\n$note'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: primaryColor),
                        onPressed: () => _openEditModal(data, doc.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteDialog(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
