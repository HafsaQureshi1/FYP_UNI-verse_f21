import 'dart:convert';
import 'package:flutter_application_1/profile_page.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';
import 'peeradmin.dart';
import 'eventadmin.dart';
import 'surveyadmin.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final List<Widget> _adminScreens = [
    const LostFoundAdmin(), // Existing admin approval screen
    const PeerAdmin(), // New screen for user management
    const EventsAdmin(), // New screen for content moderation
    const SurveyAdmin(), // New screen for analytics
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '267004637492-iugmfvid1ca8prhuvkaflcbrtre7cibs.apps.googleusercontent.com',
      );
      await googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
      
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
    return AppBar(
      title: const Text(
        "Admin Dashboard",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF01214E), // Dark blue color
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfilePage()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
          onPressed: _signOut,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _adminScreens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        backgroundColor: const Color(0xFF01214E), // Matching app bar color
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.approval),
            label: "Lost found Post ",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: "Peer Post",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flag),
            label: "Events jobs",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: "surveys",
          ),
        ],
      ),
    );
  }
}class LostFoundAdmin extends StatefulWidget {
  const LostFoundAdmin({super.key});

  @override
  _LostFoundAdminState createState() => _LostFoundAdminState();
}

class _LostFoundAdminState extends State<LostFoundAdmin> {
  Stream<QuerySnapshot> _getPostsStream() {
    return FirebaseFirestore.instance
        .collection('lostfoundadmin')
        .doc("All")
        .collection("posts")
        .where('approval', isEqualTo: null)
        .orderBy('timestamp', descending: true)
        .snapshots();
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

  Future<String> _classifyPostWithHuggingFace(String postText) async {
    final url = Uri.parse(
        "https://api-inference.huggingface.co/models/facebook/bart-large-mnli");

    final headers = {
      "Authorization": "Bearer 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",
      "Content-Type": "application/json"
    };

    final body = jsonEncode({
      "inputs": postText,
      "parameters": {
        "candidate_labels": [
          "Electronics",
          "Clothes & Bags",
          "Official Documents",
          "Wallets & Keys",
          "Books",
          "Stationery & Supplies",
          "Miscellaneous"
        ],
        "hypothesis_template": "This item is related to {}."
      }
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        List<dynamic> labels = responseData["labels"];
        List<dynamic> scores = responseData["scores"];

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
            bestCategory = "Miscellaneous";
          }
          return bestCategory;
        }
      }
    } catch (e) {
      print("Hugging Face API Exception: $e");
    }
    return "Miscellaneous";
  }

  Future<void> _approvePost(DocumentSnapshot post) async {
    final postData = post.data() as Map<String, dynamic>;
    final postId = post.id;
    final postContent = postData['postContent'] ?? '';

    String category = "Uncategorized";
    try {
      category = await _classifyPostWithHuggingFace(postContent);
      print("AI classification : $category");
    } catch (e) {
      print("AI classification failed: $e");
    }

    final approvedPostData = {
      ...postData,
      'approval': 'approved',
      'category': category,
    };

    await FirebaseFirestore.instance
        .collection('lostfoundposts')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .set(approvedPostData);

    await FirebaseFirestore.instance
        .collection('lostfoundadmin')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();
  }

  Future<void> _rejectPost(DocumentSnapshot post) async {
    final postId = post.id;
    await FirebaseFirestore.instance
        .collection('lostfoundadmin')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();
  }

  final ScrollController _scrollController = ScrollController();

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No lost posts to approve',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          var posts = snapshot.data!.docs;

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              var postData = posts[index].data() as Map<String, dynamic>;
              String username = postData['userName'] ?? 'Anonymous';
              String userId = postData['userId'] ?? '';
              String postContent = postData['postContent'] ?? '';
              String imageUrl = postData['imageUrl'] ?? '';
              Timestamp? timestamp = postData['timestamp'];

              return FutureBuilder<String>(
                future: _getUserProfilePicture(userId),
                builder: (context, profileSnapshot) {
                  String profileImageUrl = profileSnapshot.data ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User info row with profile image
                          Row(
                            children: [
                              // Profile image
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: profileImageUrl.isNotEmpty
                                    ? NetworkImage(profileImageUrl)
                                    : const AssetImage('assets/default_profile.png') as ImageProvider,
                                backgroundColor: Colors.grey[200],
                              ),
                              const SizedBox(width: 12),
                              // Username and date column
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
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Post Image
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
                                  return const Center(
                                      child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Text("Image load failed"),
                              ),
                            ),
                          const SizedBox(height: 12),

                          // Post Content
                          Text(
                            postContent,
                            style: const TextStyle(fontSize: 15),
                          ),

                          const SizedBox(height: 16),

                          // Approve / Reject Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _approvePost(posts[index]),
                                icon: const Icon(Icons.check),
                                label: const Text("Approve"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _rejectPost(posts[index]),
                                icon: const Icon(Icons.close),
                                label: const Text("Reject"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}