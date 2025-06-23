import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../dashboard_page.dart';
import 'registration_page.dart'; // Import registration page

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
      // Attempt to sign in with email and password
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If successful, navigate to the DashboardPage
      if (mounted) {
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
      _showSnackBar(message);
    } catch (e) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        // These colors will now come from the global theme's AppBarTheme
        // backgroundColor: primaryColor,
        // foregroundColor: textOnPrimary,
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        // These colors will now come from the global theme's ElevatedButtonThemeData
                        // backgroundColor: primaryColor,
                        // foregroundColor: textOnPrimary,
                        // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        // elevation: 5,
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontFamily: 'SSDBody',
                          fontSize: 18,
                          // Color will be set by foregroundColor in ElevatedButton.styleFrom in main.dart
                          // color: textOnPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegistrationPage()),
                  );
                },
                style: TextButton.styleFrom(
                  // Color will be set by TextButtonThemeData in main.dart
                  // foregroundColor: primaryColor,
                ),
                child: const Text(
                  'Don\'t have an account? Register here.',
                  style: TextStyle(
                    fontFamily: 'SSDBody',
                    fontSize: 14,
                    // Color will be set by TextButtonThemeData in main.dart
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
