import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    // In production, initialize analytics SDK here
    // e.g., Firebase Analytics, Mixpanel, etc.
    
    _initialized = true;
    _log('Analytics initialized');
  }

  void logEvent(String name, {Map<String, dynamic>? parameters}) {
    if (!_initialized) return;
    
    _log('Event: $name', parameters);
    
    // In production, send to analytics service
    // e.g., FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
  }

  void logWorkoutStarted(String workoutName, String category) {
    logEvent('workout_started', parameters: {
      'workout_name': workoutName,
      'category': category,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void logWorkoutCompleted(String workoutName, int durationSeconds, int rounds) {
    logEvent('workout_completed', parameters: {
      'workout_name': workoutName,
      'duration_seconds': durationSeconds,
      'rounds': rounds,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void logWorkoutCreated(String category, int rounds, int sets) {
    logEvent('workout_created', parameters: {
      'category': category,
      'rounds': rounds,
      'sets': sets,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void logScreenView(String screenName) {
    logEvent('screen_view', parameters: {
      'screen_name': screenName,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void logError(String error, {String? stackTrace}) {
    logEvent('error', parameters: {
      'error': error,
      'stack_trace': stackTrace,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _log(String message, [Map<String, dynamic>? data]) {
    if (kDebugMode) {
      debugPrint('Analytics: $message ${data != null ? data.toString() : ""}');
    }
  }
}
