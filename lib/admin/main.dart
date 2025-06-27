import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:ssd_barre_new/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ssd_barre_new/splash_screen.dart';
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Main: WidgetsFlutterBinding initialized.');

  try {
    // Initialize Firebase first
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Main: Firebase initialized successfully.');

    // Activate App Check with Debug provider for development
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
    debugPrint('Main: Firebase App Check activated with Debug provider.');

    // Initialize Firebase Messaging
    await _initFirebaseMessaging();

    // Run the app after setup is complete
    runApp(const MyApp());
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint('Main: Firebase default app already initialized (duplicate-app error caught).');
      runApp(const MyApp()); // Safe to continue
    } else {
      debugPrint('Main: CRITICAL ERROR - Firebase initialization failed: $e');
      return;
    }
  } catch (e) {
    debugPrint('Main: General error during Firebase initialization: $e');
    return;
  }
}

// Initialize Firebase Messaging and setup listeners
Future<void> _initFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission for notifications
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  debugPrint('User granted permission: ${settings.authorizationStatus}');

  // Get FCM token (log it; save to Firestore on login)
  String? token = await messaging.getToken();
  debugPrint('FCM Token: $token');

  // Foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Foreground message received: ${message.data}');
    if (message.notification != null) {
      debugPrint('Notification title: ${message.notification?.title}');
    }
  });

  // Background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // App opened from terminated state by notification
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('App opened from terminated state by notification: ${initialMessage.data}');
  }

  // App opened from background by notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('App opened from background by notification: ${message.data}');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();

    // Listen for auth state changes to update FCM token
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _updateUserFCMToken(user.uid);
      }
    });
  }

  // Save/update FCM token for authenticated user
  Future<void> _updateUserFCMToken(String uid) async {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('FCM Token saved/updated for user $uid.');
      } catch (e) {
        debugPrint('Error saving FCM token for user $uid: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MyApp: Building MaterialApp...');
    const Color primaryRed = Color(0xFFD13034);
    const Color blackBg = Color(0xFF1E1E1E);
    const Color whiteBg = Colors.white;
    const Color textOnRedOrBlack = Colors.white;
    const Color textOnWhite = Color(0xFF1E1E1E);

    return MaterialApp(
      title: 'SSD Barre App',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryRed,
        scaffoldBackgroundColor: whiteBg,
        colorScheme: const ColorScheme.light(
          primary: primaryRed,
          onPrimary: textOnRedOrBlack,
          secondary: blackBg,
          onSecondary: textOnWhite,
          background: whiteBg,
          onBackground: textOnWhite,
          surface: whiteBg,
          onSurface: textOnWhite,
          error: primaryRed,
          onError: textOnRedOrBlack,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryRed,
          foregroundColor: textOnRedOrBlack,
          elevation: 4,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          contentPadding: const EdgeInsets.fromLTRB(10, 16, 16, 16),
          filled: true,
          fillColor: whiteBg,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryRed),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primaryRed, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          labelStyle: const TextStyle(color: textOnWhite),
          floatingLabelStyle: const TextStyle(color: primaryRed),
          hintStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
