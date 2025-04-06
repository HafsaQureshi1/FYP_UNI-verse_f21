import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PeerAdmin extends StatefulWidget {
  const PeerAdmin({super.key});

  @override
  _PeerAdminState createState() => _PeerAdminState();
}

class _PeerAdminState extends State<PeerAdmin> {
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

  Future<void> _approvePeerPost(DocumentSnapshot post) async {
    final postData = post.data() as Map<String, dynamic>;
    final postId = post.id;
    final postContent = postData['postContent'] ?? '';

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
  }

  Future<void> _rejectPeerPost(DocumentSnapshot post) async {
    final postId = post.id;
    await FirebaseFirestore.instance
        .collection('peeradmin')
        .doc("All")
        .collection("posts")
        .doc(postId)
        .delete();
  }

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
        stream: _getPeerPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No peer posts to approve',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                    elevation: 4,
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
                                  backgroundImage: NetworkImage(profileImageUrl),
                                )
                              else
                                const CircleAvatar(
                                  radius: 20,
                                  child: Icon(Icons.person),
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                      child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    const Text("Image load failed"),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _approvePeerPost(posts[index]),
                                icon: const Icon(Icons.check),
                                label: const Text("Approve"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _rejectPeerPost(posts[index]),
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