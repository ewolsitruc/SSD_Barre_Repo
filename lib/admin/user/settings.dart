// settings.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFFD13034),
      ),
      body: const Center(
        child: Text(
          'User Settings Placeholder',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
