import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/Notificationscreen.dart';
import 'package:flutter_application_1/fcm-service.dart';
import 'package:intl/intl.dart'; // For formatting timestamps
import 'search_results.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';
import 'PeerScreen.dart';
import 'SurveyScreen.dart';
import 'EventScreen.dart';
import 'profile_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<Widget> _screens = [
    const LostFoundScreen(),
    const PeerAssistanceScreen(),
    const EventsJobsScreen(),
    const SurveysScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            '267004637492-iugmfvid1ca8prhuvkaflcbrtre7cibs.apps.googleusercontent.com',
      );
      // Sign out from Google Sign-In
      await googleSignIn.signOut();

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Navigate to Sign In Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return PreferredSize(
      preferredSize: const Size.fromHeight(50.0),
      child: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: const InputDecoration(
                  hintText: 'Search posts...',
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchResultsScreen(query: value),
                      ),
                    );
                  }
                },
              )
            : const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  "UNI-verse",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (_isSearching) {
                  _searchFocusNode.requestFocus();
                }
              });
            },
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.black,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationScreen()));
                  },
                  icon: const Icon(Icons.notifications, color: Colors.black),
                ),
                // Notification Badge Counter
                if (currentUserId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('receiverId', isEqualTo: currentUserId)
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int count = 0;
                      if (snapshot.hasData && snapshot.data != null) {
                        count = snapshot.data!.docs.length;
                      }
                      if (count == 0) {
                        return Container(); // No badge when no unread notifications
                      }

                      return Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 9.0), // Add padding here
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfilePage(),
                  ),
                );
              },
              icon: const Icon(Icons.person, color: Colors.black),
            ),
          ),
          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9.0),
            child: IconButton(
              onPressed: _signOut, // Call the sign-out function
              icon: const Icon(Icons.exit_to_app, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Lost/Found",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Peer Assistance",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner),
            label: "Events/Jobs",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Surveys",
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

class LostFoundScreen extends StatelessWidget {
  const LostFoundScreen({super.key});

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
                      .collection('lostfoundposts')
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
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return const CreateNewPostScreen();
                  },
                );
              },
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
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
  String postTime = "";
  int likeCount = 0;
  bool isLiked = false;
  String? currentUserId;
  final FCMService _fcmService = FCMService();

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
        .collection('lostfoundposts')
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
        .collection('lostfoundposts')
        .doc(widget.postId)
        .get();

    if (postDoc.exists) {
      final Timestamp? timestamp = postDoc.data()?['timestamp'];
      if (timestamp != null) {
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
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return monthNames[month];
  }

  String _formatTime(DateTime date) {
    int hour = date.hour;
    int minute = date.minute;
    String period = hour >= 12 ? "PM" : "AM";
    hour = hour > 12
        ? hour - 12
        : hour == 0
            ? 12
            : hour;
    return "$hour:${minute.toString().padLeft(2, '0')} $period";
  }

  void _toggleLike() async {
    if (currentUserId == null) return;

    final postRef = FirebaseFirestore.instance
        .collection('lostfoundposts')
        .doc(widget.postId);
    final postDoc = await postRef.get();
    final String postAuthorId = postDoc.data()?['userId'] ?? '';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    final String likerName = userDoc.data()?['username'] ?? 'Someone';

    if (isLiked) {
      await postRef.collection('likes').doc(currentUserId).delete();
      setState(() {
        isLiked = false;
        likeCount--;
      });
    } else {
      await postRef.collection('likes').doc(currentUserId).set({
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        isLiked = true;
        likeCount++;
      });

      // Send FCM Notification
      _fcmService.sendNotificationToUser(
          postAuthorId, likerName, "liked your post!");

      // Store Notification in Firestore with collection name
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': postAuthorId,
        'senderId': currentUserId,
        'senderName': likerName,
        'postId': widget.postId,
        'collection': 'lostfoundposts',
        'message': "$likerName liked your post",
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'like',
        'isRead': false,
      });
    }

    await postRef.update({'likes': likeCount});
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 20.0),
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
            Text(widget.content, style: const TextStyle(fontSize: 16.0)),
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
  final FCMService _fcmService = FCMService(); // Initialize FCMService

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

  void _addComment(String commentText) async {
    if (commentText.trim().isEmpty || _username == null) return;

    final postRef = FirebaseFirestore.instance
        .collection('lostfoundposts')
        .doc(widget.postId);

    // Fetch post document
    final postDoc = await postRef.get();

    if (!postDoc.exists) {
      return;
    }

    final String postAuthorId = postDoc.data()?['userId'] ?? '';
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Add comment and get its document reference
    final commentRef = await postRef.collection('comments').add({
      'userId': userId,
      'username': _username,
      'comment': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _commentController.clear();

    // Ensure the post owner isn't notified for their own comments
    if (postAuthorId.isNotEmpty && postAuthorId != userId) {
      _fcmService.sendNotificationOnComment(
          widget.postId, _username!, commentRef.id);

      // Store Notification in Firestore with collection name
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': postAuthorId,
        'senderId': userId,
        'senderName': _username,
        'postId': widget.postId,
        'commentId': commentRef.id,
        'collection': 'lostfoundposts',
        'message': "$_username commented on your post",
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'comment',
        'isRead': false,
      });
    }
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
                    .collection('lostfoundposts')
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
                      Timestamp? timestamp = comment['timestamp'];
                      String formattedTime = "Just now";

                      if (timestamp != null) {
                        DateTime date = timestamp.toDate();
                        formattedTime =
                            DateFormat('MMM d, yyyy • h:mm a').format(date);
                      }

                      return ListTile(
                        leading: const CircleAvatar(
                            radius: 18.0), // Add user profile pic if available
                        title: Text(comment['username'] ?? 'Unknown User',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formattedTime,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            Text(comment['comment'] ?? ''),
                          ],
                        ),
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

        await _firestore.collection('lostfoundposts').add({
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Create New Post',
          style: TextStyle(
              fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(26.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40.0),
            FutureBuilder<DocumentSnapshot>(
              future: _firestore
                  .collection('users')
                  .doc(_auth.currentUser?.uid)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (!snapshot.hasData ||
                    snapshot.data == null ||
                    !snapshot.data!.exists) {
                  return const Text("Not logged in");
                }
                String username = snapshot.data!['username'] ?? 'Anonymous';
                //String profilePic = snapshot.data!['profilePic'] ?? '';
                return Row(
                  children: [
                    const CircleAvatar(
                      radius: 20.0,
                      //backgroundImage: profilePic.isNotEmpty
                      //     ? NetworkImage(profilePic)
                      //    : const AssetImage('assets/images/hi.png') as ImageProvider,
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      username,
                      style: const TextStyle(
                          fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20.0),
            TextField(
              controller: _postController,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 20.0, horizontal: 14.0),
              ),
              style: const TextStyle(fontSize: 18.0),
            ),
            const SizedBox(height: 20.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    minimumSize: const Size(160, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
                const SizedBox(width: 10.0),
                ElevatedButton(
                  onPressed: _isPosting ? null : _createPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 58, 92),
                    minimumSize: const Size(160, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                  ),
                  child: _isPosting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Post Now',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ],
            ),
          ],
        ),
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
