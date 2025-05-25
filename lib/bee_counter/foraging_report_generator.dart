import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';
import 'package:HPGM/analytics/foraging_analysis/foraging_analysis_engine.dart';
import 'package:HPGM/bee_counter/foraging_efficiency_metric.dart';

/// Class to generate bee foraging analysis reports in PDF format
class ForagingReportGenerator {
  final String hiveId;
  final DateTime startDate;
  final DateTime endDate;

  ForagingReportGenerator({
    required this.hiveId,
    required this.startDate,
    required this.endDate,
  });

  /// Generate a PDF report for bee foraging activity
  Future<File> generateReport() async {
    // 1. Fetch data
    final beeCounts = await _fetchBeeCountData();
    final analysisData = await _fetchForagingAnalysisData();
    final efficiencyMetrics = await _calculateEfficiencyMetrics(
      beeCounts,
      analysisData,
    );

    // 2. Set up PDF document
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
    final boldFontData = await rootBundle.load(
      "assets/fonts/OpenSans-Bold.ttf",
    );
    final font = pw.Font.ttf(fontData);
    final boldFont = pw.Font.ttf(boldFontData);

    // 3. Add report pages
    pdf.addPage(_buildCoverPage(font, boldFont));

    pdf.addPage(
      _buildSummaryPage(
        font,
        boldFont,
        beeCounts,
        analysisData,
        efficiencyMetrics,
      ),
    );

    pdf.addPage(
      _buildDailyActivityPage(font, boldFont, beeCounts, efficiencyMetrics),
    );

    pdf.addPage(
      _buildForagingEfficiencyPage(font, boldFont, efficiencyMetrics),
    );

    // 4. Save PDF to temporary file
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/bee_foraging_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Fetch bee count data from the database
  Future<List<BeeCount>> _fetchBeeCountData() async {
    return await BeeCountDatabase.instance.getBeeCountsForDateRange(
      hiveId,
      startDate,
      endDate,
    );
  }

  /// Fetch foraging analysis data
  Future<Map<String, dynamic>> _fetchForagingAnalysisData() async {
    return await ForagingAnalysisEngine.analyzeForagingActivity(
      hiveId: hiveId,
      startDate: startDate,
      endDate: endDate,
      includeWeatherData: true,
    );
  }

  /// Calculate efficiency metrics from raw data
  Future<List<ForagingEfficiencyMetric>> _calculateEfficiencyMetrics(
    List<BeeCount> beeCounts,
    Map<String, dynamic> analysisData,
  ) async {
    // Group bee counts by day
    final countsByDay = <DateTime, List<BeeCount>>{};
    for (final count in beeCounts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );
      countsByDay.putIfAbsent(day, () => []).add(count);
    }

    final metrics = <ForagingEfficiencyMetric>[];

    countsByDay.forEach((date, dayCounts) {
      // Calculate metrics for each day
      int totalBeesIn = 0;
      int totalBeesOut = 0;
      int totalActivity = 0;
      final activityByHour = <int, int>{};

      for (final count in dayCounts) {
        totalBeesIn += count.beesEntering;
        totalBeesOut += count.beesExiting;
        totalActivity += count.totalActivity;

        final hour = count.timestamp.hour;
        activityByHour.update(
          hour,
          (value) => value + count.totalActivity,
          ifAbsent: () => count.totalActivity,
        );
      }

      // Find peak activity hour
      int peakHour = 12; // Default to noon
      int maxActivity = 0;
      activityByHour.forEach((hour, activity) {
        if (activity > maxActivity) {
          maxActivity = activity;
          peakHour = hour;
        }
      });

      // Map to peak period
      String peakPeriod = 'noon';
      if (peakHour >= 5 && peakHour < 10) {
        peakPeriod = 'morning';
      } else if (peakHour >= 15 && peakHour < 20) {
        peakPeriod = 'evening';
      }

      // Calculate return rate
      final returnRate =
          totalBeesOut > 0 ? (totalBeesIn / totalBeesOut) * 100 : 0;

      // Calculate efficiency score (custom formula)
      final consistencyFactor =
          activityByHour.length / 10; // More active hours = more consistent
      final returnFactor = returnRate > 100 ? 1.0 : returnRate / 100;
      final activityFactor = totalActivity > 50 ? 1.0 : totalActivity / 50;

      final efficiencyScore =
          (consistencyFactor * 0.3 +
              returnFactor * 0.4 +
              activityFactor * 0.3) *
          100;
    });

    return metrics;
  }

  /// Build cover page for the report
  pw.Page _buildCoverPage(pw.Font font, pw.Font boldFont) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(height: 100),
            pw.Text(
              'Bee Foraging Analysis',
              style: pw.TextStyle(font: boldFont, fontSize: 28),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'DETAILED REPORT',
              style: pw.TextStyle(
                font: font,
                fontSize: 16,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 40),
            pw.Container(
              width: 160,
              height: 160,
              decoration: pw.BoxDecoration(
                color: PdfColors.amber200,
                shape: pw.BoxShape.circle,
              ),
              child: pw.Center(
                child: pw.Text(
                  '🐝',
                  style: pw.TextStyle(fontSize: 80),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'Hive ID: $hiveId',
              style: pw.TextStyle(font: boldFont, fontSize: 16),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              'Period: ${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
              style: pw.TextStyle(font: font, fontSize: 14),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              'Generated on: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.Spacer(),
            pw.Text(
              'HPGM - Hive Performance & Growth Monitoring',
              style: pw.TextStyle(
                font: font,
                fontSize: 10,
                color: PdfColors.grey500,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  /// Build summary page with key metrics
  pw.Page _buildSummaryPage(
    pw.Font font,
    pw.Font boldFont,
    List<BeeCount> beeCounts,
    Map<String, dynamic> analysisData,
    List<ForagingEfficiencyMetric> metrics,
  ) {
    // Calculate summary data
    final totalBeesIn = beeCounts.fold<int>(
      0,
      (sum, count) => sum + count.beesEntering,
    );
    final totalBeesOut = beeCounts.fold<int>(
      0,
      (sum, count) => sum + count.beesExiting,
    );
    final netChange = totalBeesIn - totalBeesOut;
    final averageReturnRate =
        metrics.isNotEmpty
            ? metrics.fold<double>(0, (sum, m) => sum + m.returnRate) /
                metrics.length
            : 0;
    final averageEfficiency =
        metrics.isNotEmpty
            ? metrics.fold<double>(0, (sum, m) => sum + m.efficiencyScore) /
                metrics.length
            : 0;

    // Count records by peak time
    final peakTimeCounts = <String, int>{'morning': 0, 'noon': 0, 'evening': 0};

    for (final metric in metrics) {
      peakTimeCounts.update(metric.peakTimePeriod, (value) => value + 1);
    }

    String mostActivePeriod = 'noon';
    int maxCount = 0;
    peakTimeCounts.forEach((period, count) {
      if (count > maxCount) {
        maxCount = count;
        mostActivePeriod = period;
      }
    });

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Summary',
              style: pw.TextStyle(font: boldFont, fontSize: 20),
            ),
            pw.SizedBox(height: 20),

            // Key metrics table
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Key Metrics',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Table(
                    border: const pw.TableBorder(
                      horizontalInside: pw.BorderSide(
                        color: PdfColors.grey300,
                        width: 1,
                      ),
                    ),
                    children: [
                      pw.TableRow(
                        children: [
                          _buildTableCell(
                            'Total Records',
                            font,
                            isHeader: true,
                          ),
                          _buildTableCell(
                            '${beeCounts.length}',
                            font,
                            textAlign: pw.TextAlign.right,
                            isBold: true,
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell(
                            'Total Bees In',
                            font,
                            isHeader: true,
                          ),
                          _buildTableCell(
                            '$totalBeesIn',
                            font,
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell(
                            'Total Bees Out',
                            font,
                            isHeader: true,
                          ),
                          _buildTableCell(
                            '$totalBeesOut',
                            font,
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell(
                            'Net Population Change',
                            font,
                            isHeader: true,
                          ),
                          _buildTableCell(
                            '${netChange >= 0 ? "+" : ""}$netChange',
                            font,
                            textAlign: pw.TextAlign.right,
                            textColor:
                                netChange >= 0
                                    ? PdfColors.green700
                                    : PdfColors.red700,
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell(
                            'Average Return Rate',
                            font,
                            isHeader: true,
                          ),
                          _buildTableCell(
                            '${averageReturnRate.toStringAsFixed(1)}%',
                            font,
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell(
                            'Average Efficiency Score',
                            font,
                            isHeader: true,
                          ),
                          _buildTableCell(
                            '${averageEfficiency.toStringAsFixed(1)}/100',
                            font,
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          _buildTableCell(
                            'Most Active Period',
                            font,
                            isHeader: true,
                          ),
                          _buildTableCell(
                            _formatPeakTime(mostActivePeriod),
                            font,
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 30),

            // Findings and recommendations
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Findings & Recommendations',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                  ),
                  pw.SizedBox(height: 10),
                  // Return rate insight
                  pw.RichText(
                    text: pw.TextSpan(
                      text: 'Return Rate: ',
                      style: pw.TextStyle(font: boldFont, fontSize: 10),
                      children: [
                        pw.TextSpan(
                          text:
                              averageReturnRate >= 90
                                  ? 'Excellent return rate indicates healthy foraging conditions.'
                                  : averageReturnRate >= 75
                                  ? 'Good return rate, but there may be room for improvement.'
                                  : 'Low return rate may indicate predators, pesticide exposure, or navigation challenges.',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  // Foraging efficiency insight
                  pw.RichText(
                    text: pw.TextSpan(
                      text: 'Foraging Efficiency: ',
                      style: pw.TextStyle(font: boldFont, fontSize: 10),
                      children: [
                        pw.TextSpan(
                          text:
                              averageEfficiency >= 80
                                  ? 'Highly efficient foraging patterns observed.'
                                  : averageEfficiency >= 60
                                  ? 'Moderate foraging efficiency. Consider enhancing nearby food sources.'
                                  : 'Low foraging efficiency. Review hive placement and nearby flora.',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  // Peak activity insight
                  pw.RichText(
                    text: pw.TextSpan(
                      text: 'Peak Activity: ',
                      style: pw.TextStyle(font: boldFont, fontSize: 10),
                      children: [
                        pw.TextSpan(
                          text:
                              'Bees are most active during ${_formatPeakTime(mostActivePeriod)}. '
                              'Consider timing hive inspections outside this period to minimize disruption.',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // Footer
            _buildFooter(context, font),
          ],
        );
      },
    );
  }

  /// Build page showing daily activity patterns
  pw.Page _buildDailyActivityPage(
    pw.Font font,
    pw.Font boldFont,
    List<BeeCount> beeCounts,
    List<ForagingEfficiencyMetric> metrics,
  ) {
    // Group counts by day and hour for the activity heat map
    final countsByDayAndHour = <String, Map<int, int>>{};

    for (final count in beeCounts) {
      final dayKey = DateFormat('yyyy-MM-dd').format(count.timestamp);
      final hour = count.timestamp.hour;

      if (!countsByDayAndHour.containsKey(dayKey)) {
        countsByDayAndHour[dayKey] = {};
      }

      countsByDayAndHour[dayKey]!.update(
        hour,
        (value) => value + count.totalActivity,
        ifAbsent: () => count.totalActivity,
      );
    }

    // Calculate max activity for color scaling
    int maxActivity = 0;
    countsByDayAndHour.forEach((day, hourData) {
      hourData.forEach((hour, activity) {
        if (activity > maxActivity) {
          maxActivity = activity;
        }
      });
    });

    // Sort days chronologically
    final sortedDays = countsByDayAndHour.keys.toList()..sort();

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Daily Activity Patterns',
              style: pw.TextStyle(font: boldFont, fontSize: 20),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'The chart below shows bee activity patterns for each day in the analysis period.',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.SizedBox(height: 20),

            // Activity heat map table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                // Header row with hours
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Date', boldFont, isHeader: true),
                    ...List.generate(16, (i) => i + 5).map(
                      (hour) => _buildTableCell(
                        '$hour:00',
                        font,
                        isHeader: true,
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),

                // Data rows for each day
                ...sortedDays.map((dayKey) {
                  final hourData = countsByDayAndHour[dayKey]!;
                  final displayDate = DateFormat(
                    'MMM d',
                  ).format(DateTime.parse(dayKey));

                  return pw.TableRow(
                    children: [
                      _buildTableCell(displayDate, font),
                      ...List.generate(16, (i) => i + 5).map((hour) {
                        final activity = hourData[hour] ?? 0;
                        // Calculate intensity for cell color (0-255)
                        final intensity =
                            maxActivity > 0
                                ? (activity / maxActivity * 200).round()
                                : 0;

                        return pw.Container(
                          height: 16,
                          alignment: pw.Alignment.center,
                          color: PdfColor(
                            1,
                            1 - (intensity / 255),
                            1 - (intensity / 255),
                          ),
                          child: pw.Text(
                            activity > 0 ? activity.toString() : '',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color:
                                  intensity > 100
                                      ? PdfColors.white
                                      : PdfColors.black,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 30),

            // Daily totals table
            pw.Text(
              'Daily Totals',
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 10),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell(
                      'Date',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Bees In',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Bees Out',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Net Change',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Peak Period',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),

                // Data rows from metrics
                ...metrics.map((metric) {
                  final dailyBeeCounts =
                      beeCounts
                          .where(
                            (count) =>
                                count.timestamp.year == metric.date.year &&
                                count.timestamp.month == metric.date.month &&
                                count.timestamp.day == metric.date.day,
                          )
                          .toList();

                  final totalIn = dailyBeeCounts.fold<int>(
                    0,
                    (sum, count) => sum + count.beesEntering,
                  );
                  final totalOut = dailyBeeCounts.fold<int>(
                    0,
                    (sum, count) => sum + count.beesExiting,
                  );
                  final netChange = totalIn - totalOut;

                  return pw.TableRow(
                    children: [
                      _buildTableCell(
                        DateFormat('MMM d, yyyy').format(metric.date),
                        font,
                      ),
                      _buildTableCell(
                        totalIn.toString(),
                        font,
                        textAlign: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        totalOut.toString(),
                        font,
                        textAlign: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        '${netChange >= 0 ? "+" : ""}$netChange',
                        font,
                        textAlign: pw.TextAlign.center,
                        textColor:
                            netChange >= 0
                                ? PdfColors.green700
                                : PdfColors.red700,
                      ),
                      _buildTableCell(
                        _formatPeakTime(metric.peakTimePeriod),
                        font,
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.Spacer(),

            // Footer
            _buildFooter(context, font),
          ],
        );
      },
    );
  }

  /// Build page showing foraging efficiency data
  pw.Page _buildForagingEfficiencyPage(
    pw.Font font,
    pw.Font boldFont,
    List<ForagingEfficiencyMetric> metrics,
  ) {
    // Get top efficient days
    final topDays = _getTopEfficientDays(metrics, 5);
    final maxEfficiency = _maxEfficiencyScore(metrics);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Foraging Efficiency Analysis',
              style: pw.TextStyle(font: boldFont, fontSize: 20),
            ),
            pw.SizedBox(height: 20),

            // Efficiency chart
            pw.Container(
              height: 200,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis(
                      // Use numeric indices for the axis positions
                      List.generate(
                        metrics.length,
                        (index) => index.toDouble(),
                      ),
                    ),
                    yAxis: pw.FixedAxis([
                      for (int i = 0; i <= maxEfficiency; i += 20) i.toDouble(),
                    ], divisions: true),
                  ),
                  title: pw.ChartLegend(
                    position: pw.Alignment.bottomCenter,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    direction: pw.Axis.horizontal,
                    padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
                    textStyle: pw.TextStyle(font: font, fontSize: 8),
                  ),
                  datasets: [
                    pw.LineDataSet(
                      legend: 'Efficiency Score',
                      drawPoints: true,
                      isCurved: true,
                      color: PdfColors.amber700,
                      data: [
                        for (int i = 0; i < metrics.length; i++)
                          pw.PointChartValue(
                            i.toDouble(),
                            metrics[i].efficiencyScore,
                          ),
                      ],
                    ),
                    pw.LineDataSet(
                      legend: 'Return Rate',
                      drawPoints: true,
                      isCurved: true,
                      color: PdfColors.blue700,
                      data: [
                        for (int i = 0; i < metrics.length; i++)
                          pw.PointChartValue(
                            i.toDouble(),
                            metrics[i].returnRate > 100
                                ? 100
                                : metrics[i].returnRate,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 30),

            // Top efficient days
            pw.Text(
              'Top Performing Days',
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 10),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell(
                      'Date',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Score',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Return Rate',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Activity',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Peak Period',
                      boldFont,
                      isHeader: true,
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),

                // Data rows for top days
                ...topDays.map((metric) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(
                        DateFormat('MMM d, yyyy').format(metric.date),
                        font,
                      ),
                      _buildTableCell(
                        metric.efficiencyScore.toStringAsFixed(1),
                        font,
                        textAlign: pw.TextAlign.center,
                        isBold: true,
                      ),
                      _buildTableCell(
                        '${metric.returnRate.toStringAsFixed(1)}%',
                        font,
                        textAlign: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        metric.totalActivity.toString(),
                        font,
                        textAlign: pw.TextAlign.center,
                      ),
                      _buildTableCell(
                        _formatPeakTime(metric.peakTimePeriod),
                        font,
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 30),

            // Recommendations based on efficiency patterns
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                border: pw.Border.all(color: PdfColors.amber200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Recommendations for Improving Foraging Efficiency',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Bullet(
                    text:
                        'Plant flowering species that bloom in succession throughout the season',
                  ),
                  pw.Bullet(
                    text:
                        'Ensure water sources are available within 100 meters of the hive',
                  ),
                  pw.Bullet(
                    text:
                        'Consider the position of the hive entrance relative to sun exposure',
                  ),
                  pw.Bullet(
                    text:
                        'Monitor for and treat any diseases or parasites that may weaken foragers',
                  ),
                  pw.Bullet(
                    text:
                        'Provide supplemental feeding during periods of nectar scarcity',
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // Footer
            _buildFooter(context, font),
          ],
        );
      },
    );
  }

  /// Build footer for pages
  pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      padding: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Bee Foraging Analysis Report',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build table cells
  pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    pw.TextAlign textAlign = pw.TextAlign.left,
    PdfColor textColor = PdfColors.black,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 9,
          fontWeight:
              isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor,
        ),
        textAlign: textAlign,
      ),
    );
  }

  /// Helper method to format peak time periods
  String _formatPeakTime(String period) {
    switch (period) {
      case 'morning':
        return 'Morning (5-10 AM)';
      case 'noon':
        return 'Midday (10 AM-3 PM)';
      case 'evening':
        return 'Evening (3-8 PM)';
      default:
        return period;
    }
  }

  /// Helper method to calculate maximum efficiency score
  double _maxEfficiencyScore(List<ForagingEfficiencyMetric> metrics) {
    double max = 0.0;
    for (final metric in metrics) {
      if (metric.efficiencyScore > max) {
        max = metric.efficiencyScore;
      }
    }
    return (max * 1.2).ceilToDouble(); // Add 20% headroom
  }

  /// Helper method to get top efficient days
  List<ForagingEfficiencyMetric> _getTopEfficientDays(
    List<ForagingEfficiencyMetric> metrics,
    int count,
  ) {
    // Sort by efficiency score (descending)
    final sorted = List<ForagingEfficiencyMetric>.from(metrics)
      ..sort((a, b) => b.efficiencyScore.compareTo(a.efficiencyScore));

    // Return top N (or all if less than N)
    return sorted.take(count).toList();
  }

  /// Share the report with other apps
  Future<void> shareReport(File reportFile) async {
    try {
      await Share.shareXFiles([
        XFile(reportFile.path),
      ], text: 'Bee Foraging Analysis Report');
    } catch (e) {
      print('Error sharing report: $e');
    }
  }

  /// View the report in a preview screen
  Future<void> viewReport(BuildContext context, File reportFile) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('Bee Foraging Report'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: () => shareReport(reportFile),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () async {
                        final status = await Permission.storage.request();
                        if (status.isGranted) {
                          final directory = await getExternalStorageDirectory();
                          if (directory != null) {
                            final savedFile = File(
                              '${directory.path}/bee_foraging_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
                            );
                            await reportFile.copy(savedFile.path);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Report saved to ${savedFile.path}',
                                ),
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Storage permission denied'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
                body: PdfPreview(
                  build: (format) => reportFile.readAsBytesSync(),
                  allowSharing: true,
                  allowPrinting: true,
                  maxPageWidth: 700,
                  pdfFileName: 'bee_foraging_analysis.pdf',
                ),
              ),
        ),
      );
    } catch (e) {
      print('Error viewing report: $e');
    }
  }

  /// Save the report to external storage
  Future<File?> saveReportToExternalStorage(File reportFile) async {
    try {
      final status = await Permission.storage.request();
      if (status.isGranted) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final savedFile = File(
            '${directory.path}/bee_foraging_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
          await reportFile.copy(savedFile.path);
          return savedFile;
        }
      }
      return null;
    } catch (e) {
      print('Error saving report to external storage: $e');
      return null;
    }
  }

  /// Print the report
  Future<void> printReport(File reportFile) async {
    try {
      await Printing.layoutPdf(
        onLayout: (format) => reportFile.readAsBytesSync(),
        name: 'Bee Foraging Analysis Report',
      );
    } catch (e) {
      print('Error printing report: $e');
    }
  }
}
