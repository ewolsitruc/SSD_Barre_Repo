// calendar.dart
import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: const Color(0xFFD13034),
      ),
      body: const Center(
        child: Text(
          'Calendar Events Placeholder',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
