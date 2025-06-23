import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart'; // To check if user is logged in
import 'package:flutter/foundation.dart'; // For debugPrint

import '../user/user_data_service.dart'; // To check admin status
import 'add_event_page.dart'; // For adding new events
import 'event_detail_page.dart'; // For navigating to event details

class EventsListPage extends StatefulWidget {
  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserDataService _userDataService = UserDataService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      final currentIsAdmin = await _userDataService.isUserAdmin(user.uid);
      if (mounted) {
        setState(() {
          _isAdmin = currentIsAdmin;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
      _showSnackBar('Event deleted successfully!');
      debugPrint('EventsListPage: Event $eventId deleted.');
    } catch (e) {
      _showSnackBar('Failed to delete event: $e');
      debugPrint('EventsListPage Error: Failed to delete event $eventId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;
    final Color backgroundColor = Theme.of(context).colorScheme.background;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Events'),
        actions: [
          if (_isAdmin) // Show "Add New Event" button only if user is an admin
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                debugPrint('EventsListPage: Admin wants to add a new event.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddEventPage()),
                );
              },
              tooltip: 'Add New Event',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Browse all upcoming and past events.',
              style: TextStyle(
                fontSize: 16,
                color: textOnBackground,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('events')
                    .orderBy('eventDate', descending: false) // Order by date, soonest first
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('EventsListPage Error: ${snapshot.error}');
                    return Center(child: Text('Error loading events: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No events found yet.', style: TextStyle(color: textOnBackground)));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot doc = snapshot.data!.docs[index];
                      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                      final String eventId = doc.id;
                      final String title = data['title'] ?? 'No Title';
                      final String description = data['description'] ?? 'No Description';
                      final String location = data['location'] ?? 'Not specified';
                      final Timestamp? eventDate = data['eventDate'] as Timestamp?;
                      final String createdByUid = data['createdBy'] ?? ''; // Get UID of event creator

                      final DateTime? dateTime = eventDate?.toDate();
                      final String formattedDate = dateTime != null
                          ? DateFormat('MMM dd,ญี่ป�').format(dateTime)
                          : 'Unknown Date';
                      final String formattedTime = dateTime != null
                          ? DateFormat('hh:mm a').format(dateTime)
                          : ''; // Format time if present

                      // Determine if current user is the author of the event
                      final bool isAuthor = _auth.currentUser != null && _auth.currentUser!.uid == createdByUid;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 3,
                        color: backgroundColor,
                        child: InkWell(
                          onTap: () {
                            debugPrint('EventsListPage: Tapped on event: $title');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EventDetailPage(
                                  title: title,
                                  description: description,
                                  date: formattedDate,
                                  time: formattedTime,
                                  location: location,
                                  poster: '', // You might fetch poster name from users collection if needed
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Three-dot menu for admin or author
                                    if (isAuthor || _isAdmin)
                                      PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, color: textOnBackground),
                                        onSelected: (String result) {
                                          if (result == 'edit') {
                                            _showSnackBar('Future: Edit event functionality');
                                            debugPrint('EventsListPage: Edit Event (Future Feature)');
                                          } else if (result == 'delete') {
                                            _deleteEvent(eventId);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                          PopupMenuItem<String>(
                                            value: 'edit',
                                            child: Text('Edit Event', style: TextStyle(color: textOnBackground)),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text('Delete Event', style: TextStyle(color: textOnBackground)),
                                          ),
                                        ],
                                        color: backgroundColor,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textOnBackground.withOpacity(0.8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '$formattedDate ${formattedTime.isNotEmpty ? 'at $formattedTime' : ''} ${location.isNotEmpty ? '• $location' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: textOnBackground.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
