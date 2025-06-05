import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';

class BeeCountDatabase {
  static final BeeCountDatabase instance = BeeCountDatabase._init();
  static Database? _database;
  BeeCountDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bee_counts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE bee_counts(
      id TEXT PRIMARY KEY,
      hive_id TEXT NOT NULL,
      video_id TEXT,
      bees_entering INTEGER NOT NULL,
      bees_exiting INTEGER NOT NULL,
      timestamp TEXT NOT NULL,
      notes TEXT,
      confidence REAL
    )
    ''');
  }

  Future<String> createBeeCount(BeeCount beeCount) async {
    final db = await instance.database;

    // Generate a unique ID if not provided
    final id = beeCount.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final beeCountWithId = beeCount.copyWith(id: id);

    await db.insert(
      'bee_counts',
      beeCountWithId.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return id;
  }

  Future<BeeCount?> getBeeCount(String id) async {
    final db = await instance.database;

    final maps = await db.query('bee_counts', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return BeeCount.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<List<BeeCount>> getAllBeeCounts() async {
    final db = await instance.database;

    final result = await db.query('bee_counts', orderBy: 'timestamp DESC');
    return result.map((json) => BeeCount.fromJson(json)).toList();
  }

  Future<List<BeeCount>> getBeeCountsForHive(String hiveId) async {
    final db = await instance.database;

    final result = await db.query(
      'bee_counts',
      where: 'hive_id = ?',
      whereArgs: [hiveId],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => BeeCount.fromJson(json)).toList();
  }

  Future<int> updateBeeCount(BeeCount beeCount) async {
    final db = await instance.database;
    return db.update(
      'bee_counts',
      beeCount.toJson(),
      where: 'id = ?',
      whereArgs: [beeCount.id],
    );
  }

  Future<List<BeeCount>> readBeeCountsByDate(DateTime date) async {
    final db = await instance.database;

    // Convert date to start and end of day in ISO format
    final startOfDay =
        DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay =
        DateTime(
          date.year,
          date.month,
          date.day,
          23,
          59,
          59,
          999,
        ).toIso8601String();

    final result = await db.query(
      'bee_counts',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'timestamp DESC',
    );

    return result.map((json) => BeeCount.fromJson(json)).toList();
  }

  // NEW METHOD: Get bee counts for a date range
  Future<List<BeeCount>> getBeeCountsForDateRange(
    String hiveId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await instance.database;

    // Convert dates to ISO format for SQLite query
    final startDateString =
        DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        ).toIso8601String();

    final endDateString =
        DateTime(
          endDate.year,
          endDate.month,
          endDate.day,
          23,
          59,
          59,
          999,
        ).toIso8601String();

    final result = await db.query(
      'bee_counts',
      where: 'hive_id = ? AND timestamp BETWEEN ? AND ?',
      whereArgs: [hiveId, startDateString, endDateString],
      orderBy: 'timestamp ASC',
    );

    return result.map((json) => BeeCount.fromJson(json)).toList();
  }

  // NEW METHOD: Get counts grouped by day
  Future<Map<DateTime, List<BeeCount>>> getBeeCountsGroupedByDay(
    String hiveId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final counts = await getBeeCountsForDateRange(hiveId, startDate, endDate);
    final Map<DateTime, List<BeeCount>> groupedCounts = {};

    for (final count in counts) {
      final day = DateTime(
        count.timestamp.year,
        count.timestamp.month,
        count.timestamp.day,
      );

      if (!groupedCounts.containsKey(day)) {
        groupedCounts[day] = [];
      }

      groupedCounts[day]!.add(count);
    }

    return groupedCounts;
  }

  Future<int> deleteBeeCountByVideoId(String videoId) async {
    final db = await database;

    return await db.delete(
      'bee_counts',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
  }

  // NEW METHOD: Get average counts by time period
  Future<Map<String, Map<String, double>>> getAverageCountsByTimePeriod(
    String hiveId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final counts = await getBeeCountsForDateRange(hiveId, startDate, endDate);

    // Group counts by time period (morning, noon, evening)
    final periodCounts = <String, List<BeeCount>>{
      'morning': [], // 5-10 AM
      'noon': [], // 10-3 PM
      'evening': [], // 3-8 PM
    };

    for (final count in counts) {
      final hour = count.timestamp.hour;

      if (hour >= 5 && hour < 10) {
        periodCounts['morning']!.add(count);
      } else if (hour >= 10 && hour < 15) {
        periodCounts['noon']!.add(count);
      } else if (hour >= 15 && hour < 20) {
        periodCounts['evening']!.add(count);
      }
    }

    // Calculate averages by period
    final periodAverages = <String, Map<String, double>>{};
    for (final period in periodCounts.keys) {
      final periodData = periodCounts[period]!;
      if (periodData.isEmpty) {
        periodAverages[period] = {
          'averageIn': 0.0,
          'averageOut': 0.0,
          'netChange': 0.0,
          'totalActivity': 0.0,
        };
        continue;
      }

      int totalIn = 0;
      int totalOut = 0;
      for (final count in periodData) {
        totalIn += count.beesEntering;
        totalOut += count.beesExiting;
      }

      periodAverages[period] = {
        'averageIn': totalIn / periodData.length,
        'averageOut': totalOut / periodData.length,
        'netChange': (totalIn - totalOut) / periodData.length,
        'totalActivity': (totalIn + totalOut) / periodData.length,
      };
    }

    return periodAverages;
  }

  // NEW METHOD: Get daily average counts
  Future<Map<DateTime, Map<String, double>>> getDailyAverageCounts(
    String hiveId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final groupedCounts = await getBeeCountsGroupedByDay(
      hiveId,
      startDate,
      endDate,
    );
    final Map<DateTime, Map<String, double>> dailyAverages = {};

    groupedCounts.forEach((day, counts) {
      int totalIn = 0;
      int totalOut = 0;

      for (final count in counts) {
        totalIn += count.beesEntering;
        totalOut += count.beesExiting;
      }

      dailyAverages[day] = {
        'averageIn': totalIn / counts.length,
        'averageOut': totalOut / counts.length,
        'netChange': (totalIn - totalOut) / counts.length,
        'totalActivity': (totalIn + totalOut) / counts.length,
      };
    });

    return dailyAverages;
  }

  Future<int> deleteBeeCount(String id) async {
    final db = await instance.database;
    return await db.delete('bee_counts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  // NEW METHOD: Check if a video has been processed
  Future<bool> isVideoProcessed(String videoId) async {
    final db = await instance.database;

    final result = await db.query(
      'bee_counts',
      where: 'video_id = ?',
      whereArgs: [videoId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // NEW METHOD: Batch insert for efficiency
  Future<void> createBeeCountBatch(List<BeeCount> beeCounts) async {
    final db = await instance.database;

    // Use a transaction for better performance with multiple inserts
    await db.transaction((txn) async {
      for (final beeCount in beeCounts) {
        final id =
            beeCount.id ?? DateTime.now().millisecondsSinceEpoch.toString();
        final beeCountWithId = beeCount.copyWith(id: id);

        await txn.insert(
          'bee_counts',
          beeCountWithId.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
