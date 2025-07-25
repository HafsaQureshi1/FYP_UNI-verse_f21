import 'package:flutter/material.dart';
import '../components/postcard.dart';
import 'createpost.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screenui.dart'; // Import your chat screen widget

class EventsJobsScreen extends StatelessWidget {
  // Update this to your new Firestore collection path
  final String collectionName = "Eventposts/All/posts";

  const EventsJobsScreen({super.key});

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
              print('Post Data: ${posts[index].data()}');

              // Extract URL from post data (assuming it's stored in the 'url' field)
              String? url = postData['url']; // Fetch the URL for events
              // If URL is null, you can provide a default value, or you could handle it differently
              url = url ?? ''; // Use an empty string if URL is null
              return PostCard(
                key: ValueKey(posts[index].id),
                username: postData['userName'] ?? 'Anonymous',
                content: postData['postContent'] ?? '',
                postId: posts[index].id,
                likes: postData['likes'] ?? 0,
                userId: postData['userId'],
                collectionName: collectionName, // ✅ Pass new collection name
                imageUrl: postData['profilePicture'] ?? '',
                url: postData['url'], // Pass the event URL if available
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chatbot FAB
          FloatingActionButton(
            heroTag: "chatbotFabEvent",
            backgroundColor: const Color.fromARGB(255, 0, 58, 92),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                isDismissible: true,
                enableDrag: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  // Replace FractionallySizedBox with DraggableScrollableSheet
                  return DraggableScrollableSheet(
                    initialChildSize: 0.7, // 70% of screen height
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    builder: (_, controller) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(25)),
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
            heroTag: "postFabEvent",
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
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(25)),
                      ),
                      child:
                          CreateNewPostScreen(collectionName: collectionName),
                    ),
                  );
                },
              );
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
