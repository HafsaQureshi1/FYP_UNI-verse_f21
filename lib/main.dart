import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/fcm-service.dart';
import 'package:flutter_application_1/services/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'admin/admin.dart';
import 'package:intl/intl.dart';

// Import this for kIsWeb
import 'dart:async';
import 'screens/Home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const List<String> _adminEmails = [
    'hafsa.bssef21@iba-suk.edu.pk',
    'maazbin.bscsf21@iba-suk.edu.pk'
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UNI-verse',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const CustomSplashScreen(),
    );
  }
}

class CustomSplashScreen extends StatefulWidget {
  const CustomSplashScreen({super.key});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      await FCMService().initializeFCM();
    }

    _goToNextScreen(user);
  }

  void _goToNextScreen(User? user) {
    final userEmail = user?.email?.toLowerCase().trim();
    final isAdmin = MyApp._adminEmails.contains(userEmail);

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                isAdmin ? const AdminDashboard() : const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 253, 254, 255),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logosplash.png',
                  height: 100,
                ),
                const SizedBox(height: 20),
                const Text(
                  'UNI-verse',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 0, 58, 92),
                  ),
                ),
                const Text(
                  'Your Campus, Connected.',
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.push_pin,
                              title: 'Bulletin Board',
                              description:
                                  'Stay updated with events, jobs, and surveys.',
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.group,
                              title: 'Peer Help',
                              description:
                                  'Get advice and support from fellow students.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.notifications,
                              title: 'Notifications',
                              description:
                                  'Get real-time updates on events and posts.',
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _FeatureCard(
                              icon: Icons.search,
                              title: 'Search',
                              description:
                                  'Find posts, events, and more easily.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Column(
                  children: const [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF003A5C)),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Loading your campus experience...',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'v1.0.0',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
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

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(right: 12, left: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Color.fromARGB(255, 0, 58, 92)),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

// ✅ Ensure this function is outside of any class (top-level function)
//Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//await Firebase.initializeApp();
//  print("🔵 Background Message Received: ${message.notification?.title}");
//}

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

class GoogleSignUpButton extends StatefulWidget {
  final Function(UserCredential) onSuccess;

  const GoogleSignUpButton({super.key, required this.onSuccess});

  @override
  State<GoogleSignUpButton> createState() => _GoogleSignUpButtonState();
}

class _GoogleSignUpButtonState extends State<GoogleSignUpButton> {
  bool _isLoading = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb
        ? '267004637492-iugmfvid1ca8prhuvkaflcbrtre7cibs.apps.googleusercontent.com'
        : null,
  );

  Future<void> _handleGoogleSignUp() async {
    try {
      setState(() => _isLoading = true);

      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      final GoogleSignInAccount? newGoogleUser = await _googleSignIn.signIn();
      if (newGoogleUser == null) return;
if (newGoogleUser!.email.endsWith('@iba-suk.edu.pk') &&
        !newGoogleUser.email.endsWith('@iba-suk.edu.pk')) {
      // Not allowed domain - sign out and show error
      await _googleSignIn.signOut();
      throw Exception('Please sign in with your sukkur.iba email account');
    }
      final GoogleSignInAuthentication googleAuth =
          await newGoogleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check if the email is already registered
      final String email = newGoogleUser.email;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userDoc.docs.isNotEmpty) {
        // User already exists
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Account already exists with this email! Please sign in.')),
        );
        return;
      }

      // Check if email exists in Firebase Authentication
      try {
        final methods =
            await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'An account already exists with this email. Please sign in.')),
          );
          return;
        }
      } catch (e) {
        debugPrint("Error checking auth methods: $e");
      }

      // Create a new user with Google credentials
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Save user details to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'uid': userCredential.user!.uid,
          'username': userCredential.user!.displayName ?? 'User',
          'email': userCredential.user!.email ?? '',
          'role': 'student', // Default role
          'profilePicture': userCredential.user!.photoURL ??
              'https://firebasestorage.googleapis.com/v0/b/your-project-id.appspot.com/o/default_profile.png?alt=media', // Default profile picture
          'createdAt': FieldValue.serverTimestamp(),
        });

        widget.onSuccess(userCredential);
      }
    } catch (e, stackTrace) {
      debugPrint("Google Sign-up Error: $e");
      debugPrint("StackTrace: $stackTrace");
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
      onPressed: _isLoading ? null : _handleGoogleSignUp,
      icon: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Image.asset('assets/images/google_logo.png', height: 24),
      label: Text(
        _isLoading ? 'Signing up...' : 'Sign Up with Google',
        style: const TextStyle(fontSize: 16),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        side: const BorderSide(color: Colors.grey),
      ),
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
    scopes: ['email', 'profile'],
    clientId: kIsWeb
        ? '267004637492-iugmfvid1ca8prhuvkaflcbrtre7cibs.apps.googleusercontent.com'
        : null,
  );

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);

      // Ensure sign out before signing in again
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();

      // Force Google to prompt for account selection
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signInSilently();
      if (googleUser != null) {
        await _googleSignIn.disconnect(); // Clear cached account
      }
      final GoogleSignInAccount? newGoogleUser = await _googleSignIn.signIn();
      if (newGoogleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await newGoogleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

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
    } catch (e, stackTrace) {
      debugPrint("Google Sign-In Error: $e");
      debugPrint("StackTrace: $stackTrace");
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
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
  bool _obscurePassword = true; // Add this in your state

  // Add this at the top of your _SignUpPageState class
  final List<String> _adminEmails = [
    'waseemhasnain373@gmail.com',
    'maazbin.bscsf21@iba-suk.edu.pk',
        
    'dean@university.edu'
  ];
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Check: Password must be at least 6 characters
    // Check: Password must be at least 12 characters
   if (!email.toLowerCase().endsWith('@iba-suk.edu.pk')) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You must use a valid Sukkur IBA email (ending in @iba-suk.edu.pk).'),
      ),
    );
    return;
  }
if (password.length < 12) {
  setState(() => _isLoading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
        content: Text('Password must be at least 12 characters.')),
  );
  return;
}

// Check: Password must contain letters and digits
final hasLettersAndDigits = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)');
if (!hasLettersAndDigits.hasMatch(password)) {
  setState(() => _isLoading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Password must include letters and numbers.')),
  );
  return;
}

// Check: Password must contain at least one special character
final hasSpecialChar = RegExp(r'(?=.*[!@#\$%^&*(),.?":{}|<>])');
if (!hasSpecialChar.hasMatch(password)) {
  setState(() => _isLoading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Password must include a special character.')),
  );
  return;
}


    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        try {
  await user.sendEmailVerification();
} catch (e) {
  print('Error sending email verification: $e');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not send verification email: $e')),
  );
}


        // Check if the email is an admin email
        bool isAdmin = _adminEmails.contains(user.email?.toLowerCase().trim());

        // Save user data with role
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': _usernameController.text.trim(),
          'email': user.email,
          'role': 'student', // Set role based on email
          'profilePicture': 'https://firebasestorage.googleapis.com/...',
          'createdAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Verification email sent. Please verify your email.')),
        );

        _startEmailVerificationCheck(isAdmin: isAdmin);
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

  void _startEmailVerificationCheck({bool isAdmin = false}) {
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
              Text(
                  'Waiting for email verification...\nPlease check your email and verify your account.'),
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
                  // Redirect to appropriate screen based on role
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          isAdmin ? AdminDashboard() : const HomeScreen(),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Email not verified yet. Please verify and try again.')),
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
                  'assets/images/logo.png',
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
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0)),
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0)),
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText:
                        'Password must contain  alphanumeric and special character.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0)),
                    backgroundColor: const Color(0xFF01214E),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Sign Up',
                          style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 10),
                GoogleSignUpButton(
                  onSuccess: (UserCredential userCredential) {
                    final List<String> adminEmails = [
                      'waseemhasnain373@gmail.com',
                      'maazbin.bscsf21@iba-suk.edu.pk',
                      
                    ];

                    final String? email =
                        userCredential.user?.email?.toLowerCase().trim();

                    if (email != null && adminEmails.contains(email)) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (context) => AdminDashboard()),
                      );
                    } else {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                      );
                    }
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
                          MaterialPageRoute(
                              builder: (context) => const SignInPage()),
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
  late final SecureStorage _secureStorage;
  bool _isLoading = false;
  bool _rememberMe = false;
  List<Map<String, String>> _savedAccounts = [];
  bool _obscurePassword = true;

  final List<String> _adminEmails = [
    'waseemhasnain373@gmail.com',
    'maazbin.bscsf21@iba-suk.edu.pk',
    
  ];

  @override
  void initState() {
    super.initState();
    _secureStorage = SecureStorage();
    _initializeStorage();
  }

  Future<void> _initializeStorage() async {
    try {
      await _secureStorage.init();
      await _loadSavedAccounts();
      await _checkRememberedAccount();
    } catch (e) {
      debugPrint('Storage initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to initialize storage'),
        ),
      );
    }
  }

  Future<void> _loadSavedAccounts() async {
    try {
      final accounts = await _secureStorage.getSavedAccounts();
      if (accounts != null && accounts.isNotEmpty) {
        setState(() {
          _savedAccounts = accounts;
        });
      }
    } catch (e) {
      debugPrint('Error loading accounts: $e');
    }
  }

  Future<void> _checkRememberedAccount() async {
    try {
      final rememberedAccount = await _secureStorage.getRememberedAccount();
      if (rememberedAccount != null) {
        setState(() {
          _emailController.text = rememberedAccount['email']!;
          _passwordController.text = rememberedAccount['password']!;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking remembered account: $e');
    }
  }

  Future<void> _saveAccount(String email, String password) async {
    try {
      await _secureStorage.saveAccount(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );
      await _loadSavedAccounts();
    } catch (e) {
      debugPrint('Error saving account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save account credentials'),
        ),
      );
    }
  }

  Future<void> _removeAccount(String email, String password) async {
    try {
      await _secureStorage.removeAccount(email, password);
      await _loadSavedAccounts();
    } catch (e) {
      debugPrint('Error removing account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove account'),
        ),
      );
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Check: Password must be at least 6 characters
     if (!email.toLowerCase().endsWith('@iba-suk.edu.pk')) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You must use a valid Sukkur IBA email (ending in @iba-suk.edu.pk).'),
      ),
    );
    return;
  }
if (password.length < 12) {
  setState(() => _isLoading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
        content: Text('Password must be at least 12 characters.')),
  );
  return;
}

// Check: Password must contain letters and digits
final hasLettersAndDigits = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)');
if (!hasLettersAndDigits.hasMatch(password)) {
  setState(() => _isLoading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Password must include letters and numbers.')),
  );
  return;
}

// Check: Password must contain at least one special character
final hasSpecialChar = RegExp(r'(?=.*[!@#\$%^&*(),.?":{}|<>])');
if (!hasSpecialChar.hasMatch(password)) {
  setState(() => _isLoading = false);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Password must include a special character.')),
  );
  return;
}

    final userDocRef =
        FirebaseFirestore.instance.collection('login_attempts').doc(email);

    try {
      final snapshot = await userDocRef.get();

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final bannedUntil = data['bannedUntil']?.toDate();

        if (bannedUntil != null && DateTime.now().isBefore(bannedUntil)) {
          setState(() => _isLoading = false);
          final formattedTime = DateFormat('hh:mm a').format(bannedUntil);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Account is banned. Try again after $formattedTime.')),
          );
          return;
        }
      }

      // Try to sign in
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.reload();
        user = _auth.currentUser;

        if (user?.emailVerified ?? false) {
          await _saveAccount(email, password);

          // Reset failed attempts on successful login
          await userDocRef.set({'failedAttempts': 0}, SetOptions(merge: true));

          bool isAdmin =
              _adminEmails.contains(user?.email?.toLowerCase().trim());
          print('Email: ${user?.email}, isAdmin: $isAdmin');

          setState(() => _isLoading = false);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  isAdmin ? AdminDashboard() : const HomeScreen(),
            ),
          );
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please verify your email before signing in.')),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address format.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Login failed. Please check your credentials.';
      }

      // If the user exists, track failed login attempts
      if (e.code == 'wrong-password') {
        final snapshot = await userDocRef.get();
        int failedAttempts = 0;

        if (snapshot.exists) {
          failedAttempts = snapshot.data()?['failedAttempts'] ?? 0;
        }

        failedAttempts += 1;

        if (failedAttempts >= 3) {
          await userDocRef.set({
            'failedAttempts': failedAttempts,
            'bannedUntil': Timestamp.fromDate(
                DateTime.now().add(const Duration(hours: 2))),
          });
        } else {
          await userDocRef.set({
            'failedAttempts': failedAttempts,
          }, SetOptions(merge: true));
        }

        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$errorMessage (${failedAttempts}/3 attempts)')),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$errorMessage')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('An unexpected error occurred. Please try again.')),
      );
    }
  }

  void _showAccountSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select an account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (_savedAccounts.isEmpty)
                const Text('No saved accounts found')
              else
                ..._savedAccounts.map((account) {
                  return ListTile(
                      leading: const Icon(Icons.account_circle),
                      title: Text(account['email']!),
                      onTap: () {
                        setState(() {
                          _emailController.text = account['email']!;
                          _passwordController.text = account['password']!;
                          _rememberMe = true;
                        });
                        Navigator.pop(context);
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          await _removeAccount(
                              account['email']!, account['password']!);

                          // Refresh the list after removal
                          final updatedAccounts =
                              await _secureStorage.getSavedAccounts();

                          setState(() {
                            _savedAccounts = updatedAccounts ?? [];
                          });
                        },
                      ));
                }).toList(),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController _resetEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: TextField(
            controller: _resetEmailController,
            decoration: const InputDecoration(
              labelText: 'Enter your email',
              prefixIcon: Icon(Icons.email),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final email = _resetEmailController.text.trim();
                if (email.isNotEmpty) {
                  try {
                    await _auth.sendPasswordResetEmail(email: email);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Password reset email sent.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Send'),
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
                  'assets/images/logo.png',
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
                const SizedBox(height: 20),

                // Email Field
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    prefixIcon: const Icon(Icons.email, color: Colors.grey),
                    suffixIcon: _savedAccounts.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.arrow_drop_down),
                            onPressed: _showAccountSelection,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),

                // Password Field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 20.0),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                ),

                const SizedBox(height: 5),

                // Remember me checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Text('Remember me'),
                    const Spacer(),
                    TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Sign In Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
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

                const SizedBox(height: 10),

                // Google Sign-In Button
              GoogleSignInButton(
  onSuccess: (UserCredential userCredential) {
    final String? email = userCredential.user?.email?.toLowerCase().trim();

    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not found')),
      );
      return;
    }

    // Check if email ends with IBA Sukkur domain
    if (!email.endsWith('@iba-suk.edu.pk') &&
        !email.endsWith('@iba-suk.edu.pk')) {
      // Invalid domain — sign out and show error
      FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please use your Sukkur IBA email to sign in')),
      );
      return;
    }

    // Valid domain — continue navigation
    if (_adminEmails.contains(email)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AdminDashboard()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  },
),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SignUpPage()),
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

class SecureStorage {
  static const _rememberedEmailKey = 'remembered_email';
  static const _rememberedPasswordKey = 'remembered_password';
  static const _savedAccountsKey = 'saved_accounts';

  late final FlutterSecureStorage? _secureStorage;
  late final SharedPreferences? _sharedPreferences;

  Future<void> init() async {
    try {
      // For Android/iOS
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

      // For Web
      _sharedPreferences = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SecureStorage init error: $e');
    }
  }

  Future<void> saveAccount({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      if (rememberMe) {
        await _write(_rememberedEmailKey, email);
        await _write(_rememberedPasswordKey, password);

        final accountKey = '$email,$password';
        final existingAccounts = await _read(_savedAccountsKey) ?? '';

        if (!existingAccounts.contains(accountKey)) {
          final newAccounts = existingAccounts.isEmpty
              ? accountKey
              : '$existingAccounts|$accountKey';
          await _write(_savedAccountsKey, newAccounts);
        }
      } else {
        await _delete(_rememberedEmailKey);
        await _delete(_rememberedPasswordKey);
      }
    } catch (e) {
      debugPrint('Error saving account: $e');
      rethrow;
    }
  }

  Future<Map<String, String>?> getRememberedAccount() async {
    try {
      final email = await _read(_rememberedEmailKey);
      final password = await _read(_rememberedPasswordKey);

      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
      return null;
    } catch (e) {
      debugPrint('Error getting remembered account: $e');
      return null;
    }
  }

  Future<List<Map<String, String>>?> getSavedAccounts() async {
    try {
      final accounts = await _read(_savedAccountsKey);
      if (accounts != null && accounts.isNotEmpty) {
        return accounts.split('|').map((account) {
          final parts = account.split(',');
          return {'email': parts[0], 'password': parts[1]};
        }).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting saved accounts: $e');
      return null;
    }
  }

  Future<void> removeAccount(String email, String password) async {
    try {
      final accounts = await getSavedAccounts();
      if (accounts != null) {
        final updatedAccounts = accounts
            .where((a) => a['email'] != email || a['password'] != password)
            .map((a) => '${a['email']},${a['password']}')
            .join('|');

        await _write(_savedAccountsKey, updatedAccounts);
      }
    } catch (e) {
      debugPrint('Error removing account: $e');
      rethrow;
    }
  }

  Future<void> _write(String key, String value) async {
    if (_secureStorage != null) {
      await _secureStorage.write(key: key, value: value);
    }
    if (_sharedPreferences != null) {
      await _sharedPreferences.setString(key, value);
    }
  }

  Future<String?> _read(String key) async {
    if (_secureStorage != null) {
      return await _secureStorage!.read(key: key);
    }
    if (_sharedPreferences != null) {
      return _sharedPreferences!.getString(key);
    }
    return null;
  }

  Future<void> _delete(String key) async {
    if (_secureStorage != null) {
      await _secureStorage!.delete(key: key);
    }
    if (_sharedPreferences != null) {
      await _sharedPreferences!.remove(key);
    }
  }
}
