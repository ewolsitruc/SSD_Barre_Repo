import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../teacher/payroll_hours.dart';
import '../../teacher/pay_rate.dart';
import '../../user/user_data_service.dart';

class TeacherProfilePage extends StatefulWidget {
  final String uid;

  const TeacherProfilePage({super.key, required this.uid});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late DocumentReference _teacherRef;
  Map<String, dynamic>? _teacherData;
  List<String> _troupes = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _teacherRef = FirebaseFirestore.instance.collection('users').doc(widget.uid);
    _fetchTeacherData();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final user = UserDataService().currentUser;
    if (user != null) {
      final isAdmin = await UserDataService().isUserAdmin(user.uid);
      setState(() => _isAdmin = isAdmin);
    }
  }

  Future<void> _fetchTeacherData() async {
    final doc = await _teacherRef.get();
    if (doc.exists) {
      setState(() {
        _teacherData = doc.data() as Map<String, dynamic>;
        _troupes = List<String>.from(_teacherData!['joinedTroupes'] ?? []);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      await _teacherRef.update(_teacherData!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    }
  }

  Widget _buildProfileForm() {
    final data = _teacherData!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: (data['profileImageUrl'] ?? '').isNotEmpty
                  ? NetworkImage(data['profileImageUrl'])
                  : null,
              child: (data['profileImageUrl'] ?? '').isEmpty ? const Icon(Icons.person, size: 40) : null,
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField('First Name', 'firstName'),
          _buildTextField('Last Name', 'lastName'),
          _buildDatePicker('Birth Date', 'birthday'),
          _buildTextField('Address', 'address'),
          _buildTextField('Email', 'email', enabled: false),
          _buildTextField('Phone', 'phoneNumber'),
          _buildDatePicker('Start Date', 'startDate'),
          _buildDatePicker('End Date', 'endDate'),
          _buildTextField('Payroll ID', 'payrollId'),

          if (_troupes.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text('Assigned Troupes:', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._troupes.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(t),
                )),
              ],
            ),

          if (_isAdmin) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayrollHoursPage(teacherUid: widget.uid),
                  ),
                );
              },
              icon: const Icon(Icons.access_time),
              label: const Text('Payroll Hours'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PayRatePage(teacherUid: widget.uid),
                  ),
                );
              },
              icon: const Icon(Icons.monetization_on),
              label: const Text('Pay Rate'),
            ),
          ],

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String field, {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: _teacherData![field]?.toString() ?? '',
        enabled: enabled,
        decoration: InputDecoration(labelText: label),
        onSaved: (val) => _teacherData![field] = val ?? '',
      ),
    );
  }

  Widget _buildDatePicker(String label, String field) {
    final timestamp = _teacherData![field];
    final date = timestamp is Timestamp ? timestamp.toDate() : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('$label: ${date != null ? DateFormat.yMMMd().format(date) : 'Not set'}'),
        trailing: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => _teacherData![field] = Timestamp.fromDate(picked));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Profile')),
      body: _teacherData == null
          ? const Center(child: CircularProgressIndicator())
          : _buildProfileForm(),
    );
  }
}
