import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:HPGM/apiary_overview_cards/build_overview_card.dart';
import 'farm_model.dart';
import 'farm_card.dart';

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
      String sendToken = "Bearer ${widget.token}";

      var headers = {'Accept': 'application/json', 'Authorization': sendToken};
      var response = await http.get(
        Uri.parse('http://196.43.168.57/api/v1/farms'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        setState(() {
          farms = data.map((farm) => Farm.fromJson(farm)).toList();
        });

        // After getting farms, fetch stats for each farm
        for (var farm in farms) {
          await getApiaryStats(farm.id);
        }
      } else {
        //  print('Failed to load farms: ${response.reasonPhrase}');
      }
    } catch (error) {
      //  print('Error fetching Apiary data: $error');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> getApiaryStats(int farmId) async {
    try {
      String sendToken = "Bearer ${widget.token}";

      var headers = {'Accept': 'application/json', 'Authorization': sendToken};
      var response = await http.get(
        Uri.parse('http://196.43.168.57/api/v1/farms/$farmId/hives'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        List<dynamic> hives = jsonDecode(response.body);

        int totalHives = hives.length;
        int colonizedHives = 0;
        int needsAttentionHives = 0;

        for (var hive in hives) {
          bool isColonized =
              hive['state']['colonization_status']['Colonized'] ?? false;
          bool isConnected =
              hive['state']['connection_status']['Connected'] ?? false;
          double? honeyLevel =
              hive['state']['weight']['honey_percentage']?.toDouble();
          double? temperature =
              hive['state']['temperature']['interior_temperature']?.toDouble();

          if (isColonized) {
            colonizedHives++;
          }

          // Define conditions for hives needing attention
          // For example: not connected, high temperature, or high honey level ready for harvest
          if (!isConnected ||
              (temperature != null && temperature > 32) ||
              (honeyLevel != null && honeyLevel > 80)) {
            needsAttentionHives++;
          }
        }

        setState(() {
          apiaryStats[farmId] = ApiaryStats(
            totalHives: totalHives,
            activeHives: colonizedHives,
            needsAttentionHives: needsAttentionHives,
          );
        });
      }
    } catch (error) {
      // print('Error fetching hive stats: $error');
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
                                    height: 80,
                                    width: 80,
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
                                const Icon(
                                  Icons.person,
                                  color: Color.fromARGB(255, 206, 109, 40),
                                  size: 65,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Overall Stats Summary
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

                    // Farm Cards List (without individual stats cards)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: farms.length,
                      itemBuilder: (context, index) {
                        final farm = farms[index];
                        return buildFarmCard(farm, context, widget.token);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods to calculate totals
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
}

// Class to store apiary statistics
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
