import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting timestamps

import 'package:cloud_firestore/cloud_firestore.dart';

class SurveysScreen extends StatelessWidget {
  const SurveysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Divider(color: Colors.grey[300], thickness: 1), // Grey divider
              const CategoryChips(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('Surveyposts')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No posts found'));
                    }

                    var posts = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        var post = posts[index];
                        String username = post['userName'] ?? 'Anonymous';
                        String content = post['postContent'] ?? '';

                        return PostCard(
                          username: username,
                          content: content,
                          // userProfilePic: userProfilePic,
                          postId: post.id,
                          likes: post['likes'] ?? 0,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 0, 58, 92),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return const CreateNewPostScreen();
                  },
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            CategoryChip(label: "General"),
            CategoryChip(label: "Electronics"),
            CategoryChip(label: "Books"),
          ],
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String label;

  const CategoryChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        label: Text(label),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.grey, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class CreateNewPostScreen extends StatefulWidget {
  const CreateNewPostScreen({super.key});

  @override
  _CreateNewPostScreenState createState() => _CreateNewPostScreenState();
}

class _CreateNewPostScreenState extends State<CreateNewPostScreen> {
  final TextEditingController _postController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isPosting = false;

  Future<void> _createPost() async {
    String postContent = _postController.text.trim();
    if (postContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post cannot be empty!')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      User? user = _auth.currentUser;

      if (user != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        String username = userDoc.exists ? userDoc['username'] : 'Anonymous';

        await _firestore.collection('Surveyposts').add({
          'userId': user.uid,
          'userName': username,
          'userEmail': user.email,
          'likes': 0,
          'postContent': postContent,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );

        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color.fromARGB(255, 0, 58, 92);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(
            85), // Increased height to accommodate the camera hole
        child: Container(
          padding: const EdgeInsets.only(
              top: 35), // Add padding to move content below camera hole
          child: AppBar(
            backgroundColor: themeColor,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            title: const Text(
              'Create Post',
              style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
      ),
      // Keep SingleChildScrollView for keyboard handling
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info section with subtle divider
              Container(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<DocumentSnapshot>(
                  future: _firestore
                      .collection('users')
                      .doc(_auth.currentUser?.uid)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 40,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!snapshot.hasData ||
                        snapshot.data == null ||
                        !snapshot.data!.exists) {
                      return const Text("Not logged in");
                    }
                    String username = snapshot.data!['username'] ?? 'Anonymous';
                    return Row(
                      children: [
                        // Larger avatar with shadow
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 24.0,
                            backgroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                "Posting to Surveys",
                                style: TextStyle(
                                  fontSize: 13.0,
                                  color: Colors.grey,
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Enhanced post content area
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _postController,
                    maxLines: null,
                    minLines: 8,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 16.0),
                    decoration: InputDecoration(
                      hintText:
                          "Share a survey or research participation reqquest",
                      hintStyle: TextStyle(
                          color: Colors.grey.shade500, fontSize: 20.0),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12.0),
                    ),
                  ),
                ),
              ),

              // Full-width post button
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _isPosting ? null : _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        disabledBackgroundColor: themeColor.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        elevation: 0,
                      ),
                      child: _isPosting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.0,
                              ),
                            )
                          : const Text(
                              'Post',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),

                    const SizedBox(height: 10),

                    // Cancel button with subtle styling
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: themeColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom padding for keyboard
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
    );
  }
}

class PostCard extends StatefulWidget {
  final String username;
  final String content;
  final String postId;
  final int likes;

  const PostCard({
    super.key,
    required this.username,
    required this.content,
    required this.postId,
    required this.likes,
  });

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int likeCount = 0;
  bool isLiked = false;
  String? currentUserId;
  String postTime = "Just now";

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    likeCount = widget.likes;
    _checkIfUserLiked();
    _fetchPostTime();
  }

  Future<void> _checkIfUserLiked() async {
    if (currentUserId == null) return;

    final likeDoc = await FirebaseFirestore.instance
        .collection('Surveyposts')
        .doc(widget.postId)
        .collection('likes')
        .doc(currentUserId)
        .get();

    if (mounted) {
      // Check if widget is still in the tree
      setState(() {
        isLiked = likeDoc.exists;
      });
    }
  }

  Future<void> _fetchPostTime() async {
    final postDoc = await FirebaseFirestore.instance
        .collection('Surveyposts')
        .doc(widget.postId)
        .get();

    if (postDoc.exists) {
      Timestamp? timestamp = postDoc['timestamp']; // Firestore timestamp
      if (timestamp != null && mounted) {
        // Check if widget is still in the tree
        DateTime date = timestamp.toDate();
        String formattedTime = DateFormat('MMM d, yyyy • h:mm a').format(date);
        setState(() {
          postTime = formattedTime;
        });
      }
    }
  }

  void _toggleLike() async {
    if (currentUserId == null) return;

    final likeRef = FirebaseFirestore.instance
        .collection('Surveyposts')
        .doc(widget.postId)
        .collection('likes')
        .doc(currentUserId);

    if (isLiked) {
      await likeRef.delete();
      if (mounted) {
        // Check if widget is still in the tree
        setState(() {
          isLiked = false;
          likeCount--;
        });
      }
    } else {
      await likeRef.set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        // Check if widget is still in the tree
        setState(() {
          isLiked = true;
          likeCount++;
        });
      }
    }

    // Only update the post if the widget is still mounted
    if (mounted) {
      await FirebaseFirestore.instance
          .collection('Surveyposts')
          .doc(widget.postId)
          .update({'likes': likeCount});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 3.0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info & Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                        radius: 20.0), // Profile picture placeholder
                    const SizedBox(width: 10.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.username,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(postTime,
                            style: const TextStyle(
                                fontSize: 12.0, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10.0),

            // Post Content
            Text(widget.content, style: const TextStyle(fontSize: 16.0)),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _toggleLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: Colors.red,
                  ),
                  label: Text('$likeCount Likes'),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) =>
                          CommentSection(postId: widget.postId),
                    );
                  },
                  icon: const Icon(Icons.comment, color: Colors.blue),
                  label: const Text('Comment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CommentSection extends StatefulWidget {
  final String postId;

  const CommentSection({super.key, required this.postId});

  @override
  _CommentSectionState createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  String? _username;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _username = userDoc.data()?['username'] ?? 'Unknown User';
      });
    }
  }

  void _addComment(String commentText) {
    if (commentText.trim().isEmpty || _username == null) return;

    FirebaseFirestore.instance
        .collection('Surveyposts')
        .doc(widget.postId)
        .collection('comments')
        .add({
      'username': _username,
      'comment': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text("Comments",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Surveyposts')
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
                      return ListTile(
                        leading: const CircleAvatar(
                            radius: 18.0), // Add user profile pic if available
                        title: Text(comment['username'] ?? 'Unknown User',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(comment['comment'] ?? ''),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              children: [
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
