import 'package:HPGM/splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:HPGM/Services/notifi_service.dart';
// import 'package:HPGM/bee_counter/background_video_processing_service.dart';
import 'package:provider/provider.dart';
// import 'package:HPGM/notifications/notification_provider.dart';

Future<void> main() async {
  // Ensure Flutter is initialized before doing anything else
  WidgetsFlutterBinding.ensureInitialized();

  // Try to load .env file but don't crash if it doesn't exist
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found. Continuing without it.");
  }

  // Initialize notifications
  try {
    await NotificationService().initNotification();
  } catch (e) {
    print("Warning: Could not initialize notifications: $e");
  }

  // await BackgroundVideoProcessingService().initialize();

  // Run the app with proper provider setup
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // This MaterialApp provides the Directionality widget that was missing
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Splashscreen(),
    );
  }
}
