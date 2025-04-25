
import 'package:flutter_application_1/screens/screenui.dart';
import 'package:flutter_application_1/components/search_results.dart';
import 'package:geolocator/geolocator.dart';
import '../components/postcard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_1/screens/Notificationscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'PeerScreen.dart';
import 'SurveyScreen.dart';
import 'EventScreen.dart';
import 'profile_page.dart';
import 'createpost.dart';
import '../main.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await GeolocatorPlatform.instance
      .checkPermission(); // Ensure Geolocator initializes properly
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
    EventsJobsScreen(),
    SurveysScreen(),
  ];
  // Add PageController to manage page swiping
  final PageController _pageController = PageController();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Animate to the selected page when bottom nav item is tapped
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  // Handle page changes from swipe gestures
  void _onPageChanged(int index) {
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
    await googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();

    // Navigate to the sign-in screen and remove all previous routes
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => SignInPage()), // replace with your sign-in screen
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
                    color: Color.fromARGB(255, 0, 58,
                        92), // Changed title color to match bottom nav bar blue
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
                      return Container();
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
          IconButton(
            onPressed: _signOut,
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
      // Replace the direct _screens[_selectedIndex] with PageView
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _screens,
        physics: const ClampingScrollPhysics(), // Smooth scrolling physics
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color.fromARGB(180, 255, 255, 255),
        backgroundColor: const Color.fromARGB(255, 0, 58, 92),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 0 ? Icons.home : Icons.home_outlined),
            label: "Lost/Found",
            backgroundColor: _selectedIndex == 0
                ? const Color.fromARGB(255, 0, 77, 122)
                : null,
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 1
                ? Icons.dashboard
                : Icons.dashboard_outlined),
            label: "Peer Assistance",
            backgroundColor: _selectedIndex == 1
                ? const Color.fromARGB(255, 0, 77, 122)
                : null,
          ),
          BottomNavigationBarItem(
            icon: Icon(_selectedIndex == 2
                ? Icons.document_scanner
                : Icons.document_scanner_outlined),
            label: "Events/Jobs",
            backgroundColor: _selectedIndex == 2
                ? const Color.fromARGB(255, 0, 77, 122)
                : null,
          ),
          BottomNavigationBarItem(
            icon:
                Icon(_selectedIndex == 3 ? Icons.person : Icons.person_outline),
            label: "Surveys",
            backgroundColor: _selectedIndex == 3
                ? const Color.fromARGB(255, 0, 77, 122)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose(); // Dispose the page controller
    super.dispose();
  }
}

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  _LostFoundScreenState createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  Stream<QuerySnapshot> _getPostsStream() {
    final collectionRef =
        FirebaseFirestore.instance.collection('lostfoundposts');

    if (selectedCategory == "All") {
      return collectionRef
          .doc("All")
          .collection("posts")
          .orderBy('timestamp', descending: true)
          .snapshots();
    } else {
      return collectionRef
          .doc("All")
          .collection("posts")
          .where("category", isEqualTo: selectedCategory)
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  String selectedCategory = "All";

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
                collectionName: 'lostfoundposts',
                onCategorySelected: (category) {
                  setState(() {
                    selectedCategory = category;
                  });
                },
              ),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        var postData =
                            posts[index].data() as Map<String, dynamic>;
                        String? url = postData['url'];
                        url = url ?? '';
                        return PostCard(
                          key: ValueKey(posts[index].id),
                          username: postData['userName'] ?? 'Anonymous',
                          content: postData['postContent'] ?? '',
                          postId: posts[index].id,
                          likes: postData['likes'] ?? 0,
                          userId: postData['userId'],
                          collectionName: 'lostfoundposts',
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
                FloatingActionButton(
                  heroTag: "chatbotFab",
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
                          initialChildSize:
                              0.7, // Changed from 0.6 to 0.7 (70% of screen height)
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
                SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: "postFab",
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
                                  'lostfoundposts/$selectedCategory/posts',
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
  String selectedCategory = "All";

  List<String> getCategories() {
    if (widget.collectionName == "lostfoundposts") {
      return [
        "All",
        "Electronics",
        "Clothes & Bags",
        "Official Documents",
        "Books",
        "Stationery & Supplies",
        "Wallets & Keys",
        "Miscellaneous"
      ];
    } else if (widget.collectionName == "Peerposts") {
      return [
        "All",
        "Computer Science",
        "Education ",
        "Business",
        "Electrical Engineering",
        "Mathematics",
        "Media",
        "Miscellaneous"
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    List<String> categories = getCategories();

    return categories.isEmpty
        ? const SizedBox.shrink()
        : Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: const Color.fromARGB(5, 0, 0, 0), // Very subtle background
              border: Border(
                bottom: BorderSide(
                  color: Colors.black.withOpacity(0.05),
                  width: 0.5,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: categories.map((category) {
                  final isSelected = selectedCategory == category;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: FilterChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: const Color.fromARGB(255, 0, 58, 92),
                      backgroundColor: Colors.white,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isSelected
                              ? Colors.transparent
                              : Colors.grey.withOpacity(0.3),
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          selectedCategory = category;
                        });
                        widget.onCategorySelected(category);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          );
  }
}
