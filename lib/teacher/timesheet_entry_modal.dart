import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TimesheetEntryModal extends StatefulWidget {
  final String userId;
  final String? entryId; // If null, we're creating a new entry
  final Map<String, dynamic>? existingData;

  const TimesheetEntryModal({
    super.key,
    required this.userId,
    this.entryId,
    this.existingData,
  });

  @override
  State<TimesheetEntryModal> createState() => _TimesheetEntryModalState();
}

class _TimesheetEntryModalState extends State<TimesheetEntryModal> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  double _hours = 1.0;
  String _type = 'class';
  String? _note;

  final List<String> _types = ['class', 'admin', 'flat', 'gas'];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      final data = widget.existingData!;
      _selectedDate = (data['date'] as Timestamp).toDate();
      _hours = (data['hours'] as num).toDouble();
      _type = data['type'] ?? 'class';
      _note = data['note'];
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final entryData = {
      'date': Timestamp.fromDate(_selectedDate),
      'hours': _hours,
      'type': _type,
      'note': _note ?? '',
    };

    final entryRef = FirebaseFirestore.instance
        .collection('timesheets')
        .doc(widget.userId)
        .collection('entries');

    try {
      if (widget.entryId != null) {
        await entryRef.doc(widget.entryId).update(entryData);
      } else {
        await entryRef.add(entryData);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving timesheet entry: $e')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.entryId != null;
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Entry' : 'New Entry'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(DateFormat.yMMMd().format(_selectedDate)),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _hours.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Hours'),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter valid hours';
                  return null;
                },
                onSaved: (value) => _hours = double.parse(value!),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _type = val!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _note,
                decoration: const InputDecoration(labelText: 'Optional Note'),
                onSaved: (value) => _note = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
