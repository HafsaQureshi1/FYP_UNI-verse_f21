
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/components/search_results.dart';
import 'package:intl/intl.dart';
import '../components/profileimage.dart'; // Add this import for the ProfileAvatar component

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Error: User not authenticated")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100], // Facebook-like light gray background
      appBar: AppBar(
        title: const Text("Notifications",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white, // White app bar like Facebook
        elevation: 1, // Subtle elevation
        actions: [
          Tooltip(
            message: "Mark all as read",
            child: IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () => _markAllAsRead(currentUserId),
            ),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverId', isEqualTo: currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          return ListView.separated(
            padding: EdgeInsets.zero, // Remove default padding
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.grey[200],
              indent: 72, // Indent to align with text, not icon
            ),
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Format the timestamp
              String formattedTime = "Now";
              if (data['timestamp'] != null) {
                formattedTime =
                    _getFormattedTimestamp(data['timestamp'].toDate());
              }

              // For legacy notifications that don't have collection field
              if (!data.containsKey('collection') ||
                  data['collection'] == null) {
                _updateNotificationWithCollection(doc.id, data['postId']);
              }

              // Get collection name and display name
              String collectionName = data['collection'] ?? 'lostfoundposts';
              String collectionDisplayName =
                  _getCollectionDisplayName(collectionName);

              // Create notification message
              String notificationMessage;

              if (data['type'] == 'like') {
                notificationMessage =
                    "${data['senderName']} liked your post in $collectionDisplayName";
              } else if (data['type'] == 'comment') {
                notificationMessage =
                    "${data['senderName']} commented on your post in $collectionDisplayName";
              } else {
                notificationMessage = data['message'] ?? 'New notification';
              }

              // Determine background color based on read status
              Color bgColor = data['isRead'] == true
                  ? Colors.white
                  : const Color.fromARGB(
                      255, 237, 246, 254); // Lighter blue for unread

              return Material(
                color: bgColor,
                child: InkWell(
                  onTap: () => _handleNotificationTap(context, doc.id, data),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      leading: Stack(
                        children: [
                          // Profile avatar of the sender
                          ProfileAvatar(
                            userId: data['senderId'] ?? '',
                            radius: 24,
                          ),
                          // Small icon overlay at bottom right of the avatar
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: data['type'] == 'like'
                                    ? Colors.red.shade100
                                    : Colors.blue.shade100,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                data['type'] == 'like'
                                    ? Icons.favorite
                                    : Icons.comment,
                                color: data['type'] == 'like'
                                    ? Colors.red
                                    : Colors.blue,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 15.0,
                            color: Colors.black,
                            height: 1.4, // Increase line height for readability
                          ),
                          children: [
                            TextSpan(
                              text: data['senderName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: data['type'] == 'like'
                                  ? ' liked your post in '
                                  : ' commented on your post in ',
                              style: const TextStyle(color: Colors.black87),
                            ),
                            TextSpan(
                              text: collectionDisplayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          formattedTime,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13.0,
                          ),
                        ),
                      ),
                      trailing: data['isRead'] == true
                          ? null
                          : Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Helper method to update legacy notifications
  Future<void> _updateNotificationWithCollection(
      String notificationId, String? postId) async {
    if (postId == null) return;

    try {
      List<String> collections = [
        'lostfoundposts',
        'Peerposts',
        'Eventposts',
        'Surveyposts'
      ];

      for (String collection in collections) {
        DocumentSnapshot postDoc = await FirebaseFirestore.instance
    .collection(collection)
    .doc("All")
    .collection("posts")
    .doc(postId)
    .get();


        if (postDoc.exists) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(notificationId)
              .update({'collection': collection});
          break;
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Helper function to format timestamp in a user-friendly way
  String _getFormattedTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // Within the last minute
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    // Within the last hour
    else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    // Within the last day
    else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    // Yesterday
    else if (difference.inDays < 2) {
      return 'Yesterday at ${DateFormat('h:mm a').format(dateTime)}';
    }
    // Within the last week
    else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    }
    // Older than a week
    else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  // Get a user-friendly name for collections
  String _getCollectionDisplayName(String collection) {
    switch (collection) {
      case 'lostfoundposts':
        return 'Lost & Found';
      case 'Peerposts':
        return 'Peer Assistance';
      case 'Eventposts/All/posts':
        return 'Events & Jobs';
      case 'Surveyposts/All/posts':
        return 'Surveys';
      default:
        return collection;
    }
  }

  // Mark all notifications as read
  Future<void> _markAllAsRead(String userId) async {
    final batch = FirebaseFirestore.instance.batch();
    final unreadNotifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unreadNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }
Future<void> _handleNotificationTap(BuildContext context, String notificationId, Map<String, dynamic> data) async {
  try {
    // Mark notification as read
    await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({'isRead': true});

    // Check if postId exists
    if (data['postId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid notification data')));
      return;
    }

    String postId = data['postId'];
    String? collectionName = data['collection'];
    if(collectionName == "lostfoundposts"){
      collectionName = "lostfoundposts/All/posts";
    }
    else if(collectionName == "Peerposts"){
      collectionName = "Peerposts/All/posts";
    }
    
print("collection name : $collectionName");
    // If collection name is not provided, determine it
    if (collectionName == null) {
      List<String> collections = ['lostfoundposts/All/posts', 'Peerposts/All/posts', 'Eventposts', 'Surveyposts'];

      for (String collection in collections) {
        DocumentSnapshot postDoc = await FirebaseFirestore.instance
            .collection(collection)
            .doc("All")
            .collection("posts")
            .doc(postId)
            .get();

        if (postDoc.exists) {
          collectionName = collection;

          // Update notification with correct collection
          await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({'collection': collection});
          break;
        }
      }
    }

    // If collection name is found, navigate to post
    if (collectionName != null) {
      DocumentSnapshot postDoc = await FirebaseFirestore.instance
          .collection(collectionName)
          
          .doc(postId)
          .get();

      if (postDoc.exists) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailView(
              post: {
                ...postDoc.data() as Map<String, dynamic>,
                'id': postDoc.id,
                'collection': collectionName,
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post no longer exists')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find the post')));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error handling notification: $e')));
  }
}}
