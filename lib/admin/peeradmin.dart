import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/fcm-service.dart';

class PeerAdmin extends StatefulWidget {
  const PeerAdmin({super.key});

  @override
  _PeerAdminState createState() => _PeerAdminState();
}

class _PeerAdminState extends State<PeerAdmin> {
  // Theme colors - match with Home.dart
  final Color _primaryColor = const Color.fromARGB(255, 0, 58, 92);
  final Color _backgroundColor = const Color.fromARGB(64, 236, 236, 236);

  Stream<QuerySnapshot> _getPeerPostsStream() {
    return FirebaseFirestore.instance
        .collection('peeradmin')
        .doc("All")
        .collection("posts")
        .where('approval', isEqualTo: null)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Map<String, String> categoryMapping = {
    "Programming languages & Software & AI & Machine learning & code  (Computer Science & Computer Systems)":
        "Computer Science & Computer Systems",
    "Electronics & Circuits (Electrical Engineering)": "Electrical Engineering",
    "Teaching Methods (Education & Physical Education)":
        "Education & Physical Education",
    "Business Strategy (Business Department)": "Business Department",
    "Statistics & Calculus (Mathematics)": "Mathematics",
    "Journalism & Broadcasting (Media & Communication)":
        "Media & Communication",
    "Miscellaneous": "Miscellaneous"
  };

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

  Future<String> _classifyPeerAssistancePost(String postText) async {
    final url = Uri.parse(
        "https://api-inference.huggingface.co/models/MoritzLaurer/deberta-v3-large-zeroshot-v1");
    final headers = {
      "Authorization": "Bearer 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",
      "Content-Type": "application/json"
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

  Future<void> _approvePeerPost(DocumentSnapshot post) async {
    final postData = post.data() as Map<String, dynamic>;
    final postId = post.id;
     final posterId = postData['userId'];
    final postContent = postData['postContent'] ?? '';
  final posterName = postData['userName'] ?? 'Someone'; // Ensure this exists in your postData
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
    };

    await FirebaseFirestore.instance
        .collection('Peerposts')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .set(approvedPostData);

    await FirebaseFirestore.instance
        .collection('peeradmin')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();
        final FCMService _fcmService = FCMService();

 await _fcmService.sendNotificationOnNewPost(
    posterId,
    posterName,
    'Peer assistance',
  );
  await _fcmService.sendNotificationPostApproved(posterId, 'Peer Assistance');

   await FirebaseFirestore.instance.collection('notifications').add({
    'receiverId': posterId, // ✅ correct user ID
    'senderId': 'admin',
    'senderName': 'Admin',
    'postId': postId,
    'collection': 'Peerposts',
    'message': "✅ Your post was approved by admin",
    'timestamp': FieldValue.serverTimestamp(),
    'type': 'approval',
    'isRead': false,
  });
   
    _showToast("Peer post approved");
 await FirebaseFirestore.instance.collection('notifications').add({
    'receiverId': null, // or leave blank/null if your UI handles public messages
    'senderId': posterId,
    'senderName': posterName,
    'postId': postId,
    'collection': 'Peerposts/All/posts',
    'message': "📢 $posterName added a new post in Peer Assistance",
    'timestamp': FieldValue.serverTimestamp(),
    'type': 'new_post',
    'isRead': false,
  });
     
  }

  Future<void> _rejectPeerPost(DocumentSnapshot post) async {
    final postData = post.data() as Map<String, dynamic>;
 
  final postContent = postData['postContent'] ?? '';
  final posterId = postData['userId'] ?? '';
  final posterName = postData['userName'] ?? 'Someone'; // Ensure this exists in your postData


    final postId = post.id;
    await FirebaseFirestore.instance
        .collection('peeradmin')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();

    _showToast("Peer post rejected");
    
final FCMService _fcmService = FCMService();

await _fcmService.sendNotificationPostRejected(posterId, 'Lost & Found');
    _showToast("Post rejected");
   await FirebaseFirestore.instance.collection('notifications').add({
    'receiverId': posterId, // ✅ correct user ID
    'senderId': 'admin',
    'senderName': 'Admin',
    'postId': postId,
    'collection': 'lostfoundposts/All/posts',
    'message': "✅ Your post was rejected by admin",
    'timestamp': FieldValue.serverTimestamp(),
    'type': 'approval',
    'isRead': false,
  });
  
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPeerPostsStream(),
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
                  Icon(Icons.people_outline,
                      size: 70, color: _primaryColor.withOpacity(0.5)),
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

          var posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              var postData = posts[index].data() as Map<String, dynamic>;
              String userId = postData['userId'] ?? '';
              String username = postData['userName'] ?? 'Anonymous';
              String title = postData['postContent'] ?? '';
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
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (profileImageUrl.isNotEmpty)
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage:
                                      NetworkImage(profileImageUrl),
                                )
                              else
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      _primaryColor.withOpacity(0.2),
                                  child:
                                      Icon(Icons.person, color: _primaryColor),
                                ),
                              const SizedBox(width: 10),
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
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
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
                                  return Center(
                                      child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        _primaryColor),
                                  ));
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: _primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // Center the buttons
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _rejectPeerPost(posts[index]),
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
                                onPressed: () => _approvePeerPost(posts[index]),
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
