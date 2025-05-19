import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/fcm-service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventsAdmin extends StatefulWidget {
  const EventsAdmin({super.key});

  @override
  _EventsAdminState createState() => _EventsAdminState();
}

class _EventsAdminState extends State<EventsAdmin> {
  // Theme colors
  final Color _primaryColor = const Color.fromARGB(255, 0, 58, 92);
  final Color _backgroundColor = const Color.fromARGB(64, 236, 236, 236);
  final ScrollController _scrollController = ScrollController();

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
    ));
  }

  void _showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    );
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

  // Stream for pending approval events
  Stream<QuerySnapshot> _getPendingEventsStream() {
    return FirebaseFirestore.instance
        .collection('eventsadmin')
        .doc("All")
        .collection("posts")
        .where('approval', isEqualTo: null)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Stream for all approved events
  Stream<QuerySnapshot> _getAllEventsStream() {
    return FirebaseFirestore.instance
        .collection('Eventposts')
        .doc("All")
        .collection("posts")
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _approveEvent(DocumentSnapshot event) async {
    final eventData = event.data() as Map<String, dynamic>;
    final eventId = event.id;
    final posterId = eventData['userId'];
    final posterName = eventData['userName'] ?? 'Someone';
    
    if (posterId == null) {
      print("❌ No userId field found in post");
      return;
    }

    _showLoadingDialog(context, "Approving event and sending notifications...");

    final approvedEventData = {
      ...eventData,
      'approval': 'approved',
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Move to main approved collection
    await FirebaseFirestore.instance
        .collection('Eventposts')
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
    await _fcmService.sendNotificationPostApproved(posterId, 'Events & Jobs');

    // Store in-app notification
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': posterId,
      'senderId': 'admin',
      'senderName': 'Admin',
      'postId': eventId,
      'collection': 'Eventposts/All/posts',
      'message': "✅ Your event was approved by admin",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'approval',
      'isRead': false,
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': null,
      'senderId': posterId,
      'senderName': posterName,
      'postId': eventId,
      'collection': 'Eventposts/All/posts',
      'message': "📢 $posterName added a new event in Events and Jobs",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'new_post',
      'isRead': false,
    });

    Navigator.of(context, rootNavigator: true).pop();
    _showToast("Event approved");
  }

  Future<void> _rejectEvent(DocumentSnapshot event) async {
    final eventId = event.id;
    final postData = event.data() as Map<String, dynamic>;
    final posterId = postData['userId'] ?? '';
    final posterName = postData['userName'] ?? 'Someone';

    await FirebaseFirestore.instance
        .collection('eventsadmin')
        .doc("All")
        .collection("posts")
        .doc(eventId)
        .delete();

    _showToast("Event rejected");

    final FCMService _fcmService = FCMService();
    await _fcmService.sendNotificationPostRejected(posterId, 'Events & Jobs');
    
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': posterId,
      'senderId': 'admin',
      'senderName': 'Admin',
      'postId': eventId,
      'collection': 'Eventposts/All/posts',
      'message': "❌ Your event was rejected by admin",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'rejection',
      'isRead': false,
    });
  }

  Future<void> _deleteEvent(DocumentSnapshot event) async {
    final eventId = event.id;
    await FirebaseFirestore.instance
        .collection('Eventposts')
        .doc("All")
        .collection("posts")
        .doc(eventId)
        .delete();

    _showToast("Event deleted successfully");
  }

  Widget _buildEventCard(DocumentSnapshot event, {bool showApproveReject = false}) {
    final eventData = event.data()! as Map<String, dynamic>;
    final username = eventData['userName'] ?? 'Anonymous';
    final userId = eventData['userId'] ?? '';
    final description = eventData['postContent'] ?? '';
    final imageUrl = eventData['imageUrl'] ?? '';
    final timestamp = eventData['timestamp'] as Timestamp?;
    final eventDate = eventData['eventDate'] as Timestamp?;
    final locationAddress = eventData['location'] is Map 
        ? (eventData['location'] as Map<String, dynamic>)['address'] ?? ''
        : '';
    final url = eventData['url'] ?? '';

    return FutureBuilder<String>(
      future: _getUserProfilePicture(userId),
      builder: (context, profileSnapshot) {
        final profileImageUrl = profileSnapshot.data ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.white,
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info row with profile image
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: profileImageUrl.isNotEmpty
                          ? NetworkImage(profileImageUrl)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(width: 12),
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
                    if (!showApproveReject)
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red[700]),
                        onPressed: () => _deleteEvent(event),
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
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                            child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                        ));
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
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
                  style: const TextStyle(fontSize: 15),
                ),

                if (locationAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 18, color: _primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          locationAddress,
                          style: const TextStyle(
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
                            // You can implement URL opening here
                          },
                          child: Text(
                            url,
                            style: const TextStyle(
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

                if (showApproveReject) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _rejectEvent(event),
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
                              horizontal: 16, vertical: 10),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _approveEvent(event),
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
                              horizontal: 16, vertical: 10),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingEventsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPendingEventsStream(),
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

        final events = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: events.length,
          itemBuilder: (context, index) => _buildEventCard(events[index], showApproveReject: true),
        );
      },
    );
  }

  Widget _buildAllEventsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAllEventsStream(),
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
                Icon(Icons.event_available_outlined,
                    size: 70, color: _primaryColor.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'No events available',
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

        final events = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: events.length,
          itemBuilder: (context, index) => _buildEventCard(events[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          toolbarHeight: 10,
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: Color.fromARGB(255, 0, 28, 187),
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'All Events'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingEventsTab(),
            _buildAllEventsTab(),
          ],
        ),
      ),
    );
  }
}