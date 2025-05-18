import 'package:flutter/material.dart';
import '../components/postcard.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'createpost.dart';
import 'screenui.dart';
import 'SurveyFormCreator.dart';

class SurveysScreen extends StatelessWidget {
  final String collectionName = "Surveyposts/All/posts";

  const SurveysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print("Fetching posts from collection: $collectionName");

    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: Stack(
        children: [
          Column(
            children: [
              // ✅ Posts List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
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
                        var postData =
                            posts[index].data() as Map<String, dynamic>;

                        return PostCard(
                          key: ValueKey(posts[index].id),
                          username: postData['userName'] ?? 'Anonymous',
                          content: postData['postContent'] ?? '',
                          postId: posts[index].id,
                          likes: postData['likes'] ?? 0,
                          userId: postData['userId'],
                          imageUrl: postData['imageUrl'] ?? '',
                          url: postData['url'] ?? '',
                          collectionName:
                              collectionName, // ✅ Pass new collection name
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Modified Floating Action Buttons
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Chatbot FAB
                FloatingActionButton(
                  heroTag: "chatbotFabSurvey",
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
                  child:
                      const Icon(Icons.smart_toy_rounded, color: Colors.white),
                ),
                SizedBox(height: 16), // Space between the FABs

                // Replace direct form creator with plus button showing options
                FloatingActionButton(
                  heroTag: "postFabSurvey",
                  backgroundColor: const Color.fromARGB(255, 0, 58, 92),
                  onPressed: () {
                    _showPostOptions(context);
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

  // New method to show post options
  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Create a survey",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 0, 58, 92).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.post_add,
                      color: Color.fromARGB(255, 0, 58, 92)),
                ),
                title: const Text("Create a simple post"),
                subtitle: const Text("Share a URL to an external survey"),
                onTap: () {
                  Navigator.pop(context);
                  _showCreatePost(context);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 0, 58, 92).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_add,
                      color: Color.fromARGB(255, 0, 58, 92)),
                ),
                title: const Text("Create a survey form"),
                subtitle: const Text("Design a custom survey with questions"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SurveyFormCreator(
                        collectionName: collectionName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to show createpost bottom sheet
  void _showCreatePost(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: CreateNewPostScreen(collectionName: collectionName),
      ),
    );
  }
}
