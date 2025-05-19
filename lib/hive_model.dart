class Hive {
  final int id;
  final String longitude;
  final String latitude;
  final int farmId;
  final String? createdAt;
  final String? updatedAt;
  final HiveState? state;
  final bool autoProcessingEnabled; // Added as requested

  Hive({
    required this.id,
    required this.longitude,
    required this.latitude,
    required this.farmId,
    this.createdAt,
    this.updatedAt,
    this.state,
    this.autoProcessingEnabled = true, // Default to true
  });

  factory Hive.fromJson(Map<String, dynamic> json) {
    return Hive(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      longitude: json['longitude'] ?? '',
      latitude: json['latitude'] ?? '',
      farmId:
          json['farm_id'] is String
              ? int.parse(json['farm_id'])
              : json['farm_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      state: json['state'] != null ? HiveState.fromJson(json['state']) : null,
      autoProcessingEnabled: json['autoProcessingEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'longitude': longitude,
      'latitude': latitude,
      'farm_id': farmId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'state': state?.toJson(),
      'autoProcessingEnabled': autoProcessingEnabled,
    };
  }

  // Convenience getters to access nested state properties
  double? get temperature => state?.temperature?.interiorTemperature;
  double? get exteriorTemperature => state?.temperature?.exteriorTemperature;
  double? get humidity => state?.humidity?.interiorHumidity;
  double? get exteriorHumidity => state?.humidity?.exteriorHumidity;
  double? get weight => state?.weight?.record;
  double? get honeyLevel => state?.weight?.honeyPercentage;
  int? get carbonDioxide => state?.carbonDioxide?.record;
  String? get lastUpdated =>
      state?.weight?.dateCollected ??
      state?.temperature?.dateCollected ??
      state?.humidity?.dateCollected ??
      state?.carbonDioxide?.dateCollected;
  bool get isConnected => state?.connectionStatus?.connected ?? false;
  bool get isColonized => state?.colonizationStatus?.colonized ?? false;
  String? get name => "Hive $id"; // You can add a name field if needed
}

class HiveState {
  final WeightData? weight;
  final TemperatureData? temperature;
  final HumidityData? humidity;
  final CarbonDioxideData? carbonDioxide;
  final ConnectionStatus? connectionStatus;
  final ColonizationStatus? colonizationStatus;

  HiveState({
    this.weight,
    this.temperature,
    this.humidity,
    this.carbonDioxide,
    this.connectionStatus,
    this.colonizationStatus,
  });

  factory HiveState.fromJson(Map<String, dynamic> json) {
    return HiveState(
      weight:
          json['weight'] != null ? WeightData.fromJson(json['weight']) : null,
      temperature:
          json['temperature'] != null
              ? TemperatureData.fromJson(json['temperature'])
              : null,
      humidity:
          json['humidity'] != null
              ? HumidityData.fromJson(json['humidity'])
              : null,
      carbonDioxide:
          json['carbon_dioxide'] != null
              ? CarbonDioxideData.fromJson(json['carbon_dioxide'])
              : null,
      connectionStatus:
          json['connection_status'] != null
              ? ConnectionStatus.fromJson(json['connection_status'])
              : null,
      colonizationStatus:
          json['colonization_status'] != null
              ? ColonizationStatus.fromJson(json['colonization_status'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'weight': weight?.toJson(),
      'temperature': temperature?.toJson(),
      'humidity': humidity?.toJson(),
      'carbon_dioxide': carbonDioxide?.toJson(),
      'connection_status': connectionStatus?.toJson(),
      'colonization_status': colonizationStatus?.toJson(),
    };
  }
}

class WeightData {
  final double record;
  final double honeyPercentage;
  final String dateCollected;

  WeightData({
    required this.record,
    required this.honeyPercentage,
    required this.dateCollected,
  });

  factory WeightData.fromJson(Map<String, dynamic> json) {
    return WeightData(
      record:
          json['record'] is int
              ? (json['record'] as int).toDouble()
              : json['record'] ?? 0.0,
      honeyPercentage:
          json['honey_percentage'] is int
              ? (json['honey_percentage'] as int).toDouble()
              : json['honey_percentage'] ?? 0.0,
      dateCollected: json['date_collected'] ?? DateTime.now().toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'record': record,
      'honey_percentage': honeyPercentage,
      'date_collected': dateCollected,
    };
  }
}

class TemperatureData {
  final double? interiorTemperature;
  final double? exteriorTemperature;
  final String dateCollected;

  TemperatureData({
    this.interiorTemperature,
    this.exteriorTemperature,
    required this.dateCollected,
  });

  factory TemperatureData.fromJson(Map<String, dynamic> json) {
    return TemperatureData(
      interiorTemperature:
          json['interior_temperature'] != null
              ? (json['interior_temperature'] is int
                  ? (json['interior_temperature'] as int).toDouble()
                  : json['interior_temperature'])
              : null,
      exteriorTemperature:
          json['exterior_temperature'] != null
              ? (json['exterior_temperature'] is int
                  ? (json['exterior_temperature'] as int).toDouble()
                  : json['exterior_temperature'])
              : null,
      dateCollected: json['date_collected'] ?? DateTime.now().toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interior_temperature': interiorTemperature,
      'exterior_temperature': exteriorTemperature,
      'date_collected': dateCollected,
    };
  }
}

class HumidityData {
  final double? interiorHumidity;
  final double? exteriorHumidity;
  final String dateCollected;

  HumidityData({
    this.interiorHumidity,
    this.exteriorHumidity,
    required this.dateCollected,
  });

  factory HumidityData.fromJson(Map<String, dynamic> json) {
    return HumidityData(
      interiorHumidity:
          json['interior_humidity'] != null
              ? (json['interior_humidity'] is int
                  ? (json['interior_humidity'] as int).toDouble()
                  : json['interior_humidity'])
              : null,
      exteriorHumidity:
          json['exterior_humidity'] != null
              ? (json['exterior_humidity'] is int
                  ? (json['exterior_humidity'] as int).toDouble()
                  : json['exterior_humidity'])
              : null,
      dateCollected: json['date_collected'] ?? DateTime.now().toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interior_humidity': interiorHumidity,
      'exterior_humidity': exteriorHumidity,
      'date_collected': dateCollected,
    };
  }
}

class CarbonDioxideData {
  final int record;
  final String dateCollected;

  CarbonDioxideData({required this.record, required this.dateCollected});

  factory CarbonDioxideData.fromJson(Map<String, dynamic> json) {
    return CarbonDioxideData(
      record: json['record'] ?? 0,
      dateCollected: json['date_collected'] ?? DateTime.now().toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'record': record, 'date_collected': dateCollected};
  }
}

class ConnectionStatus {
  final bool connected;

  ConnectionStatus({required this.connected});

  factory ConnectionStatus.fromJson(Map<String, dynamic> json) {
    return ConnectionStatus(connected: json['Connected'] ?? false);
  }

  Map<String, dynamic> toJson() {
    return {'Connected': connected};
  }
}

class ColonizationStatus {
  final bool colonized;

  ColonizationStatus({required this.colonized});

  factory ColonizationStatus.fromJson(Map<String, dynamic> json) {
    return ColonizationStatus(colonized: json['Colonized'] ?? false);
  }

  Map<String, dynamic> toJson() {
    return {'Colonized': colonized};
  }
}

class HiveData {
  final String id;
  final String name;
  final String status;
  final String healthStatus;
  final String lastChecked;
  final double weight;
  final double temperature;
  final double honeyLevel;
  final bool isConnected;
  final bool isColonized;
  final bool autoProcessingEnabled;
  final double? exteriorTemperature;
  final double? interiorHumidity;
  final double? exteriorHumidity;
  final int? carbonDioxide;

  HiveData({
    required this.id,
    required this.name,
    required this.status,
    required this.healthStatus,
    required this.lastChecked,
    required this.weight,
    required this.temperature,
    required this.honeyLevel,
    required this.isConnected,
    required this.isColonized,
    required this.autoProcessingEnabled,
    this.exteriorTemperature,
    this.interiorHumidity,
    this.exteriorHumidity,
    this.carbonDioxide,
  });

  factory HiveData.fromApiHive(Hive hive) {
    // Determine status based on connection and colonization
    String status = 'Unknown';
    if (hive.isConnected) {
      status = 'Online';
    } else {
      status = 'Offline';
    }

    // Determine health status based on colonization
    String healthStatus = 'Unknown';
    if (hive.isColonized) {
      healthStatus = 'Healthy';
    } else {
      healthStatus = 'Not Colonized';
    }

    return HiveData(
      id: hive.id.toString(),
      name: hive.name ?? 'Hive ${hive.id}',
      status: status,
      healthStatus: healthStatus,
      lastChecked: hive.lastUpdated ?? DateTime.now().toIso8601String(),
      weight: hive.weight ?? 0.0,
      temperature: hive.temperature ?? 0.0,
      honeyLevel: hive.honeyLevel ?? 0.0,
      isConnected: hive.isConnected,
      isColonized: hive.isColonized,
      autoProcessingEnabled: hive.autoProcessingEnabled,
      exteriorTemperature: hive.exteriorTemperature,
      interiorHumidity: hive.humidity,
      exteriorHumidity: hive.exteriorHumidity,
      carbonDioxide: hive.carbonDioxide,
    );
  }
}
