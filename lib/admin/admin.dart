import 'dart:convert';
import 'package:flutter_application_1/screens/profile_page.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import 'peeradmin.dart';
import 'eventadmin.dart';
import 'surveyadmin.dart';
import '../services/fcm-service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final List<Widget> _adminScreens = [
    const LostFoundAdmin(),
    const PeerAdmin(),
    const EventsAdmin(),
    const SurveyAdmin(),
  ];

  // Theme colors - match with Home.dart
  final Color _primaryColor =
      const Color.fromARGB(255, 0, 58, 92); // Match Home.dart
  final Color _selectedColor = Colors.white;
  final Color _unselectedColor = const Color.fromARGB(180, 255, 255, 255);

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
      backgroundColor: _primaryColor,
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
        selectedItemColor: _selectedColor,
        unselectedItemColor: _unselectedColor,
        backgroundColor: _primaryColor,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 0 ? Icons.home : Icons.home_outlined),
            label: "Lost & Found",
            backgroundColor: _selectedIndex == 0
                ? const Color.fromARGB(255, 0, 77, 122)
                : null,
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 1
                ? Icons.dashboard
                : Icons.dashboard_outlined),
            label: "Peer Posts",
            backgroundColor: _selectedIndex == 1
                ? const Color.fromARGB(255, 0, 77, 122)
                : null,
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 2
                ? Icons.document_scanner
                : Icons.document_scanner_outlined),
            label: "Events/Jobs",
            backgroundColor: _selectedIndex == 2
                ? const Color.fromARGB(255, 0, 77, 122)
                : null,
          ),
          BottomNavigationBarItem(
            icon:
                Icon(_selectedIndex == 3 ? Icons.person : Icons.person_outline),
            label: "Surveys",
            backgroundColor: _selectedIndex == 3
                ? const Color.fromARGB(255, 0, 77, 122)
                : null,
          ),
        ],
      ),
    );
  }
}

class LostFoundAdmin extends StatefulWidget {
  const LostFoundAdmin({super.key});

  @override
  _LostFoundAdminState createState() => _LostFoundAdminState();
}

class _LostFoundAdminState extends State<LostFoundAdmin> {
  // Theme color to match with other admin screens
  final Color _primaryColor = const Color.fromARGB(255, 0, 58, 92);

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

Future<void> _approvePost(DocumentSnapshot post) async {
  final postData = post.data() as Map<String, dynamic>;
  final postId = post.id;
  final postContent = postData['postContent'] ?? '';
  final posterId = postData['userId'] ?? '';
  final posterName = postData['userName'] ?? 'Someone'; // Ensure this exists in your postData

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
final FCMService _fcmService = FCMService();

  // 🔔 Send notification to users
  await _fcmService.sendNotificationOnNewPost(
    posterId,
    posterName,
    'Lost & Found',
  );

  _showToast("Post approved");
   await FirebaseFirestore.instance.collection('notifications').add({
    'receiverId': posterId, // ✅ correct user ID
    'senderId': 'admin',
    'senderName': 'Admin',
    'postId': postId,
    'collection': 'lostfoundposts/All/posts',
    'message': "✅ Your post was approved by admin",
    'timestamp': FieldValue.serverTimestamp(),
    'type': 'approval',
    'isRead': false,
  });
   await FirebaseFirestore.instance.collection('notifications').add({
    'receiverId': null, // or leave blank/null if your UI handles public messages
    'senderId': posterId,
    'senderName': posterName,
    'postId': postId,
    'collection': 'lostfoundposts/All/posts',
    'message': "📢 $posterName added a new post in Lost & Found",
    'timestamp': FieldValue.serverTimestamp(),
    'type': 'new_post',
    'isRead': false,
  });
     

}


  Future<void> _rejectPost(DocumentSnapshot post) async {
    final postId = post.id;
    await FirebaseFirestore.instance
        .collection('lostfoundadmin')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();

    _showToast("Post rejected");
  }

  final ScrollController _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPostsStream(),
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
                    Icons.search_off_outlined,
                    size: 70,
                    color: _primaryColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No lost posts to approve',
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
                    color: Colors.white, // Set card background color to white
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
                                    : const AssetImage(
                                            'assets/default_profile.png')
                                        as ImageProvider,
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
                                loadingBuilder:
                                    (context, child, loadingProgress) {
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
                            mainAxisAlignment:
                                MainAxisAlignment.center, // Center the buttons
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _rejectPost(posts[index]),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () => _approvePost(posts[index]),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
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
