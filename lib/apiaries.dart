import 'dart:convert';
import 'package:HPGM/AddApiaryForm.dart';
import 'package:HPGM/hives.dart';
import 'editApiaryForm.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:HPGM/apiary_overview_cards/build_overview_card.dart';

import 'farm_model.dart';
import 'farm_card.dart';
import 'Services/token_storage.dart';
import 'services/cache_service.dart';
import 'Services/auth_manager.dart';

class Apiaries extends StatefulWidget {
  final String token;

  const Apiaries({Key? key, required this.token}) : super(key: key);

  @override
  State<Apiaries> createState() => _ApiariesState();
}

class _ApiariesState extends State<Apiaries> {
  List<Farm> farms = [];
  Map<int, ApiaryStats> apiaryStats = {};
  bool isLoading = true;
  bool isTabularView = true; // Default view is Tabular

  @override
  void initState() {
    super.initState();
    getApiaries();
  }

  Future<void> getApiaries() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Check if device is online
      final isOnline = await CacheService.isOnline();

      // If offline, try to load from cache first
      if (!isOnline) {
        print('📱 Device is offline, trying to load from cache...');
        final cachedFarms = await CacheService.loadFarms();
        if (cachedFarms != null) {
          if (mounted) {
            setState(() {
              farms = cachedFarms.map((farm) => Farm.fromJson(farm)).toList();
              isLoading = false;
            });
          }

          print('✓ Loaded ${farms.length} farms from cache');

          // Load stats for each farm from cache
          for (var farm in farms) {
            await getApiaryStats(farm.id);
          }

          // Show user-friendly offline message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '📱 Offline mode - Showing saved data',
                  style: TextStyle(fontFamily: "Sans"),
                ),
                backgroundColor: Colors.orange[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        } else {
          // No cached data available
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '📱 No internet connection and no saved data available',
                  style: TextStyle(fontFamily: "Sans"),
                ),
                backgroundColor: Colors.red[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
          return;
        }
      }

      // Device is online - proceed with API call
      print('🌐 Device is online, fetching from API...');

      // Use AuthManager for authenticated API call
      final response = await AuthManager.get(
        'http://196.43.168.57/api/v1/farms',
        context: context,
      );

      print('Response status: ${response?.statusCode}');
      print('Response headers: ${response?.headers}');
      print('Response body: ${response?.body}');

      if (response != null && response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        print('Parsed data: $data');

        // Save to cache for offline use
        await CacheService.saveFarms(data);

        if (mounted) {
          setState(() {
            farms =
                data.map((farm) {
                  print('Processing farm: $farm');
                  return Farm.fromJson(farm);
                }).toList();
          });
        }

        print('Farms loaded: ${farms.length}');

        for (var farm in farms) {
          await getApiaryStats(farm.id);
        }
      } else {
        print('Failed to load farms: ${response?.statusCode}');
        print('Error response: ${response?.body}');

        // Try loading from cache as fallback
        final cachedFarms = await CacheService.loadFarms();
        if (cachedFarms != null) {
          if (mounted) {
            setState(() {
              farms = cachedFarms.map((farm) => Farm.fromJson(farm)).toList();
            });
          }

          for (var farm in farms) {
            await getApiaryStats(farm.id);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ Server error (${response?.statusCode}) - Showing saved data',
                ),
                backgroundColor: Colors.orange[700],
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load farms: ${response?.statusCode}'),
                backgroundColor: Colors.red[700],
              ),
            );
          }
        }
      }
    } catch (error) {
      print('Error loading farms: $error');

      // Try loading from cache as fallback
      final cachedFarms = await CacheService.loadFarms();
      if (cachedFarms != null) {
        if (mounted) {
          setState(() {
            farms = cachedFarms.map((farm) => Farm.fromJson(farm)).toList();
          });
        }

        for (var farm in farms) {
          await getApiaryStats(farm.id);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ Connection error - Showing saved data',
                style: TextStyle(fontFamily: "Sans"),
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Provide user-friendly error messages based on error type
        String userMessage;
        if (error.toString().contains('SocketException') ||
            error.toString().contains('Network is unreachable') ||
            error.toString().contains('Connection failed')) {
          userMessage =
              '🔌 No internet connection. Please check your network and try again.';
        } else if (error.toString().contains('TimeoutException') ||
            error.toString().contains('timeout')) {
          userMessage =
              '⏱️ Connection timeout. The server is taking too long to respond.';
        } else if (error.toString().contains('404')) {
          userMessage = '📍 Server endpoint not found. Please contact support.';
        } else if (error.toString().contains('500') ||
            error.toString().contains('502') ||
            error.toString().contains('503')) {
          userMessage =
              '🔧 Server is temporarily unavailable. Please try again later.';
        } else {
          userMessage = '❌ Unable to load farms. Please try again later.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                userMessage,
                style: const TextStyle(fontFamily: "Sans"),
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> getApiaryStats(int farmId) async {
    try {
      // Check if online first
      final isOnline = await CacheService.isOnline();

      if (!isOnline) {
        // Try loading from cache when offline
        final cachedHives = await CacheService.loadHives(farmId);
        if (cachedHives != null) {
          _calculateStatsFromHives(farmId, cachedHives);
          return;
        }
      }

      // Use AuthManager for authenticated request
      final response = await AuthManager.get(
        'http://196.43.168.57/api/v1/farms/$farmId/hives',
        context: context,
      );

      if (response != null && response.statusCode == 200) {
        List<dynamic> hives = jsonDecode(response.body);

        // Save hives to cache for offline use
        await CacheService.saveHives(farmId, hives);

        _calculateStatsFromHives(farmId, hives);
      } else {
        print(
          'Failed to fetch hives for stats. Status: ${response?.statusCode}',
        );
        print('Body: ${response?.body}');

        // Try loading from cache as fallback
        final cachedHives = await CacheService.loadHives(farmId);
        if (cachedHives != null) {
          _calculateStatsFromHives(farmId, cachedHives);
        }
      }
    } catch (error) {
      print('Error loading stats for farm $farmId: $error');

      // Try loading from cache as fallback
      final cachedHives = await CacheService.loadHives(farmId);
      if (cachedHives != null) {
        _calculateStatsFromHives(farmId, cachedHives);
      }
    }
  }

  void _calculateStatsFromHives(int farmId, List<dynamic> hives) {
    int totalHives = hives.length;
    int colonizedHives = 0;
    int needsAttentionHives = 0;

    for (var hive in hives) {
      // Safe parsing with fallback values
      dynamic colonizedRaw =
          hive['state']?['colonization_status']?['Colonized'];
      dynamic connectedRaw = hive['state']?['connection_status']?['Connected'];
      dynamic honeyRaw = hive['state']?['weight']?['honey_percentage'];
      dynamic tempRaw = hive['state']?['temperature']?['interior_temperature'];

      bool isColonized = colonizedRaw == true || colonizedRaw == 1;
      bool isConnected = connectedRaw == true || connectedRaw == 1;

      double? honeyLevel = _parseDouble(honeyRaw);
      double? temperature = _parseDouble(tempRaw);

      if (isColonized) colonizedHives++;

      if (!isConnected ||
          (temperature != null && temperature > 32) ||
          (honeyLevel != null && honeyLevel > 80)) {
        needsAttentionHives++;
      }
    }

    if (mounted) {
      setState(() {
        apiaryStats[farmId] = ApiaryStats(
          totalHives: totalHives,
          activeHives: colonizedHives,
          needsAttentionHives: needsAttentionHives,
        );
      });
    }
  }

  double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<bool> updateApiary(
    int farmId,
    Map<String, dynamic> updatedData,
  ) async {
    try {
      final token = await TokenStorage.getToken();

      if (token == null || token.isEmpty) {
        return false;
      }

      String sendToken = "Bearer $token";

      var headers = {
        'Accept': 'application/json',
        'Authorization': sendToken,
        'Content-Type': 'application/json',
      };
      var response = await http.put(
        Uri.parse('http://196.43.168.57/api/v1/farms/$farmId'),
        headers: headers,
        body: jsonEncode(updatedData),
      );

      return response.statusCode == 200;
    } catch (error) {
      print('Error updating apiary: $error');
      return false;
    }
  }

  Future<void> _handleRefresh() async {
    await getApiaries();
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LiquidPullToRefresh(
        onRefresh: _handleRefresh,
        color: Colors.orange,
        height: 150,
        animSpeedFactor: 2,
        showChildOpacityTransition: true,
        child: ListView(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    SizedBox(
                      height: 125,
                      width: 2000,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.orange.withOpacity(0.8),
                                  Colors.orange.withOpacity(0.6),
                                  Colors.orange.withOpacity(0.4),
                                  Colors.orange.withOpacity(0.2),
                                  Colors.orange.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 15.0),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.brown,
                                    size: 30,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                ),
                                Container(
                                  child: Image.asset(
                                    'lib/images/log-1.png',
                                    height: 65,
                                    width: 65,
                                  ),
                                ),
                                const SizedBox(width: 100),
                                const Text(
                                  'Apiaries',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                const Spacer(),
                                // Toggle Button for View Mode
                                IconButton(
                                  icon: Icon(
                                    isTabularView
                                        ? Icons.view_module
                                        : Icons.table_chart,
                                    color: Colors.brown,
                                    size: 30,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isTabularView = !isTabularView;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Apiary Overview Section
                    if (farms.isNotEmpty && !isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          color: Colors.brown[50],
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Apiary Overview',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    buildOverviewCard(
                                      'Total Hives',
                                      _getTotalHives().toString(),
                                      Icons.hive,
                                      Colors.amber,
                                    ),
                                    buildOverviewCard(
                                      'Active Hives',
                                      _getTotalActiveHives().toString(),
                                      Icons.check_circle,
                                      Colors.green,
                                    ),
                                    buildOverviewCard(
                                      'Needs Attention',
                                      _getTotalNeedsAttentionHives().toString(),
                                      Icons.warning,
                                      Colors.red,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.orange,
                          ),
                        ),
                      ),

                    // Farm Cards Section
                    if (!isLoading)
                      isTabularView
                          ? Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _buildApiariesTable(),
                          )
                          : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: farms.length,
                            itemBuilder: (context, index) {
                              final farm = farms[index];
                              return FutureBuilder<String?>(
                                future: TokenStorage.getToken(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    return buildFarmCard(
                                      farm,
                                      context,
                                      snapshot.data!,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => AddApiaryForm(
                    onApiaryAdded: () async {
                      // Refresh the apiaries list
                      await getApiaries();
                    },
                  ),
            ),
          );

          // Also refresh when returning from the form
          if (result == true) {
            await getApiaries();
          }
        },
        backgroundColor: Colors.amber[800],
        child: const Icon(Icons.add),
        tooltip: 'Add New Apiary',
      ),
    );
  }

  int _getTotalHives() {
    int total = 0;
    apiaryStats.forEach((_, stats) {
      total += stats.totalHives;
    });
    return total;
  }

  int _getTotalActiveHives() {
    int total = 0;
    apiaryStats.forEach((_, stats) {
      total += stats.activeHives;
    });
    return total;
  }

  int _getTotalNeedsAttentionHives() {
    int total = 0;
    apiaryStats.forEach((_, stats) {
      total += stats.needsAttentionHives;
    });
    return total;
  }

  Widget _buildApiariesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.orange[700]),
            dataRowHeight: 80, // Main row height
            headingRowHeight: 60, // Header height
            dataRowColor: MaterialStateProperty.resolveWith<Color>((
              Set<MaterialState> states,
            ) {
              if (states.contains(MaterialState.hovered)) {
                return Colors.orange[50]!;
              }
              return Colors.white;
            }),
            headingTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: "Sans",
            ),
            dataTextStyle: const TextStyle(
              color: Colors.black87,
              fontFamily: "Sans",
            ),
            columns: const [
              DataColumn(label: Text('Farm Name')),
              DataColumn(label: Text('Actions')),
            ],
            rows:
                farms.map((farm) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              farm.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${farm.district} - ${farm.address}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View/Manage button
                            SizedBox(
                              width: 70,
                              height: 30,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.visibility,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'View',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  // Navigate to farm details/hives
                                  final token = await TokenStorage.getToken();
                                  if (token != null && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => Hives(
                                              farmId: farm.id,
                                              token: token,
                                              apiaryLocation: farm.address,
                                              farmName: farm.name,
                                              onHiveDeleted: () async {
                                                await getApiaryStats(
                                                  farm.id,
                                                ); // refresh stats!
                                              },
                                            ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 4, width: 4),
                            // Settings button
                            SizedBox(
                              width: 70,
                              height: 30,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.settings,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => EditApiaryForm(
                                            farmId: farm.id,
                                            initialData: farm.toJson(),
                                          ),
                                    ),
                                  );

                                  if (result == true) {
                                    await getApiaries();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 4, width: 4),
                            // Delete button
                            SizedBox(
                              width: 70,
                              height: 30,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.delete,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () {
                                  _showDeleteConfirmation(farm);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Farm farm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Farm ${farm.name}',
            style: const TextStyle(fontFamily: "Sans"),
          ),
          content: Text(
            'Are you sure you want to delete "${farm.name}"? This action cannot be undone and will also delete all associated hives.',
            style: const TextStyle(fontFamily: "Sans"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteFarm(farm.id);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFarm(int farmId) async {
    try {
      final token = await TokenStorage.getToken();

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication error. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String sendToken = "Bearer $token";

      var headers = {'Authorization': sendToken};

      var url = 'https://3de85730509a.ngrok-free.app/api/v1/farms/$farmId';
      var response = await http.delete(Uri.parse(url), headers: headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Farm deleted successfully!'),
            backgroundColor: Colors.green[700],
          ),
        );
        await getApiaries(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete farm: ${response.statusCode}'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }
}

class ApiaryStats {
  final int totalHives;
  final int activeHives;
  final int needsAttentionHives;

  ApiaryStats({
    required this.totalHives,
    required this.activeHives,
    required this.needsAttentionHives,
  });
}
