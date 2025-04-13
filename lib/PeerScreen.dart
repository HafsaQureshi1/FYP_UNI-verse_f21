import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
          .where("category",
              isEqualTo: selectedCategory) // ✅ Filter by category field
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
              // Simple CategoryChips without animation
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
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      );
                    }

                    var posts = snapshot.data!.docs;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        var postData =
                            posts[index].data() as Map<String, dynamic>;
                        String? url =
                            postData['url']; // Fetch the URL for events
                        // If URL is null, you can provide a default value, or you could handle it differently
                        url = url ?? ''; // Use an empty string if URL is null
                        return PostCard(
                          key: ValueKey(posts[index].id),
                          username: postData['userName'] ?? 'Anonymous',
                          content: postData['postContent'] ?? '',
                          postId: posts[index].id,
                          likes: postData['likes'] ?? 0,
                          userId: postData['userId'],
                          collectionName: 'Peerposts',
                          imageUrl: postData['imageUrl'] ?? '',
                          url: url,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chatbot FAB
                FloatingActionButton(
                  heroTag: "chatbotFabPeer",
                  backgroundColor: const Color.fromARGB(255, 0, 58, 92),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      isDismissible: true,
                      enableDrag: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) {
                        return DraggableScrollableSheet(
                          initialChildSize: 0.7, // 70% of screen height
                          minChildSize: 0.5,
                          maxChildSize: 0.95,
                          builder: (_, controller) {
                            return Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(25)),
                              ),
                              child: ChatScreen(),
                            );
                          },
                        );
                      },
                    );
                  },
                  child: const Icon(Icons.smart_toy_rounded,
                      color: Colors.white), // Better chatbot icon
                ),
                SizedBox(height: 16), // Space between the FABs

                // Post creation FAB
                FloatingActionButton(
                  heroTag: "postFabPeer",
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
                          heightFactor: 0.95,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(25)),
                            ),
                            child: CreateNewPostScreen(
                              collectionName:
                                  'Peerposts/$selectedCategory/posts',
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
