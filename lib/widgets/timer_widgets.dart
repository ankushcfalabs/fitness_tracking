import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CountdownAnimation extends StatefulWidget {
  final int seconds;
  final VoidCallback onComplete;

  const CountdownAnimation({
    super.key,
    required this.seconds,
    required this.onComplete,
  });

  @override
  State<CountdownAnimation> createState() => _CountdownAnimationState();
}

class _CountdownAnimationState extends State<CountdownAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            '${widget.seconds}',
            style: AppTypography.displayLarge.copyWith(
              color: AppColors.stateCountdown,
              fontSize: 120,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class CircularTimerProgress extends StatelessWidget {
  final double progress;
  final int secondsRemaining;
  final Color color;
  final double size;

  const CircularTimerProgress({
    super.key,
    required this.progress,
    required this.secondsRemaining,
    required this.color,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(secondsRemaining),
                style: AppTypography.displayLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: size * 0.25,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0) {
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }
    return '$secs';
  }
}
