import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting timestamps
import 'postcard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'createpost.dart';
class SurveysScreen extends StatelessWidget {
  const SurveysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
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
                        var post = posts[index];
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('Surveyposts')
                              .doc(post.id)
                              .snapshots(),
                          builder: (context, postSnapshot) {
                            if (postSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }
                            if (!postSnapshot.hasData ||
                                !postSnapshot.data!.exists) {
                              return const SizedBox.shrink();
                            }
                            var postData = postSnapshot.data!;
                            return PostCard(
                              username: postData['userName'] ?? 'Anonymous',
                              content: postData['postContent'] ?? '',
                              postId: postData.id,
                              likes: postData['likes'] ?? 0,
                              userId: postData['userId'],
                               collectionName: 'Surveyposts',
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              backgroundColor: const Color.fromARGB(255, 0, 58, 92),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    return const CreateNewPostScreen(collectionName: 'Surveyposts',);
                  },
                );
              },
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
