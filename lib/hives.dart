import 'package:HPGM/add_hive_form.dart';
import 'package:HPGM/edit_hive_form.dart';
import 'package:HPGM/records_form.dart';
import 'package:HPGM/services/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/hivedetails.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'dart:convert';

class Hives extends StatefulWidget {
  final int farmId;
  final String token;
  final String apiaryLocation;
  final String farmName;
  final VoidCallback onHiveDeleted; // Callback for hive deletion

  const Hives({
    Key? key,
    required this.farmId,
    required this.token,
    required this.apiaryLocation,
    required this.farmName,
    required this.onHiveDeleted, // Initialize the callback
  }) : super(key: key);

  @override
  State<Hives> createState() => _HivesState();
}

class Hive {
  final int id;
  final String longitude;
  final String latitude;
  final int farmId;
  final String? createdAt;
  final String? updatedAt;
  final double? weight;
  final double? honeyLevel;
  final double? temperature;
  final bool isConnected;
  final bool isColonized;

  Hive({
    required this.id,
    required this.longitude,
    required this.latitude,
    required this.farmId,
    required this.createdAt,
    required this.updatedAt,
    required this.weight,
    required this.temperature,
    required this.honeyLevel,
    required this.isConnected,
    required this.isColonized,
  });

  factory Hive.fromJson(Map<String, dynamic> json) {
    return Hive(
      id: json['id'],
      longitude: json['longitude'],
      latitude: json['latitude'],
      farmId: json['farm_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      weight: json['state']['weight']['record']?.toDouble(),
      temperature:
          json['state']['temperature']['interior_temperature']?.toDouble(),
      honeyLevel: json['state']['weight']['honey_percentage']?.toDouble(),
      isConnected: json['state']['connection_status']['Connected'] == 1,
      isColonized: json['state']['colonization_status']['Colonized'] == 1,
    );
  }
}

class _HivesState extends State<Hives> {
  List<Hive> hives = [];
  bool isTableView = false; // Add this state variable

  @override
  void initState() {
    super.initState();
    getHives(widget.farmId);
  }

  Future<void> getHives(int farmId) async {
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

      var url = 'http://196.43.168.57/api/v1/farms/$farmId/hives';
      var response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          hives = data.map((hive) => Hive.fromJson(hive)).toList();
        });
      } else {
        print('Failed to load hive data: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching hives: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[100],
      body: LiquidPullToRefresh(
        color: Colors.orange,
        height: 150,
        animSpeedFactor: 2,
        onRefresh: () async {
          await getHives(widget.farmId);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.orange,
              title: Text(
                '${widget.farmName} Hives List',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: "Sans",
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white, size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AddHiveForm(
                              farmId: widget.farmId,
                              apiaryLocation: widget.apiaryLocation,
                              farmName: widget.farmName,
                              onHiveAdded: () async {
                                await getHives(widget.farmId);
                              },
                            ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    isTableView ? Icons.view_list : Icons.grid_view,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() {
                      isTableView = !isTableView;
                    });
                  },
                ),
              ],
            ),
            // Conditional rendering based on view type
            isTableView
                ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildHivesTable(),
                  ),
                )
                : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 16,
                      ),
                      child: buildHiveCard(hives[index]),
                    );
                  }, childCount: hives.length),
                ),
          ],
        ),
      ),
    );
  }

  // Modified method to build the table view
  Widget _buildHivesTable() {
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
              DataColumn(label: Text('Hive ID')),
              DataColumn(label: Text('Actions')),
            ],
            rows:
                hives.map((hive) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          'Hive ${hive.id}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // View button
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
                                  final token = await TokenStorage.getToken();
                                  if (token != null && mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => HiveDetails(
                                              hiveId: hive.id,
                                              token: token,
                                              honeyLevel: hive.honeyLevel,
                                            ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 4, width: 4),
                            // Edit button
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
                                  Icons.edit,
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
                                onPressed: () {
                                  _showEditHiveDialog(hive);
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
                                  _showDeleteConfirmation(hive);
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

  // Add method to show edit dialog
  void _showEditHiveDialog(Hive hive) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => EditHiveForm(
              hiveId: hive.id,
              farmId: widget.farmId,
              apiaryLocation: widget.apiaryLocation,
              farmName: widget.farmName,
              initialLatitude: hive.latitude,
              initialLongitude: hive.longitude,
              initialColonized: hive.isColonized,
              initialConnected: hive.isConnected,
              onHiveUpdated: () async {
                await getHives(widget.farmId);
              },
            ),
      ),
    );
  }

  // Add method to show delete confirmation
  void _showDeleteConfirmation(Hive hive) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Hive ${hive.id}',
            style: const TextStyle(fontFamily: "Sans"),
          ),
          content: const Text(
            'Are you sure you want to delete this hive? This action cannot be undone.',
            style: TextStyle(fontFamily: "Sans"),
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
                _deleteHive(hive.id);
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

  // Add method to delete hive
  Future<void> _deleteHive(int hiveId) async {
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

      var url = 'https://3de85730509a.ngrok-free.app/api/v1/hives/$hiveId';
      var response = await http.delete(Uri.parse(url), headers: headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hive deleted successfully!'),
            backgroundColor: Colors.green[700],
          ),
        );
        await getHives(widget.farmId); // Refresh the list

        widget.onHiveDeleted(); // 💥 notify parent to update stats
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete hive: ${response.statusCode}'),
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

  Widget buildHiveCard(Hive hive) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      color: Colors.brown[300],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Icon(Icons.hexagon, color: Colors.orange[700], size: 28),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Name: Hive ${hive.id}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Sans",
                      color: Colors.white,
                    ),
                  ),
                ),
                Icon(
                  hive.isConnected ? Icons.link : Icons.link_off,
                  color: hive.isConnected ? Colors.green : Colors.red,
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.link,
              label: 'Status',
              value: hive.isConnected ? 'ON' : 'OFF',
              valueColor: hive.isConnected ? Colors.green : Colors.red,
            ),

            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.star,
              label: 'Performance',
              value: 'Good', //Enum value for performance{Good, Average, Poor}
              valueColor: Colors.green,
            ),

            const SizedBox(height: 12),

            // Colonization Status
            _buildInfoRow(
              icon: Icons.grass,
              label: 'Colonization Status',
              value: hive.isColonized ? 'Colonized' : 'Not Colonized',
              valueColor: hive.isColonized ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final token = await TokenStorage.getToken();
                      if (token != null && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => HiveDetails(
                                  hiveId: hive.id,
                                  token: token,
                                  honeyLevel: hive.honeyLevel,
                                ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      final token = await TokenStorage.getToken();
                      if (token != null && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => RecordsForm(
                                  apiaryLocation: widget.apiaryLocation,
                                  hiveId: 'Hive ${hive.id}',
                                  farmName: widget.farmName,
                                ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Inspect',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.orange[700], size: 25),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 19,
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontFamily: "Sans",
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.white,
                  fontFamily: "Sans",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
