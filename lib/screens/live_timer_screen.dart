import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/workout_model.dart';
import '../services/voice_service_new.dart';
import '../services/audio_service.dart';
import '../services/platform_service.dart';
import '../services/background_service.dart';
import '../widgets/common_widgets.dart';

enum TimerPhase { countdown, work, rest, roundBreak, done }

class LiveTimerScreen extends StatefulWidget {
  final Workout workout;
  final void Function(WorkoutHistory) onComplete;

  const LiveTimerScreen({
    super.key,
    required this.workout,
    required this.onComplete,
  });

  @override
  State<LiveTimerScreen> createState() => _LiveTimerScreenState();
}

class _LiveTimerScreenState extends State<LiveTimerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _phaseCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _phaseFade;

  Timer? _timer;
  int _secondsLeft = 3;
  int _currentRound = 1;
  int _currentSet = 0;
  TimerPhase _phase = TimerPhase.countdown;
  bool _paused = false;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  final VoiceServiceNew _voice = VoiceServiceNew();
  final AudioService _audio = AudioService();
  final WorkoutBackgroundService _background = WorkoutBackgroundService();
  bool _voiceEnabled = true;
  bool _soundEnabled = true;
  bool _wasPlayingBeforePause = false;
  bool _completionRecorded = false;

  static const _screenBg = Color(0xFFF5F7FA);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceMuted = Color(0xFFEFF4F8);
  static const _line = Color(0xFFD9E2EC);
  static const _ink = Color(0xFF182235);
  static const _muted = Color(0xFF66768A);
  static const _subtleText = Color(0xFF94A3B8);
  static const _workColor = Color(0xFF2F7D5A);
  static const _restColor = Color(0xFF2F6690);
  static const _breakColor = Color(0xFFB7791F);
  static const _countdownColor = Color(0xFF6B5EAE);
  static const _dangerColor = Color(0xFFB42318);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _phaseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseAnim = Tween(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _phaseFade = CurvedAnimation(parent: _phaseCtrl, curve: Curves.easeOut);
    _phaseCtrl.forward();

    _loadSettings();
    _voice.init().then((_) async {
      await _voice.announceWorkoutStart(
        widget.workout.name,
        widget.workout.rounds,
        widget.workout.sets.length,
      );
    });

    _background.init().then((_) {
      // Setup callback for notification button actions
      _background.setActionCallback((action) {
        if (!mounted) return;
        if (action == 'pause' || action == 'resume') {
          _togglePause();
        } else if (action == 'stop') {
          _saveProgressAndExit();
        }
      });
      _background.startWorkout(widget.workout.name);
    });
    _startCountdown();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused && _phase != TimerPhase.done) {
        setState(() => _elapsedSeconds++);
        _updateBackgroundNotification();
      }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await _audio.init();
    await _voice.init();
    setState(() {
      _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _voice.setEnabled(_voiceEnabled);
      _audio.setEnabled(_soundEnabled);
    });
    debugPrint(
      'LiveTimer: Loaded settings - voice: $_voiceEnabled, sound: $_soundEnabled',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _wasPlayingBeforePause = !_paused;
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause && mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _elapsedTimer?.cancel();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _phaseCtrl.dispose();
    _voice.dispose();
    _audio.dispose();
    _background.stopWorkout();

    super.dispose();
  }

  void _startCountdown() {
    _secondsLeft = 3;
    _phase = TimerPhase.countdown;
    _startTick();
  }

  void _startTick() {
    _timer?.cancel();
    _ringCtrl.forward(from: 0);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
          _ringCtrl.forward(from: 0);
          if (PlatformService.supportsHapticFeedback) {
            HapticFeedback.lightImpact();
          }
          if (_phase == TimerPhase.countdown) {
            _voice.announceCountdown(_secondsLeft);
            _audio.playCountdownBeep();
          } else if (_phase == TimerPhase.work) {
            final duration = widget.workout.sets[_currentSet].durationSeconds;
            if (_secondsLeft == duration ~/ 2 && duration >= 20) {
              _voice.announceHalfway();
              _audio.playHalfwayBeep();
            } else if (_secondsLeft == 10 ||
                _secondsLeft == 5 ||
                _secondsLeft <= 3) {
              _voice.announceTimeRemaining(_secondsLeft);
              if (_secondsLeft <= 3) _audio.playWarningBeep();
            }
          } else if (_secondsLeft <= 3) {
            _voice.announceTimeRemaining(_secondsLeft);
            _audio.playWarningBeep();
          }
        } else {
          _advance();
        }
      });
    });
  }

  void _advance() {
    _phaseCtrl.reset();
    _phaseCtrl.forward();
    if (PlatformService.supportsHapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    if (_phase == TimerPhase.countdown) {
      _phase = TimerPhase.work;
      _currentSet = 0;
      _secondsLeft = widget.workout.sets[_currentSet].durationSeconds;
      _ringCtrl.forward(from: 0);
      _voice.announceRoundStart(_currentRound, widget.workout.rounds);
      final setName = widget.workout.sets[_currentSet].name.isNotEmpty
          ? widget.workout.sets[_currentSet].name
          : 'Set ${_currentSet + 1}';
      _voice.announceSetStart(setName);
      // Small delay before beep to avoid audio conflict
      Future.delayed(const Duration(milliseconds: 300), () {
        _audio.playStartBeep();
      });
      return;
    }

    if (_phase == TimerPhase.work) {
      final setName = widget.workout.sets[_currentSet].name.isNotEmpty
          ? widget.workout.sets[_currentSet].name
          : 'Set ${_currentSet + 1}';
      _voice.announceSetEnd(setName);
      final breakTime = widget.workout.sets[_currentSet].breakSeconds;
      if (breakTime > 0) {
        _phase = TimerPhase.rest;
        _secondsLeft = breakTime;
        _ringCtrl.forward(from: 0);
        _voice.announceRest(breakTime);
        _audio.playEndBeep();
        return;
      }
      _nextSet();
      return;
    }

    if (_phase == TimerPhase.rest) {
      _nextSet();
      return;
    }

    if (_phase == TimerPhase.roundBreak) {
      _currentRound++;
      _currentSet = 0;
      _phase = TimerPhase.work;
      _secondsLeft = widget.workout.sets[_currentSet].durationSeconds;
      _ringCtrl.forward(from: 0);
      _voice.announceRoundStart(_currentRound, widget.workout.rounds);
      final setName = widget.workout.sets[_currentSet].name.isNotEmpty
          ? widget.workout.sets[_currentSet].name
          : 'Set ${_currentSet + 1}';
      _voice.announceSetStart(setName);
      _audio.playStartBeep();
      return;
    }
  }

  void _nextSet() {
    if (_currentSet < widget.workout.sets.length - 1) {
      _currentSet++;
      _phase = TimerPhase.work;
      _secondsLeft = widget.workout.sets[_currentSet].durationSeconds;
      _ringCtrl.forward(from: 0);
      final setName = widget.workout.sets[_currentSet].name.isNotEmpty
          ? widget.workout.sets[_currentSet].name
          : 'Set ${_currentSet + 1}';
      _voice.announceSetStart(setName);
      _audio.playStartBeep();
    } else if (_currentRound < widget.workout.rounds) {
      _voice.announceRoundEnd(_currentRound, widget.workout.rounds);
      _phase = TimerPhase.roundBreak;
      _secondsLeft = widget.workout.roundBreakSeconds;
      _ringCtrl.forward(from: 0);
      _voice.announceRoundBreak(
        widget.workout.roundBreakSeconds,
        _currentRound + 1,
        widget.workout.rounds,
      );
      _audio.playRoundCompleteBeep();
    } else {
      _phase = TimerPhase.done;
      _timer?.cancel();
      if (PlatformService.supportsHapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      _voice.announceWorkoutComplete(widget.workout.name, _elapsedSeconds);
      _audio.playSuccessChime();
      _onWorkoutDone();
    }
  }

  void _onWorkoutDone() {
    if (_completionRecorded) return;
    _completionRecorded = true;
    _background.stopWorkout();
    widget.onComplete(
      WorkoutHistory(
        workoutName: widget.workout.name,
        date: DateTime.now(),
        durationSeconds: _elapsedSeconds,
        roundsCompleted: _currentRound,
        emoji: widget.workout.emoji,
      ),
    );
  }

  void _saveProgressAndExit() {
    _timer?.cancel();
    _elapsedTimer?.cancel();
    _onWorkoutDone();
    if (mounted) {
      Navigator.maybePop(context);
    }
  }

  void _updateBackgroundNotification() {
    // Only update notification when app is in background
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      final timeStr =
          '${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';
      _background.updateNotification(
        phase: _phaseLabel,
        timeRemaining: timeStr,
        round: _currentRound,
        totalRounds: widget.workout.rounds,
        isPaused: _paused,
      );
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (PlatformService.supportsHapticFeedback) {
      HapticFeedback.selectionClick();
    }
    if (_paused) {
      _voice.announcePaused();
    } else {
      _voice.announceResumed();
      _ringCtrl.forward(from: 0);
    }
    // Update notification immediately to reflect pause state
    _updateBackgroundNotification();
  }

  void _skip() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Skip current phase?',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        content: Text(
          _skipMessage,
          style: const TextStyle(color: _muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _muted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (PlatformService.supportsHapticFeedback) {
                HapticFeedback.mediumImpact();
              }
              setState(() {
                _secondsLeft = 1;
                _advance();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _phaseColor,
              foregroundColor: _surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Skip phase'),
          ),
        ],
      ),
    );
  }

  void _end() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'End workout?',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Your progress will be saved.',
          style: TextStyle(color: _muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _muted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveProgressAndExit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _dangerColor,
              foregroundColor: _surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('End workout'),
          ),
        ],
      ),
    );
  }

  int get _totalPhaseDuration {
    switch (_phase) {
      case TimerPhase.countdown:
        return 3;
      case TimerPhase.work:
        return widget.workout.sets[_currentSet].durationSeconds;
      case TimerPhase.rest:
        return widget.workout.sets[_currentSet].breakSeconds;
      case TimerPhase.roundBreak:
        return widget.workout.roundBreakSeconds;
      case TimerPhase.done:
        return 1;
    }
  }

  double get _progress {
    if (_phase == TimerPhase.done) return 1.0;
    final total = _totalPhaseDuration;
    if (total <= 0) return 1.0;
    return 1.0 - (_secondsLeft / total);
  }

  Color get _phaseColor {
    switch (_phase) {
      case TimerPhase.countdown:
        return _countdownColor;
      case TimerPhase.work:
        return _workColor;
      case TimerPhase.rest:
        return _restColor;
      case TimerPhase.roundBreak:
        return _breakColor;
      case TimerPhase.done:
        return _workColor;
    }
  }

  String get _phaseLabel {
    switch (_phase) {
      case TimerPhase.countdown:
        return 'Get ready';
      case TimerPhase.work:
        return 'Work';
      case TimerPhase.rest:
        return 'Rest';
      case TimerPhase.roundBreak:
        return 'Round break';
      case TimerPhase.done:
        return 'Done';
    }
  }

  IconData get _phaseIcon {
    switch (_phase) {
      case TimerPhase.countdown:
        return Icons.timer_rounded;
      case TimerPhase.work:
        return Icons.fitness_center_rounded;
      case TimerPhase.rest:
        return Icons.coffee_rounded;
      case TimerPhase.roundBreak:
        return Icons.flag_rounded;
      case TimerPhase.done:
        return Icons.check_circle_rounded;
    }
  }

  String get _currentSetLabel {
    final set = widget.workout.sets[_currentSet];
    return set.name.isNotEmpty ? set.name : 'Set ${_currentSet + 1}';
  }

  String get _phaseSubtitle {
    switch (_phase) {
      case TimerPhase.countdown:
        return 'Starts with $_currentSetLabel';
      case TimerPhase.work:
        return _secondsLeft > 5 ? _getMotivationalTip() : _currentSetLabel;
      case TimerPhase.rest:
        return 'Recover before the next set';
      case TimerPhase.roundBreak:
        return _currentRound < widget.workout.rounds
            ? 'Round ${_currentRound + 1} starts next'
            : 'Final round complete';
      case TimerPhase.done:
        return 'Workout complete';
    }
  }

  String get _timerDetailText {
    switch (_phase) {
      case TimerPhase.countdown:
        return 'Starting soon';
      case TimerPhase.work:
        return _currentSetLabel;
      case TimerPhase.rest:
        return 'Recovery';
      case TimerPhase.roundBreak:
        return 'Next round';
      case TimerPhase.done:
        return 'Complete';
    }
  }

  String get _timeText => _phase == TimerPhase.countdown
      ? '$_secondsLeft'
      : _formatClock(_secondsLeft);

  String get _skipMessage {
    if (_phase == TimerPhase.work) {
      final breakTime = widget.workout.sets[_currentSet].breakSeconds;
      return breakTime > 0
          ? 'Move directly to the ${_formatShortDuration(breakTime)} rest period.'
          : 'Move directly to the next set.';
    }
    if (_phase == TimerPhase.rest) {
      return 'Move directly to $_upNextLabel.';
    }
    return 'Move directly to the next phase.';
  }

  int get _totalSetCount => widget.workout.sets.length * widget.workout.rounds;

  int get _completedSetCount {
    final setsPerRound = widget.workout.sets.length;
    if (setsPerRound == 0) return 0;

    final completedBeforeRound = (_currentRound - 1) * setsPerRound;
    int completed;
    switch (_phase) {
      case TimerPhase.countdown:
        completed = 0;
        break;
      case TimerPhase.work:
        completed = completedBeforeRound + _currentSet;
        break;
      case TimerPhase.rest:
        completed = completedBeforeRound + _currentSet + 1;
        break;
      case TimerPhase.roundBreak:
        completed = _currentRound * setsPerRound;
        break;
      case TimerPhase.done:
        completed = _totalSetCount;
        break;
    }

    return completed.clamp(0, _totalSetCount).toInt();
  }

  String get _upNextLabel {
    if (_phase == TimerPhase.countdown) return _currentSetLabel;

    if (_phase == TimerPhase.work) {
      final breakTime = widget.workout.sets[_currentSet].breakSeconds;
      if (breakTime > 0) return 'Rest ${_formatShortDuration(breakTime)}';
      return _nextSetOrRoundLabel;
    }

    if (_phase == TimerPhase.rest) return _nextSetOrRoundLabel;
    if (_phase == TimerPhase.roundBreak) return 'Round ${_currentRound + 1}';
    return 'Home';
  }

  String get _nextSetOrRoundLabel {
    if (_currentSet < widget.workout.sets.length - 1) {
      final nextSet = widget.workout.sets[_currentSet + 1];
      return nextSet.name.isNotEmpty ? nextSet.name : 'Set ${_currentSet + 2}';
    }
    if (_currentRound < widget.workout.rounds) {
      final roundBreak = widget.workout.roundBreakSeconds;
      return roundBreak > 0
          ? 'Round break ${_formatShortDuration(roundBreak)}'
          : 'Round ${_currentRound + 1}';
    }
    return 'Finish workout';
  }

  String _formatClock(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final mins = safeSeconds ~/ 60;
    final secs = safeSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _formatShortDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
    if (mins > 0) return '${mins}m';
    return '${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return WithForegroundTask(
      child: Scaffold(
        backgroundColor: _screenBg,
        body: SafeArea(
          child: _phase == TimerPhase.done
              ? _buildDoneScreen()
              : isWide
              ? _buildWideLayout()
              : _buildNarrowLayout(),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout() => Column(
    children: [
      _buildTopBar(),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = max(0.0, constraints.maxHeight - 44);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPhaseLabel(),
                        const SizedBox(height: 18),
                        _buildTimerRing(),
                        const SizedBox(height: 18),
                        _buildRoundSetInfo(),
                        const SizedBox(height: 8),
                        _buildProgressBar(),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildControls(),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _buildWideLayout() => Column(
    children: [
      _buildTopBar(),
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24,right: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: max(0.0, constraints.maxHeight - 48),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPhaseLabel(),
                        const SizedBox(height: 20),
                        _buildTimerRing(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRoundSetInfo(),
                        const SizedBox(height: 16),
                        _buildProgressBar(),
                        const SizedBox(height: 28),
                        _buildControls(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _surfaceDecoration(),
      child: Row(
        children: [
          _topEndButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.workout.name,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          _topIconButton(
            icon: _voiceEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            color: _restColor,
            active: _voiceEnabled,
            tooltip: _voiceEnabled ? 'Mute voice' : 'Unmute voice',
            onTap: () => setState(() {
              _voiceEnabled = !_voiceEnabled;
              _voice.setEnabled(_voiceEnabled);
            }),
          ),
          const SizedBox(width: 8),
          _topIconButton(
            icon: _soundEnabled
                ? Icons.notifications_active_rounded
                : Icons.notifications_off_rounded,
            color: _workColor,
            active: _soundEnabled,
            tooltip: _soundEnabled ? 'Mute sounds' : 'Unmute sounds',
            onTap: () => setState(() {
              _soundEnabled = !_soundEnabled;
              _audio.setEnabled(_soundEnabled);
            }),
          ),
        ],
      ),
    ),
  );

  Widget _topEndButton() => ModernTooltip(
    message: 'End workout',
    child: GestureDetector(
      onTap: _end,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _dangerColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _dangerColor.withValues(alpha: 0.18)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close_rounded, color: _dangerColor, size: 19),
            SizedBox(width: 4),
            Text(
              'End',
              style: TextStyle(
                color: _dangerColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _topIconButton({
    required IconData icon,
    required Color color,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) => ModernTooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : _surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.18) : _line,
          ),
        ),
        child: Icon(icon, color: active ? color : _subtleText, size: 21),
      ),
    ),
  );

  Widget _buildPhaseLabel() => FadeTransition(
    opacity: _phaseFade,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _phaseColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _phaseColor.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_phaseIcon, size: 17, color: _phaseColor),
                const SizedBox(width: 8),
                Text(
                  _phaseLabel,
                  style: TextStyle(
                    color: _phaseColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _phaseSubtitle,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  String _getMotivationalTip() {
    final tips = [
      'Keep your core engaged',
      'Focus on your breathing',
      'Maintain proper form',
      'You\'ve got this!',
      'Stay strong',
      'Push through',
      'Almost there',
      'Feel the burn',
    ];
    return tips[(_currentSet + _currentRound) % tips.length];
  }

  Widget _buildTimerRing() {
    final mediaSize = MediaQuery.of(context).size;
    final rawSize = min(
      min(mediaSize.width * 0.76, mediaSize.height * 0.42),
      330.0,
    );
    final ringSize = rawSize.clamp(210.0, 330.0).toDouble();

    return ScaleTransition(
      scale: _pulseAnim,
      child: SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: _surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: Size(ringSize, ringSize),
              painter: _RingPainter(
                progress: _progress,
                color: _phaseColor,
                bgColor: _line,
                strokeWidth: 10,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _phase == TimerPhase.countdown ? 'Seconds' : 'Remaining',
                  style: const TextStyle(
                    color: _subtleText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: SizedBox(
                    key: ValueKey('${_phase.name}-$_secondsLeft'),
                    width: ringSize * 0.68,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _timeText,
                        style: TextStyle(
                          color: _ink,
                          fontSize: _phase == TimerPhase.countdown ? 80 : 64,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _paused
                      ? _smallStatusPill('Paused', _muted)
                      : SizedBox(
                          key: ValueKey(_timerDetailText),
                          width: ringSize * 0.62,
                          child: Text(
                            _timerDetailText,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallStatusPill(String label, Color color) => Container(
    key: ValueKey(label),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );

  Widget _buildRoundSetInfo() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: _surfaceDecoration(),
      child: Row(
        children: [
          _infoBlock(
            'Round',
            '$_currentRound / ${widget.workout.rounds}',
            _breakColor,
          ),
          _infoDivider(),
          _infoBlock(
            'Set',
            _phase == TimerPhase.work || _phase == TimerPhase.rest
                ? '${_currentSet + 1} / ${widget.workout.sets.length}'
                : '-',
            _restColor,
          ),
          _infoDivider(),
          _infoBlock('Elapsed', _formatClock(_elapsedSeconds), _workColor),
        ],
      ),
    ),
  );

  Widget _infoDivider() => Container(width: 1, height: 42, color: _line);

  Widget _infoBlock(String label, String value, Color color) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );

  Widget _buildProgressBar() {
    final totalSets = _totalSetCount;
    final completedSets = _completedSetCount;
    final overallProgress = totalSets > 0 ? completedSets / totalSets : 0.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 8),
        decoration: _surfaceDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Workout progress',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${(overallProgress * 100).round()}%',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: overallProgress.clamp(0.0, 1.0),
                backgroundColor: _surfaceMuted,
                valueColor: AlwaysStoppedAnimation(_phaseColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.next_plan_rounded, color: _phaseColor, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Up next: $_upNextLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _controlBtn(
                icon: Icons.stop_rounded,
                label: 'End',
                color: _dangerColor,
                tooltip: 'End workout',
                onTap: _end,
                compact: compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _controlBtn(
                icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: _paused ? 'Resume' : 'Pause',
                color: _phaseColor,
                tooltip: _paused ? 'Resume timer' : 'Pause timer',
                onTap: _togglePause,
                primary: true,
                compact: compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _controlBtn(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                color: _muted,
                tooltip: 'Skip phase',
                onTap: _skip,
                compact: compact,
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    bool primary = false,
    bool compact = false,
  }) => ModernTooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: primary ? 64 : 58,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: primary ? color : _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primary ? color : _line),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: primary ? _surface : color,
                    size: primary ? 25 : 21,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary ? _surface : color,
                      fontSize: primary ? 13 : 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: primary ? _surface : color,
                    size: primary ? 25 : 21,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primary ? _surface : color,
                        fontSize: primary ? 16 : 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _buildDoneScreen() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (_, v, child) {
        final opacity = v.clamp(0.0, 1.0);
        final scale = v.clamp(0.88, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.workout.emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 22),
              const Text(
                'Workout complete',
                style: TextStyle(
                  color: _ink,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  widget.workout.name,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _doneStatCard(
                    'Rounds',
                    '${widget.workout.rounds}',
                    _breakColor,
                  ),
                  _doneStatCard(
                    'Time',
                    _formatClock(_elapsedSeconds),
                    _workColor,
                  ),
                  _doneStatCard('Sets', '$_totalSetCount', _restColor),
                ],
              ),
              const SizedBox(height: 36),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Back to Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _workColor,
                      foregroundColor: _surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _doneStatCard(String label, String value, Color color) => Container(
    width: 116,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  BoxDecoration _surfaceDecoration() => BoxDecoration(
    color: _surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _line),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = bgColor;

    canvas.drawCircle(center, radius, basePaint);

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 60; i++) {
      final angle = -pi / 2 + (2 * pi * i / 60);
      final isMajorTick = i % 5 == 0;
      final tickStart = radius - (isMajorTick ? 18 : 10);
      final tickEnd = radius - 3;
      final direction = Offset(cos(angle), sin(angle));

      tickPaint
        ..strokeWidth = isMajorTick ? 2.4 : 1.2
        ..color = isMajorTick
            ? color.withValues(alpha: 0.34)
            : bgColor.withValues(alpha: 0.82);

      canvas.drawLine(
        center + direction * tickStart,
        center + direction * tickEnd,
        tickPaint,
      );
    }

    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress > 0.001) {
      final sweepAngle = 2 * pi * clampedProgress;
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = bgColor.withValues(alpha: 0.9);
    canvas.drawCircle(center, radius - 30, innerPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.bgColor != bgColor ||
      old.strokeWidth != strokeWidth;
}
