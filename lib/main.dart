import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_app_check/firebase_app_check.dart'; // Temporarily removed App Check
import 'firebase_options.dart'; // Make sure this file exists and is correct
import 'package:firebase_auth/firebase_auth.dart'; // For auth state changes
import 'splash_screen.dart'; // Path to SplashScreen (now in lib/ directly)
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:firebase_messaging/firebase_messaging.dart'; // NEW: For push notifications
import 'package:cloud_firestore/cloud_firestore.dart'; // For saving FCM token

// Top-level function for handling background messages
// This function must not be an anonymous function or an async closure.
// It also cannot access the state of the Flutter app (since it runs in a separate isolate).
@pragma('vm:entry-point') // Required for background message handlers
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
  debugPrint("Background Message data: ${message.data}");
  // You can process the message here, e.g., show a local notification
  // For simplicity, we are just logging for now.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Main: WidgetsFlutterBinding initialized.');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Main: Firebase initialized successfully.');

    // Initialize Firebase Messaging
    await _initFirebaseMessaging();

  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      debugPrint('Main: Firebase default app already initialized (duplicate-app error caught).');
    } else {
      debugPrint('Main: CRITICAL ERROR - Firebase initialization failed: $e');
      return;
    }
  } catch (e) {
    debugPrint('Main: General error during Firebase initialization: $e');
    return;
  }

  runApp(const MyApp());
}

Future<void> _initFirebaseMessaging() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission for notifications
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  debugPrint('User granted permission: ${settings.authorizationStatus}');

  // Get the FCM token and save it to Firestore
  String? token = await messaging.getToken();
  debugPrint('FCM Token: $token');

  // Listen for incoming messages while the app is in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Got a message whilst in the foreground!');
    debugPrint('Message data: ${message.data}');

    if (message.notification != null) {
      debugPrint('Message also contained a notification: ${message.notification}');
      // You can display a local notification here if needed
      // For now, we'll just log and assume the system handles it or a UI component listens.
    }
  });

  // Handle messages when the app is in the background or terminated
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handle interaction when the app is opened from a terminated state
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('App opened from terminated state by a notification: ${initialMessage.data}');
    // Handle navigation or specific logic based on initialMessage.data
  }

  // Handle interaction when the app is in the background and opened by a notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('App opened from background by a notification: ${message.data}');
    // Handle navigation or specific logic based on message.data
  });

  // Save the token to Firestore for the currently logged-in user
  // This needs to be done after a user logs in successfully.
  // We'll update UserDataService for this. For now, just logging.
  // The actual saving will happen in `_updateUserFCMToken` called upon user login.
}


MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(color.value * strength).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - r)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
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
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        // Save/update FCM token when user logs in or auth state changes
        _updateUserFCMToken(user.uid);
      }
    });
  }

  // Function to save/update the FCM token for the user in Firestore
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
      title: 'SSD Barre',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryRed,
        hintColor: primaryRed,
        scaffoldBackgroundColor: whiteBg,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: textOnWhite),
          bodyMedium: TextStyle(color: textOnWhite),
          bodySmall: TextStyle(color: textOnWhite),
          displayLarge: TextStyle(color: textOnWhite),
          displayMedium: TextStyle(color: textOnWhite),
          displaySmall: TextStyle(color: textOnWhite),
          headlineLarge: TextStyle(color: textOnWhite),
          headlineMedium: TextStyle(color: textOnWhite),
          headlineSmall: TextStyle(color: textOnWhite),
          titleLarge: TextStyle(color: textOnWhite),
          titleMedium: TextStyle(color: textOnWhite),
          titleSmall: TextStyle(color: textOnWhite),
          labelLarge: TextStyle(color: textOnWhite),
          labelMedium: TextStyle(color: textOnWhite),
          labelSmall: TextStyle(color: textOnWhite),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryRed,
            foregroundColor: textOnRedOrBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 5,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: blackBg,
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: primaryRed,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: whiteBg,
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
          hintStyle: TextStyle(color: Colors.grey[600]),
          floatingLabelStyle: const TextStyle(color: primaryRed),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
