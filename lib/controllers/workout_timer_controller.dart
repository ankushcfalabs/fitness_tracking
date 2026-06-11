import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/workout_model.dart';

enum WorkoutState {
  idle,
  countdown,
  working,
  resting,
  roundBreak,
  completed,
  paused,
}

class WorkoutTimerController extends ChangeNotifier {
  final Workout workout;
  final Function(WorkoutHistory) onComplete;
  final Function(String)? onVoiceAnnouncement;

  WorkoutTimerController({
    required this.workout,
    required this.onComplete,
    this.onVoiceAnnouncement,
  });

  WorkoutState _state = WorkoutState.idle;
  int _currentRound = 1;
  int _currentSet = 0;
  int _secondsRemaining = 3;
  int _totalElapsedSeconds = 0;
  Timer? _timer;
  DateTime? _startTime;

  WorkoutState get state => _state;
  int get currentRound => _currentRound;
  int get currentSet => _currentSet;
  int get secondsRemaining => _secondsRemaining;
  int get totalElapsedSeconds => _totalElapsedSeconds;
  bool get isPaused => _state == WorkoutState.paused;
  bool get isActive => _state != WorkoutState.idle && _state != WorkoutState.completed;

  double get progress {
    final totalDuration = _getCurrentPhaseDuration();
    if (totalDuration == 0) return 0;
    return 1.0 - (_secondsRemaining / totalDuration);
  }

  double get overallProgress {
    final totalSets = workout.sets.length * workout.rounds;
    final completedSets = (_currentRound - 1) * workout.sets.length + _currentSet;
    return totalSets > 0 ? completedSets / totalSets : 0.0;
  }

  String get currentSetName {
    if (_currentSet < workout.sets.length) {
      final setName = workout.sets[_currentSet].name;
      return setName.isNotEmpty ? setName : 'Set ${_currentSet + 1}';
    }
    return '';
  }

  void start() {
    if (_state != WorkoutState.idle) return;
    _startTime = DateTime.now();
    _state = WorkoutState.countdown;
    _secondsRemaining = 3;
    _announceVoice('workout_start:${workout.name}:${workout.rounds}:${workout.sets.length}');
    _startTimer();
    notifyListeners();
  }

  void togglePause() {
    if (_state == WorkoutState.paused) {
      _resume();
    } else if (isActive && _state != WorkoutState.countdown) {
      _pause();
    }
  }

  void _pause() {
    _timer?.cancel();
    _state = WorkoutState.paused;
    _announceVoice('paused');
    notifyListeners();
  }

  void _resume() {
    if (_state == WorkoutState.paused) {
      _state = WorkoutState.working;
      _announceVoice('resumed');
      _startTimer();
      notifyListeners();
    }
  }

  void skip() {
    _secondsRemaining = 0;
    _advance();
  }

  void end() {
    _complete();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == WorkoutState.paused) return;

      _totalElapsedSeconds++;
      _secondsRemaining--;

      if (_secondsRemaining <= 0) {
        _advance();
      } else {
        if (_state == WorkoutState.countdown && _secondsRemaining <= 3) {
          _announceVoice('countdown:$_secondsRemaining');
        } else if (_state == WorkoutState.working) {
          final duration = workout.sets[_currentSet].durationSeconds;
          if (_secondsRemaining == duration ~/ 2 && duration >= 20) {
            _announceVoice('halfway');
          } else if (_secondsRemaining == 10 || _secondsRemaining == 5 || _secondsRemaining <= 3) {
            _announceVoice('time_remaining:$_secondsRemaining');
          }
        } else if (_state == WorkoutState.resting || _state == WorkoutState.roundBreak) {
          if (_secondsRemaining <= 3) {
            _announceVoice('time_remaining:$_secondsRemaining');
          }
        }
      }

      notifyListeners();
    });
  }

  void _advance() {
    switch (_state) {
      case WorkoutState.countdown:
        _startWorkPhase();
        break;
      case WorkoutState.working:
        _startRestPhase();
        break;
      case WorkoutState.resting:
        _nextSet();
        break;
      case WorkoutState.roundBreak:
        _nextRound();
        break;
      default:
        break;
    }
  }

  void _startWorkPhase() {
    _state = WorkoutState.working;
    _currentSet = 0;
    _secondsRemaining = workout.sets[_currentSet].durationSeconds;
    _announceVoice('round_start:$_currentRound:${workout.rounds}');
    _announceVoice('set_start:$currentSetName');
    notifyListeners();
  }

  void _startRestPhase() {
    final breakTime = workout.sets[_currentSet].breakSeconds;
    _announceVoice('set_end:$currentSetName');
    if (breakTime > 0) {
      _state = WorkoutState.resting;
      _secondsRemaining = breakTime;
      _announceVoice('rest:$breakTime');
      notifyListeners();
    } else {
      _nextSet();
    }
  }

  void _nextSet() {
    if (_currentSet < workout.sets.length - 1) {
      _currentSet++;
      _state = WorkoutState.working;
      _secondsRemaining = workout.sets[_currentSet].durationSeconds;
      final setName = currentSetName;
      _announceVoice('set_start:$setName');
      notifyListeners();
    } else {
      _endRound();
    }
  }

  void _endRound() {
    _announceVoice('round_end:$_currentRound:${workout.rounds}');
    if (_currentRound < workout.rounds) {
      _state = WorkoutState.roundBreak;
      _secondsRemaining = workout.roundBreakSeconds;
      _announceVoice('round_break:${workout.roundBreakSeconds}:${_currentRound + 1}:${workout.rounds}');
      notifyListeners();
    } else {
      _complete();
    }
  }

  void _nextRound() {
    _currentRound++;
    _currentSet = 0;
    _state = WorkoutState.working;
    _secondsRemaining = workout.sets[_currentSet].durationSeconds;
    _announceVoice('round_start:$_currentRound:${workout.rounds}');
    _announceVoice('set_start:$currentSetName');
    notifyListeners();
  }

  void _complete() {
    _timer?.cancel();
    _state = WorkoutState.completed;
    _announceVoice('workout_complete:${workout.name}:$_totalElapsedSeconds');

    final history = WorkoutHistory(
      workoutName: workout.name,
      date: _startTime ?? DateTime.now(),
      durationSeconds: _totalElapsedSeconds,
      roundsCompleted: _currentRound,
      emoji: workout.emoji,
    );

    onComplete(history);
    notifyListeners();
  }

  int _getCurrentPhaseDuration() {
    switch (_state) {
      case WorkoutState.countdown:
        return 3;
      case WorkoutState.working:
        return _currentSet < workout.sets.length
            ? workout.sets[_currentSet].durationSeconds
            : 0;
      case WorkoutState.resting:
        return _currentSet < workout.sets.length
            ? workout.sets[_currentSet].breakSeconds
            : 0;
      case WorkoutState.roundBreak:
        return workout.roundBreakSeconds;
      default:
        return 0;
    }
  }

  void _announceVoice(String message) {
    onVoiceAnnouncement?.call(message);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
