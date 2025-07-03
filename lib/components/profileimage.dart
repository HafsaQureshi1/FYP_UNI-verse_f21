import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileAvatar extends StatefulWidget {
  final String userId;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.userId,
    this.radius = 30,
  });

  @override
  _ProfileAvatarState createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? _imageUrl;
  static final Map<String, String> _cachedProfileImages = {}; // Cache for efficiency

  @override
  void initState() {
    super.initState();
    _listenToProfileImageUpdates(); // Real-time updates
  }

  /// ✅ Listens for real-time profile image changes
  void _listenToProfileImageUpdates() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.exists && mounted) {
        setState(() {
          _imageUrl = userDoc.data()?['profilePicture']; // Make sure this key matches your Firestore field
          if (_imageUrl != null) {
            _cachedProfileImages[widget.userId] = _imageUrl!; // Cache the image URL
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      key: ValueKey(_imageUrl), // Forces rebuild when image URL changes
      radius: widget.radius,
      backgroundColor: Colors.grey[300],
      backgroundImage: _imageUrl != null ? NetworkImage(_imageUrl!) : null,
      child: _imageUrl == null
          ? const Icon(Icons.person, size: 30, color: Colors.white)
          : null,
    );
  }
}
