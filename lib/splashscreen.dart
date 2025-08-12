import 'dart:async';
import 'package:HPGM/getstarted.dart';
import 'package:HPGM/login.dart';
import 'package:HPGM/dashboard_screen.dart';
import 'package:HPGM/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTime') ?? true;

    print('Debug: isFirstTime = $isFirstTime');

    if (isFirstTime) {
      // First-time user flow - clear any existing data
      await TokenStorage.clearLoginData();
      await prefs.setBool('isFirstTime', false);
      print('Debug: Navigating to GetStarted (first time)');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => GetStarted()),
      );
    } else {
      // Check session status using TokenStorage
      final isLoggedIn = await TokenStorage.isLoggedIn();
      final token = await TokenStorage.getToken();

      print(
        'Debug: isLoggedIn = $isLoggedIn, token = ${token?.substring(0, 10) ?? 'null'}...',
      );

      if (isLoggedIn && token != null) {
        // Valid session exists - navigate to Dashboard
        print('Debug: Navigating to Dashboard (logged in)');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(token: token),
          ),
        );
      } else {
        // No valid session
        print('Debug: Navigating to Login (not logged in)');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Center(
          child: Image.asset(
            'lib/images/log-1.png',
            height: 200, // Added explicit height
          ),
        ),
      ),
    );
  }
}
