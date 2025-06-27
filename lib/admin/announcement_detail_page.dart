import 'package:flutter/material.dart';

class AnnouncementDetailPage extends StatelessWidget {
  final String title;
  final String content;
  final String date;
  final String poster;

  const AnnouncementDetailPage({
    super.key,
    required this.title,
    required this.content,
    required this.date,
    required this.poster,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Announcement Details'),
        // Colors handled by global AppBarTheme
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: primaryColor, // Red title
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Posted by $poster on $date',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: textOnBackground.withOpacity(0.7), // Lighter black
              ),
            ),
            const Divider(height: 30, thickness: 1),
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                color: textOnBackground, // Black content
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
