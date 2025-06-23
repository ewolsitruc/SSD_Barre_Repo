import 'package:flutter/material.dart';

class AnnouncementsListPage extends StatelessWidget {
  const AnnouncementsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get colors from the global theme
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Announcements'),
        // Colors are handled by global AppBarTheme
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'This is the All Announcements Page!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textOnBackground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Future feature: List all announcements here.',
              style: TextStyle(
                fontSize: 16,
                color: textOnBackground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
