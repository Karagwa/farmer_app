import 'package:HPGM/splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/Services/notifi_service.dart';
import 'package:HPGM/bee_counter/bee_monitoring_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Ensure Flutter is initialized before doing anything else
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  try {
    await NotificationService().initNotification();
    print("✓ Notification service initialized");
  } catch (e) {
    print("Warning: Could not initialize notifications: $e");
  }
  
  // Initialize and AUTO-START the bee monitoring service
  try {
    print("Initializing automatic bee monitoring service...");
    final monitoringService = AutomaticBeeMonitoringService();
    await monitoringService.initializeAndStart(); // This auto-starts the service
    print("✓ Bee monitoring service started automatically");
  } catch (e) {
    print("Error starting bee monitoring service: $e");
    // Continue anyway - the app should still work
  }
  
  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HPGM',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const Splashscreen(),
    );
  }
}