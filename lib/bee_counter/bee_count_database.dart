import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
    CREATE TABLE bee_counts (
      id $idType,
      video_id $textType,
      hive_id $textType,
      timestamp $textType,
      bees_entering $intType,
      bees_exiting $intType,
      net_change $intType,
      total_activity $intType,
      notes TEXT
    )
    ''');
  }

  // Create a new bee count record
  Future<BeeCount> createBeeCount(BeeCount beeCount) async {
    final db = await instance.database;

    // No need to calculate derived fields as they are now computed properties
    final id = await db.insert('bee_counts', beeCount.toJson());
    return beeCount.copyWith(id: id.toString());
  }

  // Read a single bee count by ID
  Future<BeeCount> readBeeCount(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'bee_counts',
      columns: [
        'id',
        'video_id',
        'hive_id',
        'timestamp',
        'bees_entering',
        'bees_exiting',
        'notes',
      ],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return BeeCount.fromJson(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  // Read all bee counts
  Future<List<BeeCount>> readAllBeeCounts() async {
    final db = await instance.database;
    final result = await db.query('bee_counts');
    return result.map((map) => BeeCount.fromJson(map)).toList();
  }

  // Read bee counts by hive ID
  Future<List<BeeCount>> readBeeCountsByHiveId(String hiveId) async {
    final db = await instance.database;
    final result = await db.query(
      'bee_counts',
      where: 'hive_id = ?',
      whereArgs: [hiveId],
    );
    return result.map((map) => BeeCount.fromJson(map)).toList();
  }

  // Read bee counts by video ID
  Future<List<BeeCount>> readBeeCountsByVideoId(String videoId) async {
    final db = await instance.database;
    final result = await db.query(
      'bee_counts',
      where: 'video_id = ?',
      whereArgs: [videoId],
    );
    return result.map((map) => BeeCount.fromJson(map)).toList();
  }

  // Read bee counts for a specific date
  Future<List<BeeCount>> readBeeCountsByDate(DateTime date) async {
    final db = await instance.database;
    final dateStr = date.toIso8601String().substring(0, 10);

    final result = await db.query(
      'bee_counts',
      where: 'timestamp LIKE ?',
      whereArgs: ['$dateStr%'],
    );
    return result.map((map) => BeeCount.fromJson(map)).toList();
  }

  // Read bee counts within a date range
  Future<List<BeeCount>> readBeeCountsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await instance.database;
    final startDateStr = startDate.toIso8601String().substring(0, 10);
    final endDateStr = endDate.toIso8601String().substring(0, 10);

    final result = await db.query(
      'bee_counts',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: ['$startDateStr 00:00:00', '$endDateStr 23:59:59'],
    );
    return result.map((map) => BeeCount.fromJson(map)).toList();
  }

  // Update a bee count record
  Future<int> updateBeeCount(BeeCount beeCount) async {
    final db = await instance.database;

    return db.update(
      'bee_counts',
      beeCount.toJson(),
      where: 'id = ?',
      whereArgs: [beeCount.id],
    );
  }

  // Delete a bee count record
  Future<int> deleteBeeCount(int id) async {
    final db = await instance.database;
    return await db.delete('bee_counts', where: 'id = ?', whereArgs: [id]);
  }

  // Delete all bee counts for a specific hive
  Future<int> deleteBeeCountsByHiveId(String hiveId) async {
    final db = await instance.database;
    return await db.delete(
      'bee_counts',
      where: 'hive_id = ?',
      whereArgs: [hiveId],
    );
  }

  Future<List<DateTime>> getAvailableDates() async {
    final db = await instance.database;

    // Get distinct dates from the timestamp column
    final result = await db.rawQuery('''
        SELECT DISTINCT substr(timestamp, 1, 10) as date
        FROM bee_counts
        ORDER BY date DESC
      ''');

    return result.map((map) => DateTime.parse(map['date'] as String)).toList();
  }

  Future<DateTime?> getMostRecentDate() async {
    final db = await instance.database;

    final result = await db.rawQuery('''
        SELECT timestamp FROM bee_counts
        ORDER BY timestamp DESC
        LIMIT 1
      ''');

    if (result.isNotEmpty) {
      String timestamp = result.first['timestamp'] as String;
      return DateTime.parse(timestamp);
    }

    return null;
  }

  // Close the database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
