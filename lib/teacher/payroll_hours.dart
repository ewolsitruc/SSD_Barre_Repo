import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../user/user_data_service.dart';
import 'timesheet_entry_modal.dart';

class PayrollHoursPage extends StatefulWidget {
  final String teacherUid;

  const PayrollHoursPage({super.key, required this.teacherUid});

  @override
  State<PayrollHoursPage> createState() => _PayrollHoursPageState();
}

class _PayrollHoursPageState extends State<PayrollHoursPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? selectedTeacherId;
  String? selectedTeacherName;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
  }

  Future<void> _checkIfAdmin() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final adminStatus = await UserDataService().isUserAdmin(currentUser.uid);
      if (mounted) {
        setState(() {
          isAdmin = adminStatus;
          if (!adminStatus) {
            selectedTeacherId = widget.teacherUid;
          }
        });
      }
    }
  }

  Future<void> _openTimesheetEntryModal({
    TimesheetEntry? existingEntry,
    required String userId,
  }) async {
    final result = await showDialog<TimesheetEntry>(
      context: context,
      builder: (context) => TimesheetEntryModal(
        userId: userId,
        entryId: existingEntry?.id,
        existingData: existingEntry != null
            ? {
          'date': Timestamp.fromDate(existingEntry.date),
          'hours': existingEntry.hours,
          'type': existingEntry.type,
          'note': existingEntry.note,
        }
            : null,
      ),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existingEntry == null ? 'Entry added.' : 'Entry updated.')),
      );
      setState(() {}); // Refresh UI
    }
  }

  Widget _buildTeacherSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').where('isTeacher', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        List<DropdownMenuItem<String>> items = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['displayName'] ?? 'Unnamed';
          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(name),
          );
        }).toList();

        return Card(
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select a Teacher", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedTeacherId,
                  hint: const Text("Choose teacher"),
                  items: items,
                  onChanged: (value) {
                    setState(() {
                      selectedTeacherId = value;
                      selectedTeacherName = snapshot.data!.docs
                          .firstWhere((doc) => doc.id == value!)['displayName'];
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimesheetEntries() {
    if (selectedTeacherId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('timesheets')
          .doc(selectedTeacherId)
          .collection('entries')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final entries = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return TimesheetEntry(
            id: doc.id,
            date: (data['date'] as Timestamp).toDate(),
            hours: (data['hours'] ?? 0).toDouble(),
            type: data['type'] ?? 'unknown',
            note: data['note'] ?? '',
          );
        }).toList();

        final grouped = <String, List<TimesheetEntry>>{};
        for (final entry in entries) {
          final monthKey = DateFormat.yMMM().format(entry.date);
          grouped.putIfAbsent(monthKey, () => []).add(entry);
        }

        return Column(
          children: grouped.entries.map((e) {
            return Card(
              margin: const EdgeInsets.all(12),
              child: ExpansionTile(
                title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                children: e.value.map((entry) {
                  return ListTile(
                    title: Text('${entry.hours} hours - ${entry.type}'),
                    subtitle: Text(DateFormat.yMMMd().format(entry.date)),
                    trailing: isAdmin
                        ? IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openTimesheetEntryModal(
                        existingEntry: entry,
                        userId: selectedTeacherId!,
                      ),
                    )
                        : null,
                  );
                }).toList(),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Payroll Hours'),
      ),
      body: ListView(
        children: [
          if (isAdmin) _buildTeacherSelector(),
          _buildTimesheetEntries(),
        ],
      ),
      floatingActionButton: selectedTeacherId != null && isAdmin
          ? FloatingActionButton(
        onPressed: () => _openTimesheetEntryModal(userId: selectedTeacherId!),
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}

class TimesheetEntry {
  final String id;
  final DateTime date;
  final double hours;
  final String type;
  final String note;

  TimesheetEntry({
    required this.id,
    required this.date,
    required this.hours,
    required this.type,
    required this.note,
  });
}
