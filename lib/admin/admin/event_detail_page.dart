import 'package:flutter/material.dart';

class EventDetailPage extends StatelessWidget {
  final String title;
  final String description;
  final String date;
  final String time;
  final String location;
  final String poster;

  const EventDetailPage({
    super.key,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.poster,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
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
              'Date: $date',
              style: TextStyle(
                fontSize: 16,
                color: textOnBackground,
              ),
            ),
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Time: $time',
                  style: TextStyle(
                    fontSize: 16,
                    color: textOnBackground,
                  ),
                ),
              ),
            if (location.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Location: $location',
                  style: TextStyle(
                    fontSize: 16,
                    color: textOnBackground,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Posted by $poster',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: textOnBackground.withOpacity(0.7), // Lighter black
              ),
            ),
            const Divider(height: 30, thickness: 1),
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                color: textOnBackground, // Black description
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
