import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Import this for kIsWeb

import 'Home.dart';


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔵 Background Notification Received: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      setupFirebaseNotifications();
    }
  });

  runApp(const MyApp());
}

void setupFirebaseNotifications() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("✅ User granted permission");
  }

  // Get the device token
  String? token = await messaging.getToken();
  if (token != null) {
    print("📲 Device FCM Token: $token");
    saveUserToken(token);
  } else {
    print("❌ Failed to get FCM Token");
  }

  FirebaseMessaging.instance.onTokenRefresh.listen(saveUserToken);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("🔴 Foreground Notification: ${message.notification?.title}");
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("🟡 App opened from notification: ${message.data}");
  });
}

void saveUserToken(String token) async {
  User? user;
  while (user == null) {
    await Future.delayed(const Duration(seconds: 1));
    user = FirebaseAuth.instance.currentUser;
  }

  print("🔍 Saving FCM Token for user: ${user.uid} - Token: $token");

  await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({'fcmToken': token}, SetOptions(merge: true));

  print("✅ FCM Token saved successfully!");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UNI-verse',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SignUpPage(),
    );
  }
}

class GoogleSignInButton extends StatefulWidget {
  final Function(UserCredential) onSuccess;

  const GoogleSignInButton({
    super.key,
    required this.onSuccess,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '267004637492-9fj3m3cuchvn145cc27r5r4eannq8ign.apps.googleusercontent.com'
,scopes: ['email', 'profile'],
  );

 Future<void> _handleGoogleSignIn() async {
  try {
    setState(() => _isLoading = true);

    // Ensure sign out before signing in again
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();

    // Force Google to prompt for account selection
    final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    if (googleUser != null) {
      await _googleSignIn.disconnect();  // Clear cached account
    }

    final GoogleSignInAccount? newGoogleUser = await _googleSignIn.signIn();
    if (newGoogleUser == null) return;

    final GoogleSignInAuthentication googleAuth = await newGoogleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    
    if (userCredential.user != null) {
      // Check if this is a new user and add default fields if needed
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
      
      if (!userDoc.exists) {
        // New user with Google Sign In - create profile with defaults
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'username': userCredential.user!.displayName ?? 'User',
              'email': userCredential.user!.email ?? '',
              'role': 'student', // Default role
              'profilePicture': userCredential.user!.photoURL ?? 
                'https://firebasestorage.googleapis.com/v0/b/your-project-id.appspot.com/o/default_profile.png?alt=media', // Use Google profile pic or default
              'createdAt': FieldValue.serverTimestamp(),
            });
      }
      
      if (userCredential.user?.emailVerified ?? false) {
        widget.onSuccess(userCredential);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your email first.')),
        );
      }
    }
  } catch (e) {
    debugPrint('Google Sign In Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _handleGoogleSignIn,
      icon: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Image.asset('assets/images/google_logo.png', height: 24),
      label: Text(
        _isLoading ? 'Signing in...' : 'Continue with Google',
        style: const TextStyle(fontSize: 16),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        side: const BorderSide(color: Colors.grey),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
final TextEditingController _usernameController = TextEditingController();

 Future<void> _signUp() async {
  setState(() {
    _isLoading = true;
  });

  try {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    User? user = userCredential.user;

    if (user != null) {
      await user.sendEmailVerification();

      // Save username to Firestore with default role and profile picture
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'student', // Default role
        'profilePicture': 'https://firebasestorage.googleapis.com/v0/b/your-project-id.appspot.com/o/default_profile.png?alt=media', // Default profile picture URL
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent. Please verify your email.')),
      );

      _startEmailVerificationCheck();
    }
  } catch (e) {
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}


  void _startEmailVerificationCheck() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Verification'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Waiting for email verification...\nPlease check your email and verify your account.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseAuth.instance.currentUser?.reload();
                final user = FirebaseAuth.instance.currentUser;
                if (user?.emailVerified ?? false) {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email not verified yet. Please verify and try again.')),
                  );
                }
              },
              child: const Text('Check Verification'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 15),
                Image.asset(
                  'assets/images/hi.png',
                  width: 50,
                  height: 50,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Welcome to UNI-verse",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Sign up to create your account",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
TextField(
  controller: _usernameController,
  decoration: InputDecoration(
    labelText: 'Username',
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0)),
    prefixIcon: const Icon(Icons.person, color: Colors.grey),
  ),
),
const SizedBox(height: 10),

                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0)),
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20.0)),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                    backgroundColor: const Color(0xFF01214E),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Sign Up', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 10),

                GoogleSignInButton(
                  onSuccess: (UserCredential userCredential) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const SignInPage()),
                        );
                      },
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      User? user = userCredential.user;

      if (user != null) {
        // Reload user to get latest verification status
        await user.reload();
        user = _auth.currentUser;

        if (user?.emailVerified ?? false) {
          // If email is verified, navigate to HomeScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please verify your email before signing in.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 15),
                Image.asset(
                  'assets/images/hi.png',
                  width: 50,
                  height: 50,
                ),
                const SizedBox(height: 10),
                const Text(
                  "Welcome to UNI-verse",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Sign in to continue",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),

                // Email Field
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),

                // Password Field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),

                // Sign In Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      side: const BorderSide(color: Color.fromARGB(255, 1, 38, 100)),
                    ),
                    backgroundColor: const Color(0xFF01214E),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Dont have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const SignUpPage()),
                        );
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
