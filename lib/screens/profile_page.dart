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
  TextEditingController bioController = TextEditingController();
  TextEditingController workController = TextEditingController();
  String? profileImageUrl;
  bool isEditing = false;
  String? selectedRole;
  String? selectedDepartment;
  bool isImageLoading = false;

  final List<String> departments = [
    'Computer Science',
    'Software Engineering',
    'Mathematics',
    'BBA',
    'Electrical Engineering',
    'Media',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    user = _auth.currentUser;

    if (user != null) {
      try {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(user!.uid).get();

        if (userDoc.exists) {
          // Get data safely with null checks
          final data = userDoc.data() as Map<String, dynamic>?;
          if (data == null) return;

          String? roleFromDB = data['role'] as String?;

          if (mounted) {
            setState(() {
              // Safely access fields with null checks
              usernameController.text = data['username'] as String? ?? '';
              // Only try to access 'bio' if it exists in the document
              bioController.text =
                  data.containsKey('bio') ? (data['bio'] as String? ?? '') : '';
              // Only try to access 'work' if it exists in the document
              workController.text = data.containsKey('work')
                  ? (data['work'] as String? ?? '')
                  : '';
              // Safely access profileImage
              profileImageUrl = data['profileImage'] as String?;

              // Set the department dropdown
              String? deptFromDB = data['department'] as String?;
              selectedDepartment =
                  departments.contains(deptFromDB) ? deptFromDB : null;

              List<String> validRoles = ['Student', 'Alumni'];
              selectedRole =
                  validRoles.contains(roleFromDB) ? roleFromDB : null;
            });
          }
        }
      } catch (e) {
        print('Error fetching user data: $e');
        // Show error in UI if needed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading profile: ${e.toString()}")),
          );
        }
      }
    }
  }

  Future<void> _updateUsername() async {
    if (user != null) {
      await _firestore.collection('users').doc(user!.uid).update({
        'username': usernameController.text,
        'role': selectedRole,
        'bio': bioController.text,
        'work': workController.text,
        'department': selectedDepartment,
        'profilePicture': profileImageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      setState(() {
        isEditing = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        isImageLoading = true;
        profileImageUrl = null;
      });

      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null) {
          Uint8List? fileBytes = result.files.first.bytes;
          String fileName = result.files.first.name;

          if (fileBytes != null) {
            String? imageUrl =
                await _uploadImageToCloudinaryWeb(fileBytes, fileName);

            if (imageUrl != null) {
              await _updateFirestoreProfileImage(imageUrl);
              setState(() {
                profileImageUrl = imageUrl;
              });
            }
          }
        }
      } else {
        final ImagePicker picker = ImagePicker();
        final XFile? pickedFile =
            await picker.pickImage(source: ImageSource.gallery);

        if (pickedFile != null) {
          File imageFile = File(pickedFile.path);
          String? imageUrl = await _uploadImageToCloudinaryMobile(imageFile);

          if (imageUrl != null) {
            await _updateFirestoreProfileImage(imageUrl);
            setState(() {
              profileImageUrl = imageUrl;
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
        isImageLoading = false;
      });
    }
  }

  Future<void> _updateFirestoreProfileImage(String imageUrl) async {
    setState(() {
      isImageLoading = true;
    });

    await _firestore.collection('users').doc(user!.uid).update({
      'profileImage': imageUrl,
    });

    _fetchUserData();

    setState(() {
      profileImageUrl = imageUrl;
      isImageLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile image updated!")),
    );
  }

  Future<String?> _uploadImageToCloudinaryMobile(File imageFile) async {
    return _uploadImageToCloudinary(imageFile.readAsBytesSync());
  }

  Future<String?> _uploadImageToCloudinaryWeb(
      Uint8List fileBytes, String fileName) async {
    return _uploadImageToCloudinary(fileBytes);
  }

  Future<String?> _uploadImageToCloudinary(Uint8List fileBytes) async {
    const String cloudinaryUrl =
        "https://api.cloudinary.com/v1_1/dgyktklti/image/upload";
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
        backgroundColor: Colors.white, // Set app bar background to white
        title: const Text("Edit Profile",
            style:
                TextStyle(color: Colors.black)), // Add text color for contrast
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Colors.black), // Add icon color for contrast
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
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          profileImageUrl != null && !isImageLoading
                              ? NetworkImage(profileImageUrl!)
                              : null,
                      child: isImageLoading
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.blue),
                            )
                          : profileImageUrl == null
                              ? const Icon(Icons.person,
                                  size: 60, color: Colors.white)
                              : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.blue),
                      onPressed: _pickImage,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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

                // Role Dropdown - Fixed to avoid pink screen
                Theme(
                  data: Theme.of(context).copyWith(
                    // This removes the pink overlay
                    canvasColor: Colors.white,
                  ),
                  child: DropdownButtonFormField<String>(
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
                      DropdownMenuItem(
                          value: 'Student', child: Text('Student')),
                      DropdownMenuItem(value: 'Alumni', child: Text('Alumni')),
                    ],
                    onChanged: isEditing
                        ? (value) {
                            setState(() {
                              selectedRole = value;
                            });
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 20),

                Theme(
                  data: Theme.of(context).copyWith(
                    canvasColor: Colors.white,
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedDepartment,
                    decoration: InputDecoration(
                      labelText: 'Select Your Department',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 20.0),
                    ),
                    items: departments.map((String department) {
                      return DropdownMenuItem<String>(
                        value: department,
                        child: Text(department),
                      );
                    }).toList(),
                    onChanged: isEditing
                        ? (value) {
                            setState(() {
                              selectedDepartment = value;
                            });
                          }
                        : null,
                  ),
                ),
                const SizedBox(height: 20),

                // Bio Field
                TextField(
                  controller: bioController,
                  enabled: isEditing,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell us about yourself...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                ),
                const SizedBox(height: 20),

                // Work/Experience Field
                TextField(
                  controller: workController,
                  enabled: isEditing,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Work/Experience',
                    hintText: 'Share your work experience...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                ),
                const SizedBox(height: 20),

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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
