import 'package:HPGM/splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/Services/notifi_service.dart';
import 'package:HPGM/bee_counter/bee_monitoring_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  // Ensure Flutter is initialized before doing anything else
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  try {
    await NotificationService().initNotification();
  } catch (e) {
    print("Warning: Could not initialize notifications: $e");
  }
  
  // Initialize the notification plugin
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();     

  // Initialize the monitoring service at application startup
  final monitoringService = BeeMonitoringService();
  await monitoringService.initializeService();

  // Run the app with proper provider setup
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BeeMonitoringService _monitoringService = BeeMonitoringService();
  String _activeHiveId = '1'; 
  bool _serviceRunning = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkServiceStatus();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeHiveId = prefs.getString('active_hive_id') ?? '1';
    });
  }
  
  Future<void> _checkServiceStatus() async {
    final isRunning = await _monitoringService.isServiceRunning();
    setState(() {
      _serviceRunning = isRunning;
    });
  }
  
  

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const Splashscreen(),
    );
  }
}