import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../dashboard_page.dart';
import 'registration_page.dart'; // Import registration page
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:firebase_messaging/firebase_messaging.dart'; // NEW: For FCM Token
import 'user_data_service.dart'; // NEW: For UserDataService

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService(); // NEW: UserDataService instance
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Login: Attempting to sign in with $email');
      // Attempt to sign in with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get FCM token after successful login
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('Login: FCM Token after login: $fcmToken');

      // Update user data in Firestore, including FCM token
      await _userDataService.updateUserData(userCredential.user!, fcmToken: fcmToken);

      // If successful, navigate to the DashboardPage
      if (mounted) {
        debugPrint('Login: Sign in successful, navigating to Dashboard.');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'Login failed: ${e.message}';
      }
      debugPrint('Login Error: $message');
      _showSnackBar(message);
    } catch (e) {
      debugPrint('Login Error: An unexpected error occurred: $e');
      _showSnackBar('An unexpected error occurred: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get colors from the global theme
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color textOnPrimary = Theme.of(context).colorScheme.onPrimary; // White
    final Color textOnBackground = Theme.of(context).colorScheme.onBackground; // Black

    debugPrint('Login: Building LoginPage with theme colors - Primary: $primaryColor, TextOnBg: $textOnBackground');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        // These colors will now come from the global theme's AppBarTheme
        // backgroundColor: primaryColor, // No need to set explicitly here
        // foregroundColor: textOnPrimary, // No need to set explicitly here
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome Back!',
                style: TextStyle(
                  fontFamily: 'SSDHeader',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textOnBackground, // Use black for text on white background
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  // Border and other styles are now handled by InputDecorationTheme in main.dart
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  // Border and other styles are now handled by InputDecorationTheme in main.dart
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? CircularProgressIndicator(color: primaryColor) // Use primary red for loading indicator
                  : ElevatedButton(
                      onPressed: _login,
                      // Style is now inherited from ElevatedButtonThemeData in main.dart
                      // style: ElevatedButton.styleFrom(...)
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontFamily: 'SSDBody',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          // Color inherited from ElevatedButtonThemeData
                          // color: textOnPrimary,
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  debugPrint('Login: Navigating to RegistrationPage.');
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegistrationPage()),
                  );
                },
                // Style is now inherited from TextButtonThemeData in main.dart
                // style: TextButton.styleFrom(...)
                child: const Text(
                  'Don\'t have an account? Register here.',
                  style: TextStyle(
                    fontFamily: 'SSDBody',
                    fontSize: 14,
                    // Color inherited from TextButtonThemeData
                    // color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
