import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'models/workout_model.dart';
import 'screens/home_screen.dart';
import 'services/backup_service.dart';
import 'services/error_handler.dart';
import 'services/analytics_service.dart';
import 'services/performance_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();

  // Initialize error handling
  ErrorHandler.initialize();

  // Initialize analytics
  await AnalyticsService().initialize();

  // Optimize storage on startup
  PerformanceService.optimizeStorage();

  final prefs = await SharedPreferences.getInstance();
  runApp(FitnessApp(prefs: prefs));
}

class FitnessApp extends StatefulWidget {
  final SharedPreferences prefs;
  const FitnessApp({super.key, required this.prefs});

  @override
  State<FitnessApp> createState() => _FitnessAppState();
}

class _FitnessAppState extends State<FitnessApp> with WidgetsBindingObserver {
  late List<WorkoutHistory> _history;
  late List<Workout> _customWorkouts;

  static const _historyKey = 'workout_history';
  static const _workoutsKey = 'custom_workouts';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _history = _loadHistory();
    _customWorkouts = _loadWorkouts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // App going to background - save data
      _saveHistory();
      _saveWorkouts();
      BackupService.createBackup(_history, _customWorkouts);
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground - reload data
      setState(() {
        _history = _loadHistory();
        _customWorkouts = _loadWorkouts();
      });
    }
  }

  List<WorkoutHistory> _loadHistory() {
    final raw = widget.prefs.getString(_historyKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => WorkoutHistory.fromJson(e))
        .toList();
  }

  List<Workout> _loadWorkouts() {
    final raw = widget.prefs.getString(_workoutsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Workout.fromJson(e)).toList();
  }

  void _saveHistory() {
    widget.prefs.setString(
      _historyKey,
      jsonEncode(_history.map((h) => h.toJson()).toList()),
    );
    // Auto-backup after saving
    BackupService.createBackup(_history, _customWorkouts);
  }

  void _saveWorkouts() {
    widget.prefs.setString(
      _workoutsKey,
      jsonEncode(_customWorkouts.map((w) => w.toJson()).toList()),
    );
    // Auto-backup after saving
    BackupService.createBackup(_history, _customWorkouts);
  }

  void _onWorkoutComplete(WorkoutHistory h) {
    setState(() => _history.add(h));
    _saveHistory();
    AnalyticsService().logWorkoutCompleted(
      h.workoutName,
      h.durationSeconds,
      h.roundsCompleted,
    );
  }

  void _onSaveWorkout(Workout w) {
    setState(() {
      final idx = _customWorkouts.indexWhere((e) => e.id == w.id);
      if (idx >= 0) {
        _customWorkouts[idx] = w;
      } else {
        _customWorkouts.add(w);
        AnalyticsService().logWorkoutCreated(
          w.category,
          w.rounds,
          w.sets.length,
        );
      }
    });
    _saveWorkouts();
  }

  void _onDeleteWorkout(String id) {
    setState(() => _customWorkouts.removeWhere((w) => w.id == id));
    _saveWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitsTracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: HomeScreen(
        history: _history,
        customWorkouts: _customWorkouts,
        onWorkoutComplete: _onWorkoutComplete,
        onSaveWorkout: _onSaveWorkout,
        onDeleteWorkout: _onDeleteWorkout,
      ),
    );
  }
}
