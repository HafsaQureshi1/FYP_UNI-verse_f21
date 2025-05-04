import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/services/fcm-service.dart';
import 'package:url_launcher/url_launcher.dart';
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
      String searchQuery = widget.query.toLowerCase();

      for (String collection in collections) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection(collection)
            .doc("All")
            .collection("posts")
            .get();

        for (var doc in querySnapshot.docs) {
          final data = doc.data();

         String postContent = (data['postContent'] is String)
    ? data['postContent'].toLowerCase()
    : '';

String location = '';
if (data['location'] is String) {
  location = data['location'].toLowerCase();
} else if (data['location'] is Map) {
  location = data['location'].toString().toLowerCase();
}

String url = (data['url'] is String)
    ? data['url'].toLowerCase()
    : '';

         bool match(String field) =>
    field.contains(searchQuery) ||
    field.split(RegExp(r'\W+')).any((word) => word == searchQuery);

if (match(postContent) || match(location) || match(url)) {

            results.add({
              ...data,
              'id': doc.id,
              'collection': collection,
              'timestamp': data['timestamp'] ?? Timestamp.now(),
            });
          }
        }
      }

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
  final normalized = collection.toLowerCase().trim();
  print("Normalized collection is: $normalized");

  if (normalized == 'lostfoundposts/all/posts') return 'Lost & Found';
  if (normalized == 'peerposts/all/posts') return 'Peer Assistance';
  if (normalized == 'eventposts/all/posts') return 'Events & Jobs';
  if (normalized == 'surveyposts/all/posts') return 'Surveys';

  print("⚠️ Unmatched collection: $collection");
  return 'Unknown Collection'; // Fallback
}


  void _navigateToPost(BuildContext context, Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
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
    final String collectionPath = widget.post['collection'];
    final String postId = widget.post['id'];

    // Determine if collection path already includes 'All/posts'
    final bool isFullPath = collectionPath.contains('All/posts');

    // Build the correct reference
    final postRef = isFullPath
        ? FirebaseFirestore.instance.collection(collectionPath).doc(postId)
        : FirebaseFirestore.instance
            .collection(collectionPath)
            .doc('All')
            .collection('posts')
            .doc(postId);

    final commentSnapshot = await postRef.collection('comments').get();

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
print("👉 POST DATA: ${widget.post}");

    // Ensure that widget.post contains correct structure (use widget.post['collection'] and widget.post['id'])
   final collectionName = widget.post['collection'];
final postId = widget.post['id'];

final postRef = collectionName.contains('/')
    ? FirebaseFirestore.instance.collection(collectionName).doc(postId)
    : FirebaseFirestore.instance
        .collection(collectionName)
        .doc('All')
        .collection('posts')
        .doc(postId);


    try {
      final postDoc = await postRef.get();
      if (!postDoc.exists) return;

      final String postAuthorId = postDoc.data()?['userId'] ?? '';

      // Add the comment
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

        // Send notification about the comment
        _fcmService.sendNotificationOnComment(
          postId,
          currentUsername,
          commentRef.id,
          collectionName, // Pass the correct collection name
        );

        // Add a notification record to Firestore
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': postAuthorId,
          'senderId': currentUserId,
          'senderName': currentUsername,
          'postId': postId,
          'commentId': commentRef.id,
          'collection': collectionName, // Store the dynamic collection
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
String _getCollectionDisplayName2(String collection) {
  final normalized = collection.toLowerCase().trim();
  print("Normalized collection is: $normalized");

  if (normalized == 'lostfoundposts/all/posts') return 'Lost & Found';
  if (normalized == 'peerposts/all/posts') return 'Peer Assistance';
  if (normalized == 'eventposts/all/posts') return 'Events & Jobs';
  if (normalized == 'surveyposts/all/posts') return 'Surveys';

  print("⚠️ Unmatched collection: $collection");
  return 'Unknown Collection'; // Fallback
}

  @override
  Widget build(BuildContext context) {
    // This goes before your widget list (e.g., in build method)
String? locationText;
final location = widget.post['location'];

if (location != null) {
  if (location is String && location.isNotEmpty) {
    locationText = location;
  } else if (location is Map && location.isNotEmpty) {
    locationText = location.entries
        .map((e) => "${e.key}: ${e.value}")
        .join(', ');
  }
}

    final timestamp = widget.post['timestamp'] as Timestamp;
    final formattedDate =
        DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate());
print("actual collection value: ${widget.post['collection']}");

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Scaffold(
        backgroundColor: Colors.white, // Change background to white
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 0, 58, 92),
          
          title: Text(
            
            _getCollectionDisplayName2(widget.post['collection']),
            style: const TextStyle(color: Colors.white),
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
                          
                          // Display location if available
                         if (locationText != null && locationText.isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 4.0,
    ),
    child: Row(
      children: [
        const Icon(Icons.location_on, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded( // 👈 Wrap your Text with Expanded
          child: Text(
            locationText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis, // Optional: ellipsis if too long
            maxLines: 2, // Optional: limit to 2 lines
          ),
        ),
      ],
    ),
  ),
 // Display post URL if available (not the image URL)
                          if (widget.post['url'] != null && 
                              widget.post['url'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: GestureDetector(
                                onTap: () async {
                                  String url = widget.post['url'];
                                  if (!url.startsWith('http://') && 
                                      !url.startsWith('https://')) {
                                    url = 'https://$url';
                                  }
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not launch $url')),
                                    );
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.link, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            
                                            Text(
                                              widget.post['url'],
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

                          // Divider before buttons
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Divider(color: Colors.grey[300], height: 1),
                          ),

                          // Like and Comment buttons - Facebook style
                          Container(
                            padding: const EdgeInsets.only(top: 2.0),
                            margin: EdgeInsets.zero,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Like button with thumbs up icon
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: _toggleLike,
                                    style: TextButton.styleFrom(
                                      foregroundColor: isLiked
                                          ? Color(0xFF0561DD)
                                          : Colors.grey[700],
                                      padding:
                                          EdgeInsets.symmetric(vertical: 5.0),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: Icon(
                                      isLiked
                                          ? Icons.thumb_up
                                          : Icons.thumb_up_outlined,
                                      size: 20,
                                      color: isLiked
                                          ? Color(0xFF0561DD)
                                          : Colors.grey[700],
                                    ),
                                    label: Text(
                                      likeCount == 0
                                          ? 'Like'
                                          : likeCount == 1
                                              ? '1 Like'
                                              : '$likeCount Likes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: isLiked
                                            ? Color(0xFF0561DD)
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),

                                // Comment button
                                Expanded(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      // Focus on comment field
                                      FocusScope.of(context)
                                          .requestFocus(FocusNode());
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.grey[700],
                                      padding:
                                          EdgeInsets.symmetric(vertical: 5.0),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: Icon(
                                      Icons
                                          .forum_outlined, // A more modern comment/discussion icon
                                      size: 20,
                                      color: Colors.grey[700],
                                    ),
                                    label: Text(
                                      commentCount == 0
                                          ? 'Comment'
                                          : commentCount == 1
                                              ? '1 Comment'
                                              : '$commentCount Comments',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
  stream: (() {
    final String collectionPath = widget.post['collection'];
    final String postId = widget.post['id'];
    final bool isFullPath = collectionPath.contains('All/posts');

    final postRef = isFullPath
        ? FirebaseFirestore.instance.collection(collectionPath).doc(postId)
        : FirebaseFirestore.instance
            .collection(collectionPath)
            .doc('All')
            .collection('posts')
            .doc(postId);

    return postRef
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  })(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("No comments yet")),
      );
    }

    // your comment rendering logic here
  

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
                      decoration: InputDecoration(
                        hintText: "Write a comment...",
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        fillColor: Colors.grey[100],
                        filled: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: Color(0xFF0561DD)),
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
