import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../user/edit_profile_page.dart'; // Corrected import path for EditProfilePage
import '../user/login_page.dart'; // Import LoginPage for logout navigation
import '../dashboard_page.dart'; // Import for navigating back to dashboard
import '../admin/dev_tools_screen.dart'; // Import for admin dev tools
import '../admin/troupes_page.dart'; // Import TroupesPage
import '../admin/announcements_list_page.dart'; // Import AnnouncementsListPage
import '../admin/events_list_page.dart'; // Import EventsListPage
import '../user/bookmark_page.dart'; // Import BookmarkPage

class MainDrawer extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onLogout;

  const MainDrawer({
    super.key,
    required this.isAdmin,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'SSD Barre App',
                  style: TextStyle(
                    fontFamily: 'SSDHeader',
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Navigation',
                  style: TextStyle(
                    fontFamily: 'SSDBody',
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.dashboard, color: primaryColor),
            title: Text('Dashboard', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacement( // Use pushReplacement to clear stack
                context,
                MaterialPageRoute(builder: (context) => const DashboardPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.person, color: primaryColor),
            title: Text('My Profile', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfilePage()), // Navigates to EditProfilePage
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.group, color: primaryColor),
            title: Text('Troupes', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TroupesPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.announcement, color: primaryColor),
            title: Text('All Announcements', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnnouncementsListPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.event, color: primaryColor),
            title: Text('All Events', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EventsListPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.bookmark, color: primaryColor),
            title: Text('Bookmarks', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BookmarkPage()),
              );
            },
          ),
          if (isAdmin) // Only show Dev Tools if the user is an admin
            ListTile(
              leading: Icon(Icons.developer_mode, color: primaryColor),
              title: Text('Dev Tools', style: TextStyle(color: textOnBackground)),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DevToolsScreen()),
                );
              },
            ),
          const Divider(), // A divider to separate main items from logout
          ListTile(
            leading: Icon(Icons.logout, color: primaryColor),
            title: Text('Logout', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              onLogout(); // Call the logout function passed from DashboardPage
            },
          ),
        ],
      ),
    );
  }
}
