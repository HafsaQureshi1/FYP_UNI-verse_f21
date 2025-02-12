import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'main.dart';
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
        primarySwatch: Colors.blue,
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
    clientId: '267004637492-iugmfvid1ca8prhuvkaflcbrtre7cibs.apps.googleusercontent.com',
    
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50.0), // Adjust height if needed
        child: AppBar(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          elevation: 0,
          title: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0), // Add padding to the title
            child: Text(
              "UNI-verse",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9.0), // Add padding here
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search, color: Colors.black),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0), // Add padding here
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications, color: Colors.black),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9.0), // Add padding here
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.person, color: Colors.black),
              ),
            ),
            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9.0),
              child: IconButton(
                onPressed: _signOut, // Call the sign-out function
                icon: const Icon(Icons.exit_to_app, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
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
}

class LostFoundScreen extends StatelessWidget {
  const LostFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Divider(
  color: Colors.grey[300], // Set the color of the line
  thickness: 1, // Thickness of the line
),
            
            const CategoryChips(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: const [
                  PostCard(content: "Lost my phone in the cafeteria."),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          bottom: 16.0,
          right: 16.0,
          child: FloatingActionButton(
            onPressed: () {
              // Show the 'Create New Post' screen as a modal when the button is pressed
              showModalBottomSheet(
                context: context,
                 isScrollControlled: true, 
                builder: (context) {
                  return const CreateNewPostScreen();
                },
              );
            },
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
class CreateNewPostScreen extends StatelessWidget {
  const CreateNewPostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 58, 92), // Background color for the AppBar
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,color: Colors.white),
          
          onPressed: () {
            Navigator.of(context).pop(); // Back action
          },
        ),
        title: const Text(
          'Create New Post',
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.white
          ),
        ),
      ),
      body: Container(
        color: const Color.fromARGB(255, 255, 255, 255), // Set background color for the body
        child: Padding(
          padding: const EdgeInsets.all(26.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40.0),

              // User Information Section
              const Row(
                children: [
                  CircleAvatar(
                    radius: 20.0,
                    backgroundImage: NetworkImage('https://example.com/avatar.jpg'), // Replace with actual avatar URL
                  ),
                  SizedBox(width: 10.0),
                  Text(
                    'Ardito Saputra',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),

              // Post Content Area
              const TextField(
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind?',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 14.0),
                ),
                style: TextStyle(fontSize: 18.0),
              ),
              const SizedBox(height: 20.0),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Cancel action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 80, 80, 80),
                      minimumSize: const Size(160, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0), // Set border radius for rounded corners
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                  const SizedBox(width: 10.0),
                  ElevatedButton(
                    onPressed: () {
                      // Implement the post creation logic
                      Navigator.of(context).pop(); // Close the modal after posting
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 0, 58, 92),
                      minimumSize: const Size(160, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0), // Set border radius for rounded corners
                      ),
                    ),
                    child: const Text('Post Now', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeerAssistanceScreen extends StatelessWidget {
  const PeerAssistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
  return Stack(
    children: [
      Column(
        children: [
          Divider(
  color: Colors.grey[300], // Set the color of the line
  thickness: 1, // Thickness of the line
),
          const CategoryChips(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: const [
                PostCard(content: "Lost my phone in the cafeteria."),
              ],
            ),
          ),
        ],
      ),
      Positioned(
        bottom: 16.0,
        right: 16.0,
        child: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    ],
  );
}

}

class EventsJobsScreen extends StatelessWidget {
  const EventsJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
  return Stack(
    children: [
      Column(
        children: [
          Divider(
  color: Colors.grey[300], // Set the color of the line
  thickness: 1, // Thickness of the line
),
          const CategoryChips(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: const [
                PostCard(content: "Lost my phone in the cafeteria."),
              ],
            ),
          ),
        ],
      ),
      Positioned(
        bottom: 16.0,
        right: 16.0,
        child: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    ],
  );
}

}

class SurveysScreen extends StatelessWidget {
  const SurveysScreen({super.key});

  @override
 Widget build(BuildContext context) {
  return Stack(
    children: [
      Column(
        children: [
          const CategoryChips(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: const [
                PostCard(content: "Lost my phone in the cafeteria."),
              ],
            ),
          ),
        ],
      ),
      Positioned(
        bottom: 16.0,
        right: 16.0,
        child: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
      ),
    ],
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

class PostCard extends StatelessWidget {
  final String content;

  const PostCard({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(content),
      ),
    );
  }
}
