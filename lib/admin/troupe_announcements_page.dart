import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:flutter/foundation.dart'; // For debugPrint

class TroupeAnnouncementsPage extends StatefulWidget {
  final String troupeId;
  final String troupeName;

  const TroupeAnnouncementsPage({
    super.key,
    required this.troupeId,
    required this.troupeName,
  });

  @override
  State<TroupeAnnouncementsPage> createState() => _TroupeAnnouncementsPageState();
}

class _TroupeAnnouncementsPageState extends State<TroupeAnnouncementsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        title: Text('${widget.troupeName} Announcements'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Announcements specific to ${widget.troupeName}:',
              style: TextStyle(
                fontSize: 16,
                color: textOnBackground,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('troupes')
                    .doc(widget.troupeId)
                    .collection('announcements')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint('TroupeAnnouncementsPage Error: ${snapshot.error}');
                    return Center(child: Text('Error loading announcements: ${snapshot.error}', style: TextStyle(color: primaryColor)));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No announcements found for this troupe yet.', style: TextStyle(color: textOnBackground)));
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot doc = snapshot.data!.docs[index];
                      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

                      final String title = data['title'] ?? 'No Title';
                      final String content = data['content'] ?? 'No Content';
                      final Timestamp? createdAt = data['createdAt'] as Timestamp?;
                      final String createdByEmail = data['createdByEmail'] ?? 'Unknown User'; // Get email from saved data

                      final String formattedDate = createdAt != null
                          ? DateFormat('MMM dd, EEEE \'at\' hh:mm a').format(createdAt.toDate())
                          : 'Unknown Date';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 3,
                        color: backgroundColor, // White card background
                        child: InkWell(
                          onTap: () {
                            debugPrint('TroupeAnnouncementsPage: Tapped on announcement: $title');
                            // You can navigate to a detailed view if needed, or simply display here
                            _showSnackBar('Announcement: $title');
                          },
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
                                    color: primaryColor, // Red title
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  content,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textOnBackground.withOpacity(0.8), // Lighter black content
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '$formattedDate by ${createdByEmail.split('@')[0]}', // Display username part of email
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: textOnBackground.withOpacity(0.6), // Even lighter black
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
