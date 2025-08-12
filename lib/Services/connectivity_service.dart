import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionStatusController;
  bool _isOnline = true;
  Timer? _periodicCheck;

  bool get isOnline => _isOnline;
  Stream<bool> get connectionStream => _connectionStatusController!.stream;

  Future<void> initialize() async {
    _connectionStatusController = StreamController<bool>.broadcast();
    
    // Check initial connectivity
    await _updateConnectionStatus();
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    
    // Start periodic internet connectivity check (every 30 seconds)
    _startPeriodicCheck();
    
    print('✓ Connectivity service initialized - Online: $_isOnline');
  }

  void _onConnectivityChanged(ConnectivityResult result) async {
    print('Connectivity changed to: $result');
    await _updateConnectionStatus();
  }

  Future<void> _updateConnectionStatus() async {
    bool wasOnline = _isOnline;
    
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        _isOnline = false;
      } else {
        // Even if we have network connectivity, check if we can actually reach the internet
        _isOnline = await _hasInternetConnection();
      }
      
      if (wasOnline != _isOnline) {
        print('Connection status changed: ${_isOnline ? "Online" : "Offline"}');
        _connectionStatusController?.add(_isOnline);
      }
    } catch (e) {
      print('Error checking connectivity: $e');
      _isOnline = false;
      if (wasOnline != _isOnline) {
        _connectionStatusController?.add(_isOnline);
      }
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      // Try to reach a reliable server
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Public method to check internet connection
  Future<bool> hasInternetConnection() async {
    return await _hasInternetConnection();
  }

  void _startPeriodicCheck() {
    _periodicCheck = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateConnectionStatus();
    });
  }

  void dispose() {
    _periodicCheck?.cancel();
    _connectionStatusController?.close();
    _connectionStatusController = null;
  }
}
