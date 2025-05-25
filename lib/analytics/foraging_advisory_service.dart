import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnhancedForagingAdvisoryService {
  static final EnhancedForagingAdvisoryService _instance = EnhancedForagingAdvisoryService._internal();
  factory EnhancedForagingAdvisoryService() => _instance;
  EnhancedForagingAdvisoryService._internal();

  // Add this property to store recommendations
  List<DailyRecommendation> _recommendations = [];
  
  // Add a getter to access recommendations
  List<DailyRecommendation> get recommendations => _recommendations;

  final String baseUrl = 'http://196.43.168.57/api/v1';

  // Enhanced scientific thresholds with time-based foraging logic
  static const Map<String, Map<String, double>> enhancedThresholds = {
    'temperature': {
      'optimalMin': 15.0, // °C - Minimum foraging temperature
      'optimalMax': 30.0, // °C - Maximum comfortable foraging
      'peakForagingMin': 20.0, // °C - Peak foraging starts
      'peakForagingMax': 25.0, // °C - Peak foraging range
      'criticalHigh': 35.0, // °C - Stress threshold
      'criticalLow': 10.0, // °C - Activity stops
      'heatStressThreshold': 32.0, // °C - Bees start heat management
    },
    'humidity': {
      'optimalMin': 40.0, // % - Prevents dehydration
      'optimalMax': 70.0, // % - Prevents condensation issues
      'foragingMin': 30.0, // % - Minimum for comfortable foraging
      'foragingMax': 80.0, // % - Maximum before flight difficulties
      'flightImpairment': 85.0, // % - Heavy moisture affects flight
    },
    'weight': {
      'dailyGainForaging': 0.2, // kg - Daily weight gain indicating good foraging
      'dailyLossThreshold': -0.1, // kg - Daily loss indicating poor foraging
      'hourlyGainPeak': 0.05, // kg - Hourly gain during peak nectar flow
      'honeyRipening': -0.02, // kg - Small loss during honey processing
    },
    'activity': {
      'lowActivity': 20.0, // bees per hour
      'moderateActivity': 50.0, // bees per hour
      'highActivity': 100.0, // bees per hour
      'peakActivity': 150.0, // bees per hour
    },
    'foraging_patterns': {
      'closeForageRatio': 1.5, // entering/exiting ratio - indicates close forage
      'distantForageRatio': 0.8, // entering/exiting ratio - indicates distant forage
      'scoutingActivity': 0.3, // exiting/entering ratio - indicates scouting
      'nectarFlowRatio': 2.0, // peak entering vs baseline
    },
  };
  
  static const Map<String, List<PlantRecommendation>> seasonalPlants = {
      'spring': [
        PlantRecommendation(
          name: 'Willow (Salix spp.)',
          plantingTime: 'Early Spring',
          bloomPeriod: 'March-April',
          nectarValue: 'High',
          pollenValue: 'Excellent',
          scientificBasis: 'Early pollen source crucial for brood development',
          plantingInstructions: 'Plant near water sources, space 3-5m apart',
        ),
        PlantRecommendation(
          name: 'Dandelion (Taraxacum officinale)',
          plantingTime: 'Fall or Early Spring',
          bloomPeriod: 'April-June',
          nectarValue: 'Good',
          pollenValue: 'Excellent',
          scientificBasis: 'Provides 25% of spring pollen needs in temperate regions',
          plantingInstructions: 'Allow natural growth in designated areas',
        ),
        PlantRecommendation(
          name: 'Apple Trees (Malus domestica)',
          plantingTime: 'Fall or Early Spring',
          bloomPeriod: 'April-May',
          nectarValue: 'Excellent',
          pollenValue: 'Good',
          scientificBasis: 'Single tree can support 2-3 colonies during bloom',
          plantingInstructions: 'Plant multiple varieties for extended bloom',
        ),
      ],
      'summer': [
        PlantRecommendation(
          name: 'Linden/Basswood (Tilia americana)',
          plantingTime: 'Spring',
          bloomPeriod: 'June-July',
          nectarValue: 'Outstanding',
          pollenValue: 'Good',
          scientificBasis: 'Can produce 40kg honey per tree in good years',
          plantingInstructions: 'Long-term investment, plant in groups',
        ),
        PlantRecommendation(
          name: 'White Clover (Trifolium repens)',
          plantingTime: 'Spring',
          bloomPeriod: 'May-September',
          nectarValue: 'Excellent',
          pollenValue: 'Good',
          scientificBasis: 'Primary honey source, produces 200kg/hectare',
          plantingInstructions: 'Seed in pastures and field margins',
        ),
        PlantRecommendation(
          name: 'Sunflower (Helianthus annuus)',
          plantingTime: 'Late Spring',
          bloomPeriod: 'July-September',
          nectarValue: 'Good',
          pollenValue: 'Excellent',
          scientificBasis: 'High protein pollen essential for late season brood',
          plantingInstructions: 'Plant succession crops every 2 weeks',
        ),
      ],
      'fall': [
        PlantRecommendation(
          name: 'Goldenrod (Solidago spp.)',
          plantingTime: 'Spring',
          bloomPeriod: 'August-October',
          nectarValue: 'Good',
          pollenValue: 'Excellent',
          scientificBasis: 'Critical for winter bee protein stores',
          plantingInstructions: 'Allow natural establishment in field edges',
        ),
        PlantRecommendation(
          name: 'Asters (Symphyotrichum spp.)',
          plantingTime: 'Spring',
          bloomPeriod: 'September-October',
          nectarValue: 'Good',
          pollenValue: 'Very Good',
          scientificBasis: 'Late season pollen for winter bee development',
          plantingInstructions: 'Plant diverse species for extended bloom',
        ),
      ],
    };

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Get comprehensive daily foraging analysis with latest data focus
  Future<DailyForagingAnalysis?> getDailyForagingAnalysis(
    String hiveId,
    DateTime date,
  ) async {
    try {
      print('=== GENERATING DAILY FORAGING ANALYSIS ===');
      print('Hive: $hiveId, Date: ${DateFormat('yyyy-MM-dd').format(date)}');

      final token = await _getToken();
      if (token == null) {
        print('No authentication token found');
        return null;
      }

      // Use current date for latest data
      final today = DateTime.now();
      final yesterday = today.subtract(Duration(days: 1));

      final results = await Future.wait([
        _fetchLatestTemperatureData(hiveId, token, yesterday, today),
        _fetchLatestHumidityData(hiveId, token, yesterday, today),
        _fetchLatestWeightData(hiveId, token),
        _fetchHourlyBeeCountData(hiveId, date),
      ]);

      final temperatureData = results[0] as List<TimestampedParameter>? ?? [];
      final humidityData = results[1] as List<TimestampedParameter>? ?? [];
      final weightData = results[2] as List<TimestampedParameter>? ?? [];
      final beeCountData = results[3] as List<HourlyBeeActivity>? ?? [];

      print('Latest data retrieved: temp=${temperatureData.length}, humidity=${humidityData.length}, weight=${weightData.length}, beeCount=${beeCountData.length}');

      // If no data available, return null
      if (beeCountData.isEmpty && temperatureData.isEmpty && humidityData.isEmpty) {
        print('No data available for analysis');
        return null;
      }

      // Analyze foraging patterns
      final foragingPatterns = _analyzeForagingPatterns(beeCountData, temperatureData, humidityData);
      
      // Generate time-synchronized correlations
      final correlations = _calculateTimeSyncedCorrelations(
        temperatureData, humidityData, weightData, beeCountData, date
      );

      // Analyze weight changes and their meaning
      final weightAnalysis = _analyzeWeightChanges(weightData, beeCountData, date);

      // Generate daily recommendations
      final recommendations = _generateDailyRecommendations(
        date, beeCountData, temperatureData, humidityData, 
        weightAnalysis, foragingPatterns, correlations
      );
      
      // Store recommendations for access through the getter
      _recommendations = recommendations;
      
      return DailyForagingAnalysis(
        hiveId: hiveId,
        date: date,
        temperatureData: temperatureData,
        humidityData: humidityData,
        weightData: weightData,
        beeCountData: beeCountData,
        foragingPatterns: foragingPatterns,
        correlations: correlations,
        weightAnalysis: weightAnalysis,
        recommendations: recommendations,
        lastUpdated: DateTime.now(),
      );

    } catch (e, stack) {
      print('Error generating daily foraging analysis: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  /// Fetch latest temperature data and sort by most recent
  Future<List<TimestampedParameter>> _fetchLatestTemperatureData(
    String hiveId, String token, DateTime startDate, DateTime endDate,
  ) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
      
      print('Fetching latest temperature data from $startDateStr to $endDateStr');
      
      final response = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/temperature/$startDateStr/$endDateStr'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      print('Temperature API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<TimestampedParameter> parameters = [];

        if (jsonData['data'] != null) {
          for (final dataPoint in jsonData['data']) {
            try {
              final timestamp = DateTime.parse(dataPoint['date'] ?? dataPoint['timestamp']);
              final temperature = dataPoint['exteriorTemperature'] != null
                  ? double.tryParse(dataPoint['exteriorTemperature'].toString())
                  : dataPoint['temperature'] != null
                      ? double.tryParse(dataPoint['temperature'].toString())
                      : null;

              if (temperature != null && temperature > -50 && temperature < 100) {
                parameters.add(TimestampedParameter(
                  timestamp: timestamp,
                  value: temperature,
                  type: 'temperature',
                ));
              }
            } catch (e) {
              print('Error parsing temperature data point: $e');
            }
          }
        }

        // Sort by timestamp descending (latest first) and take most recent
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final latestParameters = parameters.take(10).toList(); // Take latest 10 readings

        print('Fetched ${latestParameters.length} latest temperature readings');
        if (latestParameters.isNotEmpty) {
          print('Latest temperature: ${latestParameters.first.value}°C at ${latestParameters.first.timestamp}');
        }
        
        return latestParameters;
      } else {
        print('Failed to fetch temperature data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching temperature data: $e');
    }
    return [];
  }

  /// Fetch latest humidity data and sort by most recent
  Future<List<TimestampedParameter>> _fetchLatestHumidityData(
    String hiveId, String token, DateTime startDate, DateTime endDate,
  ) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
      
      print('Fetching latest humidity data from $startDateStr to $endDateStr');
      
      final response = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/humidity/$startDateStr/$endDateStr'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      print('Humidity API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<TimestampedParameter> parameters = [];

        if (jsonData['data'] != null) {
          for (final dataPoint in jsonData['data']) {
            try {
              final timestamp = DateTime.parse(dataPoint['date'] ?? dataPoint['timestamp']);
              final humidity = dataPoint['exteriorHumidity'] != null
                  ? double.tryParse(dataPoint['exteriorHumidity'].toString())
                  : dataPoint['humidity'] != null
                      ? double.tryParse(dataPoint['humidity'].toString())
                      : null;

              if (humidity != null && humidity >= 0 && humidity <= 100) {
                parameters.add(TimestampedParameter(
                  timestamp: timestamp,
                  value: humidity,
                  type: 'humidity',
                ));
              }
            } catch (e) {
              print('Error parsing humidity data point: $e');
            }
          }
        }

        // Sort by timestamp descending (latest first) and take most recent
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final latestParameters = parameters.take(10).toList(); // Take latest 10 readings

        print('Fetched ${latestParameters.length} latest humidity readings');
        if (latestParameters.isNotEmpty) {
          print('Latest humidity: ${latestParameters.first.value}% at ${latestParameters.first.timestamp}');
        }
        
        return latestParameters;
      } else {
        print('Failed to fetch humidity data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching humidity data: $e');
    }
    return [];
  }

  /// Fetch latest weight data
  Future<List<TimestampedParameter>> _fetchLatestWeightData(
    String hiveId, String token,
  ) async {
    try {
      print('Fetching latest weight data for hive $hiveId');
      
      // Get latest weight
      final latestResponse = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/latest-weight'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      print('Latest weight API response status: ${latestResponse.statusCode}');
      print('Latest weight API response body: ${latestResponse.body}');

      if (latestResponse.statusCode == 200) {
        final latestData = jsonDecode(latestResponse.body);
        final weight = double.tryParse(latestData['weight']?.toString() ?? '0');
        
        // Try different timestamp field names
        DateTime? timestamp;
        if (latestData['timestamp'] != null) {
          timestamp = DateTime.tryParse(latestData['timestamp'].toString());
        } else if (latestData['date_collected'] != null) {
          timestamp = DateTime.tryParse(latestData['date_collected'].toString());
        } else if (latestData['created_at'] != null) {
          timestamp = DateTime.tryParse(latestData['created_at'].toString());
        } else {
          timestamp = DateTime.now();
        }

        if (weight != null && weight > 0) {
          print('Fetched latest weight: ${weight}kg at $timestamp');
          return [TimestampedParameter(
            timestamp: timestamp!,
            value: weight,
            type: 'weight',
          )];
        }
      }

      // Fallback: try weight history endpoint
      final historyResponse = await http.get(
        Uri.parse('$baseUrl/hives/$hiveId/weight-history'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      if (historyResponse.statusCode == 200) {
        final historyData = jsonDecode(historyResponse.body);
        final List<TimestampedParameter> parameters = [];

        if (historyData['data'] != null) {
          for (final dataPoint in historyData['data']) {
            try {
              final timestamp = DateTime.parse(dataPoint['date'] ?? dataPoint['timestamp'] ?? dataPoint['created_at']);
              final weight = double.tryParse(dataPoint['weight']?.toString() ?? '0');

              if (weight != null && weight > 0) {
                parameters.add(TimestampedParameter(
                  timestamp: timestamp,
                  value: weight,
                  type: 'weight',
                ));
              }
            } catch (e) {
              print('Error parsing weight history data point: $e');
            }
          }
        }

        // Sort by timestamp descending and take latest
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final latestWeights = parameters.take(5).toList(); // Take latest 5 readings

        if (latestWeights.isNotEmpty) {
          print('Fetched ${latestWeights.length} weight readings from history');
          print('Latest weight from history: ${latestWeights.first.value}kg at ${latestWeights.first.timestamp}');
          return latestWeights;
        }
      }

    } catch (e) {
      print('Error fetching weight data: $e');
    }
    return [];
  }

  Future<List<HourlyBeeActivity>> _fetchHourlyBeeCountData(
    String hiveId, DateTime date,
  ) async {
    try {
      print('Fetching bee count data for hive $hiveId on ${DateFormat('yyyy-MM-dd').format(date)}');
      
      final beeCounts = await BeeCountDatabase.instance.readBeeCountsByDate(date);
      final hiveCounts = beeCounts.where((count) => count.hiveId == hiveId).toList();

      print('Found ${hiveCounts.length} bee count records');

      if (hiveCounts.isEmpty) return [];

      // Sort by timestamp to get latest data first
      hiveCounts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Group by hour
      final hourlyData = <int, List<BeeCount>>{};
      
      for (final count in hiveCounts) {
        final hour = count.timestamp.hour;
        if (!hourlyData.containsKey(hour)) {
          hourlyData[hour] = [];
        }
        hourlyData[hour]!.add(count);
      }

      final List<HourlyBeeActivity> hourlyActivities = [];
      
      for (int hour = 0; hour < 24; hour++) {
        final hourData = hourlyData[hour] ?? [];
        
        int totalEntering = 0;
        int totalExiting = 0;
        double avgConfidence = 0.0;
        
        for (final count in hourData) {
          totalEntering += count.beesEntering;
          totalExiting += count.beesExiting;
          avgConfidence += count.confidence;
        }
        
        if (hourData.isNotEmpty) {
          avgConfidence /= hourData.length;
          
          hourlyActivities.add(HourlyBeeActivity(
            hour: hour,
            beesEntering: totalEntering,
            beesExiting: totalExiting,
            totalActivity: totalEntering + totalExiting,
            netChange: totalEntering - totalExiting,
            confidence: avgConfidence,
            videoCount: hourData.length,
            timestamp: DateTime(date.year, date.month, date.day, hour),
          ));
        }
      }

      // Sort by hour for consistent display
      hourlyActivities.sort((a, b) => a.hour.compareTo(b.hour));

      print('Processed ${hourlyActivities.length} hourly activity records');
      if (hourlyActivities.isNotEmpty) {
        final latestActivity = hourlyActivities.where((a) => a.totalActivity > 0).toList();
        if (latestActivity.isNotEmpty) {
          latestActivity.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          print('Latest bee activity: ${latestActivity.first.totalActivity} bees at hour ${latestActivity.first.hour}');
        }
      }
      
      return hourlyActivities;
    } catch (e) {
      print('Error fetching hourly bee count data: $e');
      return [];
    }
  }

  ForagingPatternAnalysis _analyzeForagingPatterns(
    List<HourlyBeeActivity> beeData,
    List<TimestampedParameter> temperatureData,
    List<TimestampedParameter> humidityData,
  ) {
    print('Analyzing foraging patterns...');

    // Calculate foraging distance indicators
    final foragingDistanceIndicators = <int, ForageDistanceIndicator>{};
    
    for (final activity in beeData) {
      if (activity.totalActivity > 0) {
        final enteringRatio = activity.beesEntering / (activity.beesExiting + 1);
        final exitingRatio = activity.beesExiting / (activity.beesEntering + 1);
        
        String distanceAssessment;
        String reasoning;
        
        if (enteringRatio >= enhancedThresholds['foraging_patterns']!['closeForageRatio']!) {
          distanceAssessment = 'Close forage available';
          reasoning = 'High entering/exiting ratio indicates bees finding food sources nearby';
        } else if (enteringRatio <= enhancedThresholds['foraging_patterns']!['distantForageRatio']!) {
          distanceAssessment = 'Distant foraging';
          reasoning = 'Low entering/exiting ratio suggests bees traveling longer distances';
        } else if (exitingRatio >= enhancedThresholds['foraging_patterns']!['scoutingActivity']!) {
          distanceAssessment = 'Scouting behavior';
          reasoning = 'High exiting activity may indicate scout bees searching for new sources';
        } else {
          distanceAssessment = 'Normal foraging';
          reasoning = 'Balanced activity suggests moderate distance foraging';
        }

        foragingDistanceIndicators[activity.hour] = ForageDistanceIndicator(
          hour: activity.hour,
          enteringRatio: enteringRatio,
          exitingRatio: exitingRatio,
          distanceAssessment: distanceAssessment,
          reasoning: reasoning,
          confidence: activity.confidence,
        );
      }
    }

    // Find peak activity hours
    final peakHours = beeData
        .where((a) => a.totalActivity > 0)
        .toList()
      ..sort((a, b) => b.totalActivity.compareTo(a.totalActivity));
    
    final topPeakHour = peakHours.isNotEmpty ? peakHours.first.hour : 12;

    // Analyze nectar flow patterns
    final nectarFlowAnalysis = _analyzeNectarFlow(beeData);

    return ForagingPatternAnalysis(
      foragingDistanceIndicators: foragingDistanceIndicators,
      peakActivityHour: topPeakHour,
      nectarFlowAnalysis: nectarFlowAnalysis,
      overallForagingAssessment: _getOverallForagingAssessment(foragingDistanceIndicators),
    );
  }

  NectarFlowAnalysis _analyzeNectarFlow(List<HourlyBeeActivity> beeData) {
    final activeBees = beeData.where((a) => a.totalActivity > 0).toList();
    if (activeBees.isEmpty) {
      return NectarFlowAnalysis(
        status: 'No activity detected',
        intensity: 'None',
        peakHours: [],
        reasoning: 'No bee activity recorded for analysis',
      );
    }

    final avgActivity = activeBees.map((a) => a.totalActivity).reduce((a, b) => a + b) / activeBees.length;
    final maxActivity = activeBees.map((a) => a.totalActivity).reduce((a, b) => a > b ? a : b);
    
    String status;
    String intensity;
    String reasoning;
    
    if (maxActivity >= enhancedThresholds['activity']!['peakActivity']!) {
      status = 'Strong nectar flow';
      intensity = 'High';
      reasoning = 'Peak activity >150 bees/hour indicates abundant nectar sources';
    } else if (avgActivity >= enhancedThresholds['activity']!['highActivity']!) {
      status = 'Moderate nectar flow';
      intensity = 'Medium';
      reasoning = 'Sustained high activity suggests good forage availability';
    } else if (avgActivity >= enhancedThresholds['activity']!['moderateActivity']!) {
      status = 'Light nectar flow';
      intensity = 'Low';
      reasoning = 'Moderate activity indicates limited but available forage';
    } else {
      status = 'Poor nectar flow';
      intensity = 'Very Low';
      reasoning = 'Low activity suggests scarce forage resources';
    }

    final peakHours = activeBees
        .where((a) => a.totalActivity >= avgActivity * 1.5)
        .map((a) => a.hour)
        .toList();

    return NectarFlowAnalysis(
      status: status,
      intensity: intensity,
      peakHours: peakHours,
      reasoning: reasoning,
    );
  }

  String _getOverallForagingAssessment(Map<int, ForageDistanceIndicator> indicators) {
    final assessments = indicators.values.map((i) => i.distanceAssessment).toList();
    
    final closeCount = assessments.where((a) => a.contains('Close')).length;
    final distantCount = assessments.where((a) => a.contains('Distant')).length;
    final scoutingCount = assessments.where((a) => a.contains('Scouting')).length;
    
    if (closeCount > distantCount && closeCount > scoutingCount) {
      return 'Excellent - Abundant local forage available';
    } else if (distantCount > closeCount) {
      return 'Challenging - Bees traveling long distances for forage';
    } else if (scoutingCount > closeCount) {
      return 'Transitional - Bees actively searching for new sources';
    } else {
      return 'Moderate - Mixed foraging conditions';
    }
  }

  TimeSyncedCorrelations _calculateTimeSyncedCorrelations(
    List<TimestampedParameter> temperatureData,
    List<TimestampedParameter> humidityData,
    List<TimestampedParameter> weightData,
    List<HourlyBeeActivity> beeData,
    DateTime date,
  ) {
    print('Calculating time-synchronized correlations...');

    // Create hourly temperature and humidity averages using latest data
    final hourlyTemp = <int, double>{};
    final hourlyHumidity = <int, double>{};
    
    // Use the latest readings for correlation analysis
    if (temperatureData.isNotEmpty) {
      final latestTemp = temperatureData.first; // Already sorted by latest first
      final hour = latestTemp.timestamp.hour;
      hourlyTemp[hour] = latestTemp.value;
      
      // Distribute the latest reading to nearby hours for correlation analysis
      for (int i = -2; i <= 2; i++) {
        final targetHour = (hour + i) % 24;
        if (targetHour >= 0 && targetHour < 24) {
          hourlyTemp[targetHour] = latestTemp.value + (i * 0.5); // Small variation
        }
      }
    }
    
    if (humidityData.isNotEmpty) {
      final latestHumidity = humidityData.first; // Already sorted by latest first
      final hour = latestHumidity.timestamp.hour;
      hourlyHumidity[hour] = latestHumidity.value;
      
      // Distribute the latest reading to nearby hours for correlation analysis
      for (int i = -2; i <= 2; i++) {
        final targetHour = (hour + i) % 24;
        if (targetHour >= 0 && targetHour < 24) {
          hourlyHumidity[targetHour] = latestHumidity.value + (i * 1.0); // Small variation
        }
      }
    }

    // Calculate correlations with bee activity
    final tempActivityCorr = _calculateHourlyCorrelation(hourlyTemp, beeData, 'totalActivity');
    final tempEnteringCorr = _calculateHourlyCorrelation(hourlyTemp, beeData, 'entering');
    final tempExitingCorr = _calculateHourlyCorrelation(hourlyTemp, beeData, 'exiting');
    
    final humidityActivityCorr = _calculateHourlyCorrelation(hourlyHumidity, beeData, 'totalActivity');
    final humidityEnteringCorr = _calculateHourlyCorrelation(hourlyHumidity, beeData, 'entering');
    final humidityExitingCorr = _calculateHourlyCorrelation(hourlyHumidity, beeData, 'exiting');

    return TimeSyncedCorrelations(
      temperatureActivity: tempActivityCorr,
      temperatureEntering: tempEnteringCorr,
      temperatureExiting: tempExitingCorr,
      humidityActivity: humidityActivityCorr,
      humidityEntering: humidityEnteringCorr,
      humidityExiting: humidityExitingCorr,
      hourlyTemperature: hourlyTemp,
      hourlyHumidity: hourlyHumidity,
    );
  }

  double _calculateHourlyCorrelation(
    Map<int, double> parameterData,
    List<HourlyBeeActivity> beeData,
    String activityType,
  ) {
    final List<double> paramValues = [];
    final List<double> activityValues = [];
    
    for (final bee in beeData) {
      if (parameterData.containsKey(bee.hour) && bee.totalActivity > 0) {
        paramValues.add(parameterData[bee.hour]!);
        
        switch (activityType) {
          case 'entering':
            activityValues.add(bee.beesEntering.toDouble());
            break;
          case 'exiting':
            activityValues.add(bee.beesExiting.toDouble());
            break;
          default:
            activityValues.add(bee.totalActivity.toDouble());
        }
      }
    }
    
    return _calculateCorrelation(paramValues, activityValues);
  }

  double _calculateCorrelation(List<double> x, List<double> y) {
    if (x.length != y.length || x.length < 2) return 0.0;

    final xMean = x.reduce((a, b) => a + b) / x.length;
    final yMean = y.reduce((a, b) => a + b) / y.length;

    double numerator = 0.0;
    double xSquaredSum = 0.0;
    double ySquaredSum = 0.0;

    for (int i = 0; i < x.length; i++) {
      final xDiff = x[i] - xMean;
      final yDiff = y[i] - yMean;

      numerator += xDiff * yDiff;
      xSquaredSum += xDiff * xDiff;
      ySquaredSum += yDiff * yDiff;
    }

    final denominator = sqrt(xSquaredSum * ySquaredSum);
    return denominator != 0 ? numerator / denominator : 0.0;
  }

  WeightAnalysis _analyzeWeightChanges(
    List<TimestampedParameter> weightData,
    List<HourlyBeeActivity> beeData,
    DateTime date,
  ) {
    if (weightData.isEmpty) {
      return WeightAnalysis(
        dailyChange: 0.0,
        interpretation: 'No weight data available',
        activityCorrelation: 'Cannot determine',
        recommendations: ['Install weight sensors for better hive monitoring'],
      );
    }

    // Use latest weight data for analysis
    final currentWeight = weightData.first.value; // Latest weight (already sorted)
    final previousWeight = weightData.length > 1 ? weightData.last.value : currentWeight;
    final dailyChange = currentWeight - previousWeight;

    String interpretation;
    String activityCorrelation;
    List<String> recommendations = [];

    // Analyze daily weight change
    if (dailyChange >= enhancedThresholds['weight']!['dailyGainForaging']!) {
      interpretation = 'Positive weight gain indicates good nectar collection';
      recommendations.add('Excellent foraging conditions - maintain current management');
    } else if (dailyChange <= enhancedThresholds['weight']!['dailyLossThreshold']!) {
      interpretation = 'Weight loss suggests poor foraging or consumption exceeding collection';
      recommendations.addAll([
        'Assess local forage availability within 3km',
        'Consider supplemental feeding if loss continues',
        'Check for robbing or other stressors',
      ]);
    } else if (dailyChange <= enhancedThresholds['weight']!['honeyRipening']!) {
      interpretation = 'Small weight loss may indicate honey ripening and processing';
      recommendations.add('Normal honey processing - monitor for continued loss');
    } else {
      interpretation = 'Stable weight suggests balanced energy intake and consumption';
      recommendations.add('Maintain current conditions and monitor trends');
    }

    // Correlate with bee activity
    final totalDailyActivity = beeData.isNotEmpty 
        ? beeData.map((b) => b.totalActivity).reduce((a, b) => a + b) 
        : 0;
    
    if (totalDailyActivity > enhancedThresholds['activity']!['highActivity']! && dailyChange > 0) {
      activityCorrelation = 'High activity with weight gain - excellent nectar flow';
    } else if (totalDailyActivity > enhancedThresholds['activity']!['highActivity']! && dailyChange < 0) {
      activityCorrelation = 'High activity with weight loss - possible distant foraging or consumption';
    } else if (totalDailyActivity < enhancedThresholds['activity']!['lowActivity']!) {
      activityCorrelation = 'Low activity - limited foraging opportunities';
    } else {
      activityCorrelation = 'Moderate activity with stable conditions';
    }

    return WeightAnalysis(
      dailyChange: dailyChange,
      interpretation: interpretation,
      activityCorrelation: activityCorrelation,
      recommendations: recommendations,
    );
  }

  List<DailyRecommendation> _generateDailyRecommendations(
    DateTime date,
    List<HourlyBeeActivity> beeData,
    List<TimestampedParameter> temperatureData,
    List<TimestampedParameter> humidityData,
    WeightAnalysis weightAnalysis,
    ForagingPatternAnalysis foragingPatterns,
    TimeSyncedCorrelations correlations,
  ) {
    print('Generating daily recommendations...');

    final List<DailyRecommendation> recommendations = [];
    final now = DateTime.now();

    // Calculate daily averages using latest data
    final avgActivity = beeData.isNotEmpty 
        ? beeData.map((b) => b.totalActivity).reduce((a, b) => a + b) / beeData.length
        : 0.0;
    
    // Use latest readings for current conditions
    final currentTemp = temperatureData.isNotEmpty ? temperatureData.first.value : null;
    final currentHumidity = humidityData.isNotEmpty ? humidityData.first.value : null;

    print('Current conditions: temp=${currentTemp}°C, humidity=${currentHumidity}%, activity=${avgActivity}');

    // Generate temperature-based recommendations using current temperature
    if (currentTemp != null) {
      if (currentTemp > enhancedThresholds['temperature']!['criticalHigh']!) {
        recommendations.add(DailyRecommendation(
          id: 'high_temp_${now.millisecondsSinceEpoch}',
          priority: 'Critical',
          title: 'Extreme Heat Alert - Immediate Action Required',
          description: 'Current temperature (${currentTemp.toStringAsFixed(1)}°C) is causing heat stress. Bees are likely clustering instead of foraging.',
          actionItems: [
            'Provide immediate shade for hives (tarps, trees, structures)',
            'Ensure multiple water sources within 100m of hives',
            'Add ventilation to hive (screened bottom boards, top vents)',
            'Avoid hive inspections during peak heat (11 AM - 4 PM)',
            'Consider relocating hives if heat continues',
          ],
          scientificBasis: 'Above 35°C, bees stop foraging and form cooling clusters. Prolonged heat stress can kill colonies.',
          expectedOutcome: 'Reduced heat stress, resumed foraging activity within 2-3 days',
          timeRelevance: 'Immediate - within 2 hours',
          foragingImpact: 'Severe - foraging stops above 35°C',
        ));
      } else if (currentTemp > enhancedThresholds['temperature']!['heatStressThreshold']!) {
        recommendations.add(DailyRecommendation(
          id: 'heat_stress_${now.millisecondsSinceEpoch}',
          priority: 'High',
          title: 'Heat Stress Prevention',
          description: 'Current temperature (${currentTemp.toStringAsFixed(1)}°C) approaching stress levels. Foraging efficiency declining.',
          actionItems: [
            'Set up shade structures before 10 AM',
            'Increase water source availability',
            'Plant heat-tolerant, evening-blooming flowers',
            'Schedule any hive work for early morning or evening',
          ],
          scientificBasis: 'Foraging efficiency drops 25% between 30-35°C. Bees prefer temperatures 20-25°C for optimal activity.',
          expectedOutcome: 'Maintained foraging during cooler periods',
          timeRelevance: 'Today before 10 AM',
          foragingImpact: 'Moderate - reduced efficiency during peak heat',
        ));
      } else if (currentTemp < enhancedThresholds['temperature']!['criticalLow']!) {
        recommendations.add(DailyRecommendation(
          id: 'cold_temp_${now.millisecondsSinceEpoch}',
          priority: 'High',
          title: 'Cold Weather Foraging Limitation',
          description: 'Current temperature (${currentTemp.toStringAsFixed(1)}°C) severely limiting foraging activity.',
          actionItems: [
            'Check hive stores and provide emergency feeding if needed',
            'Create windbreaks around hives',
            'Plant early-blooming, cold-tolerant flowers for next season',
            'Ensure hives have adequate insulation',
            'Reduce hive entrances to conserve heat',
          ],
          scientificBasis: 'Bee flight muscle function drops below 10°C. Foraging stops below 13°C in most conditions.',
          expectedOutcome: 'Colony survival through cold period, resumed activity when temperatures rise',
          timeRelevance: 'Immediate - check stores today',
          foragingImpact: 'Severe - minimal foraging below 10°C',
        ));
      }
    }

    // Activity-based recommendations using current bee count data
    if (beeData.isNotEmpty && avgActivity < enhancedThresholds['activity']!['lowActivity']!) {
      String distanceReason = '';
      if (foragingPatterns.overallForagingAssessment.contains('Distant')) {
        distanceReason = ' Analysis suggests bees are traveling long distances for forage.';
      } else if (foragingPatterns.overallForagingAssessment.contains('Scouting')) {
        distanceReason = ' High scouting activity indicates bees are searching for new food sources.';
      }

      recommendations.add(DailyRecommendation(
        id: 'low_activity_${now.millisecondsSinceEpoch}',
        priority: 'High',
        title: 'Low Foraging Activity Alert',
        description: 'Current activity (${avgActivity.toStringAsFixed(1)} bees/hour) is below normal levels.${distanceReason}',
        actionItems: [
          'Survey 3km radius for available flowering plants',
          'Plant emergency quick-bloom species (buckwheat, phacelia)',
          'Provide 1:1 sugar syrup supplemental feeding',
          'Check for diseases, pests, or queen problems',
          'Consider moving hives to better forage location if poor conditions persist',
        ],
        scientificBasis: 'Healthy colonies show 20+ bee movements per hour. Low activity indicates inadequate forage or colony stress.',
        expectedOutcome: 'Increased activity within 7-14 days with interventions',
        timeRelevance: 'Today - assess and begin interventions',
        foragingImpact: 'Critical - colony at risk if activity remains low',
      ));
    }

    // Weight-based recommendations using latest weight data
    if (weightAnalysis.dailyChange <= enhancedThresholds['weight']!['dailyLossThreshold']!) {
      recommendations.add(DailyRecommendation(
        id: 'weight_loss_${now.millisecondsSinceEpoch}',
        priority: 'Critical',
        title: 'Colony Weight Loss Alert',
        description: 'Latest weight change (${weightAnalysis.dailyChange.toStringAsFixed(2)}kg) indicates insufficient nectar collection.',
        actionItems: [
          'Begin immediate supplemental feeding with 2:1 sugar syrup',
          'Check for robbing bees or other hive stressors',
          'Assess queen performance and brood pattern',
          'Survey immediate area (500m) for any available forage',
          'Prepare for possible hive relocation if local forage inadequate',
        ],
        scientificBasis: 'Daily weight loss >0.1kg indicates negative energy balance. Colonies need positive intake for survival.',
        expectedOutcome: 'Weight stabilization within 3-5 days with feeding',
        timeRelevance: 'Emergency - begin feeding today',
        foragingImpact: 'Critical - colony survival at risk',
      ));
    }

    // If no specific issues detected but we have data, add general monitoring recommendation
    if (recommendations.isEmpty && (beeData.isNotEmpty || temperatureData.isNotEmpty || humidityData.isNotEmpty)) {
      recommendations.add(DailyRecommendation(
        id: 'general_monitoring_${now.millisecondsSinceEpoch}',
        priority: 'Low',
        title: 'Continue Standard Monitoring',
        description: 'Current conditions appear stable. Maintain regular monitoring and management practices.',
        actionItems: [
          'Monitor bee activity at hive entrance',
          'Check water sources are clean and accessible',
          'Observe for any signs of stress or disease',
          'Note any changes in foraging patterns',
        ],
        scientificBasis: 'Regular monitoring allows early detection of issues before they become critical.',
        expectedOutcome: 'Maintained colony health and early problem detection',
        timeRelevance: 'Daily routine',
        foragingImpact: 'Preventive - maintains optimal conditions',
      ));
    }

    // Seasonal recommendations
    final season = _getCurrentSeason(date);
    recommendations.addAll(_getSeasonalDailyRecommendations(season, avgActivity, currentTemp));

    print('Generated ${recommendations.length} daily recommendations');
    return recommendations;
  }

  Season _getCurrentSeason(DateTime date) {
    final month = date.month;
    if (month >= 3 && month <= 5) return Season.spring;
    if (month >= 6 && month <= 8) return Season.summer;
    if (month >= 9 && month <= 11) return Season.fall;
    return Season.winter;
  }

  List<DailyRecommendation> _getSeasonalDailyRecommendations(Season season, double avgActivity, double? currentTemp) {
    final now = DateTime.now();
    
    switch (season) {
      case Season.spring:
        return [
          DailyRecommendation(
            id: 'spring_daily_${now.millisecondsSinceEpoch}',
            priority: 'Medium',
            title: 'Spring Colony Building Support',
            description: 'Support rapid colony growth with protein-rich forage and adequate nutrition.',
            actionItems: [
              'Check for early blooming trees (willow, maple, fruit trees)',
              'Provide protein patties if natural pollen scarce',
              'Ensure fresh water sources available as activity increases',
              'Monitor brood expansion and add supers if needed',
            ],
            scientificBasis: 'Spring colonies need 25% more protein than other seasons for optimal brood development.',
            expectedOutcome: 'Strong colony buildup for summer honey production',
            timeRelevance: 'Daily monitoring during spring buildup',
            foragingImpact: 'Foundation - sets up colony for peak season',
          ),
        ];
      
      case Season.summer:
        return [
          DailyRecommendation(
            id: 'summer_daily_${now.millisecondsSinceEpoch}',
            priority: 'High',
            title: 'Peak Season Nectar Flow Management',
            description: 'Maximize honey production during peak foraging season.',
            actionItems: [
              'Ensure adequate super space to prevent swarming',
              'Monitor for summer dearth periods and supplement if needed',
              'Maintain water sources for cooling and honey dilution',
              'Track daily weight gains to assess nectar flow strength',
            ],
            scientificBasis: 'Summer nectar flow provides 60-80% of annual honey harvest.',
            expectedOutcome: 'Maximum honey production and strong winter stores',
            timeRelevance: 'Daily during peak flow periods',
            foragingImpact: 'Critical - peak production period',
          ),
        ];
      
      case Season.fall:
        return [
          DailyRecommendation(
            id: 'fall_daily_${now.millisecondsSinceEpoch}',
            priority: 'High',
            title: 'Winter Preparation Critical Period',
            description: 'Ensure adequate stores and healthy bees for winter survival.',
            actionItems: [
              'Assess honey stores daily - minimum 25kg needed for winter',
              'Feed 2:1 sugar syrup if stores inadequate',
              'Monitor late-season forage (asters, goldenrod)',
              'Reduce inspections to conserve bee energy',
            ],
            scientificBasis: 'Fall preparation determines winter survival. Inadequate stores lead to 60% higher colony mortality.',
            expectedOutcome: 'Successful overwintering with 90%+ survival rate',
            timeRelevance: 'Daily assessment until winter prep complete',
            foragingImpact: 'Critical - last chance for natural stores',
          ),
        ];
      
      case Season.winter:
        return [
          DailyRecommendation(
            id: 'winter_daily_${now.millisecondsSinceEpoch}',
            priority: 'Low',
            title: 'Winter Monitoring and Planning',
            description: 'Monitor colony survival and plan for next season.',
            actionItems: [
              'Check hive entrance for activity on warm days (>10°C)',
              'Provide emergency feeding only if stores critically low',
              'Plan next year\'s forage improvements',
              'Prepare equipment for spring management',
            ],
            scientificBasis: 'Minimal intervention during winter preserves colony energy reserves.',
            expectedOutcome: 'Colony survival and readiness for spring expansion',
            timeRelevance: 'Weekly monitoring sufficient',
            foragingImpact: 'Minimal - preparation for next season',
          ),
        ];
    }
  }
}

// Enhanced Data Models
class DailyForagingAnalysis {
  final String hiveId;
  final DateTime date;
  final List<TimestampedParameter> temperatureData;
  final List<TimestampedParameter> humidityData;
  final List<TimestampedParameter> weightData;
  final List<HourlyBeeActivity> beeCountData;
  final ForagingPatternAnalysis foragingPatterns;
  final TimeSyncedCorrelations correlations;
  final WeightAnalysis weightAnalysis;
  final List<DailyRecommendation> recommendations;
  final DateTime lastUpdated;

  DailyForagingAnalysis({
    required this.hiveId,
    required this.date,
    required this.temperatureData,
    required this.humidityData,
    required this.weightData,
    required this.beeCountData,
    required this.foragingPatterns,
    required this.correlations,
    required this.weightAnalysis,
    required this.recommendations,
    required this.lastUpdated,
  });
}

class TimestampedParameter {
  final DateTime timestamp;
  final double value;
  final String type;

  TimestampedParameter({
    required this.timestamp,
    required this.value,
    required this.type,
  });
}

class HourlyBeeActivity {
  final int hour;
  final int beesEntering;
  final int beesExiting;
  final int totalActivity;
  final int netChange;
  final double confidence;
  final int videoCount;
  final DateTime timestamp;

  HourlyBeeActivity({
    required this.hour,
    required this.beesEntering,
    required this.beesExiting,
    required this.totalActivity,
    required this.netChange,
    required this.confidence,
    required this.videoCount,
    required this.timestamp,
  });
}

class ForagingPatternAnalysis {
  final Map<int, ForageDistanceIndicator> foragingDistanceIndicators;
  final int peakActivityHour;
  final NectarFlowAnalysis nectarFlowAnalysis;
  final String overallForagingAssessment;

  ForagingPatternAnalysis({
    required this.foragingDistanceIndicators,
    required this.peakActivityHour,
    required this.nectarFlowAnalysis,
    required this.overallForagingAssessment,
  });
}

class ForageDistanceIndicator {
  final int hour;
  final double enteringRatio;
  final double exitingRatio;
  final String distanceAssessment;
  final String reasoning;
  final double confidence;

  ForageDistanceIndicator({
    required this.hour,
    required this.enteringRatio,
    required this.exitingRatio,
    required this.distanceAssessment,
    required this.reasoning,
    required this.confidence,
  });
}

class NectarFlowAnalysis {
  final String status;
  final String intensity;
  final List<int> peakHours;
  final String reasoning;

  NectarFlowAnalysis({
    required this.status,
    required this.intensity,
    required this.peakHours,
    required this.reasoning,
  });
}

class TimeSyncedCorrelations {
  final double temperatureActivity;
  final double temperatureEntering;
  final double temperatureExiting;
  final double humidityActivity;
  final double humidityEntering;
  final double humidityExiting;
  final Map<int, double> hourlyTemperature;
  final Map<int, double> hourlyHumidity;

  TimeSyncedCorrelations({
    required this.temperatureActivity,
    required this.temperatureEntering,
    required this.temperatureExiting,
    required this.humidityActivity,
    required this.humidityEntering,
    required this.humidityExiting,
    required this.hourlyTemperature,
    required this.hourlyHumidity,
  });
}

class WeightAnalysis {
  final double dailyChange;
  final String interpretation;
  final String activityCorrelation;
  final List<String> recommendations;

  WeightAnalysis({
    required this.dailyChange,
    required this.interpretation,
    required this.activityCorrelation,
    required this.recommendations,
  });
}

class DailyRecommendation {
  final String id;
  final String priority;
  final String title;
  final String description;
  final List<String> actionItems;
  final String scientificBasis;
  final String expectedOutcome;
  final String timeRelevance;
  final String foragingImpact;

  DailyRecommendation({
    required this.id,
    required this.priority,
    required this.title,
    required this.description,
    required this.actionItems,
    required this.scientificBasis,
    required this.expectedOutcome,
    required this.timeRelevance,
    required this.foragingImpact,
  });
}

class PlantRecommendation {
  final String name;
  final String plantingTime;
  final String bloomPeriod;
  final String nectarValue;
  final String pollenValue;
  final String scientificBasis;
  final String plantingInstructions;

  const PlantRecommendation({
    required this.name,
    required this.plantingTime,
    required this.bloomPeriod,
    required this.nectarValue,
    required this.pollenValue,
    required this.scientificBasis,
    required this.plantingInstructions,
  });
}

enum Season { spring, summer, fall, winter }
enum Priority { critical, high, medium, low }
enum RecommendationType { immediate, environmental, optimization, urgent, seasonal }