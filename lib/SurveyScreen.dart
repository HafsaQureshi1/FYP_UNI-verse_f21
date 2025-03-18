import 'package:flutter/material.dart';
// For formatting timestamps
import 'postcard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'createpost.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class SurveysScreen extends StatelessWidget {
  const SurveysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Surveyposts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts found'));
          }

          var posts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              var postData = posts[index].data() as Map<String, dynamic>;

              return PostCard(
                key: ValueKey(posts[index].id), // ✅ Prevents UI flickering
                username: postData['userName'] ?? 'Anonymous',
                content: postData['postContent'] ?? '',
                postId: posts[index].id,
                likes: postData['likes'] ?? 0,
                userId: postData['userId'],
                imageUrl: postData['imageUrl'] ?? '',
                collectionName: 'Surveyposts',
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              return const CreateNewPostScreen(collectionName: 'Surveyposts');
            },
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
