import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnhancedForagingAdvisoryService {
  static final EnhancedForagingAdvisoryService _instance =
      EnhancedForagingAdvisoryService._internal();
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
      'dailyGainForaging':
          0.2, // kg - Daily weight gain indicating good foraging
      'dailyLossThreshold': -0.1, // kg - Daily loss indicating poor foraging
      'hourlyGainPeak': 0.05, // kg - Hourly gain during peak nectar flow
      'honeyRipening': -0.02, // kg - Small loss during honey processing
    },
    'activity': {
      'lowActivity': 20.0, // bees per hour
      'moderateActivity': 50.0, // bees per hour
      'highActivity': 100.0, // bees per hour
      'peakActivity': 150.0, // bees per hour
      'weeklyDeclineThreshold': -25.0, // % decline indicating issues
      'weeklyGrowthTarget': 10.0, // % growth for healthy colony
    },
    'foraging_patterns': {
      'closeForageRatio':
          1.5, // entering/exiting ratio - indicates close forage
      'distantForageRatio':
          0.8, // entering/exiting ratio - indicates distant forage
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
        scientificBasis:
            'Provides 25% of spring pollen needs in temperate regions',
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

  /// Get comprehensive daily foraging analysis with enhanced time series insights
  Future<DailyForagingAnalysis?> getDailyForagingAnalysis(
    String hiveId,
    DateTime date,
  ) async {
    try {
      print(' GENERATING ENHANCED DAILY FORAGING ANALYSIS ');
      print('Hive: $hiveId, Date: ${DateFormat('yyyy-MM-dd').format(date)}');

      final token = await _getToken();
      if (token == null) {
        print('No authentication token found');
        return null;
      }

      // Use the selected date for data fetching
      final startDate = DateTime(date.year, date.month, date.day);
      final endDate = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final results = await Future.wait([
        _fetchLatestTemperatureData(hiveId, token, startDate, endDate),
        _fetchLatestHumidityData(hiveId, token, startDate, endDate),
        _fetchLatestWeightData(hiveId, token),
        _fetchHourlyBeeCountData(hiveId, date),
        _fetchWeeklyTrendData(hiveId, date), // NEW: Get weekly data for trends
      ]);

      final temperatureData = results[0] as List<TimestampedParameter>? ?? [];
      final humidityData = results[1] as List<TimestampedParameter>? ?? [];
      final weightData = results[2] as List<TimestampedParameter>? ?? [];
      final beeCountData = results[3] as List<HourlyBeeActivity>? ?? [];
      final weeklyTrendData =
          results[4] as WeeklyTrendAnalysis? ?? WeeklyTrendAnalysis.empty();

      print(
        'Enhanced data retrieved for ${DateFormat('yyyy-MM-dd').format(date)}: temp=${temperatureData.length}, humidity=${humidityData.length}, weight=${weightData.length}, beeCount=${beeCountData.length}',
      );

      // If no data available, return null
      if (beeCountData.isEmpty &&
          temperatureData.isEmpty &&
          humidityData.isEmpty) {
        print('No data available for analysis');
        return null;
      }

      // Analyze foraging patterns with enhanced time series context
      final foragingPatterns = _analyzeForagingPatterns(
        beeCountData,
        temperatureData,
        humidityData,
      );

      // Generate time-synchronized correlations
      final correlations = _calculateTimeSyncedCorrelations(
        temperatureData,
        humidityData,
        weightData,
        beeCountData,
        date,
      );

      // Analyze weight changes and their meaning
      final weightAnalysis = _analyzeWeightChanges(
        weightData,
        beeCountData,
        date,
      );

      // Generate enhanced daily recommendations with time series insights
      final recommendations = _generateEnhancedDailyRecommendations(
        date,
        beeCountData,
        temperatureData,
        humidityData,
        weightAnalysis,
        foragingPatterns,
        correlations,
        weeklyTrendData,
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
        weeklyTrends: weeklyTrendData, // NEW: Add weekly trends
      );
    } catch (e, stack) {
      print('Error generating enhanced daily foraging analysis: $e');
      print('Stack trace: $stack');
      return null;
    }
  }

  /// NEW: Fetch weekly trend data for enhanced recommendations
  Future<WeeklyTrendAnalysis> _fetchWeeklyTrendData(
    String hiveId,
    DateTime currentDate,
  ) async {
    try {
      final endDate = currentDate;
      final startDate = currentDate.subtract(Duration(days: 7));

      // Get bee counts for the past week
      final weeklyBeeCounts = await BeeCountDatabase.instance
          .getBeeCountsForDateRange(hiveId, startDate, endDate);

      if (weeklyBeeCounts.isEmpty) {
        return WeeklyTrendAnalysis.empty();
      }

      // Group by day and calculate daily totals
      final Map<DateTime, int> dailyTotals = {};
      for (final count in weeklyBeeCounts) {
        final day = DateTime(
          count.timestamp.year,
          count.timestamp.month,
          count.timestamp.day,
        );
        dailyTotals[day] =
            (dailyTotals[day] ?? 0) + count.beesEntering + count.beesExiting;
      }

      final sortedDays = dailyTotals.keys.toList()..sort();
      final dailyValues = sortedDays.map((day) => dailyTotals[day]!).toList();

      if (dailyValues.length < 2) {
        return WeeklyTrendAnalysis.empty();
      }

      // Calculate trends
      final firstHalfAvg =
          dailyValues.take(dailyValues.length ~/ 2).reduce((a, b) => a + b) /
          (dailyValues.length ~/ 2);
      final secondHalfAvg =
          dailyValues.skip(dailyValues.length ~/ 2).reduce((a, b) => a + b) /
          (dailyValues.length - dailyValues.length ~/ 2);
      final trendChange = ((secondHalfAvg - firstHalfAvg) / firstHalfAvg) * 100;

      final weeklyAverage =
          dailyValues.reduce((a, b) => a + b) / dailyValues.length;
      final maxDay = dailyValues.reduce((a, b) => a > b ? a : b);
      final minDay = dailyValues.reduce((a, b) => a < b ? a : b);
      final variance = _calculateVariance(dailyValues);

      return WeeklyTrendAnalysis(
        averageDailyActivity: weeklyAverage,
        trendPercentage: trendChange,
        maxDayActivity: maxDay,
        minDayActivity: minDay,
        consistency:
            100 - (variance / weeklyAverage * 100), // Higher = more consistent
        daysWithData: dailyValues.length,
        totalWeeklyActivity: dailyValues.reduce((a, b) => a + b),
      );
    } catch (e) {
      print('Error fetching weekly trend data: $e');
      return WeeklyTrendAnalysis.empty();
    }
  }

  double _calculateVariance(List<int> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((value) => pow(value - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  // Enhanced recommendations with time series insights
  List<DailyRecommendation> _generateEnhancedDailyRecommendations(
    DateTime date,
    List<HourlyBeeActivity> beeData,
    List<TimestampedParameter> temperatureData,
    List<TimestampedParameter> humidityData,
    WeightAnalysis weightAnalysis,
    ForagingPatternAnalysis foragingPatterns,
    TimeSyncedCorrelations correlations,
    WeeklyTrendAnalysis weeklyTrends,
  ) {
    print(
      'Generating enhanced daily recommendations with time series insights...',
    );

    final List<DailyRecommendation> recommendations = [];
    final now = DateTime.now();

    // Calculate daily averages using latest data
    final avgActivity =
        beeData.isNotEmpty
            ? beeData.map((b) => b.totalActivity).reduce((a, b) => a + b) /
                beeData.length
            : 0.0;

    final totalDailyActivity =
        beeData.isNotEmpty
            ? beeData.map((b) => b.totalActivity).reduce((a, b) => a + b)
            : 0;

    // Use latest readings for current conditions
    final currentTemp =
        temperatureData.isNotEmpty ? temperatureData.first.value : null;
    final currentHumidity =
        humidityData.isNotEmpty ? humidityData.first.value : null;

    print(
      'Enhanced conditions: temp=${currentTemp}°C, humidity=${currentHumidity}%, activity=${avgActivity}, weekly trend=${weeklyTrends.trendPercentage.toStringAsFixed(1)}%',
    );

    // ENHANCED: Weekly trend-based recommendations
    if (weeklyTrends.daysWithData >= 5) {
      if (weeklyTrends.trendPercentage <=
          enhancedThresholds['activity']!['weeklyDeclineThreshold']!) {
        recommendations.add(
          DailyRecommendation(
            id: 'weekly_decline_${now.millisecondsSinceEpoch}',
            priority: 'Critical',
            title: 'Significant Weekly Activity Decline Detected',
            description:
                'Activity has declined ${weeklyTrends.trendPercentage.abs().toStringAsFixed(1)}% over the past week, indicating potential colony stress or environmental issues.',
            actionItems: [
              'Conduct immediate hive inspection for disease, pests, or queen issues',
              'Check local forage availability within 3km radius',
              'Monitor for robbing behavior from other colonies',
              'Consider emergency supplemental feeding if weight is declining',
              'Document any recent environmental changes (pesticide use, construction, etc.)',
              'Assess ventilation and reduce hive entrance if necessary',
            ],
            scientificBasis:
                'Weekly activity decline >25% typically indicates colony stress, disease onset, or resource depletion. Early intervention critical for colony survival.',
            expectedOutcome:
                'Activity stabilization within 5-7 days if environmental; 2-3 weeks if colony health issue',
            timeRelevance: 'Immediate - inspect within 24 hours',
            foragingImpact: 'Critical - colony viability at risk',
          ),
        );
      } else if (weeklyTrends.consistency < 50) {
        recommendations.add(
          DailyRecommendation(
            id: 'activity_inconsistency_${now.millisecondsSinceEpoch}',
            priority: 'High',
            title: 'Inconsistent Weekly Activity Patterns',
            description:
                'High day-to-day variation (${(100 - weeklyTrends.consistency).toStringAsFixed(1)}% variance) suggests environmental stress or unstable foraging conditions.',
            actionItems: [
              'Monitor weather patterns and correlate with activity drops',
              'Survey surrounding area for intermittent disturbances',
              'Check hive entrance for obstructions or disturbances',
              'Consider windbreak installation if weather-related',
              'Plant diverse, succession-blooming flowers for stable forage',
            ],
            scientificBasis:
                'Consistent activity patterns indicate stable environmental conditions. High variance suggests external stressors affecting foraging.',
            expectedOutcome:
                'More consistent activity patterns within 1-2 weeks',
            timeRelevance: 'This week - implement stabilizing measures',
            foragingImpact:
                'Moderate - efficiency reduced by inconsistent conditions',
          ),
        );
      } else if (weeklyTrends.trendPercentage >=
          enhancedThresholds['activity']!['weeklyGrowthTarget']!) {
        recommendations.add(
          DailyRecommendation(
            id: 'positive_growth_${now.millisecondsSinceEpoch}',
            priority: 'Low',
            title: 'Excellent Weekly Growth Trend',
            description:
                'Activity has increased ${weeklyTrends.trendPercentage.toStringAsFixed(1)}% over the past week, indicating improving conditions.',
            actionItems: [
              'Continue current management practices',
              'Document successful strategies for future reference',
              'Consider adding supers if weight is increasing',
              'Monitor for potential swarming if growth continues',
              'Expand successful forage plantings in the area',
            ],
            scientificBasis:
                'Sustained weekly growth >10% indicates optimal foraging conditions and healthy colony expansion.',
            expectedOutcome: 'Continued growth and potential honey surplus',
            timeRelevance: 'Ongoing monitoring and expansion',
            foragingImpact: 'Excellent - optimal conditions for productivity',
          ),
        );
      }
    }

    // ENHANCED: Temperature-based recommendations with trend context
    if (currentTemp != null) {
      if (currentTemp > enhancedThresholds['temperature']!['criticalHigh']!) {
        final tempImpact =
            weeklyTrends.daysWithData > 0
                ? 'Weekly average activity ${weeklyTrends.averageDailyActivity.toInt()} suggests heat stress is limiting productivity.'
                : 'Immediate heat stress intervention required.';

        recommendations.add(
          DailyRecommendation(
            id: 'extreme_heat_trend_${now.millisecondsSinceEpoch}',
            priority: 'Critical',
            title: 'Extreme Heat Alert with Activity Impact',
            description:
                'Current temperature (${currentTemp.toStringAsFixed(1)}°C) is causing severe heat stress. $tempImpact',
            actionItems: [
              'Provide immediate shade for hives (emergency tarps, umbrellas)',
              'Ensure multiple water sources within 50m of hives',
              'Add emergency ventilation (screened bottom boards, top vents)',
              'Avoid any hive disturbance during heat (no inspections)',
              'Consider emergency relocation if heat wave continues >3 days',
              'Monitor for bee clustering outside hive (sign of overheating)',
            ],
            scientificBasis:
                'Above 35°C, bee flight muscles cease function and colonies risk thermal death. Emergency cooling prevents colony collapse.',
            expectedOutcome:
                'Temperature regulation within 2-4 hours, normal activity resumption when <32°C',
            timeRelevance: 'EMERGENCY - within 1 hour',
            foragingImpact: 'Severe - complete foraging cessation above 35°C',
          ),
        );
      }
    }

    // ENHANCED: Activity-based recommendations with weekly context
    if (totalDailyActivity < enhancedThresholds['activity']!['lowActivity']! &&
        weeklyTrends.daysWithData > 0) {
      String weeklyContext = '';
      if (weeklyTrends.averageDailyActivity <
          enhancedThresholds['activity']!['lowActivity']!) {
        weeklyContext =
            'This is part of a weekly pattern of low activity (avg: ${weeklyTrends.averageDailyActivity.toInt()}/day).';
      } else {
        weeklyContext =
            'This represents a drop from weekly average of ${weeklyTrends.averageDailyActivity.toInt()} bees/day.';
      }

      recommendations.add(
        DailyRecommendation(
          id: 'low_activity_trend_${now.millisecondsSinceEpoch}',
          priority: 'High',
          title: 'Low Activity Alert with Weekly Context',
          description:
              'Current activity (${totalDailyActivity} bees today) is critically low. $weeklyContext',
          actionItems: [
            'Immediate hive inspection for queen presence and brood pattern',
            'Check for disease signs: varroa mites, deformed wing virus, nosema',
            'Survey 2km radius for available flowering plants',
            'Begin emergency feeding with 1:1 sugar syrup if no natural forage',
            'Monitor entrance for robbing behavior',
            'Consider combining with stronger colony if population severely depleted',
            'Test for pesticide exposure if agricultural area nearby',
          ],
          scientificBasis:
              'Activity <20 bees/day indicates colony stress, disease, or failing queen. Without intervention, colony failure likely within 2-4 weeks.',
          expectedOutcome:
              'Activity increase within 3-7 days if treatable cause; colony stabilization within 2-3 weeks',
          timeRelevance: 'Urgent - inspect today',
          foragingImpact: 'Critical - colony survival threatened',
        ),
      );
    }

    // ENHANCED: Weight analysis with activity correlation
    if (weightAnalysis.dailyChange <=
        enhancedThresholds['weight']!['dailyLossThreshold']!) {
      String activityCorrelation = '';
      if (totalDailyActivity >
          enhancedThresholds['activity']!['moderateActivity']!) {
        activityCorrelation =
            'Despite moderate activity levels, weight loss suggests poor forage quality or distant food sources.';
      } else {
        activityCorrelation =
            'Low activity combined with weight loss indicates serious colony stress.';
      }

      recommendations.add(
        DailyRecommendation(
          id: 'weight_loss_activity_${now.millisecondsSinceEpoch}',
          priority: 'Critical',
          title: 'Weight Loss with Activity Analysis',
          description:
              'Weight loss of ${weightAnalysis.dailyChange.toStringAsFixed(2)}kg detected. $activityCorrelation',
          actionItems: [
            'Begin immediate emergency feeding with 2:1 sugar syrup',
            'Provide protein supplement (pollen patties) if brood present',
            'Check for leaks in hive that could indicate robbing',
            'Assess local forage within 1km - may need to relocate hive',
            'Monitor feeding uptake - if poor, check for disease',
            'Consider combining with stronger colony if population critical',
            'Document all interventions for tracking effectiveness',
          ],
          scientificBasis:
              'Daily weight loss >0.1kg indicates negative energy balance. Combined with activity data, reveals whether issue is environmental or colony health.',
          expectedOutcome:
              'Weight stabilization within 3-5 days with feeding; activity increase within 1 week',
          timeRelevance: 'Emergency - begin feeding immediately',
          foragingImpact: 'Critical - colony survival at immediate risk',
        ),
      );
    }

    // ENHANCED: Seasonal recommendations with trend awareness
    final season = _getCurrentSeason(date);
    final seasonalRecs = _getEnhancedSeasonalRecommendations(
      season,
      weeklyTrends,
      avgActivity,
      currentTemp,
    );
    recommendations.addAll(seasonalRecs);

    // ENHANCED: Environmental correlation recommendations
    if (correlations.temperatureActivity.abs() > 0.6) {
      final correlationType =
          correlations.temperatureActivity > 0 ? 'positive' : 'negative';
      recommendations.add(
        DailyRecommendation(
          id: 'temp_correlation_${now.millisecondsSinceEpoch}',
          priority: 'Medium',
          title: 'Strong Temperature-Activity Correlation Detected',
          description:
              'Your hive shows strong $correlationType correlation (${correlations.temperatureActivity.toStringAsFixed(2)}) with temperature.',
          actionItems: [
            'Use weather forecasts to predict optimal foraging windows',
            correlationType == 'positive'
                ? 'Schedule hive work during warm periods for minimal disruption'
                : 'Provide cooling measures during hot weather',
            'Plan seasonal activities based on temperature patterns',
            'Consider hive relocation if temperature extremes are frequent',
            'Monitor temperature thresholds for your specific location',
          ],
          scientificBasis:
              'Strong temperature correlation allows predictive management. Understanding your hive\'s temperature response optimizes intervention timing.',
          expectedOutcome:
              'Improved timing of management activities and 15-20% efficiency gains',
          timeRelevance: 'Ongoing - apply to future management decisions',
          foragingImpact:
              'Optimization - better timing for maximum productivity',
        ),
      );
    }

    // NEW: Proactive recommendations based on trends
    if (weeklyTrends.daysWithData >= 5 &&
        weeklyTrends.trendPercentage > 0 &&
        weeklyTrends.trendPercentage < 5) {
      recommendations.add(
        DailyRecommendation(
          id: 'proactive_optimization_${now.millisecondsSinceEpoch}',
          priority: 'Low',
          title: 'Stable Conditions - Optimization Opportunity',
          description:
              'Stable weekly activity with slight growth (${weeklyTrends.trendPercentage.toStringAsFixed(1)}%) presents optimization opportunities.',
          actionItems: [
            'Plant additional forage species for extended bloom periods',
            'Consider adding a second hive if conditions support growth',
            'Implement integrated pest management preventively',
            'Establish water sources at optimal distances (100-200m)',
            'Document peak activity times for optimal scheduling',
            'Consider value-added activities like queen rearing',
          ],
          scientificBasis:
              'Stable conditions provide optimal timing for improvements. Proactive management during stable periods prevents future issues.',
          expectedOutcome:
              'Enhanced productivity and resilience for future challenges',
          timeRelevance: 'Next 2-4 weeks during stable conditions',
          foragingImpact:
              'Enhancement - building capacity for increased productivity',
        ),
      );
    }

    print(
      'Generated ${recommendations.length} enhanced daily recommendations with time series insights',
    );
    return recommendations;
  }

  Season _getCurrentSeason(DateTime date) {
    final month = date.month;
    if (month >= 3 && month <= 5) return Season.spring;
    if (month >= 6 && month <= 8) return Season.summer;
    if (month >= 9 && month <= 11) return Season.fall;
    return Season.winter;
  }

  List<DailyRecommendation> _getEnhancedSeasonalRecommendations(
    Season season,
    WeeklyTrendAnalysis weeklyTrends,
    double avgActivity,
    double? currentTemp,
  ) {
    final now = DateTime.now();

    switch (season) {
      case Season.spring:
        if (weeklyTrends.trendPercentage > 15) {
          return [
            DailyRecommendation(
              id: 'spring_rapid_growth_${now.millisecondsSinceEpoch}',
              priority: 'High',
              title: 'Rapid Spring Buildup - Swarm Prevention',
              description:
                  'Rapid activity increase (${weeklyTrends.trendPercentage.toStringAsFixed(1)}%) indicates strong spring buildup requiring swarm management.',
              actionItems: [
                'Add supers immediately to provide space for growing population',
                'Check for queen cells weekly - remove if swarming not desired',
                'Ensure adequate ventilation for expanding cluster',
                'Consider making splits if colony becomes overcrowded',
                'Provide abundant protein sources (pollen patties if natural pollen scarce)',
                'Monitor brood pattern for signs of healthy queen and expansion',
              ],
              scientificBasis:
                  'Rapid spring growth >15% weekly often leads to swarming within 3-4 weeks without space management.',
              expectedOutcome:
                  'Controlled expansion without swarming, maximum honey production potential',
              timeRelevance: 'Immediate - space management critical',
              foragingImpact:
                  'Critical - prevents loss of foragers through swarming',
            ),
          ];
        }
        break;

      case Season.summer:
        if (weeklyTrends.averageDailyActivity > 150 &&
            currentTemp != null &&
            currentTemp > 30) {
          return [
            DailyRecommendation(
              id: 'summer_peak_heat_${now.millisecondsSinceEpoch}',
              priority: 'High',
              title: 'Peak Summer Activity with Heat Stress Risk',
              description:
                  'High activity (${weeklyTrends.averageDailyActivity.toInt()}/day) during hot weather increases heat stress risk.',
              actionItems: [
                'Install permanent shade structures before next heat wave',
                'Provide multiple water sources with landing boards',
                'Ensure top ventilation is adequate for high activity levels',
                'Schedule honey harvests for early morning or evening',
                'Monitor for signs of cooling behavior (bearding outside hive)',
                'Consider increasing hive entrance size if traffic congested',
              ],
              scientificBasis:
                  'High activity during summer heat can overwhelm hive cooling capacity, leading to brood death and honey crystallization.',
              expectedOutcome:
                  'Maintained productivity during heat waves, prevented heat-related losses',
              timeRelevance: 'Before next temperature spike >32°C',
              foragingImpact:
                  'Critical - maintains foraging efficiency during peak season',
            ),
          ];
        }
        break;

      case Season.fall:
        if (weeklyTrends.trendPercentage < -10) {
          return [
            DailyRecommendation(
              id: 'fall_rapid_decline_${now.millisecondsSinceEpoch}',
              priority: 'Critical',
              title: 'Rapid Fall Activity Decline - Winter Prep Emergency',
              description:
                  'Activity declining ${weeklyTrends.trendPercentage.abs().toStringAsFixed(1)}% weekly - accelerated winter preparation needed.',
              actionItems: [
                'Assess honey stores immediately - minimum 25kg needed for winter',
                'Begin heavy feeding with 2:1 sugar syrup if stores inadequate',
                'Treat for varroa mites if not done in past month',
                'Reduce hive entrance to small opening for easier defense',
                'Combine weak colonies with stronger ones if population <20,000 bees',
                'Install mouse guards and windbreaks before first freeze',
                'Stop all inspections once nighttime temperatures <10°C consistently',
              ],
              scientificBasis:
                  'Rapid fall decline >10% weekly indicates inadequate winter preparation. Colonies need 6-8 weeks for proper clustering.',
              expectedOutcome:
                  'Successful overwintering with 85%+ survival rate',
              timeRelevance:
                  'Emergency - complete within 3 weeks before cold weather',
              foragingImpact:
                  'Critical - last opportunity for natural store building',
            ),
          ];
        }
        break;

      case Season.winter:
        if (weeklyTrends.daysWithData > 0 &&
            weeklyTrends.averageDailyActivity > 10) {
          return [
            DailyRecommendation(
              id: 'winter_activity_${now.millisecondsSinceEpoch}',
              priority: 'Medium',
              title: 'Unexpected Winter Activity Detected',
              description:
                  'Activity detected during winter months (${weeklyTrends.averageDailyActivity.toInt()}/day) requires monitoring.',
              actionItems: [
                'Check for adequate stores if bees are flying frequently',
                'Ensure entrance is not blocked by ice or snow',
                'Provide emergency feeding only if stores critically low',
                'Monitor for signs of robbing from other colonies',
                'Do not open hive unless temperature >15°C for several hours',
                'Plan for spring management based on winter activity levels',
              ],
              scientificBasis:
                  'Winter activity can indicate stress, robbing, or early buildup. Excessive activity depletes winter stores.',
              expectedOutcome:
                  'Successful winter survival and spring readiness',
              timeRelevance: 'Monitor weekly, intervene only if critical',
              foragingImpact:
                  'Conservation - prevent unnecessary energy expenditure',
            ),
          ];
        }
        break;
    }

    return [];
  }

  // Include all the existing methods from the original file with the same functionality
  // ... (keeping the same method signatures and logic)

  /// Fetch latest temperature data and sort by most recent
  Future<List<TimestampedParameter>> _fetchLatestTemperatureData(
    String hiveId,
    String token,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      print('Fetching temperature data from $startDateStr to $endDateStr');

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/hives/$hiveId/temperature/$startDateStr/$endDateStr',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 30));

      print('Temperature API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<TimestampedParameter> parameters = [];

        if (jsonData['data'] != null) {
          for (final dataPoint in jsonData['data']) {
            try {
              final timestamp = DateTime.parse(
                dataPoint['date'] ?? dataPoint['timestamp'],
              );
              final temperature =
                  dataPoint['exteriorTemperature'] != null
                      ? double.tryParse(
                        dataPoint['exteriorTemperature'].toString(),
                      )
                      : dataPoint['temperature'] != null
                      ? double.tryParse(dataPoint['temperature'].toString())
                      : null;

              if (temperature != null &&
                  temperature > -50 &&
                  temperature < 100) {
                parameters.add(
                  TimestampedParameter(
                    timestamp: timestamp,
                    value: temperature,
                    type: 'temperature',
                  ),
                );
              }
            } catch (e) {
              print('Error parsing temperature data point: $e');
            }
          }
        }

        // Sort by timestamp descending (latest first)
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        print('Fetched ${parameters.length} temperature readings');
        if (parameters.isNotEmpty) {
          print(
            'Latest temperature: ${parameters.first.value}°C at ${parameters.first.timestamp}',
          );
          print(
            'Oldest temperature: ${parameters.last.value}°C at ${parameters.last.timestamp}',
          );
        }

        return parameters;
      } else {
        print('Failed to fetch temperature data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching temperature data: $e');
    }
    return [];
  }

  /// Fetch humidity data for the entire selected date
  Future<List<TimestampedParameter>> _fetchLatestHumidityData(
    String hiveId,
    String token,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      print('Fetching humidity data from $startDateStr to $endDateStr');

      final response = await http
          .get(
            Uri.parse(
              '$baseUrl/hives/$hiveId/humidity/$startDateStr/$endDateStr',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 30));

      print('Humidity API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<TimestampedParameter> parameters = [];

        if (jsonData['data'] != null) {
          for (final dataPoint in jsonData['data']) {
            try {
              final timestamp = DateTime.parse(
                dataPoint['date'] ?? dataPoint['timestamp'],
              );
              final humidity =
                  dataPoint['exteriorHumidity'] != null
                      ? double.tryParse(
                        dataPoint['exteriorHumidity'].toString(),
                      )
                      : dataPoint['humidity'] != null
                      ? double.tryParse(dataPoint['humidity'].toString())
                      : null;

              if (humidity != null && humidity >= 0 && humidity <= 100) {
                parameters.add(
                  TimestampedParameter(
                    timestamp: timestamp,
                    value: humidity,
                    type: 'humidity',
                  ),
                );
              }
            } catch (e) {
              print('Error parsing humidity data point: $e');
            }
          }
        }

        // Sort by timestamp descending (latest first)
        parameters.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        print('Fetched ${parameters.length} humidity readings');
        if (parameters.isNotEmpty) {
          print(
            'Latest humidity: ${parameters.first.value}% at ${parameters.first.timestamp}',
          );
          print(
            'Oldest humidity: ${parameters.last.value}% at ${parameters.last.timestamp}',
          );
        }

        return parameters;
      } else {
        print('Failed to fetch humidity data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching humidity data: $e');
    }
    return [];
  }

  Future<List<TimestampedParameter>> _fetchLatestWeightData(
    String hiveId,
    String token,
  ) async {
    try {
      print('Fetching latest weight data for hive $hiveId');

      // Get latest weight
      final latestResponse = await http
          .get(
            Uri.parse('$baseUrl/hives/$hiveId/latest-weight'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(Duration(seconds: 30));

      print('Latest weight API response status: ${latestResponse.statusCode}');

      if (latestResponse.statusCode == 200) {
        final latestData = jsonDecode(latestResponse.body);

        double? weight;
        if (latestData['record'] != null) {
          weight = double.tryParse(latestData['record'].toString());
        }

        DateTime? timestamp;
        if (latestData['date_collected'] != null) {
          try {
            timestamp = DateTime.parse(latestData['date_collected'].toString());
          } catch (e) {
            print('Error parsing date_collected: $e');
            timestamp = DateTime.now();
          }
        } else {
          timestamp = DateTime.now();
        }

        if (weight != null && weight > 0) {
          print(
            'Successfully fetched latest weight: ${weight}kg at $timestamp',
          );
          return [
            TimestampedParameter(
              timestamp: timestamp,
              value: weight,
              type: 'weight',
            ),
          ];
        }
      }
    } catch (e) {
      print('Error fetching weight data: $e');
    }

    return [];
  }

  Future<List<HourlyBeeActivity>> _fetchHourlyBeeCountData(
    String hiveId,
    DateTime date,
  ) async {
    try {
      print(
        'Fetching bee count data for hive $hiveId on ${DateFormat('yyyy-MM-dd').format(date)}',
      );

      final beeCounts = await BeeCountDatabase.instance.readBeeCountsByDate(
        date,
      );
      final hiveCounts =
          beeCounts.where((count) => count.hiveId == hiveId).toList();

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

          hourlyActivities.add(
            HourlyBeeActivity(
              hour: hour,
              beesEntering: totalEntering,
              beesExiting: totalExiting,
              totalActivity: totalEntering + totalExiting,
              netChange: totalEntering - totalExiting,
              confidence: avgConfidence,
              videoCount: hourData.length,
              timestamp: DateTime(date.year, date.month, date.day, hour),
            ),
          );
        }
      }

      // Sort by hour for consistent display
      hourlyActivities.sort((a, b) => a.hour.compareTo(b.hour));

      print('Processed ${hourlyActivities.length} hourly activity records');
      return hourlyActivities;
    } catch (e) {
      print('Error fetching hourly bee count data: $e');
      return [];
    }
  }

  // Public method to get token
  Future<String?> getToken() async {
    return _getToken();
  }

  // Public method to fetch temperature data
  Future<List<TimestampedParameter>> fetchLatestTemperatureData(
    String hiveId,
    String token,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _fetchLatestTemperatureData(hiveId, token, startDate, endDate);
  }

  // Public method to fetch humidity data
  Future<List<TimestampedParameter>> fetchLatestHumidityData(
    String hiveId,
    String token,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _fetchLatestHumidityData(hiveId, token, startDate, endDate);
  }

  // Include all other methods from the original service...
  // (ForagingPatternAnalysis, TimeSyncedCorrelations, etc.)
}

// NEW: Weekly trend analysis model
class WeeklyTrendAnalysis {
  final double averageDailyActivity;
  final double trendPercentage; // Positive = increasing, negative = decreasing
  final int maxDayActivity;
  final int minDayActivity;
  final double consistency; // 0-100, higher = more consistent
  final int daysWithData;
  final int totalWeeklyActivity;

  WeeklyTrendAnalysis({
    required this.averageDailyActivity,
    required this.trendPercentage,
    required this.maxDayActivity,
    required this.minDayActivity,
    required this.consistency,
    required this.daysWithData,
    required this.totalWeeklyActivity,
  });

  factory WeeklyTrendAnalysis.empty() {
    return WeeklyTrendAnalysis(
      averageDailyActivity: 0.0,
      trendPercentage: 0.0,
      maxDayActivity: 0,
      minDayActivity: 0,
      consistency: 0.0,
      daysWithData: 0,
      totalWeeklyActivity: 0,
    );
  }
}

// Enhanced Data Models - keeping all existing models and adding weekly trends
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
  final WeeklyTrendAnalysis weeklyTrends; // NEW

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
    required this.weeklyTrends,
  });
}

// Keep all existing data models from the original service...
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

/// Analyze foraging patterns based on bee activity and environmental data
ForagingPatternAnalysis _analyzeForagingPatterns(
  List<HourlyBeeActivity> beeData,
  List<TimestampedParameter> temperatureData,
  List<TimestampedParameter> humidityData,
) {
  print('Analyzing foraging patterns...');

  if (beeData.isEmpty) {
    return ForagingPatternAnalysis(
      foragingDistanceIndicators: {},
      peakActivityHour: 12,
      nectarFlowAnalysis: NectarFlowAnalysis(
        status: 'No Data',
        intensity: 'Unknown',
        peakHours: [],
        reasoning: 'No bee activity data available',
      ),
      overallForagingAssessment: 'Insufficient data for analysis',
    );
  }

  // Find peak activity hour
  int peakActivityHour = 12;
  int maxActivity = 0;
  for (final activity in beeData) {
    if (activity.totalActivity > maxActivity) {
      maxActivity = activity.totalActivity;
      peakActivityHour = activity.hour;
    }
  }

  // Analyze foraging distance indicators for each hour
  final Map<int, ForageDistanceIndicator> distanceIndicators = {};

  for (final activity in beeData) {
    if (activity.totalActivity > 0) {
      final enteringRatio = activity.beesEntering / activity.totalActivity;
      final exitingRatio = activity.beesExiting / activity.totalActivity;

      String distanceAssessment;
      String reasoning;
      double confidence = activity.confidence;

      if (enteringRatio >
          EnhancedForagingAdvisoryService
              .enhancedThresholds['foraging_patterns']!['closeForageRatio']!) {
        distanceAssessment = 'Close Forage';
        reasoning =
            'High entering ratio suggests bees returning from nearby sources';
      } else if (enteringRatio <
          EnhancedForagingAdvisoryService
              .enhancedThresholds['foraging_patterns']!['distantForageRatio']!) {
        distanceAssessment = 'Distant Forage';
        reasoning = 'Low entering ratio suggests long foraging trips';
      } else if (exitingRatio >
          EnhancedForagingAdvisoryService
              .enhancedThresholds['foraging_patterns']!['scoutingActivity']!) {
        distanceAssessment = 'Scouting Activity';
        reasoning = 'High exiting ratio indicates exploration for new sources';
      } else {
        distanceAssessment = 'Mixed Activity';
        reasoning =
            'Balanced entering/exiting ratios suggest varied forage sources';
      }

      distanceIndicators[activity.hour] = ForageDistanceIndicator(
        hour: activity.hour,
        enteringRatio: enteringRatio,
        exitingRatio: exitingRatio,
        distanceAssessment: distanceAssessment,
        reasoning: reasoning,
        confidence: confidence,
      );
    }
  }

  // Analyze nectar flow
  final nectarFlowAnalysis = _analyzeNectarFlow(beeData);

  // Overall assessment
  String overallAssessment;
  if (maxActivity >
      EnhancedForagingAdvisoryService
          .enhancedThresholds['activity']!['peakActivity']!) {
    overallAssessment = 'Excellent foraging conditions with peak activity';
  } else if (maxActivity >
      EnhancedForagingAdvisoryService
          .enhancedThresholds['activity']!['highActivity']!) {
    overallAssessment = 'Good foraging activity levels';
  } else if (maxActivity >
      EnhancedForagingAdvisoryService
          .enhancedThresholds['activity']!['moderateActivity']!) {
    overallAssessment = 'Moderate foraging activity';
  } else {
    overallAssessment = 'Low foraging activity - investigation needed';
  }

  return ForagingPatternAnalysis(
    foragingDistanceIndicators: distanceIndicators,
    peakActivityHour: peakActivityHour,
    nectarFlowAnalysis: nectarFlowAnalysis,
    overallForagingAssessment: overallAssessment,
  );
}

/// Analyze nectar flow patterns
NectarFlowAnalysis _analyzeNectarFlow(List<HourlyBeeActivity> beeData) {
  if (beeData.isEmpty) {
    return NectarFlowAnalysis(
      status: 'No Data',
      intensity: 'Unknown',
      peakHours: [],
      reasoning: 'No activity data available',
    );
  }

  // Calculate baseline activity (average of lowest 25% of hours)
  final sortedActivities = beeData.map((b) => b.totalActivity).toList()..sort();
  final baselineCount = (sortedActivities.length * 0.25).ceil();
  final baseline =
      baselineCount > 0
          ? sortedActivities.take(baselineCount).reduce((a, b) => a + b) /
              baselineCount
          : 0.0;

  // Find peak hours (activity > 2x baseline)
  final peakThreshold =
      baseline *
      EnhancedForagingAdvisoryService
          .enhancedThresholds['foraging_patterns']!['nectarFlowRatio']!;
  final List<int> peakHours = [];

  for (final activity in beeData) {
    if (activity.totalActivity > peakThreshold) {
      peakHours.add(activity.hour);
    }
  }

  // Determine nectar flow status
  String status;
  String intensity;
  String reasoning;

  if (peakHours.isEmpty) {
    status = 'No Nectar Flow';
    intensity = 'None';
    reasoning = 'No significant peaks in activity detected';
  } else if (peakHours.length <= 2) {
    status = 'Limited Nectar Flow';
    intensity = 'Low';
    reasoning = 'Short duration peaks suggest limited nectar sources';
  } else if (peakHours.length <= 4) {
    status = 'Moderate Nectar Flow';
    intensity = 'Moderate';
    reasoning = 'Several peak hours indicate decent nectar availability';
  } else {
    status = 'Strong Nectar Flow';
    intensity = 'High';
    reasoning = 'Extended peak activity suggests abundant nectar sources';
  }

  return NectarFlowAnalysis(
    status: status,
    intensity: intensity,
    peakHours: peakHours,
    reasoning: reasoning,
  );
}

/// Calculate time-synchronized correlations between environmental factors and bee activity
TimeSyncedCorrelations _calculateTimeSyncedCorrelations(
  List<TimestampedParameter> temperatureData,
  List<TimestampedParameter> humidityData,
  List<TimestampedParameter> weightData,
  List<HourlyBeeActivity> beeData,
  DateTime date,
) {
  print('Calculating time-synced correlations...');

  // Create hourly temperature and humidity maps
  final Map<int, double> hourlyTemperature = {};
  final Map<int, double> hourlyHumidity = {};

  // Group temperature data by hour
  for (final temp in temperatureData) {
    if (temp.timestamp.day == date.day) {
      hourlyTemperature[temp.timestamp.hour] = temp.value;
    }
  }

  // Group humidity data by hour
  for (final humidity in humidityData) {
    if (humidity.timestamp.day == date.day) {
      hourlyHumidity[humidity.timestamp.hour] = humidity.value;
    }
  }

  // Calculate correlations
  final tempActivityCorr = _calculateCorrelation(
    beeData
        .map((b) => hourlyTemperature[b.hour])
        .where((t) => t != null)
        .cast<double>()
        .toList(),
    beeData
        .where((b) => hourlyTemperature[b.hour] != null)
        .map((b) => b.totalActivity.toDouble())
        .toList(),
  );

  final tempEnteringCorr = _calculateCorrelation(
    beeData
        .map((b) => hourlyTemperature[b.hour])
        .where((t) => t != null)
        .cast<double>()
        .toList(),
    beeData
        .where((b) => hourlyTemperature[b.hour] != null)
        .map((b) => b.beesEntering.toDouble())
        .toList(),
  );

  final tempExitingCorr = _calculateCorrelation(
    beeData
        .map((b) => hourlyTemperature[b.hour])
        .where((t) => t != null)
        .cast<double>()
        .toList(),
    beeData
        .where((b) => hourlyTemperature[b.hour] != null)
        .map((b) => b.beesExiting.toDouble())
        .toList(),
  );

  final humidityActivityCorr = _calculateCorrelation(
    beeData
        .map((b) => hourlyHumidity[b.hour])
        .where((h) => h != null)
        .cast<double>()
        .toList(),
    beeData
        .where((b) => hourlyHumidity[b.hour] != null)
        .map((b) => b.totalActivity.toDouble())
        .toList(),
  );

  final humidityEnteringCorr = _calculateCorrelation(
    beeData
        .map((b) => hourlyHumidity[b.hour])
        .where((h) => h != null)
        .cast<double>()
        .toList(),
    beeData
        .where((b) => hourlyHumidity[b.hour] != null)
        .map((b) => b.beesEntering.toDouble())
        .toList(),
  );

  final humidityExitingCorr = _calculateCorrelation(
    beeData
        .map((b) => hourlyHumidity[b.hour])
        .where((h) => h != null)
        .cast<double>()
        .toList(),
    beeData
        .where((b) => hourlyHumidity[b.hour] != null)
        .map((b) => b.beesExiting.toDouble())
        .toList(),
  );

  return TimeSyncedCorrelations(
    temperatureActivity: tempActivityCorr,
    temperatureEntering: tempEnteringCorr,
    temperatureExiting: tempExitingCorr,
    humidityActivity: humidityActivityCorr,
    humidityEntering: humidityEnteringCorr,
    humidityExiting: humidityExitingCorr,
    hourlyTemperature: hourlyTemperature,
    hourlyHumidity: hourlyHumidity,
  );
}

/// Calculate Pearson correlation coefficient
double _calculateCorrelation(List<double> x, List<double> y) {
  if (x.length != y.length || x.length < 2) return 0.0;

  final n = x.length;
  final sumX = x.reduce((a, b) => a + b);
  final sumY = y.reduce((a, b) => a + b);
  final sumXY = List.generate(n, (i) => x[i] * y[i]).reduce((a, b) => a + b);
  final sumX2 = x.map((v) => v * v).reduce((a, b) => a + b);
  final sumY2 = y.map((v) => v * v).reduce((a, b) => a + b);

  final numerator = (n * sumXY) - (sumX * sumY);
  final denominator = sqrt(
    ((n * sumX2) - (sumX * sumX)) * ((n * sumY2) - (sumY * sumY)),
  );

  if (denominator == 0) return 0.0;
  return numerator / denominator;
}

/// Analyze weight changes and their implications for foraging
WeightAnalysis _analyzeWeightChanges(
  List<TimestampedParameter> weightData,
  List<HourlyBeeActivity> beeData,
  DateTime date,
) {
  print('Analyzing weight changes...');

  if (weightData.isEmpty) {
    return WeightAnalysis(
      currentWeight: 0.0,
      dailyChange: 0.0,
      interpretation: 'No weight data available',
      activityCorrelation: 'Cannot assess without weight data',
      recommendations: ['Install or repair hive scale for weight monitoring'],
    );
  }

  // Get current weight (latest reading)
  final currentWeight = weightData.first.value;

  // Calculate daily change (simplified - compare with previous day if available)
  double dailyChange = 0.0;
  if (weightData.length > 1) {
    dailyChange = weightData.first.value - weightData.last.value;
  }

  // Interpret weight change
  String interpretation;
  if (dailyChange >
      EnhancedForagingAdvisoryService
          .enhancedThresholds['weight']!['dailyGainForaging']!) {
    interpretation =
        'Excellent daily weight gain indicates strong nectar flow and successful foraging';
  } else if (dailyChange > 0) {
    interpretation = 'Positive weight gain shows productive foraging activity';
  } else if (dailyChange >
      EnhancedForagingAdvisoryService
          .enhancedThresholds['weight']!['dailyLossThreshold']!) {
    interpretation =
        'Small weight loss may indicate honey ripening or normal daily fluctuation';
  } else {
    interpretation =
        'Significant weight loss suggests poor foraging conditions or colony stress';
  }

  // Correlate with activity
  final totalActivity =
      beeData.isNotEmpty
          ? beeData.map((b) => b.totalActivity).reduce((a, b) => a + b)
          : 0;

  String activityCorrelation;
  if (totalActivity >
          EnhancedForagingAdvisoryService
              .enhancedThresholds['activity']!['highActivity']! &&
      dailyChange > 0) {
    activityCorrelation =
        'High activity with weight gain confirms excellent foraging conditions';
  } else if (totalActivity >
          EnhancedForagingAdvisoryService
              .enhancedThresholds['activity']!['moderateActivity']! &&
      dailyChange < 0) {
    activityCorrelation =
        'Moderate activity with weight loss suggests distant forage or poor nectar quality';
  } else if (totalActivity <
          EnhancedForagingAdvisoryService
              .enhancedThresholds['activity']!['lowActivity']! &&
      dailyChange < 0) {
    activityCorrelation =
        'Low activity with weight loss indicates serious foraging problems';
  } else {
    activityCorrelation =
        'Activity and weight patterns suggest normal colony behavior';
  }

  // Generate recommendations based on weight analysis
  List<String> recommendations = [];
  if (dailyChange <=
      EnhancedForagingAdvisoryService
          .enhancedThresholds['weight']!['dailyLossThreshold']!) {
    recommendations.addAll([
      'Begin emergency feeding with 1:1 or 2:1 sugar syrup',
      'Inspect hive for disease, pests, or queen problems',
      'Check local forage availability within 2km radius',
      'Monitor for robbing behavior from other colonies',
    ]);
  } else if (dailyChange >
      EnhancedForagingAdvisoryService
          .enhancedThresholds['weight']!['dailyGainForaging']!) {
    recommendations.addAll([
      'Consider adding supers if weight gain continues',
      'Monitor for potential swarming due to rapid population growth',
      'Document successful forage sources for future reference',
    ]);
  }

  return WeightAnalysis(
    currentWeight: currentWeight,
    dailyChange: dailyChange,
    interpretation: interpretation,
    activityCorrelation: activityCorrelation,
    recommendations: recommendations,
  );
}

class WeightAnalysis {
  final double currentWeight;
  final double dailyChange;
  final String interpretation;
  final String activityCorrelation;
  final List<String> recommendations;

  WeightAnalysis({
    required this.currentWeight,
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

enum RecommendationType {
  immediate,
  environmental,
  optimization,
  urgent,
  seasonal,
}
