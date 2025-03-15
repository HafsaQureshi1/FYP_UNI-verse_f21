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
  int commentCount = 0; // Add comment count
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final FCMService _fcmService = FCMService();
  String? userId;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post['likes'] ?? 0;
    userId = widget.post['userId'] ?? '';
    _checkIfUserLiked();
    _fetchCommentCount(); // Fetch comment count
  }

  Future<void> _checkIfUserLiked() async {
    if (currentUserId == null) return;

    try {
      final likeDoc = await FirebaseFirestore.instance
          .collection(widget.post['collection'])
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
        .doc(widget.post['id']);
    final postAuthorId = widget.post['userId'] ?? '';

    if (isLiked) {
      // Unlike post
      await postRef.collection('likes').doc(currentUserId).delete();
      setState(() {
        isLiked = false;
        likeCount--;
      });
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

      setState(() {
        isLiked = true;
        likeCount++;
      });

      // Only send notification if the post author is not the current user
      if (postAuthorId.isNotEmpty && postAuthorId != currentUserId) {
        // Send FCM Notification
        _fcmService.sendNotificationToUser(
            postAuthorId, likerName, "liked your post!");

        // Store Notification in Firestore
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': postAuthorId,
          'senderId': currentUserId,
          'senderName': likerName,
          'postId': widget.post['id'],
          'message': "$likerName liked your post!",
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'like',
          'isRead': false,
        });
      }
    }

    // Update like count in the post document
    await postRef.update({'likes': likeCount});
  }

  // Fetch comment count
  void _fetchCommentCount() {
    FirebaseFirestore.instance
        .collection(widget.post['collection'])
        .doc(widget.post['id'])
        .collection('comments')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          commentCount = snapshot.size;
        });
      }
    });
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
            style: const TextStyle(color: Colors.white), // Make text white
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Card(
                margin: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      // Replace CircleAvatar with ProfileAvatar
                      leading: userId != null && userId!.isNotEmpty
                          ? ProfileAvatar(userId: userId!, radius: 20)
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[300],
                              child:
                                  const Icon(Icons.person, color: Colors.grey),
                            ),
                      title: Text(
                        widget.post['userName'] ?? 'Anonymous',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
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
                    // Like and comment buttons with updated like count display
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left side - Like button with heart icon + count
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Like count with heart icon
                              if (likeCount > 0)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.favorite,
                                      color: Colors.red,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$likeCount',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              // Like button
                              TextButton.icon(
                                onPressed: _toggleLike,
                                icon: Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.red,
                                ),
                                label: const Text('Like'),
                              ),
                            ],
                          ),

                          // Right side - Comment section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Comment count above button
                              if (commentCount > 0)
                                Text(
                                  '$commentCount ${commentCount == 1 ? 'comment' : 'comments'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              // Comment button
                              TextButton.icon(
                                onPressed: () {
                                  Scrollable.ensureVisible(
                                    commentsKey.currentContext!,
                                    duration: const Duration(milliseconds: 300),
                                    alignment: 0.5,
                                  );
                                },
                                icon: const Icon(Icons.comment,
                                    color: Colors.blue),
                                label: const Text('Comment'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Divider before comments section
                    Divider(
                        height: 8, thickness: 1, color: Colors.grey.shade200),

                    // Comments header with key for scrolling
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, top: 12.0, bottom: 8.0),
                      key: commentsKey, // Add a key to scroll to comments
                      child: Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    // Embedded comments section
                    SizedBox(
                      height: 300, // Fixed height for comments section
                      child: CommentsWidget(
                        postId: widget.post['id'],
                        collectionName: widget.post['collection'],
                      ),
                    ),

                    // Comment input field
                    CommentInputField(
                      postId: widget.post['id'],
                      collectionName: widget.post['collection'],
                      postAuthorId: widget.post['userId'] ?? '',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Create a global key to allow scrolling to comments section
  final GlobalKey commentsKey = GlobalKey();

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

// New widget for displaying comments directly in the post detail view
class CommentsWidget extends StatelessWidget {
  final String postId;
  final String collectionName;

  const CommentsWidget({
    super.key,
    required this.postId,
    required this.collectionName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collectionName)
          .doc(postId)
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
          padding: EdgeInsets.zero,
          itemCount: comments.length,
          itemBuilder: (context, index) {
            var comment = comments[index];
            String commenterId = comment['userId'];
            Timestamp? timestamp = comment['timestamp'];
            String formattedTime = "Just now";

            if (timestamp != null) {
              DateTime date = timestamp.toDate();
              formattedTime = DateFormat('MMM d • h:mm a').format(date);
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

                String username =
                    usernameSnapshot.data!.get('username') ?? 'Unknown User';

                return ListTile(
                  leading: ProfileAvatar(userId: commenterId, radius: 18),
                  title: Text(
                    username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedTime,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(comment['comment'] ?? ''),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                );
              },
            );
          },
        );
      },
    );
  }
}

// New widget for comment input field
class CommentInputField extends StatefulWidget {
  final String postId;
  final String collectionName;
  final String postAuthorId;

  const CommentInputField({
    super.key,
    required this.postId,
    required this.collectionName,
    required this.postAuthorId,
  });

  @override
  _CommentInputFieldState createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends State<CommentInputField> {
  final TextEditingController _commentController = TextEditingController();
  final FCMService _fcmService = FCMService();
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  void _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _userId == null) return;

    try {
      // Add comment to Firestore
      final postRef = FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(widget.postId);

      final commentRef = await postRef.collection('comments').add({
        'userId': _userId,
        'comment': commentText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _commentController.clear();

      // Send notification if commenting on someone else's post
      if (widget.postAuthorId.isNotEmpty && widget.postAuthorId != _userId) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .get();

        final String currentUsername =
            userDoc.data()?['username'] ?? 'Unknown User';

        // Send FCM notification
        _fcmService.sendNotificationOnComment(
          widget.postId,
          currentUsername,
          commentRef.id,
        );

        // Add notification to Firestore
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': widget.postAuthorId,
          'senderId': _userId,
          'senderName': currentUsername,
          'postId': widget.postId,
          'commentId': commentRef.id,
          'collection': widget.collectionName,
          'message': "$currentUsername commented on your post",
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'comment',
          'isRead': false,
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 16.0,
        top: 8.0,
      ),
      child: Row(
        children: [
          ProfileAvatar(userId: _userId ?? '', radius: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: "Write a comment...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
