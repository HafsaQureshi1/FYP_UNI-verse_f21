import 'package:flutter/material.dart';
import '../components/profileimage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/theme_provider.dart';
import 'package:provider/provider.dart';
import 'profile_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore import

class SettingsScreen extends StatelessWidget {
  final Function signOutFunction;

  const SettingsScreen({Key? key, required this.signOutFunction})
      : super(key: key);

  // Function to fetch user profile data
  Future<String> _getUserName(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        // Use 'username' field which is consistent with profile_page.dart
        return userDoc['username'] ?? '';
      } else {
        return '';
      }
    } catch (e) {
      print('Error fetching user data: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final userId = currentUser?.uid ?? '';
    final userEmail = currentUser?.email ?? 'User';

    // Access theme provider with Consumer instead of direct Provider.of
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 0, 58, 92),
            elevation: 0,
            title: const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            // Removed profile icon from actions
          ),
          body: Column(
            children: [
              // User profile card at top with FutureBuilder
              Container(
                color: const Color.fromARGB(255, 0, 58, 92),
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Center(
                  child: FutureBuilder<String>(
                    future: _getUserName(userId),
                    builder: (context, snapshot) {
                      // Default name fallback if data isn't available yet
                      String displayName = userEmail.split('@').first;

                      // If we have valid data, use the username from profile
                      if (snapshot.hasData &&
                          snapshot.data != null &&
                          snapshot.data!.isNotEmpty) {
                        displayName = snapshot.data!;
                      }

                      return Column(
                        children: [
                          const SizedBox(height: 10),
                          // Profile image
                          Hero(
                            tag: 'profileAvatar',
                            child: ProfileAvatar(
                              userId: userId,
                              radius: 40,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // User name from Firestore
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // User email
                          Text(
                            userEmail,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Settings list
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 16),

                    // Settings section header - ACCOUNT
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text(
                        'ACCOUNT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ),

                    // Profile settings card - Added this card before logout
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        leading: ProfileAvatar(
                          userId: userId,
                          radius: 20,
                        ),
                        title: const Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'View and edit your profile',
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          );
                        },
                      ),
                    ),

                    // Logout card
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.exit_to_app,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Sign out from your account',
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          // Confirm logout
                          final shouldLogout = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text(
                                  'Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Logout'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (shouldLogout == true) {
                            Navigator.pop(context); // Close the settings screen
                            signOutFunction(); // Call the original logout function
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // App preferences section header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text(
                        'APP PREFERENCES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ),

                    // Appearance card with dark mode toggle
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Theme.of(context).cardColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        const Color.fromARGB(40, 100, 100, 255),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.palette,
                                    color: Color.fromARGB(255, 100, 100, 255),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'Appearance',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Dark Mode',
                                  style: TextStyle(fontSize: 15),
                                ),
                                Switch(
                                  value: themeProvider.isDarkMode,
                                  onChanged: (_) {
                                    themeProvider.toggleTheme();
                                  },
                                  activeColor:
                                      const Color.fromARGB(255, 0, 58, 92),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Account settings card
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(40, 0, 58, 92),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color.fromARGB(255, 0, 58, 92),
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Manage your account',
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Show dialog with delete account option
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Account Options'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.delete_forever,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                    ),
                                    title: const Text(
                                      'Delete Account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Permanently delete your account and data',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    onTap: () {
                                      // Close the first dialog
                                      Navigator.pop(context);

                                      // Show confirmation dialog for account deletion
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Account'),
                                          content: const Text(
                                              'Are you sure you want to permanently delete your account? This action cannot be undone.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                // Account deletion logic would go here
                                                Navigator.pop(context);
                                                // Show feedback snackbar
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Account deletion request submitted')),
                                                );
                                              },
                                              child: const Text('Delete'),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Notifications settings card
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(40, 0, 58, 92),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.notifications,
                            color: Color.fromARGB(255, 0, 58, 92),
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Customize your notification preferences',
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Notifications settings functionality would go here
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Information section header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text(
                        'INFORMATION',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ),

                    // About app card
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Theme.of(context).cardColor,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(40, 0, 58, 92),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Color.fromARGB(255, 0, 58, 92),
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'About App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Version information and details',
                          style: TextStyle(fontSize: 13),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Show about app dialog
                          showDialog(
                            context: context,
                            builder: (context) => const AboutAppDialog(),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.only(
              top: 60,
              bottom: 20,
              left: 20,
              right: 20,
            ),
            margin: const EdgeInsets.only(top: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'UNI-verse',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 0, 58, 92),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'UNI-verse is a platform designed to connect university students and alumni, providing features for lost and found items, peer assistance, events, jobs, and surveys.',
                  style: TextStyle(fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  '© 2025 UNI-verse. All Rights Reserved.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Developed by Team UNI-verse',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromARGB(255, 0, 58, 92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: CircleAvatar(
              backgroundColor: const Color.fromARGB(255, 0, 58, 92),
              radius: 40,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 38,
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png', // Corrected path to match pubspec.yaml
                    height: 70,
                    width: 70,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
