import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_model.dart';

class PerformanceService {
  static const int _maxHistoryItems = 500;
  static const int _maxCustomWorkouts = 100;
  static const Duration _cacheExpiry = Duration(days: 30);

  static Future<void> cleanupOldData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clean up old history items
    await _cleanupHistory(prefs);
    
    // Clean up excessive custom workouts
    await _cleanupWorkouts(prefs);
    
    // Clean up old preferences
    await _cleanupPreferences(prefs);
  }

  static Future<void> _cleanupHistory(SharedPreferences prefs) async {
    try {
      final historyStr = prefs.getString('workout_history');
      if (historyStr == null) return;

      final rawHistory = jsonDecode(historyStr) as List<dynamic>;
      final history = rawHistory
          .map((item) => WorkoutHistory.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      if (history.length <= _maxHistoryItems) return;

      final trimmedHistory = history.take(_maxHistoryItems).toList();
      await prefs.setString(
        'workout_history',
        jsonEncode(trimmedHistory.map((item) => item.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error cleaning history: $e');
    }
  }

  static Future<void> _cleanupWorkouts(SharedPreferences prefs) async {
    try {
      final workoutsStr = prefs.getString('custom_workouts');
      if (workoutsStr == null) return;

      final rawWorkouts = jsonDecode(workoutsStr) as List<dynamic>;
      final workouts = rawWorkouts
          .map((item) => Workout.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();

      if (workouts.length <= _maxCustomWorkouts) return;

      final trimmedWorkouts = workouts.skip(workouts.length - _maxCustomWorkouts).toList();
      await prefs.setString(
        'custom_workouts',
        jsonEncode(trimmedWorkouts.map((item) => item.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error cleaning workouts: $e');
    }
  }

  static Future<void> _cleanupPreferences(SharedPreferences prefs) async {
    try {
      // Remove any orphaned or old preference keys
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('temp_') || key.startsWith('cache_')) {
          await prefs.remove(key);
        }
      }

      final backupTimestamp = prefs.getString('last_backup_time');
      if (backupTimestamp != null) {
        final parsedBackupTime = DateTime.tryParse(backupTimestamp);
        if (parsedBackupTime != null &&
            DateTime.now().difference(parsedBackupTime) > _cacheExpiry) {
          await prefs.remove('app_backup');
          await prefs.remove('last_backup_time');
        }
      }
    } catch (e) {
      debugPrint('Error cleaning preferences: $e');
    }
  }

  static Future<void> optimizeStorage() async {
    await cleanupOldData();
  }
}
