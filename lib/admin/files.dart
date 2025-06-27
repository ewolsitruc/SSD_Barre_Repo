// files.dart
import 'package:flutter/material.dart';

class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        backgroundColor: const Color(0xFFD13034),
      ),
      body: const Center(
        child: Text(
          'Files and Downloads Placeholder',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
