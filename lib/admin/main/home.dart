// home.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: const Color(0xFFD13034),
      ),
      body: const Center(
        child: Text(
          'Home Feed Placeholder',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
} 
