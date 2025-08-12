import 'dart:async';
import 'package:flutter/material.dart';
import 'package:HPGM/Services/connectivity_service.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final bool showBanner;
  final bool showAlerts;
  
  const ConnectivityWrapper({
    super.key,
    required this.child,
    this.showBanner = true,
    this.showAlerts = true,
  });

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOnline = true;
  bool _isAlertShowing = false;
  late StreamSubscription<bool> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    // Listen to connectivity changes
    _connectivitySubscription = _connectivityService.connectionStream.listen((bool isOnline) {
      print('📱 Connectivity listener received: ${isOnline ? "Online" : "Offline"}');
      
      if (mounted) {
        setState(() {
          _isOnline = isOnline;
        });
        
        // Handle alert showing/dismissing with a slight delay to ensure UI is ready
        if (widget.showAlerts) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!isOnline && !_isAlertShowing) {
              print('🚨 Showing offline alert');
              _showConnectivityAlert();
            } else if (isOnline && _isAlertShowing) {
              print('✅ Dismissing offline alert - connection restored');
              _dismissConnectivityAlert();
              // Show brief success message instead of dialog
              _showBriefSuccessMessage();
            }
          });
        }
      }
    });
    
    // Set initial state
    _isOnline = _connectivityService.isOnline;
    print('📡 Initial connectivity state: ${_isOnline ? "Online" : "Offline"}');
    
    // Show alert immediately if app starts offline
    if (widget.showAlerts && !_isOnline && !_isAlertShowing) {
      // Delay to ensure the widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('🔄 App started offline - showing initial alert');
        _showConnectivityAlert();
      });
    }
  }

  void _showBriefSuccessMessage() {
    if (!mounted) return;
    
    // Show a brief, elegant success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Connection restored',
              style: TextStyle(
                fontFamily: "Sans",
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 6,
      ),
    );
  }

  void _showConnectivityAlert() {
    if (_isAlertShowing || !mounted) return;
    
    _isAlertShowing = true;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          title: const Row(
            children: [
              Icon(Icons.signal_wifi_off, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No Internet Connection',
                  style: TextStyle(
                    fontFamily: "Sans",
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Please check your internet connection. Some features may not work properly while offline.',
            style: TextStyle(
              fontFamily: "Sans",
              fontSize: 16,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          actions: [
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    // Check connectivity again
                    _connectivityService.initialize();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontFamily: "Sans",
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _dismissConnectivityAlert();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Continue Offline',
                    style: TextStyle(
                      fontFamily: "Sans",
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        );
      },
    );
  }

  void _dismissConnectivityAlert() {
    if (!_isAlertShowing || !mounted) return;
    
    _isAlertShowing = false;
    
    // Check if there's a dialog to dismiss
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Show connectivity banner when offline
        if (widget.showBanner && !_isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[600]!, Colors.orange[700]!],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.signal_wifi_off, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        
                        fontFamily: "Sans",
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
