import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profileimage.dart';

class UserProfileView extends StatefulWidget {
  final String userId;

  const UserProfileView({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileViewState createState() => _UserProfileViewState();

  /// Show a popup dialog with the user's profile
  static void showProfileDialog(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: UserProfileView(userId: userId),
        );
      },
    );
  }
}

class _UserProfileViewState extends State<UserProfileView> {
  bool _isLoading = true;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        color: Colors.white,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text('User not found'))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              // Profile Image
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: userData?['profileImage'] !=
                                        null
                                    ? NetworkImage(userData!['profileImage'])
                                    : null,
                                child: userData?['profileImage'] == null
                                    ? const Icon(Icons.person,
                                        size: 50, color: Colors.grey)
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Username
                              Text(
                                userData?['username'] ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // User details section
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Role & Department
                            _buildInfoItem(
                              Icons.school,
                              'Role',
                              userData?['role'] ?? 'Not specified',
                            ),
                            _buildInfoItem(
                              Icons.business,
                              'Department',
                              userData?['department'] ?? 'Not specified',
                            ),

                            const Divider(height: 30),

                            // Bio
                            if (userData?['bio'] != null &&
                                userData!['bio'].isNotEmpty)
                              _buildDetailSection('About', userData!['bio']),

                            const SizedBox(height: 10),

                            // Work Experience
                            if (userData?['work'] != null &&
                                userData!['work'].isNotEmpty)
                              _buildDetailSection(
                                  'Experience', userData!['work']),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue[700], size: 20),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
