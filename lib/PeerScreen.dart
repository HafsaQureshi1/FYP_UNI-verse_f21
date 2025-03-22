import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'postcard.dart';
import 'createpost.dart';

class PeerAssistanceScreen extends StatelessWidget {
  // ✅ Update this to your actual Firestore collection name
  final String collectionName = "Peerposts/All/posts";


  const PeerAssistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print("Fetching posts from collection: $collectionName"); // ✅ Debugging

    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: Column(
        children: [
          const CategoryChips(), // ✅ Keeps category filtering
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(collectionName) // ✅ Updated collection name
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) {
              return CreateNewPostScreen(collectionName: collectionName); // ✅ Updated
            },
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start, // ✅ Ensures proper alignment
          children: const [
            CategoryChip(label: "General"),
            CategoryChip(label: "Electronics"),
            CategoryChip(label: "Books"),
          ],
        ),
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final String label;

  const CategoryChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Chip(
        label: Text(label),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.grey, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
