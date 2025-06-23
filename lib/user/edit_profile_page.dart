import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

import '../user/edit_profile_information.dart'; // Import the new page
import '../user/login_page.dart'; // For logout navigation

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String _displayName = 'Loading...';
  String? _profileImageUrl; // State for profile image URL

  // Notification and Online Status Toggles
  bool _troupeAnnouncementsEnabled = true;
  bool _chatNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _showOnlineStatus = true;
  bool _isLoading = false; // For showing loading during data fetch/save

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;

    setState(() { _isLoading = true; });

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _displayName = data?['displayName'] ?? _currentUser!.email?.split('@')[0] ?? 'User';
          _profileImageUrl = data?['profileImageUrl'];
          _troupeAnnouncementsEnabled = data?['troupeAnnouncementPushNotifications'] ?? true;
          _chatNotificationsEnabled = data?['chatPushNotifications'] ?? true;
          _emailNotificationsEnabled = data?['emailNotifications'] ?? true;
          _showOnlineStatus = data?['showOnlineStatus'] ?? true;
        });
      } else {
        // If user doc doesn't exist (e.g., brand new registration), use email as display name
        setState(() {
          _displayName = _currentUser!.email?.split('@')[0] ?? 'User';
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _showSnackBar('Failed to load profile settings.');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _updateNotificationSettings({
    bool? troupeAnnouncements,
    bool? chatNotifications,
    bool? emailNotifications,
    bool? showOnline,
  }) async {
    if (_currentUser == null) return;

    setState(() { _isLoading = true; });

    try {
      final updates = <String, dynamic>{};
      if (troupeAnnouncements != null) {
        updates['troupeAnnouncementPushNotifications'] = troupeAnnouncements;
      }
      if (chatNotifications != null) {
        updates['chatPushNotifications'] = chatNotifications;
      }
      if (emailNotifications != null) {
        updates['emailNotifications'] = emailNotifications;
      }
      if (showOnline != null) {
        updates['showOnlineStatus'] = showOnline;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(_currentUser!.uid).update(updates);
        _showSnackBar('Settings updated!');
        debugPrint('Notification settings updated for user ${_currentUser!.uid}');
      }
    } catch (e) {
      debugPrint('Error updating notification settings: $e');
      _showSnackBar('Failed to update settings: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _showLeaveTroupeDialog() async {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Leaving the Barre?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Remember, all SSD information comes through this app.',
                style: TextStyle(color: textOnBackground.withOpacity(0.8)),
              ),
              const SizedBox(height: 20),
              // Option 1: Turn Off All Notifications
              ListTile(
                leading: Icon(Icons.notifications_off, color: primaryColor),
                title: Text('Turn Off All Notifications', style: TextStyle(color: textOnBackground)),
                onTap: () async {
                  await _updateNotificationSettings(
                    troupeAnnouncements: false,
                    chatNotifications: false,
                    emailNotifications: false,
                  );
                  if (mounted) Navigator.pop(dialogContext); // Close dialog
                },
              ),
              // Option 2: Leave This Troupe (placeholder for actual troupe management)
              ListTile(
                leading: Icon(Icons.logout, color: primaryColor),
                title: Text('Leave This Troupe (Future)', style: TextStyle(color: primaryColor)), // Red text for emphasis
                onTap: () {
                  _showSnackBar('Future feature: Logic to leave a specific troupe.');
                  debugPrint('Leave This Troupe (Future Feature)');
                  if (mounted) Navigator.pop(dialogContext); // Close dialog
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (mounted) Navigator.pop(dialogContext); // Close the dialog
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: textOnBackground.withOpacity(0.7)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    debugPrint('EditProfilePage: Logging out user...');
    await _auth.signOut();
    debugPrint('EditProfilePage: Logged out and navigated to LoginPage.');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile & Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // Center the main profile elements
                children: [
                  // Profile Image and Display Name
                  GestureDetector(
                    onTap: () {
                      debugPrint('Navigating to EditProfileInformationPage.');
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileInformationPage()),
                      ).then((_) {
                        _loadUserProfile(); // Reload data when returning from edit page
                      });
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 70, // Larger profile image
                          backgroundColor: primaryColor.withOpacity(0.2),
                          backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : null,
                          child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                              ? Icon(Icons.person, size: 80, color: primaryColor)
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _displayName,
                          style: TextStyle(
                            fontFamily: 'SSDHeader',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textOnBackground,
                          ),
                        ),
                        Text(
                          'Tap to edit profile information',
                          style: TextStyle(
                            fontSize: 12,
                            color: textOnBackground.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Notifications Section
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontFamily: 'SSDHeader',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const Divider(height: 20, thickness: 1),
                  SwitchListTile(
                    title: Text(
                      'Troupe Announcements Push Notifications',
                      style: TextStyle(color: textOnBackground),
                    ),
                    value: _troupeAnnouncementsEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _troupeAnnouncementsEnabled = value;
                      });
                      _updateNotificationSettings(troupeAnnouncements: value);
                    },
                    activeColor: primaryColor,
                    tileColor: backgroundColor, // Match scaffold background or subtle surface
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                      'Chat Push Notifications',
                      style: TextStyle(color: textOnBackground),
                    ),
                    value: _chatNotificationsEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _chatNotificationsEnabled = value;
                      });
                      _updateNotificationSettings(chatNotifications: value);
                    },
                    activeColor: primaryColor,
                    tileColor: backgroundColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                      'Email Notifications',
                      style: TextStyle(color: textOnBackground),
                    ),
                    value: _emailNotificationsEnabled,
                    onChanged: (bool value) {
                      setState(() {
                        _emailNotificationsEnabled = value;
                      });
                      _updateNotificationSettings(emailNotifications: value);
                    },
                    activeColor: primaryColor,
                    tileColor: backgroundColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text(
                      'Show Online Status',
                      style: TextStyle(color: textOnBackground),
                    ),
                    value: _showOnlineStatus,
                    onChanged: (bool value) {
                      setState(() {
                        _showOnlineStatus = value;
                      });
                      _updateNotificationSettings(showOnline: value);
                    },
                    activeColor: primaryColor,
                    tileColor: backgroundColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  const SizedBox(height: 30),

                  // Leave This Troupe Button
                  SizedBox(
                    width: double.infinity, // Make button fill width
                    child: ElevatedButton.icon(
                      onPressed: _showLeaveTroupeDialog,
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Leave This Troupe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor, // Red button
                        foregroundColor: Theme.of(context).colorScheme.onPrimary, // White text
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
