import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// Corrected import paths for the new directory structure
import 'dashboard_page.dart'; // dashboard_page.dart is now in the same directory (lib/main/)
import 'user/login_page.dart';     // login_page.dart is now in a direct sub-directory (lib/main/user/)
import 'user/user_data_service.dart'; // user_data_service.dart is now in a direct sub-directory (lib/main/user/)

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Ensure Firebase is initialized (though main.dart should handle this)
    await Firebase.initializeApp();

    _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        // Not signed in, go to login
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      } else {
        // Signed in, check if user data exists in Firestore and initialize if not
        final userDataService = UserDataService();
        await userDataService.addUserToFirestore(user);

        // Go to dashboard
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get colors from the global theme
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/splash_screen.jpg'), // Ensure this path is correct in pubspec.yaml
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(color: primaryColor), // Your app's primary color
        ),
      ),
    );
  }
}
