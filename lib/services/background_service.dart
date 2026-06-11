import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class WorkoutBackgroundService {
  static final WorkoutBackgroundService _instance = WorkoutBackgroundService._internal();
  factory WorkoutBackgroundService() => _instance;
  WorkoutBackgroundService._internal();

  bool _isInitialized = false;
  bool _isTaskDataCallbackRegistered = false;
  Function(String)? _onActionCallback;

  Future<void> init() async {
    if (_isInitialized) return;
    
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'workout_channel',
        channelName: 'Workout Timer',
        channelDescription: 'Shows ongoing workout timer with controls',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_SECRET,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    if (!_isTaskDataCallbackRegistered) {
      FlutterForegroundTask.addTaskDataCallback(_handleTaskData);
      _isTaskDataCallbackRegistered = true;
    }
    
    _isInitialized = true;
  }

  void setActionCallback(Function(String) callback) {
    _onActionCallback = callback;
  }

  void _handleTaskData(Object data) {
    if (data is! Map<String, dynamic>) return;

    final action = data['action'];
    if (action is String && _onActionCallback != null) {
      _onActionCallback!(action);
    }
  }

  Future<void> startWorkout(String workoutName) async {
    await init();
    
    // Request permissions
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      final requestedPermission =
          await FlutterForegroundTask.requestNotificationPermission();
      if (requestedPermission != NotificationPermission.granted) {
        debugPrint(
          'BackgroundService: Notification permission not granted, skipping foreground service start',
        );
        return;
      }
    }

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
    
    // Start foreground service
    final serviceStarted = await FlutterForegroundTask.startService(
      notificationTitle: '🏋️ $workoutName',
      notificationText: 'Preparing workout...',
      notificationButtons: [
        const NotificationButton(id: 'pause', text: 'Pause'),
        const NotificationButton(id: 'stop', text: 'Stop'),
      ],
      notificationInitialRoute: '/',
      callback: startCallback,
    );
    
    if (serviceStarted is ServiceRequestSuccess) {
      debugPrint('BackgroundService: Foreground service started successfully');
    } else if (serviceStarted is ServiceRequestFailure) {
      debugPrint(
        'BackgroundService: Failed to start foreground service: ${serviceStarted.error}',
      );
    }
  }

  Future<void> updateNotification({
    required String phase,
    required String timeRemaining,
    required int round,
    required int totalRounds,
    bool isPaused = false,
  }) async {
    if (await FlutterForegroundTask.isRunningService) {
      final phaseEmoji = _getPhaseEmoji(phase);
      await FlutterForegroundTask.updateService(
        notificationTitle: '$phaseEmoji $phase - Round $round/$totalRounds',
        notificationText: '⏱️ $timeRemaining ${isPaused ? "(PAUSED)" : ""}',
        notificationButtons: [
          NotificationButton(
            id: isPaused ? 'resume' : 'pause',
            text: isPaused ? 'Resume' : 'Pause',
          ),
          const NotificationButton(id: 'stop', text: 'Stop'),
        ],
      );
    }
  }

  String _getPhaseEmoji(String phase) {
    switch (phase.toUpperCase()) {
      case 'GET READY':
        return '⏳';
      case 'WORK':
        return '💪';
      case 'REST':
        return '😌';
      case 'ROUND BREAK':
        return '🎯';
      default:
        return '🏋️';
    }
  }

  Future<void> stopWorkout() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
      debugPrint('BackgroundService: Foreground service stopped');
    }
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(WorkoutTaskHandler());
}

class WorkoutTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('WorkoutTaskHandler: Service started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep service alive - called every second
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('WorkoutTaskHandler: Service destroyed');
  }

  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('WorkoutTaskHandler: Button pressed - $id');
    FlutterForegroundTask.sendDataToMain(<String, dynamic>{'action': id});
  }

  @override
  void onNotificationPressed() {
    debugPrint('WorkoutTaskHandler: Notification pressed');
    FlutterForegroundTask.launchApp('/');
  }
}
