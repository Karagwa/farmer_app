import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_echarts/flutter_echarts.dart';
import 'package:http/http.dart' as http;
import 'package:line_icons/line_icons.dart';
import 'package:intl/intl.dart';

class Weight extends StatefulWidget {
  final int hiveId;
  final String token;

  const Weight({Key? key, required this.hiveId, required this.token})
      : super(key: key);

  @override
  State<Weight> createState() => _WeightState();
}

class _WeightState extends State<Weight> {
  List<DateTime> dates = [];
  List<double?> weights = [];
  List<double?> honeyPercentages = [];
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = false;
  String? _errorMessage;
  double? _latestWeight;
  double? _latestHoneyPercentage;
  DateTime? _latestDate;

  @override
  void initState() {
    super.initState();
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 7));
    _getLatestWeight(); // First get the latest weight
    _getWeightData(); // Then get the historical data
  }

  // New method to fetch just the latest weight
  Future<void> _getLatestWeight() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final url =
          'http://196.43.168.57/api/v1/hives/${widget.hiveId}/latest-weight';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Debug - print the response structure
        print('Latest Weight API Response: ${response.body}');

        if (jsonData is Map) {
          // Parse the date
          if (jsonData['date_collected'] != null) {
            _latestDate = DateTime.parse(jsonData['date_collected'].toString());
          }

          // Parse the weight
          if (jsonData['record'] != null) {
            _latestWeight = jsonData['record'] is num
                ? (jsonData['record'] as num).toDouble()
                : double.tryParse(jsonData['record'].toString());
          }

          // Parse the honey percentage
          if (jsonData['honey_percentage'] != null) {
            _latestHoneyPercentage = jsonData['honey_percentage'] is num
                ? (jsonData['honey_percentage'] as num).toDouble()
                : double.tryParse(jsonData['honey_percentage'].toString());
          }

          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          throw FormatException(
              'Unexpected API response format for latest weight');
        }
      } else {
        setState(() {
          _errorMessage =
              'Failed to load latest weight: ${response.statusCode} - ${response.reasonPhrase}';
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching latest weight: $error');
      setState(() {
        _errorMessage = 'Error fetching latest weight: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.amber,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: Colors.amber),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _isLoading = true;
        _errorMessage = null;
      });
      await _getWeightData();
    }
  }

  Future<void> _getWeightData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Format dates properly for the API request
      final formattedStartDate = DateFormat('yyyy-MM-dd').format(_startDate);
      final formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate);

      final url =
          'http://196.43.168.57/api/v1/hives/${widget.hiveId}/weight/$formattedStartDate/$formattedEndDate';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        // Debug - print the response structure
        print('Historical API Response: ${response.body}');

        final newDates = <DateTime>[];
        final newWeights = <double?>[];
        final newHoneyPercentages = <double?>[];

        // Check if the response is an object with direct values or has a data array
        if (jsonData is Map &&
            jsonData.containsKey('data') &&
            jsonData['data'] is List) {
          // Structure with a data array
          final dataList = jsonData['data'];
          for (final dataPoint in dataList) {
            if (dataPoint['date_collected'] != null) {
              newDates
                  .add(DateTime.parse(dataPoint['date_collected'].toString()));

              double? weight;
              if (dataPoint['record'] != null) {
                weight = dataPoint['record'] is num
                    ? (dataPoint['record'] as num).toDouble()
                    : double.tryParse(dataPoint['record'].toString());
              }
              newWeights.add(weight);

              double? honeyPercentage;
              if (dataPoint['honey_percentage'] != null) {
                honeyPercentage = dataPoint['honey_percentage'] is num
                    ? (dataPoint['honey_percentage'] as num).toDouble()
                    : double.tryParse(dataPoint['honey_percentage'].toString());
              }
              newHoneyPercentages.add(honeyPercentage);
            }
          }
        } else {
          throw FormatException(
              'Unexpected API response format for historical data');
        }

        setState(() {
          dates = newDates;
          weights = newWeights;
          honeyPercentages = newHoneyPercentages;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage =
              'Failed to load historical data: ${response.statusCode} - ${response.reasonPhrase}';
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error details: $error');
      setState(() {
        _errorMessage = 'Error fetching historical weight data: $error';
        _isLoading = false;
      });
    }
  }

  // Refresh both latest and historical data
  Future<void> _refreshAllData() async {
    await _getLatestWeight();
    await _getWeightData();
  }

  double? _getStatistic(List<double?> values, StatType type) {
    final validValues = values.whereType<double>().toList();
    if (validValues.isEmpty) return null;

    switch (type) {
      case StatType.high:
        return validValues.reduce((a, b) => a > b ? a : b);
      case StatType.low:
        return validValues.reduce((a, b) => a < b ? a : b);
      case StatType.average:
        return validValues.reduce((a, b) => a + b) / validValues.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final chartTextColor = isDarkMode ? 'white' : '#333';

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Hive ${widget.hiveId} Weight',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.amber[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${DateFormat('MMM d, y').format(_startDate)} - '
                        '${DateFormat('MMM d, y').format(_endDate)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      if (_latestDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Latest data: ${DateFormat('MMM d, y HH:mm').format(_latestDate!)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.amber[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            context,
                            icon: LineIcons.calendar,
                            label: 'Change Date',
                            onPressed: () => _selectDate(context),
                          ),
                          IconButton(
                            icon: Icon(
                              LineIcons.syncIcon,
                              color:
                                  isDarkMode ? Colors.white : Colors.amber[800],
                              size: 24,
                            ),
                            onPressed: _refreshAllData,
                            tooltip: 'Refresh Data',
                          ),
                          _buildActionButton(
                            context,
                            icon: LineIcons.alternateCloudDownload,
                            label: 'Export Data',
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Current Measurements Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Current Measurements',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCurrentWidget(
                            context,
                            title: 'Weight',
                            value: _latestWeight,
                            unit: 'kg',
                            icon: Icons.scale,
                            color: Colors.orange,
                          ),
                          _buildCurrentWidget(
                            context,
                            title: 'Honey %',
                            value: _latestHoneyPercentage,
                            unit: '%',
                            icon: Icons.hive,
                            color: Colors.amber,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Error Message
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                ),

              if (!_isLoading && _errorMessage == null) ...[
                const SizedBox(height: 16),

                // Chart Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: isDarkMode ? Colors.grey[800] : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Weight Trend',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (dates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 100),
                            child: Center(
                              child: Text(
                                'No weight data available',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 300,
                            child: Echarts(
                              option: '''
                              {
                                backgroundColor: 'transparent',
                                tooltip: {
                                  trigger: 'axis',
                                  axisPointer: {
                                    type: 'cross',
                                    label: {
                                      backgroundColor: '#6a7985'
                                    }
                                  },
                                  formatter: function(params) {
                                    let result = params[0].axisValueLabel + '<br>';
                                    params.forEach(function(item) {
                                      if (item.value !== null) {
                                        result += '<div>' + item.marker + ' ' + item.seriesName + ': ' +
                                          '<span style="font-weight:bold;color:' + item.color + '">' +
                                          item.value + (item.seriesName === 'Weight' ? 'kg' : '%') + '</span></div>';
                                      }
                                    });
                                    return result;
                                  }
                                },
                                legend: {
                                  data: ['Weight', 'Honey %'],
                                  textStyle: { color: '$chartTextColor' },
                                  itemGap: 20,
                                  right: 10,
                                  top: 10
                                },
                                grid: {
                                  left: '3%',
                                  right: '4%',
                                  bottom: '3%',
                                  containLabel: true
                                },
                                xAxis: {
                                  type: 'category',
                                  boundaryGap: false,
                                  data: ${jsonEncode(dates.map((d) => DateFormat('MMM d').format(d)).toList())},
                                  axisLine: {
                                    lineStyle: {
                                      color: '${isDarkMode ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.3)'}'
                                    }
                                  },
                                  axisLabel: {
                                    color: '$chartTextColor',
                                    fontSize: 12,
                                    rotate: 30
                                  }
                                },
                                yAxis: [
                                  {
                                    type: 'value',
                                    name: 'Weight (kg)',
                                    min: 0,
                                    max: 50,
                                    interval: 10,
                                    axisLine: {
                                      lineStyle: {
                                        color: '${isDarkMode ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.3)'}'
                                      }
                                    },
                                    axisLabel: {
                                      formatter: '{value} kg',
                                      color: '$chartTextColor',
                                      fontSize: 12
                                    },
                                    splitLine: {
                                      lineStyle: {
                                        color: '${isDarkMode ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)'}'
                                      }
                                    }
                                  },
                                  {
                                    type: 'value',
                                    name: 'Honey (%)',
                                    min: 0,
                                    max: 100,
                                    interval: 20,
                                    axisLine: {
                                      lineStyle: {
                                        color: '${isDarkMode ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.3)'}'
                                      }
                                    },
                                    axisLabel: {
                                      formatter: '{value}%',
                                      color: '$chartTextColor',
                                      fontSize: 12
                                    },
                                    splitLine: { show: false }
                                  }
                                ],
                                series: [
                                  {
                                    name: 'Weight',
                                    type: 'line',
                                    smooth: true,
                                    symbol: 'circle',
                                    symbolSize: 6,
                                    data: ${jsonEncode(weights)},
                                    yAxisIndex: 0,
                                    itemStyle: {
                                      color: '#FFA726',
                                      borderColor: '#fff',
                                      borderWidth: 1
                                    },
                                    lineStyle: {
                                      width: 3,
                                      color: '#FFA726'
                                    },
                                    areaStyle: {
                                      color: {
                                        type: 'linear',
                                        x: 0,
                                        y: 0,
                                        x2: 0,
                                        y2: 1,
                                        colorStops: [
                                          { offset: 0, color: 'rgba(255,167,38,0.3)' },
                                          { offset: 1, color: 'rgba(255,167,38,0.1)' }
                                        ]
                                      }
                                    }
                                  },
                                  {
                                    name: 'Honey %',
                                    type: 'line',
                                    smooth: true,
                                    symbol: 'circle',
                                    symbolSize: 6,
                                    data: ${jsonEncode(honeyPercentages)},
                                    yAxisIndex: 1,
                                    itemStyle: {
                                      color: '#FFD54F',
                                      borderColor: '#fff',
                                      borderWidth: 1
                                    },
                                    lineStyle: {
                                      width: 3,
                                      color: '#FFD54F'
                                    },
                                    areaStyle: {
                                      color: {
                                        type: 'linear',
                                        x: 0,
                                        y: 0,
                                        x2: 0,
                                        y2: 1,
                                        colorStops: [
                                          { offset: 0, color: 'rgba(255,213,79,0.3)' },
                                          { offset: 1, color: 'rgba(255,213,79,0.1)' }
                                        ]
                                      }
                                    }
                                  }
                                ]
                              }
                              ''',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Weight Statistics',
                        icon: Icons.scale,
                        color: Colors.orange,
                        current: _latestWeight,
                        high: _getStatistic(weights, StatType.high),
                        low: _getStatistic(weights, StatType.low),
                        avg: _getStatistic(weights, StatType.average),
                        unit: 'kg',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        title: 'Honey Statistics',
                        icon: Icons.hive,
                        color: Colors.amber,
                        current: _latestHoneyPercentage,
                        high: _getStatistic(honeyPercentages, StatType.high),
                        low: _getStatistic(honeyPercentages, StatType.low),
                        avg: _getStatistic(honeyPercentages, StatType.average),
                        unit: '%',
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Information Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDarkMode ? Colors.grey[800] : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hive Weight Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context,
                        icon: Icons.info_outline,
                        text: 'Typical hive weight range: 20-40 kg',
                      ),
                      _buildInfoRow(
                        context,
                        icon: Icons.warning_amber_rounded,
                        text: 'Sudden weight drops may indicate swarming',
                      ),
                      _buildInfoRow(
                        context,
                        icon: Icons.hive,
                        text: 'Honey % indicates harvested honey quantity',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentWidget(
    BuildContext context, {
    required String title,
    required double? value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value != null ? '${value.toStringAsFixed(1)}$unit' : 'N/A',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: value != null
                ? (title == 'Weight'
                    ? (value < 20 ? Colors.red : Colors.orange)
                    : (value < 10 ? Colors.red : Colors.amber))
                : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: isDarkMode ? Colors.white : Colors.amber[800],
        backgroundColor: isDarkMode ? Colors.grey[700] : Colors.amber[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required double? current,
    required double? high,
    required double? low,
    required double? avg,
    required String unit,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (current != null)
              _buildStatItem(
                context,
                label: 'Current',
                value: current,
                unit: unit,
                icon: Icons.thermostat,
                color: color,
              ),
            _buildStatItem(
              context,
              label: 'Highest',
              value: high,
              unit: unit,
              icon: Icons.arrow_upward,
              color: color,
            ),
            _buildStatItem(
              context,
              label: 'Lowest',
              value: low,
              unit: unit,
              icon: Icons.arrow_downward,
              color: color,
            ),
            _buildStatItem(
              context,
              label: 'Average',
              value: avg,
              unit: unit,
              icon: Icons.show_chart,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required double? value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label: ',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          Flexible(
            child: Text(
              value != null ? '${value.toStringAsFixed(1)}$unit' : '--',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum StatType { high, low, average }
