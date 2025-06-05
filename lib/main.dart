import 'package:HPGM/splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/Services/notifi_service.dart';
import 'package:HPGM/bee_counter/main_app_service_bridge.dart';

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
  
  // Initialize the service bridge (this will handle the background service)
  try {
    print("Initializing service bridge and automatic bee monitoring...");
    final serviceBridge = MainAppServiceBridge();
    await serviceBridge.initialize();
    print("✓ Service bridge and bee monitoring service started automatically");
  } catch (e) {
    print("Error starting service bridge: $e");
    // Continue anyway - the app should still work
  }
  
  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final MainAppServiceBridge _serviceBridge = MainAppServiceBridge();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ensureServiceBridge();
  }

  Future<void> _ensureServiceBridge() async {
    try {
      await _serviceBridge.initialize();
      print('✓ Service bridge ensured in main app widget');
    } catch (e) {
      print('Error ensuring service bridge: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        print(' App resumed - enabling full video processing');
        _serviceBridge.onAppResumed();
        break;
      case AppLifecycleState.paused:
        print('App paused - video processing limited to background service');
        _serviceBridge.onAppPaused();
        break;
      case AppLifecycleState.detached:
        print(' App detached');
        break;
      case AppLifecycleState.inactive:
        print('App inactive');
        break;
      case AppLifecycleState.hidden:
        print(' App hidden');
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
     
      home: const Splashscreen(),
    );
  }
}