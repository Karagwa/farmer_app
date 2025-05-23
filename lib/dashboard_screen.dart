import 'package:farmer_app/analytics/foraging_analysis/foraging_analysis_screen.dart';
import 'package:farmer_app/bee_counter/bee_monitoring_screen.dart';
import 'package:farmer_app/bee_counter/bee_video_analysis_screen.dart';
import 'package:farmer_app/bee_counter/bee_activity_correlation_screen.dart';
import 'package:farmer_app/notifications/notification_screen.dart';
import 'package:farmer_app/bee_advisory/bee_advisory_screen.dart';
import 'package:farmer_app/navbar.dart';
import 'package:farmer_app/profile.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  final String token;
  const DashboardScreen({Key? key, required this.token}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  // Sample notification count - you can replace with actual data
  final int notificationCount = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bee Hive Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber[800],
        elevation: 0,
        actions: [
          // Notifications icon with badge
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                if (notificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      child: Text(
                        notificationCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsScreen(),
                ),
              );
            },
          ),
          // Profile avatar - now navigates to profile screen
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(token: widget.token),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 24, color: Colors.amber[800]),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dashboard title and welcome message
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome',
                    style: TextStyle(fontSize: 14, color: Colors.brown[600]),
                  ),
                ],
              ),
            ),

            // Main content - Grid layout feature cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // First row - two cards side by side
                    Row(
                      children: [
                        // Apiary Management Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Apiary Management',
                            icon: Icons.grid_view,
                            color: const Color(0xFFD4A657),
                            notifications: 2,
                            onTap: () {
                              // Navigate to the Home screen when Apiary Management is tapped
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      navbar(token: widget.token),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Bee Counter Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Bee Counter',
                            icon: Icons.trending_up,
                            color: const Color(0xFFCD853F),
                            onTap: () {
                              // Handle bee counter tap
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BeeMonitoringScreen(hiveId: '1'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Second row - two cards side by side
                    Row(
                      children: [
                        // Notifications Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Notifications',
                            icon: Icons.notifications,
                            color: const Color(0xFFB87333),
                            notifications: notificationCount,
                            onTap: () {
                              // Handle notifications tap
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Analytics Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Analytics',
                            icon: Icons.insights,
                            color: const Color(0xFFDAA520),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ForagingAnalysisScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Bee Activity Correlation Card - wide card
                    buildFeatureCard(
                      title: 'Bee Activity Correlations',
                      description:
                          'Analyze bee behavior patterns with environmental factors',
                      icon: Icons.analytics,
                      color: const Color(0xFFB8860B),
                      isWide: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                BeeActivityCorrelationScreen(hiveId: '1'),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    // Third row - two cards side by side
                    Row(
                      children: [
                        // Advisory Resources Card
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Advisory Resources',
                            icon: Icons.book,
                            color: const Color(0xFF8B4513),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BeeAdvisoryScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Weather Card (placeholder - you can replace with another feature)
                        Expanded(
                          child: buildFeatureCard(
                            title: 'Weather',
                            icon: Icons.cloud,
                            color: const Color(0xFF4682B4),
                            onTap: () {
                              // Handle weather tap
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Weather feature coming soon!'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });

          // Improved navigation logic
          switch (index) {
            case 0:
              // Already on Dashboard, do nothing
              break;
            case 1:
              // Navigate to Hives screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => navbar(token: widget.token),
                ),
              );
              break;
            case 2:
              // Navigate to Alerts/Notifications screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationsScreen(),
                ),
              );
              break;
            case 3:
              // Navigate to Profile screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(token: widget.token),
                ),
              );
              break;
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.brown[300],
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.hive), label: 'Hives'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget buildFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    int? notifications,
    required VoidCallback onTap,
    String? description,
    bool isWide = false,
  }) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: isWide ? 2 : 1,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 4,
            child: InkWell(
              borderRadius: BorderRadius.circular(16.0),
              onTap: onTap,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  color: color,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (notifications != null && notifications > 0)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Text(
                notifications.toString(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
