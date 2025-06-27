import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:ssd_barre_new/widgets/main_drawer.dart'; // Corrected import
import 'package:ssd_barre_new/user/login_page.dart'; // Corrected import

class AnnouncementsListPage extends StatelessWidget {
  const AnnouncementsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get colors from the global theme
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnPrimary = Theme.of(context).colorScheme.onPrimary; // White
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Announcements'),
        actions: [
          // Hamburger Menu (Drawer) icon
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu), // Hamburger icon
              onPressed: () {
                Scaffold.of(context).openEndDrawer(); // Open the EndDrawer (hamburger menu)
              },
              tooltip: 'Menu',
              color: textOnPrimary, // White icon
            ),
          ),
        ],
      ),
      endDrawer: MainDrawer(
        // For simplicity, on pages other than Dashboard, assume isAdmin is false
        // unless you fetch it specifically for this page.
        isAdmin: false,
        onLogout: () {
          debugPrint('AnnouncementsListPage: Logout from drawer.');
          // Navigate to LoginPage and clear all routes in the stack
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        }, onNavigateToHubTab: (int ) {  },
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
