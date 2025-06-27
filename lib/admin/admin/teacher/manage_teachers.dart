import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/section_title.dart';
import '../../teacher/payroll_hours.dart';
import '../../teacher/pay_rate.dart';
import '../teacher/assign_teacher_to_troupe_page.dart';
import '../../admin/teacher/manage_timesheet.dart';
import '../../admin/teacher/add_teacher.dart'; // ✅ Add this import
import '../../admin/teacher/teachers.dart'; // ✅ Add this import

class ManageTeachersPage extends StatefulWidget {
  const ManageTeachersPage({super.key});

  @override
  State<ManageTeachersPage> createState() => _ManageTeachersPageState();
}

class _ManageTeachersPageState extends State<ManageTeachersPage> {
  String? _selectedTeacherUid;
  String? _selectedTeacherName;
  List<Map<String, dynamic>> _teacherList = [];

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isTeacher', isEqualTo: true)
        .get();

    setState(() {
      _teacherList = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['displayName'] ?? 'No Name',
        };
      }).toList();
    });
  }

  void _selectTeacher(String uid, String name) {
    setState(() {
      _selectedTeacherUid = uid;
      _selectedTeacherName = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Teachers'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Admin action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Teacher'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddTeacherPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ListTile(
                    title: const Text('All Teachers'),
                    trailing: const Icon(Icons.people),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TeachersListPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ✅ Teacher dropdown
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Teacher',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedTeacherUid,
                  items: _teacherList.map((teacher) {
                    return DropdownMenuItem<String>(
                      value: teacher['uid'],
                      child: Text(teacher['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    final selected = _teacherList.firstWhere(
                          (t) => t['uid'] == value,
                      orElse: () => {'name': 'Unknown'},
                    );
                    _selectTeacher(value, selected['name']);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ✅ Teacher Actions
            if (_selectedTeacherUid != null) ...[
              SectionTitle('Actions for $_selectedTeacherName'),
              Card(
                child: ListTile(
                  title: const Text('Assign to Troupes'),
                  subtitle: const Text('Manage troupe and sub-troupe assignments.'),
                  trailing: const Icon(Icons.group_add),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AssignTeacherToTroupePage(
                          teacherId: _selectedTeacherUid!,
                          teacherName: _selectedTeacherName!,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Payroll Hours'),
                  subtitle: const Text('View monthly hour totals.'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayrollHoursPage(teacherUid: _selectedTeacherUid!),
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Pay Rates'),
                  subtitle: const Text('Class rate, admin rate, flat rate, gas reimbursement.'),
                  trailing: const Icon(Icons.monetization_on),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayRatePage(teacherUid: _selectedTeacherUid!),
                      ),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Adjust Timesheet'),
                  subtitle: const Text('Manually edit entries.'),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageTimesheetPage(teacherUid: _selectedTeacherUid!),
                      ),
                    );
                  },
                ),
              ),
            ] else ...[
              const Center(child: Text('Select a teacher to manage.')),
            ]
          ],
        ),
      ),
    );
  }
}
