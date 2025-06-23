import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter/foundation.dart'; // For debugPrint

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
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
      debugPrint('Registration: Attempting to register user: $email');
      // Attempt to create a new user with email and password
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _showSnackBar('Registration successful! You can now log in.');
      debugPrint('Registration: User $email registered successfully. Navigating back to login.');
      // Navigate back to the login page after successful registration
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is not valid.';
      } else {
        message = 'Registration failed: ${e.message}';
      }
      debugPrint('Registration Error: $message');
      _showSnackBar(message);
    } catch (e) {
      debugPrint('Registration Error: An unexpected error occurred: $e');
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

    debugPrint('Registration: Building RegistrationPage with theme colors.');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        // Colors are handled by global AppBarTheme
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Create Your Account',
                style: TextStyle(
                  fontFamily: 'SSDHeader',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textOnBackground, // Use black for text on white background
                ),
              ),
              const SizedBox(height: 24),
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
                      onPressed: _register,
                      // Style is now inherited from ElevatedButtonThemeData in main.dart
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontFamily: 'SSDBody',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          // Color inherited from ElevatedButtonThemeData (onPrimary)
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  debugPrint('Registration: Navigating back to Login page.');
                  Navigator.pop(context); // Go back to login page
                },
                // Style is now inherited from TextButtonThemeData in main.dart
                child: Text( // Removed const here because primaryColor is not a compile-time constant
                  'Already have an account? Log in.',
                  style: TextStyle(
                    fontFamily: 'SSDBody',
                    fontSize: 14,
                    color: primaryColor, // Use primary red for the text button
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
