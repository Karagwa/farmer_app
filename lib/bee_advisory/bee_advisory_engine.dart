import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:HPGM/bee_advisory/bee_advisory_database.dart';
import 'package:HPGM/analytics/foraging_analysis/foraging_analysis_engine.dart';
// import 'package:HPGM/analytics/foraging_analysis/time_based_return_rate_database.dart';
import 'package:HPGM/Services/bee_analysis_service.dart';
import 'dart:async';
class BeeAdvisoryEngine {
  // Singleton instance
  static final BeeAdvisoryEngine instance = BeeAdvisoryEngine._init();

  BeeAdvisoryEngine._init();
  
  

  // Update the generateRecommendations method in BeeAdvisoryEngine
  Future<List<Map<String, dynamic>>> generateRecommendations({
    required String hiveId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Get foraging analysis data
      final foragingData = await ForagingAnalysisEngine.analyzeForagingActivity(
        hiveId: hiveId,
        startDate: startDate,
        endDate: endDate,
        includeWeatherData:
            true, // Always include weather data for better recommendations
      );

      if (!foragingData.containsKey('hasData') || !foragingData['hasData']) {
        return [
          {'error': 'No foraging data available for analysis'},
        ];
      }

      // Extract key metrics from foraging analysis
      final metrics = foragingData['metrics'];
      final patterns = foragingData['patterns'];
      final efficiency = foragingData['efficiency'];
      final environmentalFactors = foragingData['environmentalFactors'];
      final timeBasedAnalysis = foragingData['timeBasedAnalysis'];
      final distributions = foragingData['distributions'];

      // Get existing recommendations from the database
      final existingRecommendations = await BeeAdvisoryDatabase.instance
          .readRecommendationsByHive(hiveId);

      // Generate new recommendations based on the analysis
      List<Map<String, dynamic>> recommendations = [];

      // 1. Check overall foraging performance score
      double foragePerformanceScore = foragingData['foragePerformanceScore'];
      if (foragePerformanceScore < 70) {
        var recommendation = await _generateLowPerformanceRecommendation(
          hiveId,
          foragePerformanceScore,
          foragingData,
        );

        // Add historical comparison
        recommendation['historicalComparison'] =
            await compareWithHistoricalRecommendations(hiveId, recommendation);

        recommendations.add(recommendation);
      }

      // 2. Check return rate
      double returnRate = metrics['returnRate'];
      if (returnRate < 85) {
        var recommendation = await _generateLowReturnRateRecommendation(
          hiveId,
          returnRate,
          environmentalFactors,
        );

        // Add historical comparison
        recommendation['historicalComparison'] =
            await compareWithHistoricalRecommendations(hiveId, recommendation);

        recommendations.add(recommendation);
      }

      // 3. Check foraging duration
      double foragingDuration = metrics['estimatedForagingDuration'];
      if (foragingDuration < 45) {
        var recommendation = await _generateShortForagingDurationRecommendation(
          hiveId,
          foragingDuration,
        );

        // Add historical comparison
        recommendation['historicalComparison'] =
            await compareWithHistoricalRecommendations(hiveId, recommendation);

        recommendations.add(recommendation);
      } else if (foragingDuration > 120) {
        var recommendation = await _generateLongForagingDurationRecommendation(
          hiveId,
          foragingDuration,
        );

        // Add historical comparison
        recommendation['historicalComparison'] =
            await compareWithHistoricalRecommendations(hiveId, recommendation);

        recommendations.add(recommendation);
      }

      // 4. Check foraging efficiency
      double efficiencyScore = efficiency['efficiencyScore'];
      if (efficiencyScore < 70) {
        // Create list of limiting factors
        List<Map<String, dynamic>> limitingFactors = [];

        if (efficiency.containsKey('returnRateScore') &&
            efficiency['returnRateScore'] < 70) {
          limitingFactors.add({
            'factor': 'Return Rate',
            'score': efficiency['returnRateScore'],
            'importance': 'High',
          });
        }

        if (efficiency.containsKey('durationScore') &&
            efficiency['durationScore'] < 70) {
          limitingFactors.add({
            'factor': 'Foraging Duration',
            'score': efficiency['durationScore'],
            'importance': 'Medium',
          });
        }

        if (efficiency.containsKey('consistencyScore') &&
            efficiency['consistencyScore'] < 70) {
          limitingFactors.add({
            'factor': 'Activity Consistency',
            'score': efficiency['consistencyScore'],
            'importance': 'Medium',
          });
        }

        var recommendation = await _generateLowEfficiencyRecommendation(
          hiveId,
          efficiencyScore,
          limitingFactors,
        );

        // Add historical comparison
        recommendation['historicalComparison'] =
            await compareWithHistoricalRecommendations(hiveId, recommendation);

        recommendations.add(recommendation);
      }

      // 5. Check weather dependency
      bool weatherDependent = patterns['suspectedWeatherDependency'];
      if (weatherDependent) {
        // Determine the most influential weather factor
        String mostInfluentialFactor = _getMostInfluentialWeatherFactor(
          environmentalFactors,
        );

        // Add the most influential factor to environmental factors
        Map<String, dynamic> enhancedEnvFactors = {...environmentalFactors};
        enhancedEnvFactors['mostInfluentialFactor'] = mostInfluentialFactor;

        var recommendation = await _generateWeatherDependencyRecommendation(
          hiveId,
          enhancedEnvFactors,
        );

        // Add historical comparison
        recommendation['historicalComparison'] =
            await compareWithHistoricalRecommendations(hiveId, recommendation);

        recommendations.add(recommendation);
      }

      // 6. Check time-based patterns
      if (timeBasedAnalysis.containsKey('hasData') &&
          timeBasedAnalysis['hasData']) {
        // 6a. Check trip duration distribution
        if (timeBasedAnalysis.containsKey('tripDistributionPercentages')) {
          final distribution = timeBasedAnalysis['tripDistributionPercentages'];

          if (distribution.containsKey('short') && distribution['short'] > 60) {
            var recommendation = await _generateHighShortTripsRecommendation(
              hiveId,
              distribution['short'],
            );

            // Add historical comparison
            recommendation['historicalComparison'] =
                await compareWithHistoricalRecommendations(
                  hiveId,
                  recommendation,
                );

            recommendations.add(recommendation);
          }

          if (distribution.containsKey('long') && distribution['long'] > 40) {
            var recommendation = await _generateHighLongTripsRecommendation(
              hiveId,
              distribution['long'],
            );

            // Add historical comparison
            recommendation['historicalComparison'] =
                await compareWithHistoricalRecommendations(
                  hiveId,
                  recommendation,
                );

            recommendations.add(recommendation);
          }
        }

        // 6b. Check daily return rates for concerning patterns
        if (timeBasedAnalysis.containsKey('dailyReturnRates')) {
          Map<String, Map<String, dynamic>> dailyRates =
              timeBasedAnalysis['dailyReturnRates'];

          // Check if any day has poor health indicators
          bool hasPoorHealthIndicators = false;
          List<String> problematicTimeBlocks = [];

          dailyRates.forEach((day, dayData) {
            if (dayData.containsKey('timeBlocks')) {
              Map<String, dynamic> timeBlocks = dayData['timeBlocks'];

              timeBlocks.forEach((blockName, blockData) {
                if (blockData.containsKey('healthIndicator') &&
                    blockData['healthIndicator'] == 'Poor') {
                  hasPoorHealthIndicators = true;
                  problematicTimeBlocks.add('$blockName on $day');
                }
              });
            }
          });

          if (hasPoorHealthIndicators) {
            var recommendation =
                await _generatePoorTimeBlockHealthRecommendation(
                  hiveId,
                  problematicTimeBlocks,
                );

            // Add historical comparison
            recommendation['historicalComparison'] =
                await compareWithHistoricalRecommendations(
                  hiveId,
                  recommendation,
                );

            recommendations.add(recommendation);
          }
        }

        // 6c. Check overall health score
        if (timeBasedAnalysis.containsKey('overallHealthScore')) {
          double healthScore = timeBasedAnalysis['overallHealthScore'];

          if (healthScore < 60) {
            var recommendation = await _generateLowOverallHealthRecommendation(
              hiveId,
              healthScore,
            );

            // Add historical comparison
            recommendation['historicalComparison'] =
                await compareWithHistoricalRecommendations(
                  hiveId,
                  recommendation,
                );

            recommendations.add(recommendation);
          }
        }
      }

      // 7. Check foraging patterns
      if (patterns.containsKey('possibleSwarmingBehavior') &&
          patterns['possibleSwarmingBehavior']) {
        var recommendation = await _generateSwarmingRiskRecommendation(
          hiveId,
          metrics,
        );

        // Add historical comparison
        recommendation['historicalComparison'] =
            await compareWithHistoricalRecommendations(hiveId, recommendation);

        recommendations.add(recommendation);
      }

      // 8. Check for temporal distribution issues
      if (distributions.containsKey('timeBlockDistribution')) {
        Map<String, dynamic> timeBlockDist =
            distributions['timeBlockDistribution'];

        // Check if there's a significant imbalance in activity distribution
        double maxActivity = 0;
        String peakTimeBlock = '';

        timeBlockDist.forEach((timeBlock, percentage) {
          if (percentage > maxActivity) {
            maxActivity = percentage;
            peakTimeBlock = timeBlock;
          }
        });

        // If more than 50% of activity is in one time block, recommend diversification
        if (maxActivity > 50) {
          var recommendation = await _generateActivityImbalanceRecommendation(
            hiveId,
            peakTimeBlock,
            maxActivity,
          );

          // Add historical comparison
          recommendation['historicalComparison'] =
              await compareWithHistoricalRecommendations(
                hiveId,
                recommendation,
              );

          recommendations.add(recommendation);
        }
      }

      // 9. Generate seasonal recommendations
      List<Map<String, dynamic>> seasonalRecommendations =
          await generateSeasonalRecommendations(hiveId);
      recommendations.addAll(seasonalRecommendations);

      // Store recommendations in the database
      for (var recommendation in recommendations) {
        await BeeAdvisoryDatabase.instance.insertRecommendation(recommendation);
      }

      return recommendations;
    } catch (e) {
      print('Error generating recommendations: $e');
      return [
        {'error': 'Error generating recommendations: $e'},
      ];
    }
  }

  // Generate recommendation for low overall performance
  Future<Map<String, dynamic>> _generateLowPerformanceRecommendation(
    String hiveId,
    double performanceScore,
    Map<String, dynamic> foragingData,
  ) async {
    // Get diverse plants for overall improvement
    final plants = await _getDiversePlants();

    // Get comprehensive supplements
    final supplements = await _getSuitableSupplements('Health');

    // Analyze which aspects need the most improvement
    List<String> actionItems = [];
    Map<String, dynamic> metrics = foragingData['metrics'];
    Map<String, dynamic> efficiency = foragingData['efficiency'];

    if (metrics['returnRate'] < 75) {
      actionItems.add(
        'Improve bee return rate by checking for predators and pesticide exposure',
      );
    }

    if (efficiency.containsKey('consistencyScore') &&
        efficiency['consistencyScore'] < 60) {
      actionItems.add(
        'Plant a variety of flowers that bloom in succession to provide consistent forage',
      );
    }

    if (metrics.containsKey('foragingIntensity') &&
        metrics['foragingIntensity'] < 100) {
      actionItems.add('Increase floral density within 500 meters of hives');
    }

    // General recommendations if specific issues aren't identified
    if (actionItems.isEmpty) {
      actionItems.add(
        'Conduct a comprehensive hive inspection to identify specific issues',
      );
      actionItems.add(
        'Consider relocating hives closer to abundant forage sources',
      );
      actionItems.add(
        'Implement a regular feeding schedule during nectar dearth periods',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Low Overall Foraging Performance',
      'severity': performanceScore < 60 ? 'High' : 'Medium',
      'recommended_plants': plants.map((p) => p['id']).join(','),
      'recommended_supplements': supplements.map((s) => s['id']).join(','),
      'management_actions': actionItems.join('. '),
      'expected_outcome':
          'Comprehensive improvement in foraging performance and colony health.',
      'priority': performanceScore < 60 ? 1 : 2,
      'notes':
          'Current performance score: ${performanceScore.toStringAsFixed(1)}/100. Target: >80/100',
    };
  }

  // Generate recommendation for low return rate
  Future<Map<String, dynamic>> _generateLowReturnRateRecommendation(
    String hiveId,
    double returnRate,
    Map<String, dynamic> environmentalFactors,
  ) async {
    // Get suitable plants for improving return rate
    final plants = await _getSuitablePlantsForReturnRate(environmentalFactors);

    // Get suitable supplements
    final supplements = await _getSuitableSupplements('Feed');

    // Create targeted management actions based on environmental data
    List<String> actions = ['Check for predators near the hive'];

    // Add weather-specific advice if available
    if (environmentalFactors.containsKey('weatherData')) {
      var weatherData = environmentalFactors['weatherData'];

      if (weatherData.containsKey('windSpeed') &&
          weatherData['windSpeed'].containsKey('correlations') &&
          weatherData['windSpeed']['correlations'].containsKey('returnRate')) {
        double correlation =
            weatherData['windSpeed']['correlations']['returnRate']['correlation'];
        if (correlation < -0.4) {
          // Negative correlation stronger than -0.4
          actions.add(
            'Install windbreaks to improve bee navigation in windy conditions',
          );
        }
      }

      if (weatherData.containsKey('precipitation') &&
          weatherData['precipitation'].containsKey('correlations') &&
          weatherData['precipitation']['correlations'].containsKey(
            'returnRate',
          )) {
        double correlation =
            weatherData['precipitation']['correlations']['returnRate']['correlation'];
        if (correlation < -0.4) {
          actions.add(
            'Ensure hives are tilted forward slightly to prevent water accumulation during rain',
          );
        }
      }
    }

    // Add general recommendations
    actions.add('Ensure water sources are available within 100 meters');
    actions.add('Monitor for pesticide applications in nearby fields');
    if (returnRate < 70) {
      actions.add('Consider placing entrance reducers to minimize predation');
      actions.add(
        'Install distinctive landmarks near hives to help bee navigation',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Low Bee Return Rate',
      'severity': returnRate < 75 ? 'High' : 'Medium',
      'recommended_plants': plants.map((p) => p['id']).join(','),
      'recommended_supplements': supplements.map((s) => s['id']).join(','),
      'management_actions': actions.join('. '),
      'expected_outcome': 'Improved return rate and colony strength.',
      'priority': returnRate < 75 ? 1 : 2,
      'notes':
          'Current return rate: ${returnRate.toStringAsFixed(1)}%. Target: >90%',
    };
  }

  // Generate recommendation for short foraging duration
  Future<Map<String, dynamic>> _generateShortForagingDurationRecommendation(
    String hiveId,
    double duration,
  ) async {
    // Get nectar-rich plants
    final plants = await _getSuitablePlantsByValue('nectar', 4);

    // Get suitable supplements
    final supplements = await _getSuitableSupplements('Feed');

    // Create detailed actions
    List<String> actions = [
      'Plant high-quality nectar sources within 500 meters of the hive',
      'Provide sugar syrup supplement during nectar dearth periods',
      'Create a planting plan with flowers that bloom in succession throughout the season',
      'Consider adding deep-nectar flowers that take longer to forage',
    ];

    if (duration < 30) {
      actions.add(
        'Investigate possible pesticide exposure that may be deterring extended foraging',
      );
      actions.add(
        'Check for nearby competing water sources that might be distracting foragers',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Short Foraging Trips',
      'severity': duration < 30 ? 'High' : 'Medium',
      'recommended_plants': plants.map((p) => p['id']).join(','),
      'recommended_supplements': supplements.map((s) => s['id']).join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Increased foraging duration and better resource collection.',
      'priority': duration < 30 ? 2 : 3,
      'notes':
          'Current average trip duration: ${duration.toStringAsFixed(1)} minutes. Target: 60-90 minutes',
    };
  }

  // Generate recommendation for long foraging duration
  Future<Map<String, dynamic>> _generateLongForagingDurationRecommendation(
    String hiveId,
    double duration,
  ) async {
    // Get plants that can be grown near hives
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();
    final nearbyPlants =
        allPlants
            .where(
              (p) =>
                  p['maintenance_level'] == 'Low' ||
                  p['maintenance_level'] == 'Medium',
            )
            .toList();

    // Create detailed actions
    List<String> actions = [
      'Plant more bee-friendly flowers within 500 meters of the hive',
      'Consider relocating hives closer to major forage sources',
      'Create stepping-stone plantings to guide bees to closer forage sources',
      'Add water sources within 100 meters of the hives',
    ];

    if (duration > 150) {
      actions.add(
        'Consider installing a pollinator corridor to connect hive to distant forage areas',
      );
      actions.add(
        'Plan for successional blooming to encourage foraging closer to the hive',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Long Foraging Trips',
      'severity': duration > 150 ? 'High' : 'Medium',
      'recommended_plants': nearbyPlants.map((p) => p['id']).join(','),
      'recommended_supplements': '',
      'management_actions': actions.join('. '),
      'expected_outcome': 'Reduced foraging distance and improved efficiency.',
      'priority': duration > 150 ? 2 : 3,
      'notes':
          'Current average trip duration: ${duration.toStringAsFixed(1)} minutes. Target: 60-90 minutes',
    };
  }

  // Generate recommendation for low efficiency
  Future<Map<String, dynamic>> _generateLowEfficiencyRecommendation(
    String hiveId,
    double efficiencyScore,
    List<dynamic> limitingFactors,
  ) async {
    // Get diverse plants (both nectar and pollen)
    final plants = await _getDiversePlants();

    // Get health supplements
    final supplements = await _getSuitableSupplements('Health');

    // Create targeted management actions based on limiting factors
    List<String> actions = ['Improve hive placement for better sun exposure'];

    // Add specific actions based on limiting factors
    if (limitingFactors.isNotEmpty) {
      for (var factor in limitingFactors) {
        if (factor['factor'] == 'Return Rate') {
          actions.add(
            'Check for predators or pesticides affecting bee return rate',
          );
        } else if (factor['factor'] == 'Foraging Duration') {
          actions.add(
            'Plant more diverse forage sources at varying distances from the hive',
          );
        } else if (factor['factor'] == 'Activity Consistency') {
          actions.add(
            'Create a more consistent foraging environment with succession planting',
          );
        }
      }
    }

    // Add general recommendations if few specific ones
    if (actions.length < 3) {
      actions.add(
        'Ensure hive entrances face southeast for earlier foraging activity',
      );
      actions.add(
        'Consider adding nutrient supplements to boost colony vitality',
      );
      actions.add(
        'Monitor for disease or parasite pressure that might be affecting efficiency',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Low Foraging Efficiency',
      'severity': efficiencyScore < 60 ? 'High' : 'Medium',
      'recommended_plants': plants.map((p) => p['id']).join(','),
      'recommended_supplements': supplements.map((s) => s['id']).join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Improved overall foraging efficiency and colony productivity.',
      'priority': efficiencyScore < 60 ? 1 : 2,
      'notes':
          'Current efficiency score: ${efficiencyScore.toStringAsFixed(1)}. Target: >80',
    };
  }

  // Generate recommendation for weather dependency
  Future<Map<String, dynamic>> _generateWeatherDependencyRecommendation(
    String hiveId,
    Map<String, dynamic> environmentalFactors,
  ) async {
    // Get weather-resilient plants
    final plants = await _getWeatherResilientPlants(environmentalFactors);

    // Get suitable supplements for stress periods
    final supplements = await _getSuitableSupplements('Feed');

    // Create targeted management actions based on most influential weather factor
    List<String> actions = [];

    // Add specific actions based on most influential factor
    if (environmentalFactors.containsKey('mostInfluentialFactor')) {
      String factor = environmentalFactors['mostInfluentialFactor'];

      if (factor == 'temperature') {
        actions.add('Ensure adequate shade during hot periods');
        actions.add('Consider insulation for cold periods');
        actions.add(
          'Plant temperature-resilient forage that produces nectar across temperature ranges',
        );
      } else if (factor == 'windSpeed') {
        actions.add('Install windbreaks on prevailing wind side');
        actions.add(
          'Create sheltered foraging areas with wind-resistant plants',
        );
        actions.add(
          'Consider wind-protected hive entrances during windy seasons',
        );
      } else if (factor == 'precipitation') {
        actions.add(
          'Ensure hives have proper ventilation and are tilted forward slightly to prevent water accumulation',
        );
        actions.add('Create rain shelters near hive entrances');
        actions.add(
          'Plant nectar sources that continue to produce during wet conditions',
        );
      } else {
        actions.add('Provide windbreaks if wind is a limiting factor');
        actions.add(
          'Ensure consistent water sources during varying weather conditions',
        );
      }
    } else {
      // General recommendations if specific factor not identified
      actions.add(
        'Create microclimate diversity around hives to buffer extreme weather',
      );
      actions.add('Ensure water availability during hot periods');
      actions.add('Provide wind protection on prevailing wind sides');
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'High Weather Dependency',
      'severity': 'Medium',
      'recommended_plants': plants.map((p) => p['id']).join(','),
      'recommended_supplements': supplements.map((s) => s['id']).join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Reduced impact of weather on foraging activity and more consistent productivity.',
      'priority': 2,
      'notes':
          'Colony shows high sensitivity to weather conditions, particularly ${environmentalFactors.containsKey('mostInfluentialFactor') ? environmentalFactors['mostInfluentialFactor'] : 'changing weather patterns'}.',
    };
  }

  // Generate recommendation for high percentage of short trips
  Future<Map<String, dynamic>> _generateHighShortTripsRecommendation(
    String hiveId,
    double shortTripsPercentage,
  ) async {
    // Get nectar-rich plants
    final plants = await _getSuitablePlantsByValue('nectar', 5);

    // Get suitable supplements
    final supplements = await _getSuitableSupplements('Feed');

    // Create detailed actions
    List<String> actions = [
      'Plant high-quality nectar sources near the hive',
      'Provide sugar syrup during nectar dearth periods',
      'Create a diverse foraging landscape with varying distances to encourage longer trips',
      'Consider planting flowers with deeper nectaries that require longer foraging times',
    ];

    if (shortTripsPercentage > 75) {
      actions.add(
        'Investigate possible issues with nearby forage that may be causing bees to return quickly',
      );
      actions.add(
        'Check water sources - bees may be primarily collecting water rather than nectar/pollen',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'High Percentage of Short Foraging Trips',
      'severity': shortTripsPercentage > 75 ? 'Medium' : 'Low',
      'recommended_plants': plants.map((p) => p['id']).join(','),
      'recommended_supplements': supplements.map((s) => s['id']).join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Better balance of foraging trip durations and improved resource collection.',
      'priority': shortTripsPercentage > 75 ? 2 : 3,
      'notes':
          'Currently ${shortTripsPercentage.toStringAsFixed(1)}% of trips are short (<30 min). Target: <40%',
    };
  }

  // Generate recommendation for high percentage of long trips
  Future<Map<String, dynamic>> _generateHighLongTripsRecommendation(
    String hiveId,
    double longTripsPercentage,
  ) async {
    // Get plants that can be grown near hives
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();
    final nearbyPlants =
        allPlants
            .where(
              (p) =>
                  (p['maintenance_level'] == 'Low' ||
                      p['maintenance_level'] == 'Medium') &&
                  p['nectar_value'] >= 4,
            )
            .toList();

    // Create detailed actions
    List<String> actions = [
      'Plant high-nectar flowers within 500 meters of the hive',
      'Consider moving hives closer to major forage areas',
      'Create a series of stepping-stone plantings to guide bees to closer resources',
      'Ensure water sources are available within 100 meters of hives',
    ];

    if (longTripsPercentage > 60) {
      actions.add(
        'Investigate the surrounding area for potential forage deserts',
      );
      actions.add(
        'Consider establishing small satellite gardens between hives and distant forage',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'High Percentage of Long Foraging Trips',
      'severity': longTripsPercentage > 60 ? 'Medium' : 'Low',
      'recommended_plants': nearbyPlants.map((p) => p['id']).join(','),
      'recommended_supplements': '',
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Reduced foraging distances and improved energy efficiency.',
      'priority': longTripsPercentage > 60 ? 2 : 3,
      'notes':
          'Currently ${longTripsPercentage.toStringAsFixed(1)}% of trips are long (>90 min). Target: <30%',
    };
  }

  // Generate recommendation for poor time block health
  Future<Map<String, dynamic>> _generatePoorTimeBlockHealthRecommendation(
    String hiveId,
    List<String> problematicTimeBlocks,
  ) async {
    // Get diverse plants
    final plants = await _getDiversePlants();

    // Get health supplements
    final supplements = await _getSuitableSupplements('Health');

    // Create targeted management actions
    List<String> actions = [
      'Monitor foraging activity closely during problematic time periods: ${problematicTimeBlocks.join(", ")}',
      'Check for time-specific threats like pesticide applications or predator activity',
      'Ensure forage availability throughout all time periods',
      'Consider supplemental feeding during problematic time blocks',
    ];

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Poor Foraging Health in Specific Time Periods',
      'severity': 'High',
      'recommended_plants': plants.map((p) => p['id']).join(','),
      'recommended_supplements': supplements.map((s) => s['id']).join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Improved foraging health across all time periods and better overall colony performance.',
      'priority': 1,
      'notes': 'Problematic time periods: ${problematicTimeBlocks.join(", ")}',
    };
  }

  // Generate recommendation for low overall health score
  Future<Map<String, dynamic>> _generateLowOverallHealthRecommendation(
    String hiveId,
    double healthScore,
  ) async {
    // Get diverse plants
    final plants = await _getDiversePlants();

    // Get comprehensive supplements
    final healthSupplements = await _getSuitableSupplements('Health');
    final feedSupplements = await _getSuitableSupplements('Feed');

    // Combine supplement types, prioritizing health
    List<Map<String, dynamic>> allSupplements = [
      ...healthSupplements,
      ...feedSupplements,
    ];

    // Create comprehensive action plan
    List<String> actions = [
      'Conduct a full hive inspection to check for disease, pests, or queen issues',
      'Implement a comprehensive health and nutrition plan',
      'Plant a diverse range of bee-friendly flowers within foraging range',
      'Provide protein and carbohydrate supplements during dearth periods',
      'Monitor for pesticide applications in surrounding areas',
      'Consider consulting with a local beekeeping expert for a site assessment',
    ];

    if (healthScore < 40) {
      actions.add(
        'Consider requeening if colony shows persistent health issues',
      );
      actions.add(
        'Evaluate whether the location is suitable for beekeeping or if hives should be relocated',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Low Overall Foraging Health',
      'severity': healthScore < 40 ? 'High' : 'Medium',
      'recommended_plants': plants.map((p) => p['id']).join(','),
      'recommended_supplements': allSupplements
          .take(5)
          .map((s) => s['id'])
          .join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Comprehensive improvement in colony health and foraging performance.',
      'priority': healthScore < 40 ? 1 : 2,
      'notes':
          'Current health score: ${healthScore.toStringAsFixed(1)}/100. Target: >75/100',
    };
  }

  // Generate recommendation for swarming risk
  Future<Map<String, dynamic>> _generateSwarmingRiskRecommendation(
    String hiveId,
    Map<String, dynamic> metrics,
  ) async {
    // Get plants that can help with swarming management
    final plants = await BeeAdvisoryDatabase.instance.readAllPlants();
    final swarmingPlants =
        plants.where((plant) => plant['nectar_value'] >= 4).toList();

    // Create detailed actions
    double netChange = metrics['totalNetChange'];

    List<String> actions = [
      'Inspect the hive for queen cells',
      'Add additional supers to provide more space if the hive is congested',
      'Consider splitting the colony as a preemptive measure',
      'Ensure adequate ventilation in the hive',
    ];

    if (netChange < -100) {
      actions.add(
        'Check nearby areas for swarms in case a swarm has already departed',
      );
      actions.add(
        'Monitor for a new queen if egg-laying has decreased recently',
      );
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Swarming Risk Detected',
      'severity': 'High',
      'recommended_plants': swarmingPlants
          .take(5)
          .map((p) => p['id'])
          .join(','),
      'recommended_supplements': '',
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Prevention of colony loss through swarming and maintained productivity.',
      'priority': 1,
      'notes':
          'Net population change: ${netChange.toStringAsFixed(0)} bees. Monitor closely for swarming behavior.',
    };
  }

  // Generate recommendation for activity imbalance
  Future<Map<String, dynamic>> _generateActivityImbalanceRecommendation(
    String hiveId,
    String peakTimeBlock,
    double activityPercentage,
  ) async {
    // Get plants with varied blooming times
    final plants = await BeeAdvisoryDatabase.instance.readAllPlants();

    // Create a diverse plant selection based on peak time to balance activity
    List<Map<String, dynamic>> selectedPlants = [];

    if (peakTimeBlock.contains('Early Morning')) {
      // If early morning is peak, add afternoon/evening plants
      selectedPlants =
          plants
              .where(
                (plant) =>
                    plant['flowering_season'].toString().toLowerCase().contains(
                      'summer',
                    ) ||
                    plant['description'].toString().toLowerCase().contains(
                      'afternoon',
                    ),
              )
              .toList();
    } else if (peakTimeBlock.contains('Evening')) {
      // If evening is peak, add morning plants
      selectedPlants =
          plants
              .where(
                (plant) =>
                    plant['flowering_season'].toString().toLowerCase().contains(
                      'spring',
                    ) ||
                    plant['description'].toString().toLowerCase().contains(
                      'morning',
                    ),
              )
              .toList();
    } else {
      // For other peaks, add generally diverse plants
      selectedPlants =
          plants.where((plant) => plant['nectar_value'] >= 4).toList();
    }

    // If we have too few plants, add some general ones
    if (selectedPlants.length < 3) {
      selectedPlants = await _getDiversePlants();
    }

    // Create management actions
    List<String> actions = [
      'Plant flowers that bloom during non-peak periods to balance foraging activity',
      'Create diverse foraging opportunities throughout the day',
      'Consider the placement of plants to encourage foraging at different times',
      'Monitor for factors that might be limiting activity during non-peak periods',
    ];

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Foraging Activity Imbalance',
      'severity': 'Medium',
      'recommended_plants': selectedPlants
          .take(5)
          .map((p) => p['id'])
          .join(','),
      'recommended_supplements': '',
      'management_actions': actions.join('. '),
      'expected_outcome':
          'More balanced foraging activity throughout the day and improved overall efficiency.',
      'priority': 3,
      'notes':
          '${activityPercentage.toStringAsFixed(1)}% of activity occurs during ${peakTimeBlock}. Target: More balanced distribution across time periods.',
    };
  }

  // Add these methods to the BeeAdvisoryEngine class

  // Track recommendation history and improvements
  Future<Map<String, dynamic>> getRecommendationHistory(
    String hiveId, {
    int months = 6,
  }) async {
    try {
      // Get current date and date from months ago
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month - months, now.day);

      // Get all recommendations for this hive in the time period
      final recommendations = await BeeAdvisoryDatabase.instance
          .getRecommendationsByDateRange(hiveId, startDate, now);

      if (recommendations.isEmpty) {
        return {
          'hasData': false,
          'message': 'No historical recommendation data available',
        };
      }

      // Group recommendations by month
      Map<String, List<Map<String, dynamic>>> recommendationsByMonth = {};

      for (var rec in recommendations) {
        DateTime recDate = DateFormat('yyyy-MM-dd').parse(rec['date']);
        String monthKey = DateFormat('yyyy-MM').format(recDate);

        if (!recommendationsByMonth.containsKey(monthKey)) {
          recommendationsByMonth[monthKey] = [];
        }

        recommendationsByMonth[monthKey]!.add(rec);
      }

      // Calculate improvement metrics
      Map<String, dynamic> improvementMetrics = {};
      List<String> sortedMonths = recommendationsByMonth.keys.toList()..sort();

      // Track issues over time
      Map<String, List<double>> issueTracker = {};

      // Process each month's recommendations
      for (String month in sortedMonths) {
        var monthRecs = recommendationsByMonth[month]!;

        // Count issues by severity
        int highSeverity = 0;
        int mediumSeverity = 0;
        int lowSeverity = 0;

        // Track specific issues
        for (var rec in monthRecs) {
          String issue = rec['issue_identified'];
          double severity =
              rec['severity'] == 'High'
                  ? 3
                  : rec['severity'] == 'Medium'
                  ? 2
                  : 1;

          if (rec['severity'] == 'High')
            highSeverity++;
          else if (rec['severity'] == 'Medium')
            mediumSeverity++;
          else
            lowSeverity++;

          // Add to issue tracker
          if (!issueTracker.containsKey(issue)) {
            issueTracker[issue] = [];
          }
          issueTracker[issue]!.add(severity);
        }

        // Calculate month's severity score (weighted average)
        double severityScore =
            (highSeverity * 3 + mediumSeverity * 2 + lowSeverity) /
            (highSeverity + mediumSeverity + lowSeverity);

        improvementMetrics[month] = {
          'recommendationCount': monthRecs.length,
          'highSeverityCount': highSeverity,
          'mediumSeverityCount': mediumSeverity,
          'lowSeverityCount': lowSeverity,
          'severityScore': severityScore,
        };
      }

      // Calculate improvement trends for each issue
      Map<String, Map<String, dynamic>> issueTrends = {};

      issueTracker.forEach((issue, severities) {
        if (severities.length > 1) {
          // Calculate trend (negative is improvement, positive is worsening)
          double firstSeverity = severities.first;
          double lastSeverity = severities.last;
          double trend = lastSeverity - firstSeverity;

          // Calculate consistency (standard deviation)
          double mean = severities.reduce((a, b) => a + b) / severities.length;
          double sumSquaredDiff = severities.fold(
            0,
            (sum, item) => sum + math.pow(item - mean, 2),
          );
          double stdDev = math.sqrt(sumSquaredDiff / severities.length);

          issueTrends[issue] = {
            'trend': trend,
            'improved': trend < 0,
            'worsened': trend > 0,
            'unchanged': trend == 0,
            'consistency': stdDev,
            'occurrences': severities.length,
            'initialSeverity': firstSeverity,
            'currentSeverity': lastSeverity,
          };
        } else {
          issueTrends[issue] = {
            'trend': 0,
            'improved': false,
            'worsened': false,
            'unchanged': true,
            'consistency': 0,
            'occurrences': 1,
            'initialSeverity': severities.first,
            'currentSeverity': severities.first,
          };
        }
      });

      // Calculate overall improvement
      double overallImprovement = 0;
      if (sortedMonths.length > 1) {
        double firstMonthScore =
            improvementMetrics[sortedMonths.first]['severityScore'];
        double lastMonthScore =
            improvementMetrics[sortedMonths.last]['severityScore'];
        overallImprovement =
            firstMonthScore - lastMonthScore; // Positive means improvement
      }

      // Get implemented recommendations
      final implementedRecs = await BeeAdvisoryDatabase.instance
          .getImplementedRecommendations(hiveId);

      // Calculate implementation rate
      double implementationRate =
          recommendations.isEmpty
              ? 0
              : implementedRecs.length / recommendations.length * 100;

      return {
        'hasData': true,
        'monthlyMetrics': improvementMetrics,
        'issueTrends': issueTrends,
        'overallImprovement': overallImprovement,
        'implementationRate': implementationRate,
        'implementedCount': implementedRecs.length,
        'totalRecommendations': recommendations.length,
        'months': sortedMonths,
      };
    } catch (e) {
      print('Error getting recommendation history: $e');
      return {
        'hasData': false,
        'error': 'Error retrieving recommendation history: $e',
      };
    }
  }

  // Generate a historical comparison for a new recommendation
  Future<Map<String, dynamic>> compareWithHistoricalRecommendations(
    String hiveId,
    Map<String, dynamic> newRecommendation,
  ) async {
    try {
      // Get past recommendations for the same issue
      final pastRecommendations = await BeeAdvisoryDatabase.instance
          .getRecommendationsByIssue(
            hiveId,
            newRecommendation['issue_identified'],
          );

      if (pastRecommendations.isEmpty) {
        return {
          'isNew': true,
          'message': 'This is a new issue with no historical data',
        };
      }

      // Sort by date
      pastRecommendations.sort(
        (a, b) => DateFormat(
          'yyyy-MM-dd',
        ).parse(a['date']).compareTo(DateFormat('yyyy-MM-dd').parse(b['date'])),
      );

      // Get the most recent recommendation for this issue
      final mostRecent = pastRecommendations.last;

      // Calculate days since last occurrence
      final daysSinceLastOccurrence =
          DateTime.now()
              .difference(DateFormat('yyyy-MM-dd').parse(mostRecent['date']))
              .inDays;

      // Compare severity
      final severityChanged =
          mostRecent['severity'] != newRecommendation['severity'];
      final severityWorsened =
          _getSeverityValue(newRecommendation['severity']) >
          _getSeverityValue(mostRecent['severity']);

      // Check if any recommended actions are the same
      List<String> previousActions = mostRecent['management_actions'].split(
        '. ',
      );
      List<String> newActions = newRecommendation['management_actions'].split(
        '. ',
      );

      Set<String> previousActionSet = previousActions.toSet();
      Set<String> newActionSet = newActions.toSet();

      Set<String> repeatedActions = previousActionSet.intersection(
        newActionSet,
      );
      Set<String> newlyAddedActions = newActionSet.difference(
        previousActionSet,
      );

      // Calculate recurrence frequency
      int occurrences = pastRecommendations.length + 1; // +1 for current
      int totalDays =
          DateTime.now()
              .difference(
                DateFormat(
                  'yyyy-MM-dd',
                ).parse(pastRecommendations.first['date']),
              )
              .inDays;

      double recurrenceFrequency =
          occurrences / (totalDays / 30); // Occurrences per month

      return {
        'isNew': false,
        'isRecurring': true,
        'daysSinceLastOccurrence': daysSinceLastOccurrence,
        'occurrences': occurrences,
        'recurrenceFrequency': recurrenceFrequency,
        'severityChanged': severityChanged,
        'severityWorsened': severityWorsened,
        'repeatedActionCount': repeatedActions.length,
        'repeatedActions': repeatedActions.toList(),
        'newActionCount': newlyAddedActions.length,
        'newActions': newlyAddedActions.toList(),
        'previousRecommendation': mostRecent,
        'implementationStatus': await _getImplementationStatus(
          hiveId,
          mostRecent,
        ),
      };
    } catch (e) {
      print('Error comparing with historical recommendations: $e');
      return {
        'isNew': true,
        'error': 'Error comparing with historical data: $e',
      };
    }
  }

  // Helper method to get numeric value for severity
  int _getSeverityValue(String severity) {
    switch (severity) {
      case 'High':
        return 3;
      case 'Medium':
        return 2;
      case 'Low':
        return 1;
      default:
        return 0;
    }
  }

  // Check if previous recommendations were implemented
  Future<Map<String, dynamic>> _getImplementationStatus(
    String hiveId,
    Map<String, dynamic> recommendation,
  ) async {
    try {
      final implemented = await BeeAdvisoryDatabase.instance
          .checkRecommendationImplemented(recommendation['id']);

      if (implemented) {
        return {
          'implemented': true,
          'message': 'Previous recommendation was marked as implemented',
        };
      } else {
        return {
          'implemented': false,
          'message': 'Previous recommendation was not marked as implemented',
        };
      }
    } catch (e) {
      return {
        'implemented': false,
        'error': 'Error checking implementation status: $e',
      };
    }
  }
  // Helper methods to get suitable plants and supplements

  Future<List<Map<String, dynamic>>> _getSuitablePlantsForReturnRate(
    Map<String, dynamic> environmentalFactors,
  ) async {
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();

    // If we have environmental data, filter by climate
    if (environmentalFactors.containsKey('weatherData') &&
        environmentalFactors['weatherData'].isNotEmpty) {
      String climate = 'temperate'; // Default

      // Try to determine climate from temperature ranges if available
      if (environmentalFactors['weatherData'].containsKey('temperature') &&
          environmentalFactors['weatherData']['temperature'].containsKey(
            'values',
          ) &&
          environmentalFactors['weatherData']['temperature']['values']
              .isNotEmpty) {
        var tempValues =
            environmentalFactors['weatherData']['temperature']['values'];
        if (tempValues.isNotEmpty) {
          double avgTemp = 0;
          for (var temp in tempValues) {
            avgTemp += temp;
          }
          avgTemp /= tempValues.length;

          if (avgTemp > 30) {
            climate = 'tropical';
          } else if (avgTemp > 25) {
            climate = 'subtropical';
          } else if (avgTemp > 15) {
            climate = 'temperate';
          } else {
            climate = 'cool temperate';
          }
        }
      }

      // Filter plants by climate and high nectar value
      return allPlants
          .where(
            (plant) =>
                plant['climate_preference'].toString().toLowerCase().contains(
                  climate.toLowerCase(),
                ) &&
                (plant['nectar_value'] >= 4),
          )
          .toList();
    }

    // If no environmental data, just return high nectar plants
    return allPlants.where((plant) => plant['nectar_value'] >= 4).toList();
  }

  Future<List<Map<String, dynamic>>> _getSuitablePlantsByValue(
    String valueType,
    int minValue,
  ) async {
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();
    return allPlants
        .where((plant) => plant[valueType + '_value'] >= minValue)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getDiversePlants() async {
    // Get a diverse selection of plants for general recommendations
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();

    // Get a mix of high nectar and high pollen plants with different seasons
    Map<String, bool> includedSeasons = {};
    List<Map<String, dynamic>> diversePlants = [];

    // First add high-value plants (both nectar and pollen)
    var highValuePlants =
        allPlants
            .where(
              (plant) =>
                  plant['nectar_value'] >= 4 && plant['pollen_value'] >= 4,
            )
            .toList();

    // Add some high-value plants, tracking their seasons
    for (var plant in highValuePlants.take(3)) {
      diversePlants.add(plant);
      String season = plant['flowering_season'].toString().toLowerCase();
      includedSeasons[season] = true;
    }

    // Then fill in any missing seasons
    var seasonalPlants =
        allPlants
            .where(
              (plant) =>
                  !diversePlants.any(
                    (p) => p['id'] == plant['id'],
                  ) && // Not already included
                  (plant['nectar_value'] >= 3 || plant['pollen_value'] >= 3),
            ) // Decent value
            .toList();

    for (var plant in seasonalPlants) {
      String season = plant['flowering_season'].toString().toLowerCase();
      if (!includedSeasons.containsKey(season)) {
        diversePlants.add(plant);
        includedSeasons[season] = true;
      }

      // Break if we have enough diverse plants
      if (diversePlants.length >= 5) break;
    }

    return diversePlants;
  }

  Future<List<Map<String, dynamic>>> _getWeatherResilientPlants(
    Map<String, dynamic> environmentalFactors,
  ) async {
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();

    // If we know the most influential weather factor, prioritize plants that are resilient to it
    if (environmentalFactors.containsKey('mostInfluentialFactor')) {
      String factor = environmentalFactors['mostInfluentialFactor'];

      if (factor == 'windSpeed') {
        // Plants that are wind-resistant
        return allPlants
            .where(
              (plant) =>
                  plant['maintenance_level'] == 'Low' &&
                  !plant['description'].toString().toLowerCase().contains(
                    'tall',
                  ),
            )
            .toList();
      } else if (factor == 'temperature') {
        // Plants that tolerate temperature extremes
        return allPlants
            .where(
              (plant) =>
                  plant['climate_preference'].toString().toLowerCase().contains(
                    'varied',
                  ) ||
                  plant['climate_preference'].toString().toLowerCase().contains(
                    'diverse',
                  ),
            )
            .toList();
      } else if (factor == 'precipitation') {
        // Drought-tolerant plants
        return allPlants
            .where(
              (plant) => plant['water_requirements']
                  .toString()
                  .toLowerCase()
                  .contains('low'),
            )
            .toList();
      }
    }

    // Default to hardy plants
    return allPlants
        .where((plant) => plant['maintenance_level'] == 'Low')
        .toList();
  }

  Future<List<Map<String, dynamic>>> _getSuitableSupplements(
    String type,
  ) async {
    return await BeeAdvisoryDatabase.instance.searchSupplementsByType(type);
  }

  // Add these methods to the BeeAdvisoryEngine class

  // Get current season based on date and location
  String _getCurrentSeason(DateTime date, {String hemisphere = 'northern'}) {
    int month = date.month;

    if (hemisphere.toLowerCase() == 'southern') {
      // Southern hemisphere seasons
      if (month >= 3 && month <= 5) return 'Fall';
      if (month >= 6 && month <= 8) return 'Winter';
      if (month >= 9 && month <= 11) return 'Spring';
      return 'Summer';
    } else {
      // Northern hemisphere seasons (default)
      if (month >= 3 && month <= 5) return 'Spring';
      if (month >= 6 && month <= 8) return 'Summer';
      if (month >= 9 && month <= 11) return 'Fall';
      return 'Winter';
    }
  }

  // Generate seasonal recommendations
  Future<List<Map<String, dynamic>>> generateSeasonalRecommendations(
    String hiveId, {
    String? hemisphere,
  }) async {
    try {
      // Get current date and season
      final now = DateTime.now();
      final currentSeason = _getCurrentSeason(
        now,
        hemisphere: hemisphere ?? 'northern',
      );
      final nextSeason = _getNextSeason(currentSeason);

      // Get hive location data (if available)
      final hiveData = await BeeAdvisoryDatabase.instance.getHiveData(hiveId);
      String userHemisphere =
          hemisphere ??
          (hiveData != null && hiveData.containsKey('hemisphere')
              ? hiveData['hemisphere']
              : 'northern');

      // Generate recommendations based on season
      List<Map<String, dynamic>> recommendations = [];

      // Current season recommendations
      Map<String, dynamic> currentSeasonRec =
          await _generateCurrentSeasonRecommendation(
            hiveId,
            currentSeason,
            userHemisphere,
          );
      recommendations.add(currentSeasonRec);

      // Preparation for next season
      Map<String, dynamic> nextSeasonPrep =
          await _generateNextSeasonPreparation(
            hiveId,
            nextSeason,
            userHemisphere,
          );
      recommendations.add(nextSeasonPrep);

      // Store recommendations in the database
      for (var recommendation in recommendations) {
        await BeeAdvisoryDatabase.instance.insertRecommendation(recommendation);
      }

      return recommendations;
    } catch (e) {
      print('Error generating seasonal recommendations: $e');
      return [
        {'error': 'Error generating seasonal recommendations: $e'},
      ];
    }
  }

  // Get the next season
  String _getNextSeason(String currentSeason) {
    switch (currentSeason) {
      case 'Spring':
        return 'Summer';
      case 'Summer':
        return 'Fall';
      case 'Fall':
        return 'Winter';
      case 'Winter':
        return 'Spring';
      default:
        return 'Spring';
    }
  }

  // Generate recommendation for current season
  Future<Map<String, dynamic>> _generateCurrentSeasonRecommendation(
    String hiveId,
    String season,
    String hemisphere,
  ) async {
    // Get plants appropriate for the current season
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();
    final seasonalPlants =
        allPlants
            .where(
              (plant) =>
                  plant['flowering_season'].toString().toLowerCase().contains(
                    season.toLowerCase(),
                  ) ||
                  _isPlantInSeason(plant, season, hemisphere),
            )
            .toList();

    // Get supplements appropriate for the season
    final allSupplements =
        await BeeAdvisoryDatabase.instance.readAllSupplements();
    List<Map<String, dynamic>> seasonalSupplements = [];

    switch (season) {
      case 'Spring':
        seasonalSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'build',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'growth',
                      ),
                )
                .toList();
        break;
      case 'Summer':
        seasonalSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'production',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'nectar',
                      ),
                )
                .toList();
        break;
      case 'Fall':
        seasonalSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'winter',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'health',
                      ),
                )
                .toList();
        break;
      case 'Winter':
        seasonalSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'survival',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'cluster',
                      ),
                )
                .toList();
        break;
    }

    // Generate season-specific management actions
    List<String> actions = _getSeasonalManagementActions(season, hemisphere);

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': '$season Season Management',
      'severity': 'Medium',
      'recommended_plants': seasonalPlants
          .take(5)
          .map((p) => p['id'])
          .join(','),
      'recommended_supplements': seasonalSupplements
          .take(3)
          .map((s) => s['id'])
          .join(','),
      'management_actions': actions.join('. '),
      'expected_outcome': 'Optimal colony management for $season conditions.',
      'priority': 2,
      'notes':
          'Seasonal recommendation for $season in the $hemisphere hemisphere.',
      'seasonal': true,
    };
  }

  // Generate recommendation for preparing for next season
  Future<Map<String, dynamic>> _generateNextSeasonPreparation(
    String hiveId,
    String nextSeason,
    String hemisphere,
  ) async {
    // Get plants that will bloom in the next season
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();
    final nextSeasonPlants =
        allPlants
            .where(
              (plant) =>
                  plant['flowering_season'].toString().toLowerCase().contains(
                    nextSeason.toLowerCase(),
                  ) ||
                  _isPlantInSeason(plant, nextSeason, hemisphere),
            )
            .toList();

    // Generate next season preparation actions
    List<String> actions = _getNextSeasonPreparationActions(
      nextSeason,
      hemisphere,
    );

    // Get supplements for next season preparation
    final allSupplements =
        await BeeAdvisoryDatabase.instance.readAllSupplements();
    List<Map<String, dynamic>> preparationSupplements = [];

    switch (nextSeason) {
      case 'Spring':
        preparationSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'stimulate',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'preparation',
                      ),
                )
                .toList();
        break;
      case 'Summer':
        preparationSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'production',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'strength',
                      ),
                )
                .toList();
        break;
      case 'Fall':
        preparationSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'winter',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'preparation',
                      ),
                )
                .toList();
        break;
      case 'Winter':
        preparationSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'immunity',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'health',
                      ),
                )
                .toList();
        break;
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Preparing for $nextSeason',
      'severity': 'Medium',
      'recommended_plants': nextSeasonPlants
          .take(5)
          .map((p) => p['id'])
          .join(','),
      'recommended_supplements': preparationSupplements
          .take(3)
          .map((s) => s['id'])
          .join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Well-prepared colony for the upcoming $nextSeason season.',
      'priority': 2,
      'notes':
          'Preparation recommendation for upcoming $nextSeason in the $hemisphere hemisphere.',
      'seasonal': true,
      'preparation': true,
    };
  }

  // Check if a plant is in season
  bool _isPlantInSeason(
    Map<String, dynamic> plant,
    String season,
    String hemisphere,
  ) {
    // Check if plant has bloom months data
    if (!plant.containsKey('bloom_start_month') ||
        !plant.containsKey('bloom_end_month')) {
      return false;
    }

    int bloomStart = plant['bloom_start_month'];
    int bloomEnd = plant['bloom_end_month'];

    // Adjust for hemisphere if needed
    if (hemisphere.toLowerCase() == 'southern') {
      // Shift by 6 months for southern hemisphere
      bloomStart = (bloomStart + 6) % 12;
      if (bloomStart == 0) bloomStart = 12;

      bloomEnd = (bloomEnd + 6) % 12;
      if (bloomEnd == 0) bloomEnd = 12;
    }

    // Check if current season months overlap with bloom period
    List<int> seasonMonths = [];
    switch (season) {
      case 'Spring':
        seasonMonths =
            hemisphere.toLowerCase() == 'northern' ? [3, 4, 5] : [9, 10, 11];
        break;
      case 'Summer':
        seasonMonths =
            hemisphere.toLowerCase() == 'northern' ? [6, 7, 8] : [12, 1, 2];
        break;
      case 'Fall':
        seasonMonths =
            hemisphere.toLowerCase() == 'northern' ? [9, 10, 11] : [3, 4, 5];
        break;
      case 'Winter':
        seasonMonths =
            hemisphere.toLowerCase() == 'northern' ? [12, 1, 2] : [6, 7, 8];
        break;
    }

    // Check if any month in the season falls within the bloom period
    for (int month in seasonMonths) {
      if (bloomStart <= bloomEnd) {
        // Normal case: e.g., April (4) to June (6)
        if (month >= bloomStart && month <= bloomEnd) {
          return true;
        }
      } else {
        // Wrap-around case: e.g., November (11) to February (2)
        if (month >= bloomStart || month <= bloomEnd) {
          return true;
        }
      }
    }

    return false;
  }

  // Add these methods to the BeeAdvisoryEngine class

  // Generate predictive recommendations
  Future<List<Map<String, dynamic>>> generatePredictiveRecommendations(
    String hiveId, {
    int predictionDays = 30,
  }) async {
    try {
      // Get historical foraging data
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: 90)); // Last 90 days

      final historicalData =
          await ForagingAnalysisEngine.analyzeForagingActivity(
            hiveId: hiveId,
            startDate: startDate,
            endDate: now,
            includeWeatherData: true,
          );

      if (!historicalData.containsKey('hasData') ||
          !historicalData['hasData']) {
        return [
          {'error': 'Insufficient historical data for prediction'},
        ];
      }

      // Get recommendation history
      final recommendationHistory = await getRecommendationHistory(
        hiveId,
        months: 3,
      );

      // Generate predictions
      List<Map<String, dynamic>> predictions = [];

      // 1. Predict based on seasonal patterns
      Map<String, dynamic> seasonalPrediction = await _predictSeasonalIssues(
        hiveId,
        historicalData,
        recommendationHistory,
      );
      if (seasonalPrediction.isNotEmpty) {
        predictions.add(seasonalPrediction);
      }

      // 2. Predict based on weather forecast
      Map<String, dynamic> weatherPrediction =
          await _predictWeatherRelatedIssues(hiveId, historicalData);
      if (weatherPrediction.isNotEmpty) {
        predictions.add(weatherPrediction);
      }

      // 3. Predict based on trend analysis
      Map<String, dynamic> trendPrediction = await _predictTrendBasedIssues(
        hiveId,
        historicalData,
        recommendationHistory,
      );
      if (trendPrediction.isNotEmpty) {
        predictions.add(trendPrediction);
      }

      // 4. Predict based on recurring patterns
      Map<String, dynamic> recurringPrediction = await _predictRecurringIssues(
        hiveId,
        recommendationHistory,
      );
      if (recurringPrediction.isNotEmpty) {
        predictions.add(recurringPrediction);
      }

      // Store predictions in the database
      for (var prediction in predictions) {
        await BeeAdvisoryDatabase.instance.insertRecommendation(prediction);
      }

      return predictions;
    } catch (e) {
      print('Error generating predictive recommendations: $e');
      return [
        {'error': 'Error generating predictive recommendations: $e'},
      ];
    }
  }

  // Predict seasonal issues
  Future<Map<String, dynamic>> _predictSeasonalIssues(
    String hiveId,
    Map<String, dynamic> historicalData,
    Map<String, dynamic> recommendationHistory,
  ) async {
    // Get current season and next season
    final now = DateTime.now();
    final currentSeason = _getCurrentSeason(now);
    final nextSeason = _getNextSeason(currentSeason);

    // Get hive location data (if available)
    final hiveData = await BeeAdvisoryDatabase.instance.getHiveData(hiveId);
    String hemisphere =
        hiveData != null && hiveData.containsKey('hemisphere')
            ? hiveData['hemisphere']
            : 'northern';

    // Check if we have seasonal patterns in historical data
    if (!historicalData.containsKey('patterns') ||
        !historicalData['patterns'].containsKey('seasonalPatterns')) {
      return {};
    }

    Map<String, dynamic> seasonalPatterns =
        historicalData['patterns']['seasonalPatterns'];

    // Check if we have data for the upcoming season
    String upcomingSeasonKey = nextSeason.toLowerCase();
    if (!seasonalPatterns.containsKey(upcomingSeasonKey)) {
      return {};
    }

    Map<String, dynamic> upcomingSeasonData =
        seasonalPatterns[upcomingSeasonKey];

    // Check for potential issues in the upcoming season
    List<String> predictedIssues = [];
    String severity = 'Medium';

    if (upcomingSeasonData.containsKey('returnRate') &&
        upcomingSeasonData['returnRate'] < 85) {
      predictedIssues.add(
        'Low return rate (${upcomingSeasonData['returnRate'].toStringAsFixed(1)}%)',
      );
      if (upcomingSeasonData['returnRate'] < 75) {
        severity = 'High';
      }
    }

    if (upcomingSeasonData.containsKey('efficiencyScore') &&
        upcomingSeasonData['efficiencyScore'] < 70) {
      predictedIssues.add(
        'Low efficiency (${upcomingSeasonData['efficiencyScore'].toStringAsFixed(1)})',
      );
      if (upcomingSeasonData['efficiencyScore'] < 60) {
        severity = 'High';
      }
    }

    if (upcomingSeasonData.containsKey('healthScore') &&
        upcomingSeasonData['healthScore'] < 70) {
      predictedIssues.add(
        'Poor health (${upcomingSeasonData['healthScore'].toStringAsFixed(1)})',
      );
      if (upcomingSeasonData['healthScore'] < 60) {
        severity = 'High';
      }
    }

    if (predictedIssues.isEmpty) {
      return {};
    }

    // Get plants appropriate for the upcoming season
    final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();
    final seasonalPlants =
        allPlants
            .where(
              (plant) =>
                  plant['flowering_season'].toString().toLowerCase().contains(
                    nextSeason.toLowerCase(),
                  ) ||
                  _isPlantInSeason(plant, nextSeason, hemisphere),
            )
            .toList();

    // Get supplements appropriate for the upcoming season
    final allSupplements =
        await BeeAdvisoryDatabase.instance.readAllSupplements();
    List<Map<String, dynamic>> seasonalSupplements = [];

    switch (nextSeason) {
      case 'Spring':
        seasonalSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'build',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'growth',
                      ),
                )
                .toList();
        break;
      case 'Summer':
        seasonalSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'production',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'nectar',
                      ),
                )
                .toList();
        break;
      case 'Fall':
        seasonalSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'winter',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'health',
                      ),
                )
                .toList();
        break;
      case 'Winter':
        seasonalSupplements =
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'survival',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'cluster',
                      ),
                )
                .toList();
        break;
    }

    // Generate preventive actions
    List<String> actions = [];

    for (String issue in predictedIssues) {
      if (issue.contains('return rate')) {
        actions.add(
          'Prepare for potential return rate issues by checking for predators and ensuring clear flight paths',
        );
      }
      if (issue.contains('efficiency')) {
        actions.add(
          'Plan for efficiency challenges by ensuring diverse forage sources are available',
        );
      }
      if (issue.contains('health')) {
        actions.add(
          'Prepare for potential health issues with preventive supplements and regular monitoring',
        );
      }
    }

    // Add general seasonal preparation actions
    actions.addAll(_getNextSeasonPreparationActions(nextSeason, hemisphere));

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Predicted $nextSeason Season Issues',
      'severity': severity,
      'recommended_plants': seasonalPlants
          .take(5)
          .map((p) => p['id'])
          .join(','),
      'recommended_supplements': seasonalSupplements
          .take(3)
          .map((s) => s['id'])
          .join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Prevention of predicted issues in the upcoming $nextSeason season.',
      'priority': severity == 'High' ? 2 : 3,
      'notes':
          'Based on historical seasonal patterns, the following issues are predicted for $nextSeason: ${predictedIssues.join(", ")}',
      'predictive': true,
      'seasonal': true,
    };
  }

  // Predict weather-related issues
  Future<Map<String, dynamic>> _predictWeatherRelatedIssues(
    String hiveId,
    Map<String, dynamic> historicalData,
  ) async {
    // Check if we have environmental factors data
    if (!historicalData.containsKey('environmentalFactors') ||
        !historicalData['environmentalFactors'].containsKey('weatherData')) {
      return {};
    }

    Map<String, dynamic> weatherData =
        historicalData['environmentalFactors']['weatherData'];

    // Get weather forecast (mock - in a real app, you would integrate with a weather API)
    Map<String, dynamic> weatherForecast = await _getMockWeatherForecast();

    // Find the most influential weather factor
    String mostInfluentialFactor = _getMostInfluentialWeatherFactor(
      historicalData['environmentalFactors'],
    );
    double correlationStrength = 0;

    if (weatherData.containsKey(mostInfluentialFactor) &&
        weatherData[mostInfluentialFactor].containsKey('correlations') &&
        weatherData[mostInfluentialFactor]['correlations'].containsKey(
          'totalActivity',
        )) {
      correlationStrength =
          weatherData[mostInfluentialFactor]['correlations']['totalActivity']['correlation']
              .abs();
    }

    // If correlation is not strong enough, no prediction
    if (correlationStrength < 0.4) {
      return {};
    }

    // Check if the forecast has extreme values for the influential factor
    bool hasExtremeForecast = false;
    String extremeCondition = '';

    if (weatherForecast.containsKey(mostInfluentialFactor)) {
      double forecastValue = weatherForecast[mostInfluentialFactor];

      switch (mostInfluentialFactor) {
        case 'temperature':
          if (forecastValue > 35 || forecastValue < 10) {
            hasExtremeForecast = true;
            extremeCondition =
                forecastValue > 35 ? 'high temperatures' : 'low temperatures';
          }
          break;
        case 'windSpeed':
          if (forecastValue > 25) {
            hasExtremeForecast = true;
            extremeCondition = 'high winds';
          }
          break;
        case 'precipitation':
          if (forecastValue > 20) {
            hasExtremeForecast = true;
            extremeCondition = 'heavy precipitation';
          }
          break;
        case 'humidity':
          if (forecastValue > 90 || forecastValue < 30) {
            hasExtremeForecast = true;
            extremeCondition =
                forecastValue > 90 ? 'high humidity' : 'low humidity';
          }
          break;
      }
    }

    if (!hasExtremeForecast) {
      return {};
    }

    // Get weather-resilient plants
    final plants = await _getWeatherResilientPlants(
      historicalData['environmentalFactors'],
    );

    // Get suitable supplements for stress periods
    final supplements = await _getSuitableSupplements('Feed');

    // Generate weather-specific actions
    List<String> actions = [];

    switch (mostInfluentialFactor) {
      case 'temperature':
        if (extremeCondition.contains('high')) {
          actions.add(
            'Provide additional shade for hives during the forecasted heat',
          );
          actions.add('Ensure water sources are available and won\'t dry out');
          actions.add('Consider adding ventilation to hives');
          actions.add(
            'Monitor for overheating and be prepared to cool hives if necessary',
          );
        } else {
          actions.add(
            'Reduce hive entrances during the forecasted cold period',
          );
          actions.add('Consider adding insulation to hives');
          actions.add(
            'Ensure adequate food stores are accessible within the cluster',
          );
          actions.add(
            'Monitor for cluster location and adequate ventilation to prevent condensation',
          );
        }
        break;
      case 'windSpeed':
        actions.add('Secure hives against forecasted high winds');
        actions.add(
          'Create temporary windbreaks if permanent ones aren\'t in place',
        );
        actions.add('Reduce entrances to minimize drafts');
        actions.add('Check hives after wind events for damage');
        break;
      case 'precipitation':
        actions.add(
          'Ensure hives are tilted slightly forward to prevent water accumulation',
        );
        actions.add('Check that hive roofs are secure and waterproof');
        actions.add('Clear entrances after heavy rain to prevent blockage');
        actions.add(
          'Consider providing supplemental feed if extended rain prevents foraging',
        );
        break;
      case 'humidity':
        if (extremeCondition.contains('high')) {
          actions.add(
            'Ensure adequate ventilation to prevent excess moisture in hives',
          );
          actions.add(
            'Monitor for signs of fungal diseases which thrive in humid conditions',
          );
          actions.add('Consider adding moisture-absorbing materials to hives');
        } else {
          actions.add('Provide water sources near hives during dry conditions');
          actions.add(
            'Monitor for dehydration in brood and consider light misting if necessary',
          );
        }
        break;
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Predicted Weather Impact',
      'severity': 'Medium',
      'recommended_plants': plants.take(5).map((p) => p['id']).join(','),
      'recommended_supplements': supplements
          .take(3)
          .map((s) => s['id'])
          .join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Minimized impact of forecasted weather conditions on colony activity and health.',
      'priority': 2,
      'notes':
          'Based on historical weather sensitivity, the colony is predicted to experience issues related to $extremeCondition. Recommended actions are based on mitigating these effects.',
      'predictive': true,
      'weather_related': true,
    };
  }

  // Mock weather forecast - in a real app, this would be replaced with an API call
  Future<Map<String, dynamic>> _getMockWeatherForecast() async {
    // Simulate API delay
    await Future.delayed(Duration(milliseconds: 300));

    // Return mock forecast
    final now = DateTime.now();

    // Generate somewhat realistic values based on season
    double temperature;
    double windSpeed;
    double precipitation;
    double humidity;

    String season = _getCurrentSeason(now);

    switch (season) {
      case 'Spring':
        temperature = 15 + (math.Random().nextDouble() * 10); // 15-25°C
        windSpeed = 5 + (math.Random().nextDouble() * 15); // 5-20 km/h
        precipitation = math.Random().nextDouble() * 15; // 0-15 mm
        humidity = 60 + (math.Random().nextDouble() * 20); // 60-80%
        break;
      case 'Summer':
        temperature = 25 + (math.Random().nextDouble() * 15); // 25-40°C
        windSpeed = math.Random().nextDouble() * 10; // 0-10 km/h
        precipitation = math.Random().nextDouble() * 10; // 0-10 mm
        humidity = 50 + (math.Random().nextDouble() * 30); // 50-80%
        break;
      case 'Fall':
        temperature = 10 + (math.Random().nextDouble() * 10); // 10-20°C
        windSpeed = 5 + (math.Random().nextDouble() * 20); // 5-25 km/h
        precipitation = 5 + (math.Random().nextDouble() * 20); // 5-25 mm
        humidity = 70 + (math.Random().nextDouble() * 20); // 70-90%
        break;
      case 'Winter':
        temperature = -5 + (math.Random().nextDouble() * 15); // -5-10°C
        windSpeed = 10 + (math.Random().nextDouble() * 20); // 10-30 km/h
        precipitation = math.Random().nextDouble() * 10; // 0-10 mm
        humidity = 60 + (math.Random().nextDouble() * 30); // 60-90%
        break;
      default:
        temperature = 20;
        windSpeed = 10;
        precipitation = 5;
        humidity = 70;
    }

    // Occasionally generate extreme values for testing
    if (math.Random().nextDouble() > 0.7) {
      // 30% chance of extreme value
      int extremeType = math.Random().nextInt(4);
      switch (extremeType) {
        case 0:
          temperature = math.Random().nextBool() ? 40 : -10;
          break;
        case 1:
          windSpeed = 30 + (math.Random().nextDouble() * 20); // 30-50 km/h
          break;
        case 2:
          precipitation = 30 + (math.Random().nextDouble() * 20); // 30-50 mm
          break;
        case 3:
          humidity = math.Random().nextBool() ? 95 : 20;
          break;
      }
    }

    return {
      'temperature': temperature,
      'windSpeed': windSpeed,
      'precipitation': precipitation,
      'humidity': humidity,
      'forecast_date': DateFormat(
        'yyyy-MM-dd',
      ).format(now.add(Duration(days: 3))),
    };
  }

  // Predict trend-based issues
  Future<Map<String, dynamic>> _predictTrendBasedIssues(
    String hiveId,
    Map<String, dynamic> historicalData,
    Map<String, dynamic> recommendationHistory,
  ) async {
    // Check if we have enough data for trend analysis
    if (!historicalData.containsKey('metrics') ||
        !historicalData.containsKey('trends')) {
      return {};
    }

    Map<String, dynamic> metrics = historicalData['metrics'];
    Map<String, dynamic> trends = historicalData['trends'];

    // Check for concerning trends
    List<String> concerningTrends = [];
    String severity = 'Medium';

    // Check return rate trend
    if (trends.containsKey('returnRateTrend') &&
        trends['returnRateTrend'] < -5) {
      concerningTrends.add(
        'Declining return rate (${trends['returnRateTrend'].toStringAsFixed(1)}% per month)',
      );
      if (trends['returnRateTrend'] < -10) {
        severity = 'High';
      }
    }

    // Check efficiency trend
    if (trends.containsKey('efficiencyTrend') &&
        trends['efficiencyTrend'] < -5) {
      concerningTrends.add(
        'Declining efficiency (${trends['efficiencyTrend'].toStringAsFixed(1)} points per month)',
      );
      if (trends['efficiencyTrend'] < -10) {
        severity = 'High';
      }
    }

    // Check health trend
    if (trends.containsKey('healthTrend') && trends['healthTrend'] < -5) {
      concerningTrends.add(
        'Declining health (${trends['healthTrend'].toStringAsFixed(1)} points per month)',
      );
      if (trends['healthTrend'] < -10) {
        severity = 'High';
      }
    }

    // Check population trend
    if (trends.containsKey('populationTrend') &&
        trends['populationTrend'] < -100) {
      concerningTrends.add(
        'Declining population (${trends['populationTrend'].toStringAsFixed(0)} bees per month)',
      );
      if (trends['populationTrend'] < -500) {
        severity = 'High';
      }
    }

    if (concerningTrends.isEmpty) {
      return {};
    }

    // Get diverse plants
    final plants = await _getDiversePlants();

    // Get comprehensive supplements
    final healthSupplements = await _getSuitableSupplements('Health');
    final feedSupplements = await _getSuitableSupplements('Feed');

    // Combine supplement types, prioritizing health
    List<Map<String, dynamic>> allSupplements = [
      ...healthSupplements,
      ...feedSupplements,
    ];

    // Generate trend-specific actions
    List<String> actions = [];

    for (String trend in concerningTrends) {
      if (trend.contains('return rate')) {
        actions.add(
          'Investigate potential causes of declining return rates such as predators, pesticides, or disease',
        );
        actions.add(
          'Consider installing entrance reducers to minimize predation',
        );
        actions.add('Check surrounding areas for new pesticide applications');
      }
      if (trend.contains('efficiency')) {
        actions.add(
          'Evaluate hive placement for optimal sun exposure and wind protection',
        );
        actions.add(
          'Ensure diverse forage sources are available at varying distances',
        );
        actions.add(
          'Check for signs of disease or parasites that might be affecting foraging efficiency',
        );
      }
      if (trend.contains('health')) {
        actions.add(
          'Conduct a thorough hive inspection focusing on brood pattern and disease symptoms',
        );
        actions.add('Consider testing for common pathogens');
        actions.add(
          'Implement a comprehensive health management plan including supplements and monitoring',
        );
      }
      if (trend.contains('population')) {
        actions.add(
          'Check for queen performance and consider requeening if necessary',
        );
        actions.add('Evaluate for signs of swarming or absconding');
        actions.add(
          'Monitor for brood diseases that might be affecting population growth',
        );
      }
    }

    // Add general preventive actions
    actions.add(
      'Implement regular monitoring to track if interventions are reversing negative trends',
    );
    actions.add(
      'Consider consulting with a local beekeeping expert if trends continue despite interventions',
    );

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Predicted Issues Based on Trends',
      'severity': severity,
      'recommended_plants': plants.take(5).map((p) => p['id']).join(','),
      'recommended_supplements': allSupplements
          .take(5)
          .map((s) => s['id'])
          .join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Reversal of concerning trends and improved colony performance.',
      'priority': severity == 'High' ? 1 : 2,
      'notes':
          'Based on trend analysis, the following concerning patterns were identified: ${concerningTrends.join(", ")}',
      'predictive': true,
      'trend_based': true,
    };
  }

  // Predict recurring issues
  Future<Map<String, dynamic>> _predictRecurringIssues(
    String hiveId,
    Map<String, dynamic> recommendationHistory,
  ) async {
    // Check if we have recommendation history data
    if (!recommendationHistory.containsKey('hasData') ||
        !recommendationHistory['hasData'] ||
        !recommendationHistory.containsKey('issueTrends')) {
      return {};
    }

    Map<String, Map<String, dynamic>> issueTrends =
        recommendationHistory['issueTrends'];

    // Find recurring issues with high frequency
    List<String> recurringIssues = [];
    String mostFrequentIssue = '';
    double highestFrequency = 0;

    issueTrends.forEach((issue, data) {
      if (data.containsKey('occurrences') &&
          data['occurrences'] >= 3 &&
          !issue.contains('Season')) {
        // Exclude seasonal recommendations

        // Calculate approximate frequency (occurrences per month)
        double frequency =
            data['occurrences'] / 3; // Assuming 3 months of history

        if (frequency >= 1) {
          // At least once per month
          recurringIssues.add(
            '$issue (${frequency.toStringAsFixed(1)} times per month)',
          );

          if (frequency > highestFrequency) {
            highestFrequency = frequency;
            mostFrequentIssue = issue;
          }
        }
      }
    });

    if (recurringIssues.isEmpty || mostFrequentIssue.isEmpty) {
      return {};
    }

    // Get details of the most frequent issue
    Map<String, dynamic> issueData = issueTrends[mostFrequentIssue]!;

    // Determine severity based on frequency and current severity
    String severity = 'Medium';
    if (highestFrequency >= 2 ||
        (issueData.containsKey('currentSeverity') &&
            _getSeverityValue(issueData['currentSeverity']) >= 3)) {
      severity = 'High';
    }

    // Get plants and supplements based on the issue type
    List<Map<String, dynamic>> recommendedPlants = [];
    List<Map<String, dynamic>> recommendedSupplements = [];

    if (mostFrequentIssue.contains('Return Rate')) {
      recommendedPlants = await _getSuitablePlantsByValue('nectar', 4);
      recommendedSupplements = await _getSuitableSupplements('Feed');
    } else if (mostFrequentIssue.contains('Efficiency')) {
      recommendedPlants = await _getDiversePlants();
      recommendedSupplements = await _getSuitableSupplements('Health');
    } else if (mostFrequentIssue.contains('Health')) {
      recommendedPlants = await _getDiversePlants();
      recommendedSupplements = await _getSuitableSupplements('Health');
    } else if (mostFrequentIssue.contains('Duration') ||
        mostFrequentIssue.contains('Trip')) {
      if (mostFrequentIssue.contains('Short')) {
        recommendedPlants = await _getSuitablePlantsByValue('nectar', 4);
      } else {
        recommendedPlants = await BeeAdvisoryDatabase.instance.readAllPlants();
        recommendedPlants =
            recommendedPlants
                .where(
                  (p) =>
                      p['maintenance_level'] == 'Low' ||
                      p['maintenance_level'] == 'Medium',
                )
                .toList();
      }
      recommendedSupplements = await _getSuitableSupplements('Feed');
    } else {
      // Default
      recommendedPlants = await _getDiversePlants();
      recommendedSupplements = await _getSuitableSupplements('Health');
    }

    // Generate actions to address the recurring issue
    List<String> actions = [];

    // Check if previous recommendations were implemented
    bool previouslyImplemented = false;
    if (issueData.containsKey('implementationStatus') &&
        issueData['implementationStatus'].containsKey('implemented')) {
      previouslyImplemented = issueData['implementationStatus']['implemented'];
    }

    if (previouslyImplemented) {
      actions.add(
        'Previous recommendations were implemented but the issue persists, suggesting a need for different approaches',
      );
      actions.add(
        'Consider consulting with a bee specialist for an in-depth evaluation',
      );

      if (mostFrequentIssue.contains('Return Rate')) {
        actions.add(
          'Investigate for persistent predator pressure or nearby pesticide use',
        );
        actions.add(
          'Consider relocating hives if environmental factors cannot be mitigated',
        );
      } else if (mostFrequentIssue.contains('Efficiency')) {
        actions.add('Evaluate queen performance and consider requeening');
        actions.add(
          'Check for chronic disease or parasite issues that might be affecting efficiency',
        );
      } else if (mostFrequentIssue.contains('Health')) {
        actions.add('Implement a more aggressive health management protocol');
        actions.add('Consider testing for less common pathogens or toxins');
      } else if (mostFrequentIssue.contains('Duration') ||
          mostFrequentIssue.contains('Trip')) {
        actions.add(
          'Evaluate the surrounding landscape for forage quality and quantity',
        );
        actions.add(
          'Consider more substantial landscape modifications to improve forage availability',
        );
      }
    } else {
      // If not implemented, suggest the most effective previous recommendations
      if (issueData.containsKey('repeatedActions') &&
          issueData['repeatedActions'].isNotEmpty) {
        List<String> repeatedActions = issueData['repeatedActions'];
        actions.add(
          'Previous recommendations that should be prioritized: ${repeatedActions.join(". ")}',
        );
      }

      actions.add(
        'Implement recommendations consistently to address this recurring issue',
      );
      actions.add('Set up a regular monitoring schedule to track improvement');
    }

    return {
      'hive_id': hiveId,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'issue_identified': 'Recurring Issue: $mostFrequentIssue',
      'severity': severity,
      'recommended_plants': recommendedPlants
          .take(5)
          .map((p) => p['id'])
          .join(','),
      'recommended_supplements': recommendedSupplements
          .take(3)
          .map((s) => s['id'])
          .join(','),
      'management_actions': actions.join('. '),
      'expected_outcome':
          'Resolution of persistent issue and improved colony stability.',
      'priority': severity == 'High' ? 1 : 2,
      'notes':
          'This issue has recurred frequently (${highestFrequency.toStringAsFixed(1)} times per month) and requires focused attention.',
      'predictive': true,
      'recurring': true,
    };
  }

  // Get seasonal management actions
  List<String> _getSeasonalManagementActions(String season, String hemisphere) {
    switch (season) {
      case 'Spring':
        return [
          'Monitor for swarm cells and implement swarm prevention measures',
          'Add supers as the colony expands',
          'Ensure adequate room for brood nest expansion',
          'Monitor pollen and nectar availability',
          'Consider splitting strong colonies',
          'Begin regular disease and pest monitoring',
        ];
      case 'Summer':
        return [
          'Ensure adequate ventilation during hot periods',
          'Monitor for nectar flow and add supers as needed',
          'Check for adequate water sources near hives',
          'Monitor for pest buildup, especially varroa mites',
          'Consider honey harvest timing based on nectar flows',
          'Provide shade during extreme heat',
        ];
      case 'Fall':
        return [
          'Assess and treat for varroa mites if necessary',
          'Evaluate honey stores for winter',
          'Reduce hive entrances as temperatures cool',
          'Consider combining weak colonies',
          'Ensure adequate fall nutrition to raise healthy winter bees',
          'Remove empty supers to help bees concentrate in smaller space',
        ];
      case 'Winter':
        return [
          'Ensure adequate ventilation while minimizing drafts',
          'Consider windbreaks or insulation in cold climates',
          'Monitor food stores periodically',
          'Clear entrances after snow',
          'Minimize hive disturbance during cold periods',
          'Consider emergency feeding if stores run low',
        ];
      default:
        return [
          'Implement seasonal management practices appropriate for your area',
        ];
    }
  }

  // Get next season preparation actions
  List<String> _getNextSeasonPreparationActions(
    String nextSeason,
    String hemisphere,
  ) {
    switch (nextSeason) {
      case 'Spring':
        return [
          'Prepare equipment for colony expansion',
          'Plan for potential splits or nucleus colonies',
          'Order queens if requeening is planned',
          'Prepare areas for new colonies if expansion is planned',
          'Plant early-blooming flowers for first nectar sources',
          'Clean and prepare additional supers and frames',
        ];
      case 'Summer':
        return [
          'Prepare honey harvesting equipment',
          'Plan for managing honey supers during peak flow',
          'Ensure adequate shade options for hot weather',
          'Prepare water sources that wont dry out',
          'Plan pest monitoring schedule for summer months',
          'Consider planting late-summer blooming plants for continued nectar flow',
        ];
      case 'Fall':
        return [
          'Prepare winter feeding supplements',
          'Plan for fall mite treatments',
          'Consider equipment for winter preparation (entrance reducers, etc.)',
          'Plan for combining weak colonies before winter',
          'Prepare windbreaks or insulation if needed in your climate',
          'Plant fall-blooming flowers for late-season nectar and pollen',
        ];
      case 'Winter':
        return [
          'Prepare emergency winter feeding options',
          'Plan for periodic winter checks',
          'Consider insulation needs based on your climate',
          'Prepare equipment for early spring management',
          'Plan for early spring supplements if needed in your area',
          'Order seeds for spring bee forage planting',
        ];
      default:
        return ['Prepare for seasonal transitions appropriate for your area'];
    }
  }

  // Process farmer form input and generate personalized recommendations
  Future<Map<String, dynamic>> processFarmerForm(
    Map<String, dynamic> formData,
  ) async {
    try {
      // Store the farmer input
      await BeeAdvisoryDatabase.instance.insertFarmerInput(formData);

      // Generate recommendations based on form data
      List<Map<String, dynamic>> recommendedPlants = [];
      List<Map<String, dynamic>> recommendedSupplements = [];
      List<String> managementActions = [];

      // Get all plants and supplements
      final allPlants = await BeeAdvisoryDatabase.instance.readAllPlants();
      final allSupplements =
          await BeeAdvisoryDatabase.instance.readAllSupplements();

      // Filter based on climate zone
      if (formData.containsKey('climate_zone') &&
          formData['climate_zone'] != null) {
        recommendedPlants =
            allPlants
                .where(
                  (plant) => plant['climate_preference']
                      .toString()
                      .toLowerCase()
                      .contains(
                        formData['climate_zone'].toString().toLowerCase(),
                      ),
                )
                .toList();
      } else {
        recommendedPlants = allPlants;
      }

      // Consider available area
      if (formData.containsKey('available_area') &&
          formData['available_area'] != null) {
        double area =
            double.tryParse(formData['available_area'].toString()) ?? 0;

        if (area < 100) {
          // Small area (less than 100 sq meters)
          // Prioritize compact plants
          recommendedPlants =
              recommendedPlants
                  .where(
                    (plant) =>
                        !plant['description'].toString().toLowerCase().contains(
                          'large',
                        ) &&
                        !plant['description'].toString().toLowerCase().contains(
                          'tall',
                        ),
                  )
                  .toList();

          managementActions.add(
            'Consider vertical gardening to maximize space',
          );
          managementActions.add('Focus on high-yield, compact plants');
        } else if (area > 1000) {
          // Large area (more than 1000 sq meters)
          managementActions.add(
            'Plant in large blocks to increase visibility to foraging bees',
          );
          managementActions.add('Consider establishing wildflower meadows');
        }
      }

      // Consider current issues
      if (formData.containsKey('current_issues') &&
          formData['current_issues'] != null) {
        String issues = formData['current_issues'].toString().toLowerCase();

        if (issues.contains('low honey')) {
          recommendedPlants =
              recommendedPlants
                  .where((plant) => plant['nectar_value'] >= 4)
                  .toList();

          recommendedSupplements.addAll(
            allSupplements.where((supp) => supp['type'] == 'Feed').toList(),
          );

          managementActions.add(
            'Focus on planting high-nectar producing flowers',
          );
        }

        if (issues.contains('disease') || issues.contains('pest')) {
          recommendedSupplements.addAll(
            allSupplements.where((supp) => supp['type'] == 'Health').toList(),
          );

          managementActions.add('Consider regular health monitoring');
          managementActions.add(
            'Implement integrated pest management practices',
          );
        }

        if (issues.contains('weak')) {
          recommendedSupplements.addAll(
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'strength',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'health',
                      ),
                )
                .toList(),
          );

          managementActions.add('Provide protein supplements in early spring');
          managementActions.add('Ensure consistent water supply near hives');
        }

        // Handle specific issues that might not be detected from foraging data
        if (issues.contains('queen')) {
          managementActions.add('Check for queen presence and quality');
          managementActions.add(
            'Consider requeening if queen performance is suboptimal',
          );
        }

        if (issues.contains('robbing')) {
          managementActions.add(
            'Reduce hive entrances during nectar dearth periods',
          );
          managementActions.add(
            'Avoid open feeding to prevent triggering robbing behavior',
          );
        }
      }

      // Consider water source information
      if (formData.containsKey('water_distance') &&
          formData['water_distance'] != null) {
        double waterDistance =
            double.tryParse(formData['water_distance'].toString()) ?? 0;

        if (waterDistance > 300) {
          managementActions.add(
            'Provide a closer water source for bees - ideally within 100 meters',
          );
          managementActions.add(
            'Consider installing a bee-friendly water station with landing spots',
          );
        } else if (waterDistance == 0) {
          managementActions.add(
            'Ensure bees have access to clean water within 300 meters of hives',
          );
        }
      }

      // Consider current supplements
      if (formData.containsKey('current_supplements') &&
          formData['current_supplements'] != null) {
        String currentSupplements =
            formData['current_supplements'].toString().toLowerCase();

        // If they're not already providing protein supplements
        if (!currentSupplements.contains('pollen') &&
            !currentSupplements.contains('protein')) {
          recommendedSupplements.addAll(
            allSupplements
                .where(
                  (supp) =>
                      supp['name'].toString().toLowerCase().contains(
                        'pollen',
                      ) ||
                      supp['description'].toString().toLowerCase().contains(
                        'protein',
                      ),
                )
                .toList(),
          );

          managementActions.add(
            'Consider adding protein/pollen supplements to your feeding regimen',
          );
        }

        // If they're not already providing probiotics
        if (!currentSupplements.contains('probiotic')) {
          recommendedSupplements.addAll(
            allSupplements
                .where(
                  (supp) =>
                      supp['name'].toString().toLowerCase().contains(
                        'probiotic',
                      ) ||
                      supp['description'].toString().toLowerCase().contains(
                        'gut health',
                      ),
                )
                .toList(),
          );
        }
      }

      // Consider bee breed
      if (formData.containsKey('bee_breed') && formData['bee_breed'] != null) {
        String beeBreed = formData['bee_breed'].toString();

        if (beeBreed == 'Italian') {
          // Italian bees are known for being prolific and good honey producers but can be susceptible to certain diseases
          managementActions.add(
            'Monitor for varroa mites regularly - Italian bees can be susceptible',
          );
          managementActions.add(
            'Provide ample nectar sources - Italian bees are excellent honey producers',
          );
        } else if (beeBreed == 'Carniolan') {
          // Carniolan bees are known for winter hardiness and gentle temperament
          managementActions.add(
            'Ensure adequate winter stores - Carniolans are good winter survivors but need sufficient stores',
          );
          managementActions.add(
            'Monitor for swarming in spring - Carniolans build up quickly',
          );
        } else if (beeBreed == 'Russian') {
          // Russian bees are known for varroa resistance
          managementActions.add(
            'Consider reduced treatment schedule - Russian bees have some natural mite resistance',
          );
        }
      }

      // Consider disease history
      if (formData.containsKey('disease_history') &&
          formData['disease_history'] != null) {
        String diseaseHistory =
            formData['disease_history'].toString().toLowerCase();

        if (diseaseHistory.contains('varroa') ||
            diseaseHistory.contains('mite')) {
          recommendedSupplements.addAll(
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'immune',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'resistance',
                      ),
                )
                .toList(),
          );

          managementActions.add(
            'Implement an integrated pest management (IPM) approach for varroa control',
          );
          managementActions.add(
            'Consider using screened bottom boards and drone brood removal as part of IPM',
          );
        }

        if (diseaseHistory.contains('nosema')) {
          recommendedSupplements.addAll(
            allSupplements
                .where(
                  (supp) =>
                      supp['benefits'].toString().toLowerCase().contains(
                        'gut',
                      ) ||
                      supp['benefits'].toString().toLowerCase().contains(
                        'digestive',
                      ),
                )
                .toList(),
          );

          managementActions.add(
            'Ensure good hive ventilation to prevent moisture buildup',
          );
          managementActions.add(
            'Consider probiotic supplements to support bee gut health',
          );
        }
      }

      // Consider budget constraints
      if (formData.containsKey('budget_constraint') &&
          formData['budget_constraint'] != null) {
        String budget = formData['budget_constraint'].toString().toLowerCase();

        if (budget.contains('low') || budget.contains('limited')) {
          // Prioritize low-cost solutions
          recommendedSupplements =
              recommendedSupplements
                  .where((supp) => supp['price_range'] == 'Low')
                  .toList();

          managementActions.add('Focus on easy-to-grow, self-seeding plants');
          managementActions.add(
            'Consider making your own sugar syrup instead of commercial feeds',
          );
          managementActions.add(
            'Implement DIY pest monitoring methods like sticky boards',
          );
        }
      }

      // Limit to top 5 recommendations for each category
      if (recommendedPlants.length > 5) {
        recommendedPlants = recommendedPlants.sublist(0, 5);
      }

      if (recommendedSupplements.length > 3) {
        recommendedSupplements = recommendedSupplements.sublist(0, 3);
      }

      return {
        'success': true,
        'recommended_plants': recommendedPlants,
        'recommended_supplements': recommendedSupplements,
        'management_actions': managementActions,
        'message': 'Recommendations generated based on your input.',
      };
    } catch (e) {
      print('Error processing farmer form: $e');
      return {'success': false, 'error': 'Error processing form data: $e'};
    }
  }

  // Add this method to the BeeAdvisoryService class

  
  // Helper method to get the most influential weather factor
  String _getMostInfluentialWeatherFactor(
    Map<String, dynamic> environmentalFactors,
  ) {
    if (!environmentalFactors.containsKey('weatherData')) {
      return 'temperature'; // Default if no weather data available
    }

    Map<String, dynamic> weatherData = environmentalFactors['weatherData'];
    double highestCorrelation = 0;
    String mostInfluential = 'temperature';

    // Check all weather factors for their correlation with bee activity
    List<String> factors = [
      'temperature',
      'windSpeed',
      'precipitation',
      'humidity',
    ];
    for (String factor in factors) {
      if (weatherData.containsKey(factor) &&
          weatherData[factor].containsKey('correlations') &&
          weatherData[factor]['correlations'].containsKey('totalActivity')) {
        double correlation =
            weatherData[factor]['correlations']['totalActivity']['correlation']
                .abs();
        if (correlation > highestCorrelation) {
          highestCorrelation = correlation;
          mostInfluential = factor;
        }
      }
    }

    return mostInfluential;
  }
}
