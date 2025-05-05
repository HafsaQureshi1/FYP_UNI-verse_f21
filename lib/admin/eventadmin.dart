import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fcm-service.dart';
class EventsAdmin extends StatefulWidget {
  const EventsAdmin({super.key});

  @override
  _EventsAdminState createState() => _EventsAdminState();
}

class _EventsAdminState extends State<EventsAdmin> {
  // Theme colors - match with Home.dart
  final Color _primaryColor = const Color.fromARGB(255, 0, 58, 92);
  final Color _backgroundColor = const Color.fromARGB(64, 236, 236, 236);

  Stream<QuerySnapshot> _getEventsStream() {
    return FirebaseFirestore.instance
        .collection('eventsadmin')
        .doc("All")
        .collection("posts")
        .where('approval', isEqualTo: null)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<String> _getUserProfilePicture(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc.data()?['profilePicture'] ?? '';
    } catch (e) {
      print("Error fetching profile picture: $e");
      return '';
    }
  }

  // Add toast notification method
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _approveEvent(DocumentSnapshot event) async {
  final eventData = event.data() as Map<String, dynamic>;
  final eventId = event.id;
  final posterId = eventData['userId']; // Ensure this field exists in your event posts
  final posterName = eventData['userName'] ?? 'Someone';
print("poster id $posterId");
  if (posterId == null) {
    print("❌ No userId field found in post");
    return;
  }

  final approvedEventData = {
    ...eventData,
    'approval': 'approved',
  };

  // Move to main approved collection
  await FirebaseFirestore.instance
      .collection('Eventposts') // lowercase 'e' to match UI logic
      .doc("All")
      .collection("posts")
      .doc(eventId)
      .set(approvedEventData);

  // Remove from admin approval list
  await FirebaseFirestore.instance
      .collection('eventsadmin')
      .doc("All")
      .collection("posts")
      .doc(eventId)
      .delete();

  // Send push notification
  final FCMService _fcmService = FCMService();
  await _fcmService.sendNotificationOnNewPost(
    posterId,
    posterName,
    'Events & Jobs',
  );

  // Store in-app notification
  await FirebaseFirestore.instance.collection('notifications').add({
    'receiverId': posterId, // ✅ correct user ID
    'senderId': 'admin',
    'senderName': 'Admin',
    'postId': eventId,
    'collection': 'Eventposts/All/posts',
    'message': "✅ Your post was approved by admin",
    'timestamp': FieldValue.serverTimestamp(),
    'type': 'approval',
    'isRead': false,
  });

  _showToast("Event approved");
}


  Future<void> _rejectEvent(DocumentSnapshot event) async {
    final eventId = event.id;
    await FirebaseFirestore.instance
        .collection('eventsadmin')
        .doc("All")
        .collection("posts")
        .doc(eventId)
        .delete();

    _showToast("Event rejected");
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();

    // Convert to 12-hour format with AM/PM
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '${date.day}/${date.month}/${date.year} $hour:$minute $period';
  }

  String _formatEventDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _getEventsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_outlined,
                      size: 70, color: _primaryColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No events to approve',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }

          var events = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: events.length,
            itemBuilder: (context, index) {
              var eventData = events[index].data() as Map<String, dynamic>;
              String userId = eventData['userId'] ?? '';
              String username = eventData['userName'] ?? 'Anonymous';
              String description = eventData['postContent'] ?? '';
              String imageUrl = eventData['imageUrl'] ?? '';
              Timestamp? eventDate = eventData['eventDate'];
              Timestamp? timestamp = eventData['timestamp'];
String location = eventData['location'] ?? '';
String url = eventData['url'] ?? '';

              return FutureBuilder<String>(
                future: _getUserProfilePicture(userId),
                builder: (context, profileSnapshot) {
                  String profileImageUrl = profileSnapshot.data ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.white, // Set card background color to white
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (profileImageUrl.isNotEmpty)
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      NetworkImage(profileImageUrl),
                                )
                              else
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      _primaryColor.withOpacity(0.2),
                                  child:
                                      Icon(Icons.person, color: _primaryColor),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _formatTimestamp(timestamp),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (eventDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event,
                                      size: 16, color: _primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatEventDate(eventDate),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 200,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                      child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        _primaryColor),
                                  ));
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (location.isNotEmpty) ...[
  const SizedBox(height: 8),
  Row(
    children: [
      Icon(Icons.location_on, size: 18, color: _primaryColor),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          location,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  ),
],
if (url.isNotEmpty) ...[
  const SizedBox(height: 8),
  Row(
    children: [
      Icon(Icons.link, size: 18, color: _primaryColor),
      const SizedBox(width: 6),
      Expanded(
        child: InkWell(
          onTap: () {
            // Optional: You can open this URL using url_launcher if you want
          },
          child: Text(
            url,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    ],
  ),
],

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // Center the buttons
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _rejectEvent(events[index]),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Reject",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC3545),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _approveEvent(events[index]),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  "Approve",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF28A745),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
