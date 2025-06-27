// chat.dart
import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: const Color(0xFFD13034),
      ),
      body: const Center(
        child: Text(
          'Chat Groups Placeholder',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
