import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/fcm-service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PeerAdmin extends StatefulWidget {
  const PeerAdmin({super.key});

  @override
  _PeerAdminState createState() => _PeerAdminState();
}

class _PeerAdminState extends State<PeerAdmin> {
  // Theme colors - match with Home.dart
  final Color _primaryColor = const Color.fromARGB(255, 0, 58, 92);
  final Color _backgroundColor = const Color.fromARGB(64, 236, 236, 236);
  final ScrollController _scrollController = ScrollController();

  final Map<String, List<String>> keywordMap = {
    "Computer Science": [
      "programming", "code", "coding", "flutter", "java", "python", "c++", "software",
      "android", "ios", "web", "database", "sql", "nosql", "API", "frontend", "backend",
      "AI", "ML", "artificial intelligence", "machine learning", "data science",
      "devops", "cloud", "firebase", "github", "react", "angular", "docker"
    ],
    "Electrical Engineering": [
      "circuit", "voltage", "current", "resistor", "capacitor", "inductor", "oscilloscope",
      "power", "transformer", "electricity", "watt", "ampere", "signal", "microcontroller",
      "arduino", "embedded", "analog", "digital", "transistor", "diode", "sensor", "relay"
    ],
    "Education & Physical Education": [
      "teaching", "teacher", "student", "lecture", "class", "education", "learning", "study",
      "assignment", "course", "school", "university", "PE", "sports", "exercise", "training",
      "coaching", "fitness", "health", "activity", "tournament", "competition", "curriculum"
    ],
    "Business": [
      "business", "startup", "entrepreneur", "finance", "marketing", "sales", "customer",
      "strategy", "investment", "money", "profit", "loss", "budget", "HR", "human resources",
      "management", "economy", "commerce", "pitch", "project", "advertising", "brand"
    ],
    "Mathematics": [
      "algebra", "calculus", "geometry", "statistics", "math", "mathematics", "equation",
      "function", "integral", "derivative", "vector", "matrix", "probability", "graph",
      "set theory", "number", "trigonometry", "logarithm", "theorem", "prime", "formula"
    ],
    "Media": [
      "media", "journalism", "news", "anchor", "editor", "editing", "film", "movie", "cinema",
      "photography", "camera", "shot", "clip", "video", "recording", "script", "broadcast",
      "radio", "tv", "advertisement", "press", "social media", "influencer", "interview"
    ]
  };

  Stream<QuerySnapshot> _getPendingPostsStream() {
    return FirebaseFirestore.instance
        .collection('peeradmin')
        .doc("All")
        .collection("posts")
        .where('approval', isEqualTo: null)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _getAllPostsStream() {
    return FirebaseFirestore.instance
        .collection('Peerposts')
        .doc("All")
        .collection("posts")
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<String> _handleLowConfidence(String postText) async {
    final lowerText = postText.toLowerCase();

    for (var entry in keywordMap.entries) {
      for (var keyword in entry.value) {
        if (lowerText.contains(keyword.toLowerCase())) {
          print("Keyword match found: '${keyword}' → Category: ${entry.key}");
          return entry.key;
        }
      }
    }

    print("No keyword match found. Defaulting to 'Miscellaneous'");
    return "Miscellaneous";
  }

  Future<String> _classifyPeerAssistancePost(String postText) async {
    final url = Uri.parse(
        "https://api-inference.huggingface.co/models/MoritzLaurer/mDeBERTa-v3-base-xnli-multilingual-nli-2mil7");
    final headers = {
      "Authorization": "Bearer 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",
      "Content-Type": "application/json; charset=UTF-8"
    };

    final body = jsonEncode({
      "inputs": postText,
      "parameters": {
        "candidate_labels": [
          "Computer Science",
          "Electrical Engineering",
          "Education & Physical Education",
          "Business",
          "Mathematics",
          "Media",
          "Miscellaneous"
        ],
        "hypothesis_template": "This post is related to {}."
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      // Print the response status and body for debugging
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<dynamic> labels = responseData["labels"];
        List<dynamic> scores = responseData["scores"];

        // Print the labels and scores for debugging
        print("Labels: $labels");
        print("Scores: $scores");

        if (labels.isNotEmpty && scores.isNotEmpty) {
          String bestCategory = "Miscellaneous";
          double bestConfidence = 0.0;

          for (int i = 0; i < labels.length; i++) {
            if (labels[i] != "Miscellaneous" && scores[i] > bestConfidence) {
              bestCategory = labels[i];
              bestConfidence = scores[i];
            }
          }

          if (bestConfidence < 0.2) {
            return await _handleLowConfidence(postText);
          }

          return bestCategory;
        }
      } else {
        return await _handleLowConfidence(postText);
      }
    } catch (e) {
      print("Hugging Face API Exception: $e");
      return await _handleLowConfidence(postText);
    }

    return "Miscellaneous";
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

  Future<void> _approvePeerPost(DocumentSnapshot post) async {
    final postData = post.data() as Map<String, dynamic>;
    final postId = post.id;
    final posterId = postData['userId'];
    final postContent = postData['postContent'] ?? '';
    final posterName = postData['userName'] ?? 'Someone'; 

    _showLoadingDialog(context, "Approving post and sending notifications...");

    String category = "Uncategorized";
    try {
      category = await _classifyPeerAssistancePost(postContent);
      print("AI classification : $category");
    } catch (e) {
      print("AI classification failed: $e");
    }

    final approvedPostData = {
      ...postData,
      'approval': 'approved',
      'category': category,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('Peerposts')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .set(approvedPostData);

    final FCMService _fcmService = FCMService();

    await _fcmService.sendNotificationOnNewPost(
      posterId,
      posterName,
      'Peer assistance',
    );
    await _fcmService.sendNotificationPostApproved(posterId, 'Peer Assistance');

    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': posterId,
      'senderId': 'admin',
      'senderName': 'Admin',
      'postId': postId,
      'collection': 'Peerposts',
      'message': "✅ Your post was approved by admin",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'approval',
      'isRead': false,
    });
       
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': null,
      'senderId': posterId,
      'senderName': posterName,
      'postId': postId,
      'collection': 'Peerposts/All/posts',
      'message': "📢 $posterName added a new post in Peer Assistance",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'new_post',
      'isRead': false,
    });
    
    Navigator.of(context, rootNavigator: true).pop();
    _showToast("Post approved");
    
    await FirebaseFirestore.instance
        .collection('peeradmin')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();
  }

  Future<void> _rejectPeerPost(DocumentSnapshot post) async {
    final postData = post.data() as Map<String, dynamic>;
    final postId = post.id;
    final posterId = postData['userId'] ?? '';
    final posterName = postData['userName'] ?? 'Someone';

    await FirebaseFirestore.instance
        .collection('peeradmin')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();
    
    final FCMService _fcmService = FCMService();

    await _fcmService.sendNotificationPostRejected(posterId, 'Peer Assistance');
    
    await FirebaseFirestore.instance.collection('notifications').add({
      'receiverId': posterId,
      'senderId': 'admin',
      'senderName': 'Admin',
      'postId': postId,
      'collection': 'Peerposts/All/posts',
      'message': "❌ Your post was rejected by admin",
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'rejection',
      'isRead': false,
    });
    
    _showToast("Post rejected");
  }

  Future<void> _deletePost(DocumentSnapshot post) async {
    final postId = post.id;
    await FirebaseFirestore.instance
        .collection('Peerposts')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post deleted successfully')),
    );
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

  Widget _buildPostCard(DocumentSnapshot post, {bool showApproveReject = false}) {
    final postData = post.data()! as Map<String, dynamic>;
    final username = postData['userName'] ?? 'Anonymous';
    final userId = postData['userId'] ?? '';
    final postContent = postData['postContent'] ?? '';
    final imageUrl = postData['imageUrl'] ?? '';
    final timestamp = postData['timestamp'] as Timestamp?;

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
                        onPressed: () => _deletePost(post),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

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
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) => const Text("Image load failed"),
                    ),
                  ),
                const SizedBox(height: 12),

                Text(
                  postContent,
                  style: const TextStyle(fontSize: 15),
                ),

                if (showApproveReject) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _rejectPeerPost(post),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _approvePeerPost(post),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Widget _buildPendingPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getPendingPostsStream(),
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
                Icon(
                  Icons.people_outline,
                  size: 70,
                  color: _primaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No peer posts to approve',
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

        final posts = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) => _buildPostCard(posts[index], showApproveReject: true),
        );
      },
    );
  }

  Widget _buildAllPostsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAllPostsStream(),
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
                Icon(
                  Icons.inbox,
                  size: 70,
                  color: _primaryColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No peer posts available',
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

        final posts = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) => _buildPostCard(posts[index], showApproveReject: false),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
              Tab(text: 'All Posts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingPostsTab(),
            _buildAllPostsTab(),
          ],
        ),
      ),
    );
  }
}