import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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

  File? _imageFile;
  Uint8List? _webImage;
  String? _uploadedImageUrl;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

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

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes) async {
    const cloudinaryUrl = "https://api.cloudinary.com/v1_1/dgyktklti/image/upload";
    const uploadPreset = "Universe_upload";

    var request = http.MultipartRequest("POST", Uri.parse(cloudinaryUrl));
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: 'upload.jpg'));

    var response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final decodedData = jsonDecode(responseData);
      return decodedData['secure_url'];
    } else {
      return null;
    }
  }

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
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        String username = userDoc.exists ? userDoc['username'] : 'Anonymous';

        String? uploadedImageUrl;

        // If an image is selected, upload asynchronously
        if (_imageFile != null || _webImage != null) {
          Uint8List imageBytes = kIsWeb ? _webImage! : await _imageFile!.readAsBytes();
          uploadedImageUrl = await _uploadImageToCloudinary(imageBytes);
        }

        // Store post in Firestore
        await _firestore.collection(widget.collectionName).add({
          'userId': user.uid,
          'userName': username,
          'userEmail': user.email,
          'likes': 0,
          'postContent': postContent,
          'imageUrl': uploadedImageUrl ?? '',
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
      appBar: AppBar(
        backgroundColor: themeColor,
        title: const Text('Create Post', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _postController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Write your post...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            if (_imageFile != null || _webImage != null)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: kIsWeb
                    ? Image.memory(_webImage!, fit: BoxFit.cover)
                    : Image.file(_imageFile!, fit: BoxFit.cover),
              ),
            const SizedBox(height: 10),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text("Add Photo"),
                ),
                if (_imageFile != null || _webImage != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _imageFile = null;
                        _webImage = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isPosting ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: _isPosting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Post',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
