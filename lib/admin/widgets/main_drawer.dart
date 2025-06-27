import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin/add_event_page.dart';
import '../dashboard_page.dart';
import '../user/edit_profile_page.dart';
import '../user/ssd_hub_page.dart';
import '../troupes_page.dart';
import '../admin/add_announcement_page.dart';
import '../admin/manage_join_requests_page.dart';
import '../admin/dev_tools_screen.dart';
import '../user/join_troupe_page.dart';

class MainDrawer extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onLogout;
  final Function(int) onNavigateToHubTab;

  const MainDrawer({
    super.key,
    required this.isAdmin,
    required this.onLogout,
    required this.onNavigateToHubTab,
  });

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    debugPrint('Attempting to launch URL: $url');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
      _showSnackBar(context, 'Could not open the link.');
    }
  }

  bool _isCurrentRoute(BuildContext context, String routeName) {
    return ModalRoute.of(context)?.settings.name == routeName;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'SSD Barre App',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 24),
                ),
                Text(
                  isAdmin ? 'Admin' : 'User',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.school, color: primaryColor),
            title: Text('Parent Portal', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              _launchUrl(context, 'https://app.gostudiopro.com/online/ssdistheplacetobe');
            },
          ),
          ListTile(
            leading: Icon(Icons.store_mall_directory, color: primaryColor),
            title: Text('Nimbly Store', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              _launchUrl(context, 'https://www.shopnimbly.com/ssdistheplacetobe');
            },
          ),
          ListTile(
            leading: Icon(Icons.dashboard, color: primaryColor),
            title: Text('SSD Hub', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              // Avoid pushing SSDHubPage again if already there
              final currentRoute = ModalRoute.of(context)?.settings.name;
              if (currentRoute == null || !currentRoute.contains('SSDHubPage')) {
                debugPrint('MainDrawer: Navigating to SSDHubPage.');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SSDHubPage()),
                );
              } else {
                debugPrint('MainDrawer: Already on SSDHubPage, switching tab to Spotlight.');
                onNavigateToHubTab(0); // Spotlight tab
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.group, color: primaryColor),
            title: Text('Join A Troupe', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => JoinTroupePage()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.edit, color: primaryColor),
            title: Text('My Profile', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfilePage()),
              );
            },
          ),
          if (isAdmin) ...[
            ListTile(
              leading: Icon(Icons.build, color: primaryColor),
              title: Text('Admin Tools', style: TextStyle(color: textOnBackground)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DevToolsScreen()),
                );
              },
            ),
          ],
          ListTile(
            leading: Icon(Icons.logout, color: primaryColor),
            title: Text('Logout', style: TextStyle(color: textOnBackground)),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
        ],
      ),
    );
  }
}
