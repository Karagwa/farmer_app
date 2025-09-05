import 'package:HPGM/Services/auth_manager.dart';
import 'package:HPGM/splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/Services/notifi_service.dart';
import 'package:HPGM/Services/connectivity_service.dart';
import 'package:HPGM/bee_counter/main_app_service_bridge.dart';
import 'package:HPGM/Services/apiary_queue_service.dart';
import 'services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // Initialize connectivity service
  try {
    await ConnectivityService().initialize();
    print("✓ Connectivity service initialized");
  } catch (e) {
    print("Warning: Could not initialize connectivity service: $e");
  }

  // Validate authentication on startup
  try {
    await AuthManager.validateOnStartup();
    print("✓ Authentication validation completed");
  } catch (e) {
    print("Warning: Authentication validation failed: $e");
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
    _setupApiaryQueueSync();
  }

  Future<void> _ensureServiceBridge() async {
    try {
      await _serviceBridge.initialize();
      print('✓ Service bridge ensured in main app widget');
    } catch (e) {
      print('Error ensuring service bridge: $e');
    }
  }

  void _setupApiaryQueueSync() {
    ConnectivityService().connectionStream.listen((isOnline) async {
      if (isOnline) {
        final queue = await ApiaryQueueService.getQueue();
        for (int i = 0; i < queue.length; ) {
          final item = queue[i];
          try {
            final token = await TokenStorage.getToken();
            if (token == null || token.isEmpty) break;
            http.Response response;
            // Detect type by endpoint or data keys
            String? endpoint;
            Map<String, dynamic> body = {};
            if (item.data.containsKey('endpoint')) {
              endpoint = item.data['endpoint'];
            }
            // Inspection record
            if (endpoint != null && endpoint.contains('/hives/inspections')) {
              body = item.data['inspection'] ?? {};
              response = await http.post(
                Uri.parse(endpoint),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode(body),
              );
            }
            // Add Hive
            else if (endpoint != null && endpoint.contains('/hives') && item.actionType == ApiaryActionType.add) {
              body = item.data['hive'] ?? {};
              response = await http.post(
                Uri.parse(endpoint),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode(body),
              );
            }
            // Edit Hive
            else if (endpoint != null && endpoint.contains('/hives') && item.actionType == ApiaryActionType.edit) {
              body = item.data['hive'] ?? {};
              response = await http.put(
                Uri.parse(endpoint),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode(body),
              );
            }
            // Add Apiary
            else if (item.actionType == ApiaryActionType.add && endpoint != null && endpoint.contains('/farms')) {
              response = await http.post(
                Uri.parse(endpoint),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode(item.data),
              );
            }
            // Edit Apiary
            else if (item.actionType == ApiaryActionType.edit && endpoint != null && endpoint.contains('/farms')) {
              response = await http.put(
                Uri.parse(endpoint),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                body: jsonEncode(item.data),
              );
            }
            else {
              print('Unknown queue item type or missing endpoint, skipping');
              i++;
              continue;
            }
            if (response.statusCode == 201 || response.statusCode == 200) {
              await ApiaryQueueService.removeFromQueue(i);
              print('✓ Queued action synced successfully');
            } else {
              print('Failed to sync queued action: ${response.statusCode}');
              i++;
            }
          } catch (e) {
            print('Error syncing queued action: $e');
            i++;
          }
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('✓ App resumed - enabling full video processing');
        _serviceBridge.onAppResumed();
        break;
      case AppLifecycleState.paused:
        print('App paused - video processing limited to background service');
        _serviceBridge.onAppPaused();
        break;
      case AppLifecycleState.detached:
        print('✓ App detached');
        break;
      case AppLifecycleState.inactive:
        print('App inactive');
        break;
      case AppLifecycleState.hidden:
        print('✓ App hidden');
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
