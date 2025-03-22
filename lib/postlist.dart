import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/Home.dart';
import 'package:flutter_application_1/postcard.dart';
class PostList extends StatefulWidget {
  final String collectionName; // Chooses which main collection to fetch from

  const PostList({super.key, required this.collectionName});

  @override
  _PostListState createState() => _PostListState();
}

class _PostListState extends State<PostList> {
  String selectedCategory = "All";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.collectionName == "lostfoundposts" ||
            widget.collectionName == "peerposts")
          CategoryChips(
            collectionName: widget.collectionName,
            onCategorySelected: (category) {
              setState(() {
                selectedCategory = category;
              });
            },
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getFilteredStream(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var posts = snapshot.data!.docs;

              if (posts.isEmpty) {
                return const Center(child: Text("No posts available"));
              }

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  var post = posts[index].data() as Map<String, dynamic>;

                  return PostCard(
                    postId: posts[index].id,
                    userId: post['userId'],
                    username: post['userName'],
                    content: post['postContent'],
                    likes: post['likes'] ?? 0,
                    collectionName: widget.collectionName,
                    imageUrl: post['imageUrl'],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// **Fetches posts from Firestore with category filtering**
 /// **Fetches posts from Firestore with category filtering**
Stream<QuerySnapshot> _getFilteredStream() {
  if ((widget.collectionName == "lostfoundposts" || widget.collectionName == "peerposts") &&
      selectedCategory == "All") {
    // 🔹 Fetch posts only from the "All" subcollection
    return FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc("All") // Fetch from the "All" subcollection
        .collection("posts")
        .orderBy('timestamp', descending: true)
        .snapshots();
  } else if (selectedCategory != "All") {
    // 🔹 Fetch only from the selected category's subcollection
    return FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(selectedCategory)
        .collection("posts")
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Default: return empty stream (should not reach here)
  return Stream.empty();
}


}

