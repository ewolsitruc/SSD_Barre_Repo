import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
// CORRECTED IMPORTS based on your provided folder structure:
import 'package:ssd_barre_new/dashboard_page.dart';         // dashboard_page.dart is in lib/
import 'package:ssd_barre_new/user/login_page.dart';         // login_page.dart is in lib/user/
import 'package:ssd_barre_new/user/user_data_service.dart';  // user_data_service.dart is in lib/user/

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
    await Firebase.initializeApp();

    _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      } else {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        final userDataService = UserDataService(); // FIXED: define it here

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
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/splash_screen.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      ),
    );
  }
}
