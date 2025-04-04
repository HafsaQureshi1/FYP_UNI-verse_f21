import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/fcm-service.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'profileimage.dart';
import 'image_viewer_screen.dart';

class PostCard extends StatefulWidget {
  
  final String postId;
  final String userId;
  final String username;
  final String content;
  final int likes;
  final String collectionName;
  final String? imageUrl;

  const PostCard({ 
    Key? key, // Add this
    required this.postId,
    required this.userId,
    required this.username,
    required this.content,
    required this.likes,
    required this.collectionName,
    this.imageUrl,
  });

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  String postTime = "";
  int likeCount = 0;
  bool isLiked = false;
  String? currentUserId;
  String? profileImageUrl;
  String currentUsername = '';
  String? imageUrl;
  // Check if the post belongs to the current user
  bool isOwner = false;
  int commentCount = 0; // Add comment count variable

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    likeCount = widget.likes;
    // Set isOwner by comparing post's userId with currentUserId
    isOwner = currentUserId == widget.userId;

    _fetchUsername();
    _fetchProfileImage();
    _fetchPostTime();
    _checkIfUserLiked();
    _fetchImageUrl();
    _fetchCommentCount(); // Add method call to fetch comment count
  }
Future<String> _classifyPostWithHuggingFace(String postText) async {
  print("🔹 Sending request to Hugging Face...");

  final url = Uri.parse("https://api-inference.huggingface.co/models/facebook/bart-large-mnli");
  final headers = {
    "Authorization": "Bearer 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",  
    "Content-Type": "application/json"
  };

  final body = jsonEncode({
  "inputs": postText,  // ✅ Corrected: "inputs" instead of "sequence"
  "parameters": {
    "candidate_labels": [  // ✅ Moved inside "parameters"
     "Electronics",
      "Clothes & Bags",
      "Official Documents",
      "Books ",
         "Wallets & Keys "
        "Stationery & Supplies",
      "Miscellaneous"
    ]
  }
});


  try {
    final response = await http.post(url, headers: headers, body: body);

    print("🔹 API Response Status Code: ${response.statusCode}");
    print("🔹 API Response Body: ${response.body}");

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      print("🔹 Parsed JSON: $responseData");  // Print JSON to debug

      List<dynamic> labels = responseData["labels"];
      List<dynamic> scores = responseData["scores"];

      if (labels.isNotEmpty && scores.isNotEmpty) {
        String bestCategory = labels[0];  // Get highest confidence category
        double confidence = scores[0];

        print("✅ AI Category: $bestCategory (Confidence: ${confidence.toStringAsFixed(2)})");
        return confidence > 0.3 ? bestCategory : "Miscellaneous";  // Confidence threshold
      }
    } else {
      print("❌ AI Classification Failed. Response: ${response.body}");
    }
  } catch (e) {
    print("❌ Hugging Face API Exception: $e");
  }
  return "Miscellaneous";  // Default if API fails
  }

Map<String, String> categoryMapping = {
  "Programming & Software & AI & Machine learning (Computer Science & Computer Systems)": "Computer Science & Computer Systems",
  "Electronics & Circuits (Electrical Engineering)": "Electrical Engineering",
  "Teaching Methods (Education & Physical Education)": "Education & Physical Education",
  "Business Strategy (Business Department)": "Business Department",
  "Statistics & Calculus (Mathematics)": "Mathematics",
  "Journalism & Broadcasting (Media & Communication)": "Media & Communication",
  "Miscellaneous": "Miscellaneous"
};
Future<String> _classifyPeerAssistancePost(String postText) async {
  print("🔹 Sending request to Hugging Face for Peer Assistance...");

  final url = Uri.parse("https://api-inference.huggingface.co/models/facebook/bart-large-mnli");
  final headers = {
    "Authorization": "Bearer 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",
    "Content-Type": "application/json"
  };

  final body = jsonEncode({
    "inputs": postText,
    "parameters": {
      "candidate_labels": [
         "Computer Science",
          "Electrical Engineering)",
          "Education & Physical Education)",
          "Business ",
          "Mathematics",
          "Media ",
          "Miscellaneous"
      ],
      "hypothesis_template": "This post is related to {}."
    }
  });

  try {
    final response = await http.post(url, headers: headers, body: body);
    print("🔹 API Response Status Code: ${response.statusCode}");

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      List<dynamic> labels = responseData["labels"];
      List<dynamic> scores = responseData["scores"];

      if (labels.isNotEmpty && scores.isNotEmpty) {
        // Find the best category excluding "Miscellaneous"
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

        // 🔹 **Map AI Label to Original Chip Name**
       
        print("✅ Selected Category: $bestCategory (Confidence: ${bestConfidence.toStringAsFixed(4)})");
        return bestCategory;
      }
    } else {
      print("❌ AI Classification Failed. Response: ${response.body}");
    }
  } catch (e) {
    print("❌ Hugging Face API Exception: $e");
  }

  return "Miscellaneous"; // Default if API fails
}



  /// ✅ Fetches user details dynamically
  void _fetchUsername() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        setState(() {
          currentUsername = userDoc.data()?['username'] ?? 'Unknown User';
        });
      }
    });
  }

  void _fetchProfileImage() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        setState(() {
          profileImageUrl = userDoc.data()?['profilePicture'];
        });
      }
    });
  }
void _fetchImageUrl() async {
  String collectionPath = _getCollectionPath();
  String postId = widget.postId;

  
  final postRef = FirebaseFirestore.instance.collection(collectionPath).doc(postId);
  
  final postDoc = await postRef.get();

  if (!postDoc.exists) {
   
    return; // Stop execution if the document does not exist
  }

  
  // Listen for updates
  postRef.snapshots().listen((postDoc) {
    if (postDoc.exists && mounted) {
      setState(() {
        imageUrl = postDoc.data()?['imageUrl'];
      });
    }
  });
}
Future<void> _fetchPostTime() async {
  String collectionPath = _getCollectionPath();

  final postDoc = await FirebaseFirestore.instance
      .collection(collectionPath)
      .doc(widget.postId)
      .get();

  if (postDoc.exists) {
    final Timestamp? timestamp = postDoc.data()?['timestamp'];
    if (timestamp != null && mounted) {
      final DateTime date = timestamp.toDate();
      final String formattedDate =
          "${date.day} ${_getMonthName(date.month)} ${_formatTime(date)}";
      setState(() {
        postTime = formattedDate;
      });
    }
  }
}

String _getMonthName(int month) {
  const monthNames = [
    "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];
  return monthNames[month];
}

String _formatTime(DateTime date) {
  int hour = date.hour;
  int minute = date.minute;
  String period = hour >= 12 ? "PM" : "AM";
  hour = hour > 12 ? hour - 12 : hour == 0 ? 12 : hour;
  return "$hour:${minute.toString().padLeft(2, '0')} $period";

}Future<void> _checkIfUserLiked() async {
  if (currentUserId == null) return;

  String collectionPath = _getCollectionPath();
  final postRef = FirebaseFirestore.instance.collection(collectionPath).doc(widget.postId);

  postRef.snapshots().listen((postDoc) {
    if (postDoc.exists && mounted) {
      setState(() {
        isLiked = postDoc.data()?['likes'] != null && postDoc.data()?['likes'] > 0;
        likeCount = postDoc.data()?['likes'] ?? 0;
      });
    }
  }, onError: (error) {
    print("Error fetching like status: $error");
  });
}


void _toggleLike() async {
  if (currentUserId == null) return;

  String collectionPath = _getCollectionPath();
  final postRef = FirebaseFirestore.instance.collection(collectionPath).doc(widget.postId);

  final postDoc = await postRef.get();
  List<dynamic> likedBy = List.from(postDoc.data()?['likedBy'] ?? []);

  bool currentlyLiked = likedBy.contains(currentUserId);

  setState(() {
    isLiked = !currentlyLiked;
    likeCount = isLiked ? likeCount + 1 : likeCount - 1;
  });

  await postRef.update({
    'likes': FieldValue.increment(isLiked ? 1 : -1),
    'likedBy': isLiked ? FieldValue.arrayUnion([currentUserId]) : FieldValue.arrayRemove([currentUserId])
  });

  if (isLiked) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get()
        .then((userDoc) async {
      final String likerName = userDoc.data()?['username'] ?? 'Someone';

      final postAuthorId = postDoc.data()?['userId'] ?? '';
      if (postAuthorId == currentUserId) return; // Prevent self-notification

      // Save notification to Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': postAuthorId,
        'senderId': currentUserId,
        'senderName': likerName,
        'postId': widget.postId,
        'collection': widget.collectionName,
        'message': "$likerName liked your post",
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'like',
        'isRead': false,
      });

      // Send push notification via FCM
      await FCMService().sendNotificationToUser(
        postAuthorId,
        likerName,
        "liked your post!"
      );
    });
  }
}



// 🔹 **Helper Function to Get Correct Collection Path**
  String _getCollectionPath() {
    if (widget.collectionName.startsWith("lostfoundposts")) {
      return "lostfoundposts/All/posts";
    } else if (widget.collectionName.startsWith("Peerposts")) {
      return "Peerposts/All/posts";
    } else if (widget.collectionName.startsWith("Eventposts")) {
      return "Eventposts";
    } else if (widget.collectionName.startsWith("Surveyposts")) {
      return "Surveyposts";
    } else {
      print("❌ Invalid collection name: ${widget.collectionName}");
      throw Exception("Invalid collection name: ${widget.collectionName}");
    }
  }
void _deletePost() async {
  if (!isOwner) return;

  try {
    String category = "All";
    DocumentSnapshot? postDoc;

    // **Handle surveys and events separately since they don't have subcategories**
    if (widget.collectionName == "Surveyposts/All/posts" || widget.collectionName == "Eventposts/All/posts") {
      print("collection name: ${widget.collectionName}");
      // Log the full path to verify correctness
      print("Looking for post at path: ${widget.collectionName}/All/posts/${widget.postId}");
      
      // Check directly in the collection under All/posts
      postDoc = await FirebaseFirestore.instance
          .collection(widget.collectionName.split('/')[0])  // Get the main collection, e.g. "Surveyposts"
          .doc("All")  // "All" document
          .collection("posts")  // Subcollection "posts"
          .doc(widget.postId)  // Document ID of the post
          .get();
    } else {
      // Handle Lost & Found and Peer Assistance which have subcategories
      bool hasSubcategories = widget.collectionName == "lostfoundposts" || widget.collectionName == "Peerposts";
      print("collection name: ${widget.collectionName}");

      // Check in "All/posts"
      postDoc = await FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc("All")
          .collection("posts")
          .doc(widget.postId)
          .get();

      // Check in subcategories if applicable
      if (!postDoc.exists && hasSubcategories) {
        QuerySnapshot categories = await FirebaseFirestore.instance
            .collection(widget.collectionName)
            .get();

        for (var doc in categories.docs) {
          if (doc.id == "All") continue;

          DocumentSnapshot subPost = await FirebaseFirestore.instance
              .collection(widget.collectionName)
              .doc(doc.id)
              .collection("posts")
              .doc(widget.postId)
              .get();

          if (subPost.exists) {
            category = doc.id;
            postDoc = subPost;
            break;
          }
        }
      }
    }

    if (postDoc == null || !postDoc.exists) {
      print("❌ Post not found in any collection!");
      print("Checking post at path: ${widget.collectionName} .${widget.postId}");
      return;
    }

    // Show delete confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                // **Delete from main collection for surveys and events**
                await FirebaseFirestore.instance
                    .collection(widget.collectionName.split('/')[0])  // Get the main collection, e.g. "Surveyposts"
                    .doc("All")
                    .collection("posts")
                    .doc(widget.postId)
                    .delete();

                // **Delete from AI-categorized subcollection (only for lost n found & peer posts)**
                if (widget.collectionName == "lostfoundposts" || widget.collectionName == "Peerposts") {
                  if (category != "All") {
                    await FirebaseFirestore.instance
                        .collection(widget.collectionName)
                        .doc(category)
                        .collection("posts")
                        .doc(widget.postId)
                        .delete();
                  }
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post deleted successfully')),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    print("❌ Error deleting post: $e");
  }
}
void _editPost() async {
  if (!isOwner) return;

  try {
    // Check if the collection has subcollections like "All/posts" (lostfound, peer)
    String collectionPath = widget.collectionName;
    bool isSubcollectionRequired = widget.collectionName == 'lostfoundposts' || widget.collectionName == 'Peerposts';

    final postRef = isSubcollectionRequired
        ? FirebaseFirestore.instance
            .collection(widget.collectionName) // Main collection (e.g., 'lostfoundposts')
            .doc("All")  // 'All' document
            .collection("posts")  // 'posts' subcollection
            .doc(widget.postId) // The post ID
        : FirebaseFirestore.instance
            .collection(widget.collectionName) // Direct collection (e.g., 'surveys', 'events')
            .doc(widget.postId);  // The post ID

    final postDoc = await postRef.get();

    if (!postDoc.exists) {
      print("❌ Post not found at path: $collectionPath/${widget.postId}");
      return;
    }

    final Map<String, dynamic>? postData = postDoc.data();

    if (postData == null) return;

    final currentContent = postData['postContent'] ?? '';
    final currentCategory = postData['category'] ?? 'Uncategorized';

    final TextEditingController contentController =
        TextEditingController(text: currentContent);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: TextField(
            controller: contentController,
            decoration: const InputDecoration(
              hintText: "Update your post content...",
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedContent = contentController.text.trim();
                if (updatedContent.isNotEmpty) {
                  // 🔥 AI Re-Categorization Based on Collection Name
                  String newCategory = currentCategory;

                  if (widget.collectionName == "lostfoundposts") {
                    print("🔹 Reclassifying Lost & Found Post...");
                    newCategory = await _classifyPostWithHuggingFace(updatedContent);
                    print("✅ AI Categorized as: $newCategory");
                  } else if (widget.collectionName == "Peerposts") {
                    print("🔹 Reclassifying Peer Assistance Post...");
                    newCategory = await _classifyPeerAssistancePost(updatedContent);
                    print("✅ AI Categorized as: $newCategory");
                  }

                  // ✅ Update post in Firestore
                  await postRef.update({
                    'postContent': updatedContent,
                    'category': newCategory, // AI updated category
                    'editedAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post updated successfully')),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  } catch (e) {
    print("❌ Error editing post: $e");
  }
}



  // ✅ Show Options Menu
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(context);
                  _editPost();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Post',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deletePost();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

Future<void> _fetchCommentCount() async {
  String collectionPath = widget.collectionName;

  // If "All/posts" is already in the collection name, don't append it again
  if (!collectionPath.contains("/All/posts")) {
    collectionPath = "$collectionPath/All/posts";
  }

  print("Fetching comments from: $collectionPath/${widget.postId}/comments");

  FirebaseFirestore.instance
      .collection(collectionPath)
      .doc(widget.postId)
      .collection("comments")
      .snapshots()
      .listen((snapshot) {
    if (mounted) {
      setState(() {
        commentCount = snapshot.docs.length;
      });
    }
  }, onError: (error) {
    print("Error fetching comment count: $error");
  });
}


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.only(bottom: 15.0),
          elevation: 1.0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User details with options menu for owner
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // User info
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20.0,
                            backgroundColor: Colors.grey[300],
                            child: profileImageUrl == null
                                ? const CircularProgressIndicator()
                                : ClipOval(
                                    child: Image.network(
                                      profileImageUrl!,
                                      fit: BoxFit.cover,
                                      width: 40.0,
                                      height: 40.0,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                              Icons.person,
                                              size: 20.0,
                                              color: Colors.grey[600]),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 15.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentUsername,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(postTime,
                                    style: const TextStyle(
                                        fontSize: 12.0, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ Options menu (only visible to post owner)
                    if (isOwner)
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: _showOptionsMenu,
                      ),
                  ],
                ),

                const SizedBox(height: 10.0),

                // Post Content
                Text(widget.content, style: const TextStyle(fontSize: 16.0)),

                // Image (if available)
                if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageViewerScreen(
                            imageUrl: widget.imageUrl!,
                            heroTag: "post_image_${widget.postId}",
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 8.0),
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        maxHeight: 250,
                      ),
                      child: Hero(
                        tag: "post_image_${widget.postId}",
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.contain,
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
                                  child: Icon(
                                    Icons.error_outline,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                // Like and Comment Buttons
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _toggleLike,
                        icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: Colors.red),
                        label: Text(likeCount == 0
                            ? 'Like'
                            : likeCount == 1
                                ? '1 Like'
                                : '$likeCount Likes'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => CommentSection(
                              postId: widget.postId,
                              collectionName: widget.collectionName,
                            ),
                          );
                        },
                        icon: const Icon(Icons.comment, color: Colors.blue),
                        label: Text(commentCount == 0
                            ? 'Comment'
                            : commentCount == 1
                                ? '1 Comment'
                                : '$commentCount Comments'),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CommentSection extends StatefulWidget {
  final String postId;
  final String collectionName; // Generalized collection name

  const CommentSection({super.key, required this.postId, required this.collectionName});

  @override
  _CommentSectionState createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final TextEditingController _commentController = TextEditingController();
  final FCMService _fcmService = FCMService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserId();
  }

  void _fetchUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid;
      });
    }
  }

  void _addComment(String commentText) async {
  if (commentText.trim().isEmpty || _userId == null) return;

  // Get the collection path dynamically based on the current post's collection
  String collectionPath = _getCollectionPath();

  // Reference to the specific post document
  final postRef = FirebaseFirestore.instance
      .collection(collectionPath)
      .doc(widget.postId); // Ensure widget.postId is the correct identifier

  try {
    final postDoc = await postRef.get();
    if (!postDoc.exists) return; // If the post doesn't exist, exit

    final String postAuthorId = postDoc.data()?['userId'] ?? ''; // Get the post author's ID

    // Add the comment to the post's 'comments' subcollection
    final commentRef = await postRef.collection('comments').add({
      'userId': _userId, // Current user's ID who is commenting
      'comment': commentText, // The text of the comment
      'timestamp': FieldValue.serverTimestamp(), // Automatically get the timestamp
    });

    // Clear the comment input controller
    _commentController.clear();

    // If the post author is not the current user, notify them
    if (postAuthorId.isNotEmpty && postAuthorId != _userId) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .get();
      final String currentUsername = userDoc.data()?['username'] ?? 'Unknown User';

      // Call the function to send notification to the post author
      _fcmService.sendNotificationOnComment(
        widget.postId, 
        currentUsername, 
        commentRef.id, 
        widget.collectionName, // Dynamically pass the collection name
      );

      // Add a notification document in Firestore for the comment
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': postAuthorId,
        'senderId': _userId,
        'senderName': currentUsername,
        'postId': widget.postId, // Store the post ID
        'commentId': commentRef.id, // Store the comment ID
        'collection': widget.collectionName, // Store the dynamic collection name
        'message': "$currentUsername commented on your post", // The message
        'timestamp': FieldValue.serverTimestamp(), // Timestamp for the notification
        'type': 'comment', // Type of notification
        'isRead': false, // Initially, the notification is unread
      });
    }
  } catch (e) {
    print("Error adding comment: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: 400,
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection(_getCollectionPath())
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
                      String commenterId = comment['userId'];
                      Timestamp? timestamp = comment['timestamp'];
                      String formattedTime = "Just now";

                      if (timestamp != null) {
                        DateTime date = timestamp.toDate();
                        formattedTime = DateFormat('MMM d, yyyy • h:mm a').format(date);
                      }

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(commenterId).snapshots(),
                        builder: (context, usernameSnapshot) {
                          if (!usernameSnapshot.hasData || !usernameSnapshot.data!.exists) {
                            return const SizedBox();
                          }
                          String username = usernameSnapshot.data!.get('username') ?? 'Unknown User';
                          return ListTile(
                            leading: ProfileAvatar(userId: commenterId, radius: 18),
                            title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            ),
            Row(
              children: [
                ProfileAvatar(userId: _userId ?? '', radius: 18),
                const SizedBox(width: 10),
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

  // 🔹 **Helper Function to Get Correct Collection Path**
 String _getCollectionPath() {
  print("🔍 Checking collection for: ${widget.collectionName}");
    if (widget.collectionName.startsWith("lostfoundposts")) {
      return "lostfoundposts/All/posts";
    } else if (widget.collectionName.startsWith("Peerposts")) {
      return "Peerposts/All/posts";
    } else if (widget.collectionName.startsWith("Eventposts")) {
      return "Eventposts/All/posts";
    } else if (widget.collectionName.startsWith("Surveyposts")) {
      return "Surveyposts/All/posts";
    } else {
      print("❌ Invalid collection name: ${widget.collectionName}");
      throw Exception("Invalid collection name: ${widget.collectionName}");
    }
  }
}
