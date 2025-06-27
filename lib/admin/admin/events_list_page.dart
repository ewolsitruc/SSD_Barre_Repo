import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart'; // To check if user is logged in
import 'package:flutter/foundation.dart'; // For debugPrint

// CORRECTED IMPORTS based on your provided folder structure:
import 'package:ssd_barre_new/user/user_data_service.dart'; // From lib/user/
import 'package:ssd_barre_new/admin/add_event_page.dart'; // From lib/admin/
import 'package:ssd_barre_new/admin/event_detail_page.dart'; // From lib/user/

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

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: primaryColor,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 4,
        actions: [
          if (_isAdmin) // Show "Add Event" button only if user is admin
            IconButton(
              icon: const Icon(Icons.add_box),
              onPressed: () {
                debugPrint('EventsListPage: Admin tapped Add Event button.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddEventPage()),
                );
              },
              tooltip: 'Add New Event',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            // Listen to authentication state changes
            child: StreamBuilder<User?>(
              stream: _auth.authStateChanges(), // Stream for user authentication state
              builder: (context, authSnapshot) {
                if (authSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (authSnapshot.hasError) {
                  debugPrint('EventsListPage Auth Stream Error: ${authSnapshot.error}');
                  return Center(child: Text('Error loading user data: ${authSnapshot.error}'));
                }

                final User? currentUser = authSnapshot.data;

                if (currentUser == null) {
                  // User is not logged in, show a message
                  return Center(
                    child: Text(
                      'Please log in to view events.',
                      style: TextStyle(color: textOnBackground),
                    ),
                  );
                }

                // User is logged in, now stream events
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('events')
                      .orderBy('eventDate') // Assuming eventDate exists and is a Timestamp
                      .snapshots(),
                  builder: (context, eventSnapshot) {
                    if (eventSnapshot.hasError) {
                      debugPrint('EventsListPage Error: ${eventSnapshot.error}');
                      return Center(child: Text('Error loading events: ${eventSnapshot.error}'));
                    }

                    if (eventSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!eventSnapshot.hasData || eventSnapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No events available.',
                          style: TextStyle(color: textOnBackground),
                        ),
                      );
                    }

                    final events = eventSnapshot.data!.docs;

                    return ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        // Safely cast data to Map and use null-aware operators
                        final Map<String, dynamic>? data = event.data() as Map<String, dynamic>?;

                        if (data == null) {
                          // If for some reason the data map is null, skip this document
                          debugPrint('EventsListPage: Document data is null for event ID: ${event.id}');
                          return const SizedBox.shrink();
                        }

                        // Safely access fields with null-aware operators and provide default values
                        final String title = data['title'] as String? ?? 'No Title';
                        final String description = data['description'] as String? ?? 'No Description';
                        final Timestamp? eventDateTimestamp = data['eventDate'] as Timestamp?;
                        final String eventTimeRaw = data['eventTime'] as String? ?? ''; // Store as raw string
                        final String location = data['location'] as String? ?? 'Not specified';
                        final String poster = data['poster'] as String? ?? 'Unknown';

                        // Format date
                        final String formattedDate = eventDateTimestamp != null
                            ? DateFormat('MMMM d, yyyy').format(eventDateTimestamp.toDate())
                            : 'Unknown Date';

                        // Format time only if raw time string is not empty
                        String formattedTime = '';
                        if (eventTimeRaw.isNotEmpty) {
                          try {
                            // Assuming eventTimeRaw is in HH:mm format (e.g., "14:30")
                            final DateTime parsedTime = DateFormat('HH:mm').parse(eventTimeRaw);
                            formattedTime = DateFormat.jm().format(parsedTime); // e.g., "2:30 PM"
                          } catch (e) {
                            debugPrint('Error parsing eventTime: $eventTimeRaw - $e');
                            formattedTime = eventTimeRaw; // Use raw string if parsing fails
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            onTap: () {
                              debugPrint('EventsListPage: Tapped event: $title');
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EventDetailPage(
                                    title: title,
                                    description: description,
                                    date: formattedDate,
                                    time: formattedTime, // Pass formatted time
                                    location: location,
                                    poster: poster,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
