import 'package:flutter/material.dart';
import 'postcard.dart';
import 'createpost.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventsJobsScreen extends StatelessWidget {
  // Update this to your new Firestore collection path
  final String collectionName = "Eventposts/All/posts";

  EventsJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(collectionName) // ✅ Updated collection path
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
                key: ValueKey(posts[index].id),
                username: postData['userName'] ?? 'Anonymous',
                content: postData['postContent'] ?? '',
                postId: posts[index].id,
                likes: postData['likes'] ?? 0,
                userId: postData['userId'],
                collectionName: collectionName, // ✅ Pass new collection name
                imageUrl: postData['imageUrl'] ?? '',
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
            isDismissible: true,
            enableDrag: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
              return FractionallySizedBox(
                heightFactor: 0.95, // 95% of screen height
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(25)),
                  ),
                  child: CreateNewPostScreen(collectionName: collectionName),
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
