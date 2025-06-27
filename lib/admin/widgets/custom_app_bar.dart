import 'package:flutter/material.dart';
import 'main_drawer.dart'; // Import MainDrawer

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget titleWidget;
  final bool showNotificationsIcon;
  final int totalUnreadCount;
  final VoidCallback? onNotificationsTap;
  final bool isAdmin; // Required for MainDrawer
  final VoidCallback onLogout; // Required for MainDrawer
  final Widget? leadingWidget; // Optional leading widget (e.g., profile picture)
  final PreferredSizeWidget? bottom; // NEW: Optional bottom widget for tabs

  const CustomAppBar({
    super.key,
    required this.titleWidget,
    this.showNotificationsIcon = true,
    this.totalUnreadCount = 0,
    this.onNotificationsTap,
    required this.isAdmin,
    required this.onLogout,
    this.leadingWidget,
    this.bottom, required String title, // NEW: Initialize bottom
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titleWidget,
      leading: leadingWidget, // Use the provided leadingWidget
      // The actions and endDrawer are managed by the CustomAppBar itself
      // to ensure consistency across pages using it.
      actions: [
        if (showNotificationsIcon)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: onNotificationsTap,
                tooltip: 'Notifications',
              ),
              if (totalUnreadCount > 0)
                Positioned(
                  right: 11,
                  top: 11,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$totalUnreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu), // Hamburger icon
            onPressed: () {
              Scaffold.of(context).openEndDrawer(); // Open the end drawer
            },
            tooltip: 'Open menu',
          ),
        ),
      ],
      bottom: bottom, // NEW: Pass the bottom widget to the actual AppBar
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
