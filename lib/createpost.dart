import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/LocationPicker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'profileimage.dart';
import 'categorize.dart';

class CreateNewPostScreen extends StatefulWidget {
  final String collectionName;

  const CreateNewPostScreen({super.key, required this.collectionName});

  @override
  _CreateNewPostScreenState createState() => _CreateNewPostScreenState();
}

class _CreateNewPostScreenState extends State<CreateNewPostScreen> {
  final TextEditingController _postController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isPosting = false;
  LatLng? _selectedLocation;
  String _selectedAddress = "No location selected";

  String _username = '';
  String? _userId;

  File? _imageFile;
  Uint8List? _webImage;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  String _ruleBasedClassification(String postText) {
    Map<String, List<String>> categoryKeywords = {
      "Stationery & Supplies": [
        "pen",
        "pencil",
        "geometry",
        "notebook",
        "calculator"
      ],
      "Electronics": ["laptop", "mobile", "charger", "headphones"],
      "Clothing & Accessories": ["bag", "jacket", "shoes", "watch"],
      "Documents": ["id card", "certificate", "passport", "paper"],
      "Books": ["book", "textbook", "novel", "magazine"],
    };

    postText = postText.toLowerCase(); // Convert to lowercase

    for (var entry in categoryKeywords.entries) {
      for (var keyword in entry.value) {
        if (postText.contains(keyword)) {
          return entry.key; // Assign category if a keyword is found
        }
      }
    }

    return "Miscellaneous"; // If no match is found
  }

  Future<void> _pickLocation() async {
    final LatLng? location = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LocationPicker()),
    );

    if (location != null) {
      setState(() {
        _selectedLocation = location;
        _updateAddress(location);
      });
    }
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

  Future<String> _classifyPostWithHuggingFace(String postText) async {
    print("🔹 Sending request to Hugging Face...");

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
          "Wallets & Keys ",
          "Books ",
          "Stationery & Supplies",
          "Miscellaneous"
        ],
        "hypothesis_template": "This item is related to {}."
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
          // Print labels and scores
          for (int i = 0; i < labels.length; i++) {
            print("🔹 ${labels[i]}: ${scores[i].toStringAsFixed(4)}");
          }

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

          print(
              "✅ Selected Category: $bestCategory (Confidence: ${bestConfidence.toStringAsFixed(4)})");

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

  Future<String> _classifyPeerAssistancePost(String postText) async {
    print("🔹 Sending request to Hugging Face for Peer Assistance...");

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
          "Programming languages & Software & AI & Machine learning & code  (Computer Science & Computer Systems)",
          "Electronics & Circuits (Electrical Engineering)",
          "Teaching Methods (Education & Physical Education)",
          "Business Strategy (Business Department)",
          "Statistics & Calculus (Mathematics)",
          "Journalism & Broadcasting (Media & Communication)",
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

        print("🔹 AI Response Labels: $labels");
        print("🔹 AI Response Scores: $scores");

        if (labels.isNotEmpty && scores.isNotEmpty) {
          // Find the best category excluding "Miscellaneous"
          String bestCategory = "Miscellaneous";
          double bestConfidence = 0.0;

          for (int i = 0; i < labels.length; i++) {
            print(
                "🔹 Checking: ${labels[i]} (Score: ${scores[i].toStringAsFixed(4)})");

            if (labels[i] != "Miscellaneous" && scores[i] > bestConfidence) {
              bestCategory = labels[i];
              bestConfidence = scores[i];
            }
          }

          if (bestConfidence < 0.2) {
            bestCategory = "Miscellaneous";
          }

          // 🔹 **Map AI Label to Original Chip Name**
          String mappedCategory =
              categoryMapping[bestCategory] ?? "Miscellaneous";

          print(
              "✅ Selected Category: $mappedCategory (Confidence: ${bestConfidence.toStringAsFixed(4)})");
          return mappedCategory;
        }
      } else {
        print("❌ AI Classification Failed. Response: ${response.body}");
      }
    } catch (e) {
      print("❌ Hugging Face API Exception: $e");
    }

    return "Miscellaneous"; // Default if API fails
  }

  Future<void> _createPost() async {
    print("Original widget.collectionName: ${widget.collectionName}");

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

        String? uploadedImageUrl;

        // Upload image if selected
        if (_imageFile != null || _webImage != null) {
          Uint8List imageBytes =
              kIsWeb ? _webImage! : await _imageFile!.readAsBytes();
          uploadedImageUrl = await _uploadImageToCloudinary(imageBytes);
        }

        // 🔹 **Determine Collection Path**
        String collectionPath;
        String category =
            "Uncategorized"; // Default category (for AI-categorized posts)

        if (widget.collectionName.startsWith("lostfoundposts")) {
          // 🔹 **AI Categorization for Lost & Found**
          print("🔹 Classifying post with AI...");
          category = await _classifyPostWithHuggingFace(postContent);
          print("✅ AI Categorized as: $category");
          collectionPath = "lostfoundposts/All/posts";
        } else if (widget.collectionName.startsWith("Peerposts")) {
          // 🔹 **AI Categorization for Peer Assistance**
          print("🔹 Classifying peer assistance post with AI...");
          category = await _classifyPeerAssistancePost(postContent);
          print("✅ AI Categorized as: $category");
          collectionPath = "Peerposts/All/posts";
        } else if (widget.collectionName.startsWith("Eventposts")) {
          collectionPath = "Eventposts/All/posts";
        } else if (widget.collectionName.startsWith("Surveyposts")) {
          collectionPath = "Surveyposts/All/posts";
        } else {
          print("❌ Invalid collection name: ${widget.collectionName}");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid collection name!')),
          );
          return;
        }

        // ✅ Firestore Reference
        final generalRef = _firestore.collection(collectionPath).doc();
        final postData = {
          'userId': user.uid,
          'userName': username,
          'userEmail': user.email,
          'likes': 0,
          'postContent': postContent,
          'imageUrl': uploadedImageUrl ?? '',
          'timestamp': FieldValue.serverTimestamp(),
          if (widget.collectionName.startsWith("lostfoundposts") ||
              widget.collectionName.startsWith("Peerposts"))
            "category": category, // ✅ Store category for AI-categorized posts
          "location": _selectedLocation != null
              ? {
                  "latitude": _selectedLocation!.latitude,
                  "longitude": _selectedLocation!.longitude,
                  "address": _selectedAddress,
                }
              : null,
        };

        print("🚀 Posting to: $collectionPath"); // Debugging path
        print("📝 Document ID: ${generalRef.id}"); // Debugging ID

        await generalRef.set(postData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted!')),
        );

        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in!')),
        );
      }
    } catch (e) {
      print("❌ Firestore Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  Future<void> _updateAddress(LatLng position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() {
          _selectedAddress = placemarks.first.street ?? "Unknown Address";
        });
      }
    } catch (e) {
      print("Error fetching address: $e");
    }
  }

  // Fetch current user information
  Future<void> _fetchUserInfo() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _userId = currentUser.uid;
      });

      try {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            _username = userDoc.data()?['username'] ?? 'User';
          });
        }
      } catch (e) {
        print('Error fetching user info: $e');
      }
    }
  }

  // Select image from gallery
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
        });
      } else {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    }
  }

  // Upload image to Cloudinary
  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes) async {
    const cloudinaryUrl =
        "https://api.cloudinary.com/v1_1/dgyktklti/image/upload";
    const uploadPreset = "Universe_upload";

    var request = http.MultipartRequest("POST", Uri.parse(cloudinaryUrl));
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes,
        filename: 'upload.jpg'));

    var response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final decodedData = jsonDecode(responseData);
      return decodedData['secure_url'];
    } else {
      return null;
    }
  }

  // Create and save post to Firestore
  // Get user-friendly post type label
  String _getPostTypeLabel(String collectionName) {
    // Extract the base collection name from the path
    if (collectionName.startsWith('lostfoundposts')) {
      return 'Lost & Found';
    } else if (collectionName.startsWith('Eventposts')) {
      return 'Events & Jobs';
    } else if (collectionName.startsWith('Peerposts')) {
      return 'Peer Assistance';
    } else if (collectionName.startsWith('Surveyposts')) {
      return 'Survey';
    } else {
      return 'Post';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    const themeColor = Color.fromARGB(255, 0, 58, 92);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and close button
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(25),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    'New ${_getPostTypeLabel(widget.collectionName)} Post',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Positioned(
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.withOpacity(0.1),
                      ),
                      child: const Icon(Icons.close,
                          size: 20, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey.withOpacity(0.1),
          ),

          // Content area
          Expanded(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User profile info
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade200, width: 1.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        // User avatar
                        _userId != null
                            ? ProfileAvatar(userId: _userId!, radius: 20)
                            : CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey[200],
                                child: const Icon(Icons.person,
                                    color: Colors.grey),
                              ),
                        const SizedBox(width: 12),

                        // Username and posting info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _username.isEmpty ? 'Loading...' : _username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Posting to ${_getPostTypeLabel(widget.collectionName)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Post text input
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TextField(
                      controller: _postController,
                      minLines: 2,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(
                        hintText: "Write your post here...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 8.0),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Image preview
                  if (_imageFile != null || _webImage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              constraints: BoxConstraints(
                                maxHeight: screenSize.height * 0.4,
                              ),
                              child: kIsWeb
                                  ? Image.memory(
                                      _webImage!,
                                      fit: BoxFit.contain,
                                    )
                                  : Image.file(
                                      _imageFile!,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                          // Remove image button
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 20),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setState(() {
                                    _imageFile = null;
                                    _webImage = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Divider(color: Colors.grey[200], height: 32),

                  // Add image button
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text("Add Image to your Post",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),

                  const SizedBox(height: 16), // Added spacing between buttons

                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text("Add Location",
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

// Display selected location
                  if (_selectedLocation != null)
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAddress,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Post button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isPosting ? null : _createPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
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
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  // Account for keyboard padding
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
