import 'package:flutter_application_1/search_results.dart';

import 'postcard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/Notificationscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';
import 'PeerScreen.dart';
import 'SurveyScreen.dart';
import 'EventScreen.dart';
import 'profile_page.dart';

import 'createpost.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.white, // Use this instead of primarySwatch
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<Widget> _screens = [
    const LostFoundScreen(),
    const PeerAssistanceScreen(),
    const EventsJobsScreen(),
    const SurveysScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            '267004637492-iugmfvid1ca8prhuvkaflcbrtre7cibs.apps.googleusercontent.com',
      );
      // Sign out from Google Sign-In
      await googleSignIn.signOut();

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();

      // Navigate to Sign In Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return PreferredSize(
      preferredSize: const Size.fromHeight(50.0),
      child: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: const InputDecoration(
                  hintText: 'Search posts...',
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchResultsScreen(query: value),
                      ),
                    );
                  }
                },
              )
            : const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text(
                  "UNI-verse",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
        titleSpacing: 0,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
              )
            : null,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (_isSearching) {
                  _searchFocusNode.requestFocus();
                }
              });
            },
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.black,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            constraints: const BoxConstraints(),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => NotificationScreen()));
                },
                icon: const Icon(Icons.notifications, color: Colors.black),
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                constraints: const BoxConstraints(),
              ),
              // Notification Badge Counter
              if (currentUserId != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('receiverId', isEqualTo: currentUserId)
                      .where('isRead', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int count = 0;
                    if (snapshot.hasData && snapshot.data != null) {
                      count = snapshot.data!.docs.length;
                    }
                    if (count == 0) {
                      return Container(); // No badge when no unread notifications
                    }

                    return Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfilePage(),
                ),
              );
            },
            icon: const Icon(Icons.person, color: Colors.black),
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            constraints: const BoxConstraints(),
          ),
          // Logout Button
          IconButton(
            onPressed: _signOut, // Call the sign-out function
            icon: const Icon(Icons.exit_to_app, color: Colors.black),
            padding: const EdgeInsets.only(left: 8.0, right: 16.0),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Lost/Found",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Peer Assistance",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner),
            label: "Events/Jobs",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Surveys",
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}

class LostFoundScreen extends StatelessWidget {
  const LostFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: Stack(
        children: [
          Column(
            children: [
              const CategoryChips(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('lostfoundposts')
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
                              .collection('lostfoundposts')
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
                            // Use safe access pattern for imageUrl
                            String? imageUrl;
                            try {
                              final data =
                                  postData.data() as Map<String, dynamic>?;
                              imageUrl = data?['imageUrl'] as String?;
                            } catch (e) {
                              // Handle error silently
                              print('Error accessing imageUrl: $e');
                            }

                            return PostCard(
                              username: postData['userName'] ?? 'Anonymous',
                              content: postData['postContent'] ?? '',
                              postId: postData.id,
                              likes: postData['likes'] ?? 0,
                              userId: postData['userId'],
                              collectionName: 'lostfoundposts',
                              imageUrl: imageUrl,
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
                  isDismissible: true,
                  enableDrag: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    return FractionallySizedBox(
                      heightFactor: 0.95, // Updated to 95% of screen height
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(25),
                          ),
                        ),
                        child: const CreateNewPostScreen(
                          collectionName: 'lostfoundposts',
                        ),
                      ),
                    );
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

class CategoryChips extends StatelessWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
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
