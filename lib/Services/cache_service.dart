import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:HPGM/Services/auth_manager.dart';

/// Simple cache service for storing API responses locally
class CacheService {
  static const String _farmsKey = 'cached_farms';
  static const String _hivesPrefix = 'cached_hives_farm_';
  static const String _lastUpdatePrefix = 'last_update_';

  /// Check if device is online
  static Future<bool> isOnline() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Save farms data to cache
  static Future<void> saveFarms(List<dynamic> farms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final farmsJson = jsonEncode(farms);
      await prefs.setString(_farmsKey, farmsJson);
      await prefs.setString(
        '${_lastUpdatePrefix}farms',
        DateTime.now().toIso8601String(),
      );
      print('✓ Farms cached successfully');
    } catch (e) {
      print('❌ Error caching farms: $e');
    }
  }

  /// Load farms data from cache
  static Future<List<dynamic>?> loadFarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final farmsJson = prefs.getString(_farmsKey);
      if (farmsJson != null) {
        final farms = jsonDecode(farmsJson) as List<dynamic>;
        print('✓ Loaded ${farms.length} farms from cache');
        return farms;
      }
    } catch (e) {
      print('❌ Error loading cached farms: $e');
    }
    return null;
  }

  /// Save hives data for a specific farm to cache
  static Future<void> saveHives(int farmId, List<dynamic> hives) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hivesJson = jsonEncode(hives);
      await prefs.setString('$_hivesPrefix$farmId', hivesJson);
      await prefs.setString(
        '${_lastUpdatePrefix}hives_$farmId',
        DateTime.now().toIso8601String(),
      );
      print('✓ Hives for farm $farmId cached successfully');
    } catch (e) {
      print('❌ Error caching hives for farm $farmId: $e');
    }
  }

  /// Load hives data for a specific farm from cache
  static Future<List<dynamic>?> loadHives(int farmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hivesJson = prefs.getString('$_hivesPrefix$farmId');
      if (hivesJson != null) {
        final hives = jsonDecode(hivesJson) as List<dynamic>;
        print('✓ Loaded ${hives.length} hives for farm $farmId from cache');
        return hives;
      }
    } catch (e) {
      print('❌ Error loading cached hives for farm $farmId: $e');
    }
    return null;
  }

  /// Save generic data with a custom key
  static Future<void> saveData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = jsonEncode(data);
      await prefs.setString('cached_$key', dataJson);
      await prefs.setString(
        '${_lastUpdatePrefix}$key',
        DateTime.now().toIso8601String(),
      );
      print('✓ Data cached with key: $key');
    } catch (e) {
      print('❌ Error caching data with key $key: $e');
    }
  }

  /// Load generic data with a custom key
  static Future<dynamic> loadData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = prefs.getString('cached_$key');
      if (dataJson != null) {
        final data = jsonDecode(dataJson);
        print('✓ Loaded cached data with key: $key');
        return data;
      }
    } catch (e) {
      print('❌ Error loading cached data with key $key: $e');
    }
    return null;
  }

  /// Get last update time for specific data
  static Future<DateTime?> getLastUpdateTime(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeString = prefs.getString('${_lastUpdatePrefix}$key');
      if (timeString != null) {
        return DateTime.parse(timeString);
      }
    } catch (e) {
      print('❌ Error getting last update time for $key: $e');
    }
    return null;
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs
              .getKeys()
              .where(
                (key) =>
                    key.startsWith('cached_') ||
                    key.startsWith(_lastUpdatePrefix),
              )
              .toList();

      for (final key in keys) {
        await prefs.remove(key);
      }
      print('✓ Cache cleared successfully');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }

  /// Check if cache exists for a specific key
  static Future<bool> hasCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('cached_$key');
    } catch (e) {
      return false;
    }
  }

  /// Make authenticated request with automatic fallback to cache
  static Future<dynamic> authenticatedRequestWithCache({
    required String endpoint,
    required String cacheKey,
    BuildContext? context,
    bool forceRefresh = false,
  }) async {
    try {
      // If not forcing refresh and offline, load from cache immediately
      if (!forceRefresh && !await isOnline()) {
        print('📱 Offline - loading from cache: $cacheKey');
        return await loadData(cacheKey);
      }

      // Try authenticated request using AuthManager
      final response = await AuthManager.get(endpoint, context: context);

      if (response != null && response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save successful response to cache
        await saveData(cacheKey, data);
        print('✅ Data fetched and cached: $cacheKey');

        return data;
      } else {
        // API failed, try cache fallback
        print(
          '⚠️ API failed (${response?.statusCode}), trying cache fallback: $cacheKey',
        );
        return await loadData(cacheKey);
      }
    } catch (e) {
      print('❌ Request error, trying cache: $e');
      return await loadData(cacheKey);
    }
  }
}
