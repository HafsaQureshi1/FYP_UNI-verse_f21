import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'postcard.dart';
import 'createpost.dart';
import 'Home.dart';
import 'screenui.dart'; // Import your chat screen widget

class PeerAssistanceScreen extends StatefulWidget {
  const PeerAssistanceScreen({super.key});

  @override
  _PeerAssistanceScreenState createState() => _PeerAssistanceScreenState();
}

class _PeerAssistanceScreenState extends State<PeerAssistanceScreen> {
  String selectedCategory = "All"; // Default category selection
  final ScrollController _scrollController = ScrollController();

  // ✅ Fetch posts based on category selection
  Stream<QuerySnapshot> _getPostsStream() {
    final collectionRef = FirebaseFirestore.instance.collection('Peerposts');

    if (selectedCategory == "All") {
      // If "All" is selected, fetch all posts from all categories
      return collectionRef
          .doc("All") // ✅ Fetch from "All" category
          .collection("posts")
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else {
      // Fetch posts only from the selected category
      return collectionRef
          .doc("All") // ✅ All posts are inside "All"
          .collection("posts")
          .where("category", isEqualTo: selectedCategory) // ✅ Filter by category field
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: Stack(
        children: [
          Column(
            children: [
              // ✅ Category Chips for Filtering
              CategoryChips(
                collectionName: 'Peerposts',
                onCategorySelected: (category) {
                  setState(() {
                    selectedCategory = category;
                  });
                },
              ),

              // ✅ Posts List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getPostsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No posts found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      );
                    }

                    var posts = snapshot.data!.docs;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                          collectionName: 'Peerposts',
                          imageUrl: postData['imageUrl'] ?? '',
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
                  isDismissible: true,
                  enableDrag: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return FractionallySizedBox(
                      heightFactor: 0.95, // 95% of screen height
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                        ),
                        child: CreateNewPostScreen(
                          collectionName: 'Peerposts/$selectedCategory/posts',
                        ),
                      ),
                    );
                  },
                );
              },
              child: const Icon(Icons.add, color: Colors.white), // Post creation icon
            ),
          ),
          // ✅ Chatbot Floating Action Button (above the post creation FAB)
          Positioned(
            bottom: 80.0, // Positioned above the post creation button
            right: 16.0,
            child: FloatingActionButton(
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
                          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                        ),
                        child: ChatScreen(), // Your chatbot screen
                      ),
                    );
                  },
                );
              },
              child: const Icon(Icons.chat, color: Colors.white), // Chatbot icon
            ),
          ),

          // ✅ Floating Action Button for Creating New Post
          
        ],
      ),
    );
  }
}
