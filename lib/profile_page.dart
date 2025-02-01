import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:Colors.white,
       
      body: Center(
         child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Heading
                const Text(
                  "Create your Profile",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily:'sans' 
                  ),
                ),
                const SizedBox(height: 30),

                // Camera Button
                IconButton(
                  icon: const Icon(
                    Icons.camera_alt,
                    size: 50,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    // Handle attach profile image
                  },
                ),
                const SizedBox(height: 20),

                // Username Field
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Enter Username',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                ),
                const SizedBox(height: 20),

                // Email Field
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Your Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                ),
                const SizedBox(height: 20),

                // Bio Field
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Enter Bio',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                ),
                const SizedBox(height: 20),

                // Dropdown Field
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Select Your Role',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Student',
                      child: Text('Student'),
                    ),
                    DropdownMenuItem(
                      value: 'Alumni',
                      child: Text('Alumni'),
                    ),
                  ],
                  onChanged: (value) {
                    // Handle dropdown value change
                  },
                ),
                const SizedBox(height: 20),

                // Create Profile Button
                ElevatedButton(
                  onPressed: () {
                    // Handle create profile logic
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    backgroundColor: const Color(0xFF01214E), // Button color
                  ),
                  child: const Text(
                    'Create Profile',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
