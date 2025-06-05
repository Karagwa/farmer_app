import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class BeeAdvisoryDatabase {
  static final BeeAdvisoryDatabase instance = BeeAdvisoryDatabase._init();
  static Database? _database;

  BeeAdvisoryDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bee_advisory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const blobType = 'BLOB';

    // Table for bee-friendly plants
    await db.execute('''
    CREATE TABLE plants (
      id $idType,
      name $textType,
      scientific_name $textType,
      description $textType,
      planting_instructions $textType,
      climate_preference $textType,
      flowering_season $textType,
      nectar_value $intType,
      pollen_value $intType,
      image_path $textType,
      benefits_to_bees $textType,
      maintenance_level $textType,
      water_requirements $textType,
      sun_requirements $textType,
      timestamp $textType
    )
    ''');

    // Table for bee supplements
    await db.execute('''
    CREATE TABLE supplements (
      id $idType,
      name $textType,
      type $textType,
      description $textType,
      usage_instructions $textType,
      dosage $textType,
      benefits $textType,
      when_to_use $textType,
      cautions $textType,
      image_path $textType,
      price_range $textType,
      availability $textType,
      timestamp $textType
    )
    ''');

    // Table for recommendations based on foraging analysis
    await db.execute('''
    CREATE TABLE recommendations (
      id $idType,
      hive_id $textType,
      date $textType,
      issue_identified $textType,
      severity $textType,
      recommended_plants TEXT,
      recommended_supplements TEXT,
      management_actions $textType,
      expected_outcome $textType,
      priority $intType,
      is_implemented $intType DEFAULT 0,
      implementation_date $textType,
      notes $textType,
      timestamp $textType
    )
    ''');

    // Table for farmer inputs
    await db.execute('''
    CREATE TABLE farmer_inputs (
      id $idType,
      farmer_name $textType,
      farm_location $textType,
      hive_count $intType,
      available_area $realType,
      climate_zone $textType,
      current_plants $textType,
      current_issues $textType,
      budget_constraint $textType,
      goals $textType,
      timestamp $textType
    )
    ''');

    // Insert some initial plant data
    await _insertInitialPlantData(db);

    // Insert some initial supplement data
    await _insertInitialSupplementData(db);
  }

  Future _insertInitialPlantData(Database db) async {
    // Insert some common bee-friendly plants
    final plants = [
      {
        'id': 'plant_001',
        'name': 'Lavender',
        'scientific_name': 'Lavandula',
        'description':
            'Aromatic perennial with purple flowers, highly attractive to bees.',
        'planting_instructions':
            'Plant in well-drained soil in full sun. Space plants 12-18 inches apart.',
        'climate_preference': 'Mediterranean, temperate',
        'flowering_season': 'Summer',
        'nectar_value': 5,
        'pollen_value': 3,
        'image_path': 'assets/plants/lavender.jpg',
        'benefits_to_bees':
            'High nectar content, long blooming period, attracts honey bees and native bees.',
        'maintenance_level': 'Low',
        'water_requirements': 'Low',
        'sun_requirements': 'Full sun',
        'timestamp': DateTime.now().toIso8601String(),
      },
      {
        'id': 'plant_002',
        'name': 'Sunflower',
        'scientific_name': 'Helianthus annuus',
        'description':
            'Tall annual with large yellow flowers that produce abundant pollen.',
        'planting_instructions':
            'Sow seeds directly in soil after last frost. Space 6-12 inches apart.',
        'climate_preference': 'Temperate, subtropical',
        'flowering_season': 'Summer to Fall',
        'nectar_value': 3,
        'pollen_value': 5,
        'image_path': 'assets/plants/sunflower.jpg',
        'benefits_to_bees':
            'Excellent pollen source, supports many bee species, easy to grow.',
        'maintenance_level': 'Low',
        'water_requirements': 'Moderate',
        'sun_requirements': 'Full sun',
        'timestamp': DateTime.now().toIso8601String(),
      },
      {
        'id': 'plant_003',
        'name': 'Borage',
        'scientific_name': 'Borago officinalis',
        'description':
            'Annual herb with blue star-shaped flowers that produce copious nectar.',
        'planting_instructions':
            'Sow seeds directly in soil after last frost. Self-seeds readily.',
        'climate_preference': 'Temperate',
        'flowering_season': 'Spring to Fall',
        'nectar_value': 5,
        'pollen_value': 4,
        'image_path': 'assets/plants/borage.jpg',
        'benefits_to_bees':
            'Produces nectar continuously, flowers refill with nectar every two minutes.',
        'maintenance_level': 'Low',
        'water_requirements': 'Moderate',
        'sun_requirements': 'Full sun to partial shade',
        'timestamp': DateTime.now().toIso8601String(),
      },
      // Add more plants as needed
    ];

    for (var plant in plants) {
      await db.insert('plants', plant);
    }
  }

  // Add these methods to the BeeAdvisoryDatabase class

  // Get recommendations by date range
  Future<List<Map<String, dynamic>>> getRecommendationsByDateRange(
    String hiveId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;

    final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

    final result = await db.query(
      'recommendations',
      where: 'hive_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [hiveId, startDateStr, endDateStr],
      orderBy: 'date ASC',
    );

    return result;
  }

  // Get recommendations by issue
  Future<List<Map<String, dynamic>>> getRecommendationsByIssue(
    String hiveId,
    String issue,
  ) async {
    final db = await database;

    final result = await db.query(
      'recommendations',
      where: 'hive_id = ? AND issue_identified = ?',
      whereArgs: [hiveId, issue],
      orderBy: 'date ASC',
    );

    return result;
  }

  // Get implemented recommendations
  Future<List<Map<String, dynamic>>> getImplementedRecommendations(
    String hiveId,
  ) async {
    final db = await database;

    final result = await db.query(
      'recommendation_implementations',
      where: 'hive_id = ?',
      whereArgs: [hiveId],
    );

    return result;
  }

  // Check if a recommendation was implemented
  Future<bool> checkRecommendationImplemented(int recommendationId) async {
    final db = await database;

    final result = await db.query(
      'recommendation_implementations',
      where: 'recommendation_id = ?',
      whereArgs: [recommendationId],
    );

    return result.isNotEmpty;
  }

  // Create recommendation_implementations table if it doesn't exist
  Future<void> _createImplementationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recommendation_implementations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recommendation_id INTEGER NOT NULL,
        hive_id TEXT NOT NULL,
        implementation_date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (recommendation_id) REFERENCES recommendations (id)
      )
    ''');
  }

  // Mark a recommendation as implemented
  Future<int> markRecommendationImplemented(
    int recommendationId,
    String hiveId, {
    String? notes,
  }) async {
    final db = await database;

    return await db.insert('recommendation_implementations', {
      'recommendation_id': recommendationId,
      'hive_id': hiveId,
      'implementation_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'notes': notes ?? '',
    });
  }

  Future _insertInitialSupplementData(Database db) async {
    // Insert some common bee supplements
    final supplements = [
      {
        'id': 'supp_001',
        'name': 'Sugar Syrup',
        'type': 'Feed',
        'description':
            'Basic carbohydrate supplement for bees when nectar is scarce.',
        'usage_instructions':
            'Mix 1:1 (spring) or 2:1 (fall) sugar to water ratio. Provide in feeder.',
        'dosage':
            'As needed, typically 1-2 liters per hive per week during dearth.',
        'benefits':
            'Prevents starvation, supports colony growth, encourages brood rearing.',
        'when_to_use': 'Early spring, fall, or during nectar dearth.',
        'cautions':
            'Do not feed during honey flow. Can lead to robbing if spilled.',
        'image_path': 'assets/supplements/sugar_syrup.jpg',
        'price_range': 'Low',
        'availability': 'Easy to make at home',
        'timestamp': DateTime.now().toIso8601String(),
      },
      {
        'id': 'supp_002',
        'name': 'Pollen Substitute',
        'type': 'Feed',
        'description':
            'Protein supplement that mimics natural pollen nutrition.',
        'usage_instructions':
            'Place patty on top of frames directly above the brood nest.',
        'dosage': '1-2 patties per hive, replace when consumed.',
        'benefits':
            'Supports brood rearing, improves bee health, compensates for pollen shortage.',
        'when_to_use':
            'Early spring before natural pollen is available, or during pollen dearth.',
        'cautions':
            'Remove during honey flow. Monitor for small hive beetles in warm climates.',
        'image_path': 'assets/supplements/pollen_sub.jpg',
        'price_range': 'Moderate',
        'availability': 'Beekeeping suppliers',
        'timestamp': DateTime.now().toIso8601String(),
      },
      {
        'id': 'supp_003',
        'name': 'Probiotic Supplement',
        'type': 'Health',
        'description':
            'Contains beneficial microbes that support bee gut health.',
        'usage_instructions':
            'Mix with sugar syrup according to manufacturer instructions.',
        'dosage': 'Typically 1 teaspoon per gallon of syrup.',
        'benefits':
            'Improves disease resistance, aids digestion, enhances overall colony health.',
        'when_to_use':
            'Spring buildup, after antibiotic treatment, or when colony appears stressed.',
        'cautions':
            'Follow manufacturer guidelines. Not a replacement for good management.',
        'image_path': 'assets/supplements/probiotic.jpg',
        'price_range': 'Moderate to High',
        'availability': 'Specialized beekeeping suppliers',
        'timestamp': DateTime.now().toIso8601String(),
      },
      // Add more supplements as needed
    ];

    for (var supplement in supplements) {
      await db.insert('supplements', supplement);
    }
  }

  // CRUD operations for plants
  Future<String> insertPlant(Map<String, dynamic> plant) async {
    final db = await instance.database;

    if (!plant.containsKey('id')) {
      plant['id'] = 'plant_${DateTime.now().millisecondsSinceEpoch}';
    }

    plant['timestamp'] = DateTime.now().toIso8601String();

    await db.insert('plants', plant);
    return plant['id'];
  }

  Future<List<Map<String, dynamic>>> readAllPlants() async {
    final db = await instance.database;
    return await db.query('plants');
  }

  Future<Map<String, dynamic>?> readPlant(String id) async {
    final db = await instance.database;
    final maps = await db.query('plants', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> searchPlantsByClimate(
    String climate,
  ) async {
    final db = await instance.database;
    return await db.query(
      'plants',
      where: 'climate_preference LIKE ?',
      whereArgs: ['%$climate%'],
    );
  }

  // CRUD operations for supplements
  Future<String> insertSupplement(Map<String, dynamic> supplement) async {
    final db = await instance.database;

    if (!supplement.containsKey('id')) {
      supplement['id'] = 'supp_${DateTime.now().millisecondsSinceEpoch}';
    }

    supplement['timestamp'] = DateTime.now().toIso8601String();

    await db.insert('supplements', supplement);
    return supplement['id'];
  }

  Future<List<Map<String, dynamic>>> readAllSupplements() async {
    final db = await instance.database;
    return await db.query('supplements');
  }

  Future<Map<String, dynamic>?> readSupplement(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'supplements',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> searchSupplementsByType(
    String type,
  ) async {
    final db = await instance.database;
    return await db.query(
      'supplements',
      where: 'type LIKE ?',
      whereArgs: ['%$type%'],
    );
  }

  // CRUD operations for recommendations
  Future<String> insertRecommendation(
    Map<String, dynamic> recommendation,
  ) async {
    final db = await instance.database;

    if (!recommendation.containsKey('id')) {
      recommendation['id'] = 'rec_${DateTime.now().millisecondsSinceEpoch}';
    }

    recommendation['timestamp'] = DateTime.now().toIso8601String();

    await db.insert('recommendations', recommendation);
    return recommendation['id'];
  }

  Future<List<Map<String, dynamic>>> readRecommendationsByHive(
    String hiveId,
  ) async {
    final db = await instance.database;
    return await db.query(
      'recommendations',
      where: 'hive_id = ?',
      whereArgs: [hiveId],
      orderBy: 'priority ASC',
    );
  }

  Future<int> updateRecommendationImplementation(
    String id,
    bool implemented, {
    String? notes,
  }) async {
    final db = await instance.database;

    return await db.update(
      'recommendations',
      {
        'is_implemented': implemented ? 1 : 0,
        'implementation_date':
            implemented ? DateTime.now().toIso8601String() : null,
        if (notes != null) 'notes': notes,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // CRUD operations for farmer inputs
  Future<String> insertFarmerInput(Map<String, dynamic> input) async {
    final db = await instance.database;

    if (!input.containsKey('id')) {
      input['id'] = 'farm_${DateTime.now().millisecondsSinceEpoch}';
    }

    input['timestamp'] = DateTime.now().toIso8601String();

    await db.insert('farmer_inputs', input);
    return input['id'];
  }

  Future<Map<String, dynamic>?> readLatestFarmerInput() async {
    final db = await instance.database;
    final maps = await db.query(
      'farmer_inputs',
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Add this method to the BeeAdvisoryDatabase class

  Future<List<Map<String, dynamic>>> readAllHives() async {
    final db = await instance.database;

    try {
      // Query the hives table, or create a default entry if the table doesn't exist yet
      List<Map<String, dynamic>> hives = [];

      try {
        hives = await db.query('hives');
      } catch (e) {
        print('Error querying hives table: $e');
        // Create the hives table if it doesn't exist
        await db.execute('''
          CREATE TABLE IF NOT EXISTS hives (
            id TEXT PRIMARY KEY,
            latitude TEXT,
            longitude TEXT,
            farm_id TEXT,
            hemisphere TEXT DEFAULT 'northern'
          )
        ''');
      }

      // If no hives found, return at least a default hive
      if (hives.isEmpty) {
        // Default hive for testing
        return [
          {'id': 'default_hive', 'hemisphere': 'northern'},
        ];
      }

      return hives;
    } catch (e) {
      print('Error reading all hives: $e');
      // Return at least a default hive in case of error
      return [
        {'id': 'default_hive', 'hemisphere': 'northern'},
      ];
    }
  }

  Future<Map<String, dynamic>?> getHiveData(String hiveId) async {
    try {
      final hives = await readAllHives();

      // Find the hive with the matching ID
      for (var hive in hives) {
        if (hive['id'] == hiveId) {
          return hive;
        }
      }

      // If no matching hive is found, return null
      return null;
    } catch (e) {
      print('Error getting hive data: $e');
      // Return default data in case of error
      return {'id': hiveId, 'hemisphere': 'northern'};
    }
  }

  // Add this query method:

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    // Return mock data for testing purposes
    return [];
  }

  // Close the database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
