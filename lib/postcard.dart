import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/fcm-service.dart';
import 'package:intl/intl.dart';
import 'profileimage.dart';
class PostCard extends StatefulWidget {
  final String postId;
  final String userId;
  final String username;
  final String content;
  final int likes;
  final String collectionName; // ✅ Generalized collection name
  final String? imageUrl;

  const PostCard({
    super.key,
    required this.postId,
    required this.userId,
    required this.username,
    required this.content,
    required this.likes,
    required this.collectionName, // ✅ Required parameter
    this.imageUrl,
  });

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  String postTime = "";
  int likeCount = 0;
  bool isLiked = false;
  String? currentUserId;
  String? profileImageUrl;
  String currentUsername = '';
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    likeCount = widget.likes;

    _fetchUsername();
    _fetchProfileImage();
    _fetchPostTime();
    _checkIfUserLiked();
    _fetchImageUrl();
  }

  /// ✅ Fetches user details dynamically
  void _fetchUsername() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        setState(() {
          currentUsername = userDoc.data()?['username'] ?? 'Unknown User';
        });
      }
    });
  }

  void _fetchProfileImage() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        setState(() {
          profileImageUrl = userDoc.data()?['profilePicture'];
        });
      }
    });
  }

  void _fetchImageUrl() {
    FirebaseFirestore.instance
        .collection(widget.collectionName) // ✅ Use dynamic collection name
        .doc(widget.postId)
        .snapshots()
        .listen((postDoc) {
      if (postDoc.exists && mounted) {
        setState(() {
          imageUrl = postDoc.data()?['imageUrl'];
        });
      }
    });
  }

  Future<void> _fetchPostTime() async {
    final postDoc = await FirebaseFirestore.instance
        .collection(widget.collectionName) // ✅ Dynamic collection reference
        .doc(widget.postId)
        .get();

    if (postDoc.exists) {
      final Timestamp? timestamp = postDoc.data()?['timestamp'];
      if (timestamp != null && mounted) {
        final DateTime date = timestamp.toDate();
        final String formattedDate =
            "${date.day} ${_getMonthName(date.month)} ${date.year}, ${_formatTime(date)}";
        setState(() {
          postTime = formattedDate;
        });
      }
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return monthNames[month];
  }

  String _formatTime(DateTime date) {
    int hour = date.hour;
    int minute = date.minute;
    String period = hour >= 12 ? "PM" : "AM";
    hour = hour > 12 ? hour - 12 : hour == 0 ? 12 : hour;
    return "$hour:${minute.toString().padLeft(2, '0')} $period";
  }

  Future<void> _checkIfUserLiked() async {
    if (currentUserId == null) return;

    final likeDoc = await FirebaseFirestore.instance
        .collection(widget.collectionName) // ✅ Dynamic collection reference
        .doc(widget.postId)
        .collection('likes')
        .doc(currentUserId)
        .get();

    if (mounted) {
      setState(() {
        isLiked = likeDoc.exists;
      });
    }
  }

  /// ✅ **Generalized Like Toggle Function**
  void _toggleLike() async {
    if (currentUserId == null) return;

    final postRef = FirebaseFirestore.instance
        .collection(widget.collectionName) // ✅ Use dynamic collection name
        .doc(widget.postId);

    // ✅ Update UI immediately
    setState(() {
      isLiked = !isLiked;
      likeCount = isLiked ? likeCount + 1 : likeCount - 1;
    });

    if (!isLiked) {
      await postRef.collection('likes').doc(currentUserId).delete();
    } else {
      await postRef.collection('likes').doc(currentUserId).set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Fetch likerName asynchronously
      FirebaseFirestore.instance.collection('users').doc(currentUserId).get().then((userDoc) async {
        final String likerName = userDoc.data()?['username'] ?? 'Someone';

        final postDoc = await postRef.get();
        final String postAuthorId = postDoc.data()?['userId'] ?? '';

        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': postAuthorId,
          'senderId': currentUserId,
          'senderName': likerName,
          'postId': widget.postId,
          'collection': widget.collectionName, // ✅ Dynamic collection
          'message': "$likerName liked your post",
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'like',
          'isRead': false,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 15.0),
          elevation: 1.0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ✅ User details
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20.0,
                      backgroundColor: Colors.grey[300],
                      child: profileImageUrl == null
                          ? const CircularProgressIndicator()
                          : ClipOval(
                              child: Image.network(
                                profileImageUrl!,
                                fit: BoxFit.cover,
                                width: 40.0,
                                height: 40.0,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.person, size: 20.0, color: Colors.grey[600]),
                              ),
                            ),
                    ),
                    const SizedBox(width: 15.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(currentUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(postTime, style: const TextStyle(fontSize: 12.0, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10.0),

                /// ✅ Post Content
                Text(widget.content, style: const TextStyle(fontSize: 16.0)),

                /// ✅ Image (if available)
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200.0,
                      ),
                    ),
                  ),

                /// ✅ Like and Comment Buttons
               Padding(
  padding: const  EdgeInsets.only(top: 12.0),  // Added vertical padding
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      TextButton.icon(
        onPressed: _toggleLike,
        icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.red),
        label: Text('$likeCount Likes'),
      ),
      TextButton.icon(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => CommentSection(
              postId: widget.postId,
              collectionName: widget.collectionName,
            ),
          );
        },
        icon: const Icon(Icons.comment, color: Colors.blue),
        label: const Text('Comment'),
      ),
    ],
  ),
)

              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CommentSection extends StatefulWidget {
  final String postId;
  final String collectionName; // Generalized collection name

  const CommentSection({super.key, required this.postId, required this.collectionName});

  @override
  _CommentSectionState createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  final FCMService _fcmService = FCMService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  void _fetchUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
    }
  }

  void _addComment(String commentText) async {
    if (commentText.trim().isEmpty || _userId == null) return;

    final postRef = FirebaseFirestore.instance
        .collection(widget.collectionName) // Use dynamic collection
        .doc(widget.postId);

    final postDoc = await postRef.get();
    if (!postDoc.exists) return;

    final String postAuthorId = postDoc.data()?['userId'] ?? '';

    final commentRef = await postRef.collection('comments').add({
      'userId': _userId,
      'comment': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();

    if (postAuthorId.isNotEmpty && postAuthorId != _userId) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      final String currentUsername = userDoc.data()?['username'] ?? 'Unknown User';

      _fcmService.sendNotificationOnComment(widget.postId, currentUsername, commentRef.id);

      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': postAuthorId,
        'senderId': _userId,
        'senderName': currentUsername,
        'postId': widget.postId,
        'commentId': commentRef.id,
        'collection': widget.collectionName, // Store the dynamic collection
        'message': "$currentUsername commented on your post",
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'comment',
        'isRead': false,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(widget.collectionName)
                    .doc(widget.postId)
                    .collection('comments')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No comments yet"));
                  }
                  var comments = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      var comment = comments[index];
                      String commenterId = comment['userId'];
                      Timestamp? timestamp = comment['timestamp'];
                      String formattedTime = "Just now";

                      if (timestamp != null) {
                        DateTime date = timestamp.toDate();
                        formattedTime = DateFormat('MMM d, yyyy • h:mm a').format(date);
                      }

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(commenterId).snapshots(),
                        builder: (context, usernameSnapshot) {
                          if (!usernameSnapshot.hasData || !usernameSnapshot.data!.exists) {
                            return const SizedBox();
                          }
                          String username = usernameSnapshot.data!.get('username') ?? 'Unknown User';
                          return ListTile(
                            leading: ProfileAvatar(userId: commenterId, radius: 18),
                            title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text(comment['comment'] ?? ''),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
                ProfileAvatar(userId: _userId ?? '', radius: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: "Write a comment...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () {
                    _addComment(_commentController.text);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

