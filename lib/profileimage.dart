import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileAvatar extends StatefulWidget {
  final String userId;
  final double radius;

  const ProfileAvatar({
    Key? key,
    required this.userId,
    this.radius = 30,
  }) : super(key: key);

  @override
  _ProfileAvatarState createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? _imageUrl;
  bool _isLoading = true;
  static final Map<String, String> _cachedProfileImages = {}; // Cache to prevent redundant network calls

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
  }

  Future<void> _fetchProfileImage() async {
    if (_cachedProfileImages.containsKey(widget.userId)) {
      setState(() {
        _imageUrl = _cachedProfileImages[widget.userId];
        _isLoading = false;
      });
      return;
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists && userDoc['profileImage'] != null) {
        _imageUrl = userDoc['profileImage'] as String;
        _cachedProfileImages[widget.userId] = _imageUrl!; // Cache the image URL
      }
    } catch (e) {
      print("Error fetching profile image: $e");
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.grey[300],
      backgroundImage: _imageUrl != null ? NetworkImage(_imageUrl!) : null,
      child: _isLoading
          ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            )
          : _imageUrl == null
              ? const Icon(Icons.person, size: 30, color: Colors.white)
              : null,
    );
  }
}
