import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/components/search_results.dart';
import 'package:intl/intl.dart';
import '../components/profileimage.dart';
import 'package:async/async.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Keep track of locally marked read notifications
  final Set<String> _locallyMarkedAsRead = {};

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Error: User not authenticated")),
      );
    }

    final userSpecific = FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: currentUserId)
        .snapshots();

    final general = FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isNull: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Notifications",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          Tooltip(
            message: "Mark all as read",
            child: IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: () {
                _markAllAsRead(currentUserId);
                // Clear the list and rebuild the UI
                setState(() {
                  _locallyMarkedAsRead.clear();
                });
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<QuerySnapshot>>(
        stream: StreamZip([userSpecific, general]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("No notifications yet."));
          }

          final allDocs = snapshot.data!
              .expand((qSnap) => qSnap.docs)
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final receiverId = data['receiverId'];
                final senderId = data['senderId'];

                // Show general notifications to everyone except the sender
                if (receiverId == null && senderId != currentUserId) {
                  return true;
                }

                // Show user-specific notifications
                return receiverId == currentUserId;
              })
              .toList();

          allDocs.sort((a, b) {
            final aTime = a['timestamp']?.toDate() ?? DateTime(1970);
            final bTime = b['timestamp']?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });

          if (allDocs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          return ListView.separated(
            itemCount: allDocs.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.grey[200],
              indent: 72,
            ),
            itemBuilder: (context, index) {
              final doc = allDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final notificationId = doc.id;

              // Check if notification should be shown as read locally or from Firestore
              final isRead = _locallyMarkedAsRead.contains(notificationId) || 
                            (data['isRead'] == true);

              String formattedTime = "Now";
              if (data['timestamp'] != null) {
                formattedTime =
                    _getFormattedTimestamp(data['timestamp'].toDate());
              }

              if (!data.containsKey('collection') ||
                  data['collection'] == null) {
                _updateNotificationWithCollection(notificationId, data['postId']);
              }

              final collectionName = data['collection'] ?? 'lostfoundposts';
              final collectionDisplayName =
                  _getCollectionDisplayName(collectionName);

              String iconType = data['type'];
              String notificationMessage;

              switch (iconType) {
                case 'like':
                  notificationMessage =
                      "${data['senderName']} liked your post in $collectionDisplayName";
                  break;
                case 'comment':
                  notificationMessage =
                      "${data['senderName']} commented on your post in $collectionDisplayName";
                  break;
                case 'approval':
                  notificationMessage =
                      "✅ Your post in $collectionDisplayName was approved by admin.";
                  break;
                case 'rejection':
                  notificationMessage =
                      "❌ Your post in $collectionDisplayName was rejected by admin.";
                  break;
                case 'newPost':
                  notificationMessage =
                      "${data['senderName']} added a new post in $collectionDisplayName.";
                  break;
                default:
                  notificationMessage = data['message'] ?? 'New notification';
              }

              final bgColor = isRead
                  ? Colors.white
                  : const Color.fromARGB(255, 237, 246, 254);

              return Material(
                color: bgColor,
                child: InkWell(
 onTap: () async {
  final docSnap = await FirebaseFirestore.instance
      .collection('notifications')
      .doc(notificationId)
      .get();

  if (!context.mounted) return;

  if (docSnap.exists) {
    final freshData = docSnap.data() as Map<String, dynamic>;

    // Use Future.delayed to ensure navigation happens after the current frame
    Future.delayed(Duration(milliseconds: 100), () {
      _handleNotificationTap(context, notificationId, freshData);
    });
  }
}

,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      leading: Stack(
                        children: [
                          ProfileAvatar(
                            userId: data['senderId'] ?? '',
                            radius: 24,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: iconType == 'like'
                                    ? Colors.red.shade100
                                    : Colors.blue.shade100,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                iconType == 'like'
                                    ? Icons.favorite
                                    : iconType == 'comment'
                                        ? Icons.comment
                                        : iconType == 'approval'
                                            ? Icons.check_circle
                                            : iconType == 'rejection'
                                                ? Icons.cancel
                                                : Icons.notifications,
                                color: iconType == 'like'
                                    ? Colors.red
                                    : iconType == 'comment'
                                        ? Colors.blue
                                        : iconType == 'approval'
                                            ? Colors.green
                                            : iconType == 'rejection'
                                                ? Colors.redAccent
                                                : Colors.deepPurple,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        notificationMessage,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15.0,
                          color: Colors.black,
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
                      trailing: isRead
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

  void _updateNotificationWithCollection(String docId, String? postId) async {
    // If the postId is null, we can't determine the collection
    if (postId == null) return;

    // Fetch the post from the relevant collection (Lost & Found, Peer Assistance, etc.)
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final postSnapshot = await postRef.get();

    if (!postSnapshot.exists) {
      return;
    }

    // Assuming each post has a 'collection' field to identify its type
    final postData = postSnapshot.data() as Map<String, dynamic>;
    final collectionName = postData['collection'];

    if (collectionName != null) {
      // Update the notification with the collection name if missing
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'collection': collectionName});
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
      case 'lostfoundposts/All/posts':
        return 'Lost & Found';
      case 'lostfoundposts':
        return 'Lost & Found';
      case 'Peerposts':
        return 'Peer Assistance';
      case 'Peerposts/All/posts':
        return 'Peer Assistance';
      case 'Eventposts':
        return 'Events and Jobs';
      case 'eventposts':
        return 'Events and Jobs';
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

    // Fetch user-specific unread notifications
    final userNotifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in userNotifications.docs) {
      batch.update(doc.reference, {'isRead': true});
      
      // Add to locally marked as read set
      setState(() {
        _locallyMarkedAsRead.add(doc.id);
      });
    }

    // Fetch general unread notifications (receiverId == null), excluding those sent by the user
    final generalNotifications = await FirebaseFirestore.instance
        .collection('notifications')
        .where('receiverId', isNull: true)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in generalNotifications.docs) {
      if (doc['senderId'] != userId) {
        batch.update(doc.reference, {'isRead': true});
        
        // Add to locally marked as read set
        setState(() {
          _locallyMarkedAsRead.add(doc.id);
        });
      }
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
    else if(collectionName == "Eventposts"){
      collectionName = "Eventposts/All/posts";
    }
    else if(collectionName == "Surveyposts"){
      collectionName = "Surveyposts/All/posts";
    }

    print("collection name : $collectionName");

    // If collection name is not provided, determine it
    if (collectionName == null) {
      List<String> collections = ['lostfoundposts/All/posts', 'Peerposts/All/posts', 'Eventposts', 'Surveyposts'];
      print("collection name : $collectionName");

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
        // Pop the current screen to ensure the notification UI gets updated immediately
        Navigator.pop(context);

        // Now push the PostDetailView
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
}

}