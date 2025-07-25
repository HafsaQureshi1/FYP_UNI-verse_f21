import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_1/services/fcm-service.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'profileimage.dart';
import 'image_viewer_screen.dart';
import '../screens/user_profile_view.dart'; // Make sure this import is correct
import '../screens/surveyResponseScreen.dart'; // Import the survey response screen
import '../screens/SurveyResultsScreen.dart'; // Add this import for the results screen

class PostCard extends StatefulWidget {
  final String postId;
  final String userId;
  final String username;
  final String content;
  final int likes;
  final String collectionName;
  final String? imageUrl;
  final String? url;

  const PostCard({
    Key? key,
    required this.postId,
    required this.userId,
    required this.username,
    required this.content,
    required this.likes,
    required this.collectionName,
    this.imageUrl,
    this.url,
  }) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  Map<String, dynamic>? _postLocation;
  String _locationAddress = '';
  bool _isFetchingLocation = false;
  String postTime = "";
  int likeCount = 0;
  bool isLiked = false;
  String? currentUserId;
  String? profileImageUrl;
  String currentUsername = '';
  String? imageUrl;
  int responseCount = 0;
  bool hasActualForm = false; // Keep track of survey form

  // Show user profile in a popup dialog
  void _showUserProfile(BuildContext context) {
    UserProfileView.showProfileDialog(context, widget.userId);
  }

  bool isOwner = false;
  int commentCount = 0;
  bool _isLoading = true;
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
    likeCount = widget.likes;
    isOwner = currentUserId == widget.userId;

    // Check if this is a survey form post at initialization
    if (widget.collectionName.contains("Surveyposts")) {
      FirebaseFirestore.instance
          .collection(_getCollectionPath())
          .doc(widget.postId)
          .get()
          .then((doc) {
        if (doc.exists && mounted) {
          final data = doc.data()!;
          setState(() {
            // Only set hasActualForm to true if it has questions array and isSurveyForm flag
            hasActualForm = data['isSurveyForm'] == true &&
                data['questions'] != null &&
                (data['questions'] as List).isNotEmpty;
          });
        }
      });
    }

    _initializeData();
  }

  Future<void> _launchURL(String url, BuildContext context) async {
    try {
      Uri uri;

      // Ensure the URL has a scheme
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        uri = Uri.parse('https://$url');
      } else {
        uri = Uri.parse(url);
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _initializeData() async {
    try {
      await Future.wait([
        _fetchUsername(),
        _fetchProfileImage(),
        _fetchPostTime(),
        _checkIfUserLiked(),
        _fetchImageUrl(),
        _fetchCommentCount(),
        _fetchLocation(),
        _fetchSurveyResponseCount(), // Add this line to fetch response count
      ] as Iterable<Future>);
    } catch (e) {
      print("Error initializing post data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add this new method to fetch survey response count
  Future<void> _fetchSurveyResponseCount() async {
    if (!widget.collectionName.contains("Surveyposts")) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_getCollectionPath())
          .doc(widget.postId)
          .collection('responses')
          .count()
          .get();

      if (mounted) {
        setState(() {
          responseCount = snapshot.count ?? 0;
        });
      }
    } catch (e) {
      print("Error fetching survey response count: $e");
    }
  }

  // Add this new method to navigate to the survey results screen
  void _viewSurveyResults(BuildContext context) {
    if (widget.collectionName.contains("Surveyposts")) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SurveyResultsScreen(
            surveyId: widget.postId,
            collectionPath: _getCollectionPath(),
          ),
        ),
      );
    }
  }

  Future<void> _fetchLocation() async {
    if (_isFetchingLocation) return;

    setState(() => _isFetchingLocation = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection(_getCollectionPath())
          .doc(widget.postId)
          .get();

      if (doc.exists) {
        final locationData = doc.data()?['location'];
        if (locationData != null) {
          setState(() {
            _postLocation = Map<String, dynamic>.from(locationData);
            _locationAddress = locationData['address'] ?? 'Location available';
          });
        }
      }
    } catch (e) {
      print('Error fetching location: $e');
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _resetState();
      _initializeData();
    }
  }

  void _resetState() {
    setState(() {
      _isLoading = true;
      likeCount = widget.likes;
      isLiked = false;
      commentCount = 0;
      profileImageUrl = null;
      currentUsername = '';
      postTime = "";
      imageUrl = null;
    });

    // Cancel all previous subscriptions
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Map<String, List<String>> categoryKeywords = {
    "Electronics": [
      "phone",
      "laptop",
      "charger",
      "headphones",
      "camera",
      "tablet",
      "tv",
      "watch",
      "smartphone",
      "speaker",
      "earbuds",
      "keyboard",
      "mouse",
      "monitor",
      "power bank",
      "wireless"
    ],
    "Clothes & Bags": [
      "shirt",
      "pants",
      "jacket",
      "bag",
      "dress",
      "shoes",
      "coat",
      "jeans",
      "t-shirt",
      "sweater",
      "scarf",
      "suit",
      "hat",
      "gloves",
      "skirt",
      "shorts",
      "sweatshirt"
    ],
    "Official Documents": [
      "Student id ",
      "Student id card",
      "ID",
      "passport",
      "certificate",
      "degree",
      "license",
      "document",
      "visa",
      "contract",
      "papers",
      "birth certificate",
      "government ID",
      "application form"
    ],
    "Wallets & Keys": [
      "wallet",
      "keys",
      "purse",
      "credit card",
      "keychain",
      "car keys",
      "house keys",
      "money",
      "coin",
      "billfold",
      "ID card",
      "coins"
    ],
    "Books": [
      "book",
      "novel",
      "textbook",
      "journal",
      "literature",
      "e-book",
      "comics",
      "story",
      "guide",
      "manual",
      "magazine",
      "paperback",
      "hardcover",
      "dictionary",
      "encyclopedia"
    ],
    "Stationery & Supplies": [
      "pen",
      "notebook",
      "marker",
      "sticky notes",
      "eraser",
      "pencil",
      "ruler",
      "stapler",
      "highlighter",
      "paper clips",
      "folder",
      "calculator",
      "scissors",
      "glue",
      "tape",
      "post-it",
      "whiteboard"
    ],
    "Miscellaneous": [
      "found",
      "misc",
      "random",
      "lost",
      "other",
      "unique",
      "special",
      "unidentified",
      "unknown",
      "something",
      "anything"
    ]
  };

// Step 2: Create a Function to Manually Categorize the Post
  String _manualCategorizePost(String postText) {
    postText = postText
        .toLowerCase(); // Convert to lowercase to make the check case-insensitive

    // Check each category for relevant keywords
    for (var category in categoryKeywords.keys) {
      for (var keyword in categoryKeywords[category]!) {
        if (postText.contains(keyword.toLowerCase())) {
          return category; // Return the category if a keyword is found
        }
      }
    }

    return "Miscellaneous"; // If no match, return Miscellaneous
  }

  Future<String> _classifyPostWithHuggingFace(String postText) async {
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

      // Check the response status code
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Print the entire response to debug
        print("Response Data: $responseData");

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

          if (bestConfidence < 0.3) {
            return _manualCategorizePost(postText);
          }

          return bestCategory;
        }
      } else {
        // If response code is not 200, print the error details
        print("Error: Received non-200 response code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Hugging Face API Exception: $e");
    }

    return "Miscellaneous";
  }

  final Map<String, List<String>> keywordMap = {
    "Computer Science": [
      "programming",
      "code",
      "coding",
      "flutter",
      "java",
      "python",
      "c++",
      "software",
      "android",
      "ios",
      "web",
      "database",
      "sql",
      "nosql",
      "API",
      "frontend",
      "backend",
      "AI",
      "ML",
      "artificial intelligence",
      "machine learning",
      "data science",
      "devops",
      "cloud",
      "firebase",
      "github",
      "react",
      "angular",
      "docker"
    ],
    "Electrical Engineering": [
      "circuit",
      "voltage",
      "current",
      "resistor",
      "capacitor",
      "inductor",
      "oscilloscope",
      "power",
      "transformer",
      "electricity",
      "watt",
      "ampere",
      "signal",
      "microcontroller",
      "arduino",
      "embedded",
      "analog",
      "digital",
      "transistor",
      "diode",
      "sensor",
      "relay"
    ],
    "Education & Physical Education": [
      "teaching",
      "teacher",
      "student",
      "lecture",
      "class",
      "education",
      "learning",
      "study",
      "assignment",
      "course",
      "school",
      "university",
      "PE",
      "sports",
      "exercise",
      "training",
      "coaching",
      "fitness",
      "health",
      "activity",
      "tournament",
      "competition",
      "curriculum"
    ],
    "Business": [
      "business",
      "startup",
      "entrepreneur",
      "finance",
      "marketing",
      "sales",
      "customer",
      "strategy",
      "investment",
      "money",
      "profit",
      "loss",
      "budget",
      "HR",
      "human resources",
      "management",
      "economy",
      "commerce",
      "pitch",
      "project",
      "advertising",
      "brand"
    ],
    "Mathematics": [
      "algebra",
      "calculus",
      "geometry",
      "statistics",
      "math",
      "mathematics",
      "equation",
      "function",
      "integral",
      "derivative",
      "vector",
      "matrix",
      "probability",
      "graph",
      "set theory",
      "number",
      "trigonometry",
      "logarithm",
      "theorem",
      "prime",
      "formula"
    ],
    "Media": [
      "media",
      "journalism",
      "news",
      "anchor",
      "editor",
      "editing",
      "film",
      "movie",
      "cinema",
      "photography",
      "camera",
      "shot",
      "clip",
      "video",
      "recording",
      "script",
      "broadcast",
      "radio",
      "tv",
      "advertisement",
      "press",
      "social media",
      "influencer",
      "interview"
    ]
  };
  Future<String> _handleLowConfidence(String postText) async {
    final lowerText = postText.toLowerCase();

    for (var entry in keywordMap.entries) {
      for (var keyword in entry.value) {
        if (lowerText.contains(keyword.toLowerCase())) {
          print(
              "Manually Keyword match found: '${keyword}' → Category: ${entry.key}");
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
      "Content-Type": "application/json; charset=UTF-8" // Correct content-type
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

          if (bestConfidence < 0.3) {
            return await _handleLowConfidence(postText);
          }

          return bestCategory;
        }
      } else {
        print("Error: Received non-200 response code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e) {
      print("Hugging Face API Exception: $e");
    }

    return "Miscellaneous";
  }

  void _fetchUsername() {
    final sub = FirebaseFirestore.instance
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
    _subscriptions.add(sub);
  }

  void _fetchProfileImage() {
    final sub = FirebaseFirestore.instance
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
    _subscriptions.add(sub);
  }

  void _fetchImageUrl() {
    final sub = FirebaseFirestore.instance
        .collection(_getCollectionPath())
        .doc(widget.postId)
        .snapshots()
        .listen((postDoc) {
      if (postDoc.exists && mounted) {
        setState(() {
          imageUrl = postDoc.data()?['imageUrl'];
        });
      }
    });
    _subscriptions.add(sub);
  }

  Future<void> _fetchPostTime() async {
    final postDoc = await FirebaseFirestore.instance
        .collection(_getCollectionPath())
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

  void _checkIfUserLiked() {
    if (currentUserId == null) return;

    final sub = FirebaseFirestore.instance
        .collection(_getCollectionPath())
        .doc(widget.postId)
        .snapshots()
        .listen((postDoc) {
      if (postDoc.exists && mounted) {
        final likedBy = List.from(postDoc.data()?['likedBy'] ?? []);
        setState(() {
          isLiked = likedBy.contains(currentUserId);
          likeCount = postDoc.data()?['likes'] ?? 0;
        });
      }
    });
    _subscriptions.add(sub);
  }

  void _toggleLike() async {
    if (currentUserId == null) return;

    final postRef = FirebaseFirestore.instance
        .collection(_getCollectionPath())
        .doc(widget.postId);

    final postDoc = await postRef.get();
    List<dynamic> likedBy = List.from(postDoc.data()?['likedBy'] ?? []);

    bool currentlyLiked = likedBy.contains(currentUserId);

    setState(() {
      isLiked = !currentlyLiked;
      likeCount = isLiked ? likeCount + 1 : likeCount - 1;
    });

    await postRef.update({
      'likes': FieldValue.increment(isLiked ? 1 : -1),
      'likedBy': isLiked
          ? FieldValue.arrayUnion([currentUserId])
          : FieldValue.arrayRemove([currentUserId])
    });

    if (isLiked) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      final String likerName = userDoc.data()?['username'] ?? 'Someone';
      final postAuthorId = postDoc.data()?['userId'] ?? '';

      if (postAuthorId != currentUserId) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': postAuthorId,
          'senderId': currentUserId,
          'senderName': likerName,
          'postId': widget.postId,
          'collection': widget.collectionName,
          'message': "$likerName ",
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'like',
          'isRead': false,
        });

        await FCMService().sendNotificationToUser(
            postAuthorId, likerName, "liked your post!");
      }
    }
  }

  String _getCollectionPath() {
    if (widget.collectionName.contains("lostfoundposts")) {
      return "lostfoundposts/All/posts";
    } else if (widget.collectionName.contains("Peerposts")) {
      return "Peerposts/All/posts";
    } else if (widget.collectionName.contains("Eventposts")) {
      return "Eventposts/All/posts";
    } else if (widget.collectionName.contains("Surveyposts")) {
      return "Surveyposts/All/posts";
    } else {
      throw Exception("Invalid collection name: ${widget.collectionName}");
    }
  }

  void _deletePost() async {
    if (!isOwner) return;

    try {
      final collectionPath = _getCollectionPath();
      final postRef = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(widget.postId);

      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissal by tapping outside
        builder: (BuildContext dialogContext) {
          // Use a separate dialogContext
          return AlertDialog(
            title: const Text('Delete Post'),
            content: const Text(
                'Are you sure you want to delete this post? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  // Show progress indicator while deleting
                  Navigator.pop(
                      dialogContext); // First dismiss the confirmation dialog

                  // Show loading indicator (optional)
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deleting post...')));

                  try {
                    await postRef.delete();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Post deleted successfully')),
                      );
                    }
                  } catch (e) {
                    print("Error deleting post: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Failed to delete post: ${e.toString()}')),
                      );
                    }
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("Error showing delete dialog: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process: ${e.toString()}')),
        );
      }
    }
  }

  void _editPost() async {
    if (!isOwner) return;

    try {
      final postRef = FirebaseFirestore.instance
          .collection(_getCollectionPath())
          .doc(widget.postId);

      final postDoc = await postRef.get();
      if (!postDoc.exists) return;

      final postData = postDoc.data();
      final currentContent = postData?['postContent'] ?? widget.content;
      final currentCategory = postData?['category'] ?? 'Uncategorized';

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
                    String newCategory = currentCategory;

                    if (widget.collectionName.contains("lostfoundposts")) {
                      newCategory =
                          await _classifyPostWithHuggingFace(updatedContent);
                    } else if (widget.collectionName.contains("Peerposts")) {
                      newCategory =
                          await _classifyPeerAssistancePost(updatedContent);
                    }

                    await postRef.update({
                      'postContent': updatedContent,
                      'category': newCategory,
                      'editedAt': FieldValue.serverTimestamp(),
                    });

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Post updated successfully')),
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
      print("Error editing post: $e");
    }
  }

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

  void _fetchCommentCount() {
    final sub = FirebaseFirestore.instance
        .collection(_getCollectionPath())
        .doc(widget.postId)
        .collection("comments")
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          commentCount = snapshot.size;
        });
      }
    }, onError: (error) {
      print("Error fetching comment count: $error");
    });
    _subscriptions.add(sub);
  }

  // Add this new method to handle survey form taps
  void _showSurveyForm(BuildContext context) {
    if (widget.collectionName.contains("Surveyposts")) {
      FirebaseFirestore.instance
          .collection(_getCollectionPath())
          .doc(widget.postId)
          .get()
          .then((doc) {
        if (doc.exists) {
          final data = doc.data()!;

          // Only show survey form if it's actually a form
          if (data['isSurveyForm'] == true &&
              data['questions'] != null &&
              (data['questions'] as List).isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SurveyResponseScreen(
                  surveyId: widget.postId,
                  collectionPath: _getCollectionPath(),
                ),
              ),
            );
          } else {
            // If it's just a URL post, show message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'This is an external survey. Please click the URL to access it.')),
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if this is a survey post
    bool isSurveyPost = widget.collectionName.contains("Surveyposts");

    return Column(
      children: [
        GestureDetector(
          // Only enable tap if it's a survey form and not the owner
          onTap: (isSurveyPost && hasActualForm && !isOwner)
              ? () => _showSurveyForm(context)
              : null,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
            elevation: 0.0, // Facebook cards have minimal elevation
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
              side: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1), // Facebook-like subtle border
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User details with options menu for owner
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // User info - make image and name clickable with popup
                          Expanded(
                            child: InkWell(
                              onTap: () => _showUserProfile(context),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => _showUserProfile(context),
                                    child: CircleAvatar(
                                      radius: 20.0,
                                      backgroundColor: Colors.grey[300],
                                      
                                      child: profileImageUrl == null
                                          ? const Icon(Icons.person, size: 20.0)
                                          : ClipOval(
                                              child: Image.network(
    '$profileImageUrl?${DateTime.now().millisecondsSinceEpoch}',
    key: ValueKey(profileImageUrl),
    fit: BoxFit.cover,
    width: 40.0,
    height: 40.0,
    errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: 20.0, color: Colors.grey[600]),
  ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 15.0),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _showUserProfile(context),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            currentUsername,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(postTime,
                                              style: const TextStyle(
                                                  fontSize: 12.0,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Options menu (only visible to post owner)
                          if (isOwner)
                            IconButton(
                              icon: const Icon(Icons
                                  .more_horiz), // More Facebook-like menu icon
                              onPressed: _showOptionsMenu,
                            ),
                        ],
                      ),

                      const SizedBox(height: 10.0),

                      // Post Content
                      Text(
                        widget.content,
                        style: const TextStyle(fontSize: 16.0),
                      ),

                      // Check for URL and display it if it's valid
                      if (widget.url != null &&
                          widget.url!.trim().isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: InkWell(
                            onTap: () =>
                                _launchURL(widget.url!.trim(), context),
                            child: Text(
                              widget.url!.trim(),
                              style: const TextStyle(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Image (if available)
                      if (imageUrl != null && imageUrl!.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImageViewerScreen(
                                  imageUrl: imageUrl!,
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
                                child: FadeInImage(
                                  image: NetworkImage(imageUrl!),
                                  placeholder: const AssetImage(
                                      'assets/images/placeholder.png'),
                                  fit: BoxFit.contain,
                                  imageErrorBuilder:
                                      (context, error, stackTrace) {
                                    print('Error loading image: $error');
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

                      // Location info (if available)
                      if (_postLocation != null && _locationAddress.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Location: $_locationAddress'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: 20, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _locationAddress,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Divider before like/comment buttons
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Divider(color: Colors.grey[300], height: 1),
                      ),

                      // Like and Comment Buttons - Facebook style
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
                                      ? Color.fromARGB(255, 0, 58, 92)
                                      : Colors.grey[700],
                                  padding: EdgeInsets.symmetric(
                                      vertical:
                                          5.0), // Reduced padding for buttons
                                  minimumSize: Size
                                      .zero, // Allow the button to be smaller
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
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor:
                                        Colors.white, // Ensure white background
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16.0)),
                                    ),
                                    builder: (context) => CommentSection(
                                      postId: widget.postId,
                                      collectionName: widget.collectionName,
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                  padding: EdgeInsets.symmetric(
                                      vertical:
                                          8.0), // Increased padding for buttons
                                  minimumSize: Size.zero,
                                ),
                                icon: Icon(
                                  Icons
                                      .forum_outlined, // A more modern discussion/comment icon
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

                      // If this is a survey post, show survey info
                      if (widget.collectionName.contains("Surveyposts")) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Survey indicator badge
                            Container(
                              margin: EdgeInsets.only(bottom: 4),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Color.fromARGB(255, 0, 58, 92)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assignment,
                                      size: 16,
                                      color: Color.fromARGB(255, 0, 58, 92)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Survey',
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 0, 58, 92),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // REMOVE the response count badge here
                            // (This was the orange badge with people icon)
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Survey buttons (Take Survey and View Results)
                // Only show if this is a survey form post with isSurveyForm=true
                if (widget.collectionName.contains("Surveyposts") &&
                    hasActualForm)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      child: Row(
                        children: [
                          // View results button - only visible to survey creator
                          if (isOwner)
                            ElevatedButton.icon(
                              icon: Icon(Icons.bar_chart,
                                  size: 16, color: Colors.white),
                              label: Text('Results'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromARGB(255, 0, 58, 92),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                textStyle: TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _viewSurveyResults(context),
                            ),
                          if (isOwner) SizedBox(width: 8),
                          // Take Survey button - only visible if not the owner
                          if (!isOwner)
                            ElevatedButton.icon(
                              icon: Icon(Icons.assignment_turned_in,
                                  size: 16, color: Colors.white),
                              label: Text('Take Survey'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromARGB(255, 0, 58, 92),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                textStyle: TextStyle(fontSize: 12),
                              ),
                              onPressed: () => _showSurveyForm(context),
                            ),
                        ],
                      ),
                    ),
                  ),
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

  const CommentSection(
      {super.key, required this.postId, required this.collectionName});

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
        .doc(widget.postId);

    try {
      final postDoc = await postRef.get();
      if (!postDoc.exists || postDoc.data() == null)
        return; // Check for non-existent or null data

      final String postAuthorId = postDoc.data()?['userId'] ?? '';

      // Add the comment to the post's 'comments' subcollection
      final commentRef = await postRef.collection('comments').add({
        'userId': _userId, // Current user's ID who is commenting
        'comment': commentText, // The text of the comment
        'timestamp':
            FieldValue.serverTimestamp(), // Automatically get the timestamp
      });

      // Clear the comment input controller
      _commentController.clear();

      // If the post author is not the current user, notify them
      if (postAuthorId.isNotEmpty && postAuthorId != _userId) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .get();
        final String currentUsername =
            userDoc.data()?['username'] ?? 'Unknown User';
        print("collection name in add comment $widget.collectionName");
        // Send notification to the post author
        _fcmService.sendNotificationOnComment(
          widget.postId,
          currentUsername,
          commentRef.id,
          widget.collectionName,
        );

        // Add a notification document in Firestore for the comment
        await FirebaseFirestore.instance.collection('notifications').add({
          'receiverId': postAuthorId,
          'senderId': _userId,
          'senderName': currentUsername,
          'postId': widget.postId, // Store the post ID
          'commentId': commentRef.id, // Store the comment ID
          'collection':
              widget.collectionName, // Store the dynamic collection name
          'message': "$currentUsername commented on your post", // The message
          'timestamp':
              FieldValue.serverTimestamp(), // Timestamp for the notification
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 12,
        left: 12,
        right: 12,
      ),
      height: 400,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text("Comments",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 40, color: Colors.grey[400]),
                        SizedBox(height: 12),
                        Text(
                          "No comments yet",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Be the first to comment!",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
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
                      formattedTime =
                          DateFormat('MMM d, yyyy • h:mm a').format(date);
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
                            usernameSnapshot.data!.get('username') ??
                                'Unknown User';

                        return ListTile(
                          leading:
                              ProfileAvatar(userId: commenterId, radius: 18),
                          title: Text(username,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formattedTime,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey)),
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
          Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                ProfileAvatar(userId: _userId ?? '', radius: 18),
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
                  icon: Icon(Icons.send_rounded, color: Color(0xFF1877F2)),
                  onPressed: () {
                    _addComment(_commentController.text);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
