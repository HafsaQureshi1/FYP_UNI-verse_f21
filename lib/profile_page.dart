import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? user;
  TextEditingController usernameController = TextEditingController();
  String? profileImageUrl;
  bool isEditing = false;
  String? selectedRole;
 bool isImageLoading = false;
  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

 Future<void> _fetchUserData() async {
  user = _auth.currentUser;

  if (user != null) {
    DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(user!.uid).get();

    if (userDoc.exists) {
      String? roleFromDB = userDoc['role'] ?? '';

      if (mounted) {  // Check if widget is still in the tree
        setState(() {
          usernameController.text = userDoc['username'] ?? '';
          profileImageUrl = userDoc['profileImage'];

          // Ensure the fetched role exists in the dropdown items
          List<String> validRoles = ['Student', 'Alumni'];
          selectedRole = validRoles.contains(roleFromDB) ? roleFromDB : null;
        });
      }
    }
  }
}


  Future<void> _updateUsername() async {
    if (user != null) {
      await _firestore.collection('users').doc(user!.uid).update({
        'username': usernameController.text,
        'role': selectedRole,
        'profilePicture': profileImageUrl, // Ensure this is not lost
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      setState(() {
        isEditing = false; // Reset editing mode after update
      });
    }
  }

 Future<void> _pickImage() async {
  try {
    setState(() {
      isImageLoading = true; // Start spinner immediately
      profileImageUrl = null; // Clear previous image to prevent flickering
    });

    if (kIsWeb) {
      // Web Image Picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        Uint8List? fileBytes = result.files.first.bytes;
        String fileName = result.files.first.name;

        if (fileBytes != null) {
          String? imageUrl = await _uploadImageToCloudinaryWeb(fileBytes, fileName);
          
          if (imageUrl != null) {
            await _updateFirestoreProfileImage(imageUrl);
            setState(() {
              profileImageUrl = imageUrl; // Update with new image
            });
          }
        }
      }
    } else {
      // Mobile Image Picker
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        String? imageUrl = await _uploadImageToCloudinaryMobile(imageFile);
        
        if (imageUrl != null) {
          await _updateFirestoreProfileImage(imageUrl);
          setState(() {
            profileImageUrl = imageUrl; // Update with new image
          });
        }
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: ${e.toString()}")),
    );
  } finally {
    setState(() {
      isImageLoading = false; // Stop spinner after process completes
    });
  }
}


  Future<void> _updateFirestoreProfileImage(String imageUrl) async {
    setState(() {
      isImageLoading = true; // Start loading
    });

    await _firestore.collection('users').doc(user!.uid).update({
      'profileImage': imageUrl,
    });

    _fetchUserData(); // Refresh data

    setState(() {
      profileImageUrl = imageUrl;
      isImageLoading = false; // Stop loading after update
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile image updated!")),
    );
  }
  // Fetch updated data to refresh the UI
 

  Future<String?> _uploadImageToCloudinaryMobile(File imageFile) async {
    return _uploadImageToCloudinary(imageFile.readAsBytesSync());
  }

  Future<String?> _uploadImageToCloudinaryWeb(Uint8List fileBytes, String fileName) async {
    return _uploadImageToCloudinary(fileBytes);
  }

  Future<String?> _uploadImageToCloudinary(Uint8List fileBytes) async {
    const String cloudinaryUrl = "https://api.cloudinary.com/v1_1/dgyktklti/image/upload";
    const String uploadPreset = "Universe_upload";

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['upload_preset'] = uploadPreset;
      request.fields['cloud_name'] = "dgyktklti";
      request.fields['folder'] = "profile_pictures";

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: "profile_picture.jpg",
        ),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = json.decode(responseData);
        return jsonResponse['secure_url'];
      } else {
        throw Exception("Failed to upload image: ${response.reasonPhrase}");
      }
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }

  @override
    Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Profile Image with Upload Button and Loading Indicator
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: profileImageUrl != null && !isImageLoading
                          ? NetworkImage(profileImageUrl!)
                          : null,
                      child: isImageLoading
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.blue),
                            )
                          : profileImageUrl == null
                              ? const Icon(Icons.person, size: 60, color: Colors.white)
                              : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.blue),
                      onPressed: _pickImage,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Username Field with Edit Option
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: usernameController,
                        enabled: isEditing,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16.0, horizontal: 20.0),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(isEditing ? Icons.check : Icons.edit),
                      onPressed: () {
                        if (isEditing) {
                          _updateUsername();
                        } else {
                          setState(() {
                            isEditing = true;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Email Field (Read-Only)
                TextField(
                  controller: TextEditingController(text: user?.email ?? ''),
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Your Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                ),
                const SizedBox(height: 20),

                // Role Dropdown (Editable)
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Select Your Role',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Student', child: Text('Student')),
                    DropdownMenuItem(value: 'Alumni', child: Text('Alumni')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedRole = value;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Update Profile Button
                ElevatedButton(
                  onPressed: _updateUsername,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    backgroundColor: const Color(0xFF01214E),
                  ),
                  child: const Text(
                    'Update Profile',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
