import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_model.dart';

class BackupService {
  static const String _backupKey = 'app_backup';
  static const String _lastBackupKey = 'last_backup_time';

  static Future<void> createBackup(
    List<WorkoutHistory> history,
    List<Workout> customWorkouts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final backup = {
        'version': '1.0.0',
        'timestamp': DateTime.now().toIso8601String(),
        'history': history.map((h) => h.toJson()).toList(),
        'workouts': customWorkouts.map((w) => w.toJson()).toList(),
      };
      
      await prefs.setString(_backupKey, jsonEncode(backup));
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());
    } catch (e) {
      // Silently fail - backup is not critical
    }
  }

  static Future<Map<String, dynamic>?> getBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupStr = prefs.getString(_backupKey);
      if (backupStr == null) return null;
      
      return jsonDecode(backupStr) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Future<DateTime?> getLastBackupTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timeStr = prefs.getString(_lastBackupKey);
      if (timeStr == null) return null;
      
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> restoreBackup() async {
    try {
      final backup = await getBackup();
      if (backup == null) return false;
      
      final prefs = await SharedPreferences.getInstance();
      
      // Restore history
      if (backup['history'] != null) {
        await prefs.setString(
          'workout_history',
          jsonEncode(backup['history']),
        );
      }
      
      // Restore custom workouts
      if (backup['workouts'] != null) {
        await prefs.setString(
          'custom_workouts',
          jsonEncode(backup['workouts']),
        );
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_backupKey);
      await prefs.remove(_lastBackupKey);
    } catch (e) {
      // Silently fail
    }
  }
}
