import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BatteryOptimizationService {
  static final BatteryOptimizationService _instance = BatteryOptimizationService._internal();
  factory BatteryOptimizationService() => _instance;
  BatteryOptimizationService._internal();

  /// Check if battery optimization is enabled for the app
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (e) {
      return false;
    }
  }

  /// Request to disable battery optimization for the app
  /// This allows the app to run in background without restrictions
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    
    try {
      // Check if already ignoring
      final isIgnoring = await isIgnoringBatteryOptimizations();
      if (isIgnoring) return true;
      
      // Request to ignore battery optimizations
      return await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    } catch (e) {
      debugPrint('BatteryOptimization: Error requesting exemption: $e');
      return false;
    }
  }

  /// Open battery optimization settings for the app
  Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) return true;
    
    try {
      return await FlutterForegroundTask.openIgnoreBatteryOptimizationSettings();
    } catch (e) {
      debugPrint('BatteryOptimization: Error opening settings: $e');
      return false;
    }
  }
}
