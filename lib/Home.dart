import 'package:flutter_application_1/search_results.dart';
import 'package:geolocator/geolocator.dart';

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
  await GeolocatorPlatform.instance.checkPermission();  // Ensure Geolocator initializes properly
 
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
    LostFoundScreen(),
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
class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  _LostFoundScreenState createState() => _LostFoundScreenState();
}
class  _LostFoundScreenState extends State<LostFoundScreen>{
   Stream<QuerySnapshot> _getPostsStream() {
  print("📢 Fetching posts for category: $selectedCategory");

  final collectionRef = FirebaseFirestore.instance.collection('lostfoundposts');

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

 final ScrollController _scrollController = ScrollController();
 String selectedCategory = "All"; // Default selection
  @override
   Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(64, 236, 236, 236),
      body: Stack(
        children: [
          Column(
            children: [
              // Category Chips for Filtering
              CategoryChips(
                collectionName: 'lostfoundposts',
                onCategorySelected: (category) {
                  setState(() {
                    selectedCategory = category;
                  });
                },
              ),

              // Posts List
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
                          collectionName: 'lostfoundposts',
                          imageUrl: postData['imageUrl'] ?? '',
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // Floating Action Button for Creating New Post
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
                          collectionName: 'lostfoundposts/$selectedCategory/posts',
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
class CategoryChips extends StatefulWidget {
  final String collectionName;
  final Function(String) onCategorySelected;

  const CategoryChips({
    super.key,
    required this.collectionName,
    required this.onCategorySelected,
  });

  @override
  _CategoryChipsState createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<CategoryChips> {
  String selectedCategory = "All"; // Default selection

  // Define categories based on the selected collection
  List<String> getCategories() {
    if (widget.collectionName == "lostfoundposts") {
      return ["All",    // ✅ Moved inside "parameters"
    "Electronics",
      "Documents",
      "Clothing & Accessories",
      "Personal Items",
      
      "Books & Stationery",
      "Miscellaneous"
    ];
    } else if (widget.collectionName == "peerposts") {
      return ["All", "Academics", "Career Advice", "Social Life"];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    List<String> categories = getCategories();

    return categories.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = category;
                      });
                      widget.onCategorySelected(category);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(category),
                        backgroundColor:
                            selectedCategory == category ? Colors.blue : Colors.white,
                        labelStyle: TextStyle(
                            color: selectedCategory == category ? Colors.white : Colors.black),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                              color: selectedCategory == category ? Colors.blue : Colors.grey,
                              width: 1.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          );
  }
}
