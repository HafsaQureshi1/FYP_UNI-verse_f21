import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/fcm-service.dart';
import 'profileimage.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  _SearchResultsScreenState createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  Future<void> _performSearch() async {
    try {
      final collections = [
        'lostfoundposts',
        'Peerposts',
        'Eventposts',
        'Surveyposts',
      ];

      List<Map<String, dynamic>> results = [];

      // Convert query to lowercase for case-insensitive search
      String searchQuery = widget.query.toLowerCase();

      for (String collection in collections) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection(collection)
            .doc("All")
            .collection("posts")
            .get(); // Get all documents first

        // Filter documents locally
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          String postContent = (data['postContent'] ?? '').toLowerCase();

          // Check if post content contains the search query
          if (postContent.contains(searchQuery)) {
            results.add({
              ...data,
              'id': doc.id,
              'collection': collection,
              'timestamp': data['timestamp'] ?? Timestamp.now(),
            });
          }
        }
      }

      // Sort results by timestamp
      results.sort((a, b) =>
          (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));

      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String _getCollectionDisplayName(String collection) {
    switch (collection) {
      case 'lostfoundposts':
        return 'Lost & Found';
      case 'Peerposts':
        return 'Peer Assistance';
      case 'Eventposts':
        return 'Events & Jobs';
      case 'Surveyposts':
        return 'Surveys';
      default:
        return collection;
    }
  }

  void _navigateToPost(BuildContext context, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PostDetailView(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        title: Text(
          'Results for "${widget.query}"',
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
        // Add this to make the back arrow white
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isEmpty
              ? const Center(child: Text('No results found'))
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    final timestamp = result['timestamp'] as Timestamp;
                    final formattedDate = DateFormat('MMM d, yyyy • h:mm a')
                        .format(timestamp.toDate());
                    // Remove likeCount variable as we don't need it anymore

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: InkWell(
                        onTap: () => _navigateToPost(context, result),
                        child: ListTile(
                          title: Text(
                            result['userName'] ?? 'Anonymous',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(result['postContent'] ?? ''),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    _getCollectionDisplayName(
                                        result['collection']),
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(' • '),
                                  Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              // Remove the Row that displays like count
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// New Post Detail View for viewing full post
class PostDetailView extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailView({super.key, required this.post});

  @override
  _PostDetailViewState createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  bool isLiked = false;
  int likeCount = 0;
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FCMService _fcmService = FCMService();
  String? userId;
  final TextEditingController _commentController = TextEditingController();
  int commentCount = 0;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post['likes'] ?? 0;
    userId = widget.post['userId'] ?? '';
    _checkIfUserLiked();
    _fetchCommentCount();
  }

  Future<void> _fetchCommentCount() async {
  try {
    final commentSnapshot = await FirebaseFirestore.instance
        .collection(widget.post['collection'])
        .doc('All')
        .collection('posts')
        .doc(widget.post['id'])
        .collection('comments')
        .get();

    if (mounted) {
      setState(() {
        commentCount = commentSnapshot.docs.length;
      });
    }
  } catch (e) {
    print("Error fetching comment count: $e");
  }
}

Future<void> _checkIfUserLiked() async {
  if (currentUserId == null) return;

  try {
    final likeDoc = await FirebaseFirestore.instance
        .collection(widget.post['collection'])
        .doc('All')
        .collection('posts')
        .doc(widget.post['id'])
        .collection('likes')
        .doc(currentUserId)
        .get();

    if (mounted) {
      setState(() {
        isLiked = likeDoc.exists;
      });
    }
  } catch (e) {
    print("Error checking like status: $e");
  }
}

Future<void> _toggleLike() async {
  if (currentUserId == null) return;

  final postRef = FirebaseFirestore.instance
      .collection(widget.post['collection'])
      .doc('All')
      .collection('posts')
      .doc(widget.post['id']);
  final postAuthorId = widget.post['userId'] ?? '';

  try {
    if (isLiked) {
      // Unlike post
      await postRef.collection('likes').doc(currentUserId).delete();
      if (mounted) {
        setState(() {
          isLiked = false;
          likeCount--;
        });
      }
    } else {
      // Like post
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final String likerName = userDoc.data()?['username'] ?? 'Someone';

      await postRef.collection('likes').doc(currentUserId).set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          isLiked = true;
          likeCount++;
        });
      }

      // Notify post author (if different)
      if (postAuthorId.isNotEmpty && postAuthorId != currentUserId) {
        _fcmService.sendNotificationToUser(
            postAuthorId, likerName, "liked your post!");

        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': postAuthorId,
          'senderId': currentUserId,
          'senderName': likerName,
          'postId': widget.post['id'],
          'collection': widget.post['collection'],
          'message': "$likerName liked your post!",
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'like',
          'isRead': false,
        });
      }
    }

    // Update like count in the post document
    await postRef.update({'likes': likeCount});
  } catch (e) {
    print("Error toggling like: $e");
  }
}

Future<void> _addComment(String commentText) async {
  if (commentText.trim().isEmpty || currentUserId == null) return;

  final postRef = FirebaseFirestore.instance
      .collection(widget.post['collection'])
      .doc('All')
      .collection('posts')
      .doc(widget.post['id']);

  try {
    final postDoc = await postRef.get();
    if (!postDoc.exists) return;

    final String postAuthorId = postDoc.data()?['userId'] ?? '';

    final commentRef = await postRef.collection('comments').add({
      'userId': currentUserId,
      'comment': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
    _fetchCommentCount(); // Refresh comment count

    // Notify post author if not commenting on their own post
    if (postAuthorId.isNotEmpty && postAuthorId != currentUserId) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final String currentUsername =
          userDoc.data()?['username'] ?? 'Unknown User';

      _fcmService.sendNotificationOnComment(
          widget.post['id'], currentUsername, commentRef.id);

      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': postAuthorId,
        'senderId': currentUserId,
        'senderName': currentUsername,
        'postId': widget.post['id'],
        'commentId': commentRef.id,
        'collection': widget.post['collection'],
        'message': "$currentUsername commented on your post",
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'comment',
        'isRead': false,
      });
    }
  } catch (e) {
    print("Error adding comment: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    final timestamp = widget.post['timestamp'] as Timestamp;
    final formattedDate =
        DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate());

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 0, 58, 92),
          title: Text(
            _getCollectionDisplayName(widget.post['collection']),
            style: const TextStyle(
                color: Colors.white), // Added white text style here
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: userId != null && userId!.isNotEmpty
                                ? ProfileAvatar(userId: userId!, radius: 20)
                                : CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.grey[300],
                                    child: const Icon(Icons.person,
                                        color: Colors.grey),
                                  ),
                            title: Text(
                              widget.post['userName'] ?? 'Anonymous',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(formattedDate),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              widget.post['postContent'] ?? '',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          // Display image if available
                          if (widget.post['imageUrl'] != null &&
                              widget.post['imageUrl'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Image.network(
                                  widget.post['imageUrl'],
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 150,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Icon(Icons.error_outline,
                                            color: Colors.grey, size: 40),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                          // Remove like and comment count text display

                          const Divider(),
                          // Like and Comment buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: _toggleLike,
                                icon: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                ),
                                label: Text(likeCount == 1
                                    ? '1 Like'
                                    : '$likeCount Likes'),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  // Focus on comment field
                                  FocusScope.of(context)
                                      .requestFocus(FocusNode());
                                  _commentController.clear();
                                },
                                icon: const Icon(Icons.comment,
                                    color: Colors.blue),
                                label: Text(commentCount == 1
                                    ? '1 Comment'
                                    : '$commentCount Comments'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Comments section
                    Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "Comments",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection(widget.post['collection'])
                                .doc("All")
                                .collection("posts")
                                .doc(widget.post['id'])
                      
                                .collection('comments')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: Text("No comments yet")),
                                );
                              }

                              var comments = snapshot.data!.docs;
                              return ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  var comment = comments[index];
                                  String commenterId = comment['userId'];
                                  Timestamp? timestamp = comment['timestamp'];
                                  String formattedTime = "Just now";

                                  if (timestamp != null) {
                                    DateTime date = timestamp.toDate();
                                    formattedTime =
                                        DateFormat('MMM d, yyyy • h:mm a')
                                            .format(date);
                                  }

                                  return StreamBuilder<DocumentSnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(commenterId)
                                        .snapshots(),
                                    builder: (context, usernameSnapshot) {
                                      if (!usernameSnapshot.hasData ||
                                          !usernameSnapshot.data!.exists) {
                                        return const SizedBox();
                                      }

                                      String username = usernameSnapshot.data!
                                              .get('username') ??
                                          'Unknown User';

                                      return ListTile(
                                        leading: ProfileAvatar(
                                            userId: commenterId, radius: 18),
                                        title: Text(username,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(formattedTime,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey)),
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
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Comment input field (fixed at bottom)
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ProfileAvatar(
                    userId: currentUserId ?? '',
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: "Write a comment...",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            ),
          ],
        ),
      ),
    );
  }

  String _getCollectionDisplayName(String collection) {
    switch (collection) {
      case 'lostfoundposts':
        return 'Lost & Found';
      case 'Peerposts':
        return 'Peer Assistance';
      case 'Eventposts':
        return 'Events & Jobs';
      case 'Surveyposts':
        return 'Surveys';
      default:
        return collection;
    }
  }
}
