import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_model.dart';
import '../widgets/battery_optimization_dialog.dart';
import 'live_timer_screen.dart';
import 'workout_builder_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class _HomeColors {
  static const bg = Color(0xFFF7F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF0F4F8);
  static const line = Color(0xFFD9E2EC);
  static const ink = Color(0xFF182235);
  static const muted = Color(0xFF66768A);
  static const subtle = Color(0xFF94A3B8);
  static const primary = Color(0xFF2F7D5A);
  static const blue = Color(0xFF2F6690);
  static const amber = Color(0xFFB7791F);
  static const purple = Color(0xFF6B5EAE);
  static const rose = Color(0xFF9B5270);
  static const danger = Color(0xFFB42318);
}

BoxDecoration _homeSurfaceDecoration({
  Color borderColor = _HomeColors.line,
  double shadowOpacity = 0.04,
}) => BoxDecoration(
  color: _HomeColors.surface,
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: borderColor),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: shadowOpacity),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ],
);

class HomeScreen extends StatefulWidget {
  final List<WorkoutHistory> history;
  final List<Workout> customWorkouts;
  final void Function(WorkoutHistory) onWorkoutComplete;
  final void Function(Workout) onSaveWorkout;
  final void Function(String) onDeleteWorkout;

  const HomeScreen({
    super.key,
    required this.history,
    required this.customWorkouts,
    required this.onWorkoutComplete,
    required this.onSaveWorkout,
    required this.onDeleteWorkout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  String _selectedCategory = 'All';
  int _navIndex = 0;

  final _categories = [
    'All',
    'HIIT',
    'Tabata',
    'Circuit',
    'Beginner',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
    _showFirstTimeHelp();
  }

  void _showFirstTimeHelp() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('first_time_help') ?? false;
    if (!shown && mounted) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showHomeSnackBar('Tap a workout to review it before starting.');
          prefs.setBool('first_time_help', true);
        }
      });
    }
  }

  void _showHomeSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_rounded, color: _HomeColors.blue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _HomeColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _HomeColors.surface,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _HomeColors.line),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  List<Workout> get _allWorkouts => [
    ...predefinedWorkouts,
    ...widget.customWorkouts,
  ];

  List<Workout> get _filteredWorkouts {
    if (_selectedCategory == 'All') return _allWorkouts;
    if (_selectedCategory == 'Custom') return widget.customWorkouts;
    return _allWorkouts
        .where((workout) => workout.category == _selectedCategory)
        .toList();
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _HomeColors.surface,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _HomeColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _HomeColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _HomeColors.blue.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: _HomeColors.blue,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Athlete',
                style: TextStyle(
                  color: _HomeColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.history.length} workouts completed',
                style: const TextStyle(color: _HomeColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: _HomeColors.surfaceMuted,
                    foregroundColor: _HomeColors.ink,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startWorkout(Workout workout) {
    showDialog(
      context: context,
      builder: (_) => _HomeWorkoutPreviewDialog(
        workout: workout,
        onStart: () async {
          await BatteryOptimizationDialog.show(context);

          if (!mounted) return;

          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, a, b) => LiveTimerScreen(
                workout: workout,
                onComplete: widget.onWorkoutComplete,
              ),
              transitionsBuilder: (_, a, b, child) => SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(
                      CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
                    ),
                child: child,
              ),
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        },
      ),
    );
  }

  void _openBuilder({Workout? workout}) async {
    final result = await Navigator.push<Workout>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, b) => WorkoutBuilderScreen(workout: workout),
        transitionsBuilder: (_, a, b, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    if (result != null) widget.onSaveWorkout(result);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;

    return Scaffold(
      backgroundColor: _HomeColors.bg,
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildHomeTab(isWide),
          WorkoutBuilderScreen(
            key: ValueKey(_navIndex),
            onSave: widget.onSaveWorkout,
            embedded: true,
          ),
          HistoryScreen(history: widget.history),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
      floatingActionButton: _navIndex == 0
          ? _HomeTooltip(
              message: 'Create workout',
              child: FloatingActionButton.extended(
                onPressed: () => _openBuilder(),
                backgroundColor: _HomeColors.primary,
                foregroundColor: _HomeColors.surface,
                elevation: 3,
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'New workout',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildNavBar() => Container(
    decoration: BoxDecoration(
      color: _HomeColors.surface,
      border: const Border(top: BorderSide(color: _HomeColors.line)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, -6),
        ),
      ],
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(0, Icons.home_rounded, 'Home'),
            _navItem(1, Icons.fitness_center_rounded, 'Builder'),
            _navItem(2, Icons.history_rounded, 'History'),
            _navItem(3, Icons.settings_rounded, 'Settings'),
          ],
        ),
      ),
    ),
  );

  Widget _navItem(int index, IconData icon, String label) {
    final active = _navIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _navIndex = index;
            if (index == 0) _selectedCategory = 'All';
          });
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? _HomeColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: _HomeColors.primary.withValues(alpha: 0.18))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: active ? _HomeColors.primary : _HomeColors.muted,
                size: 23,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? _HomeColors.primary : _HomeColors.muted,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(bool isWide) {
    final filtered = _filteredWorkouts;
    final hasAnyWorkouts = _allWorkouts.isNotEmpty;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(),
        SliverToBoxAdapter(child: _buildStatsRow()),
        if (hasAnyWorkouts) SliverToBoxAdapter(child: _buildQuickStart()),
        if (hasAnyWorkouts) SliverToBoxAdapter(child: _buildCategoryFilter()),
        if (hasAnyWorkouts)
          SliverToBoxAdapter(child: _buildWorkoutsHeading(filtered.length)),
        if (filtered.isNotEmpty)
          isWide ? _buildWorkoutGrid(filtered) : _buildWorkoutList(filtered)
        else
          SliverFillRemaining(
            hasScrollBody: false,
            child: _HomeEmptyState(
              icon: Icons.fitness_center_rounded,
              title: _selectedCategory == 'All'
                  ? 'No workouts yet'
                  : 'No $_selectedCategory workouts',
              subtitle: _selectedCategory == 'Custom'
                  ? 'Create a custom workout to see it here.'
                  : 'Try another category or create your own workout.',
              actionLabel: 'Create Workout',
              onAction: () => _openBuilder(),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildSliverHeader() => SliverToBoxAdapter(
    child: FadeTransition(
      opacity: _headerFade,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 18,
          20,
          14,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _HomeColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _HomeColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        color: _HomeColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ready to Train?',
                      style: TextStyle(
                        color: _HomeColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _headerSubtitle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _HomeColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                children: [
                  _HeaderIconButton(
                    icon: Icons.person_rounded,
                    color: _HomeColors.blue,
                    tooltip: 'Profile',
                    onTap: _showProfileSheet,
                  ),
                  const SizedBox(height: 10),
                  _HeaderIconButton(
                    icon: Icons.add_rounded,
                    color: _HomeColors.primary,
                    tooltip: 'Create workout',
                    onTap: () => _openBuilder(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _headerSubtitle() {
    if (widget.history.isEmpty) {
      return 'Choose a workout and start your first session.';
    }
    final last = [...widget.history]..sort((a, b) => b.date.compareTo(a.date));
    return 'Last session: ${last.first.workoutName}';
  }

  Widget _buildStatsRow() {
    final totalWorkouts = widget.history.length;
    final totalMins =
        widget.history.fold<int>(
          0,
          (sum, item) => sum + item.durationSeconds,
        ) ~/
        60;
    final streak = _calculateStreak();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final stats = [
            _DashboardStat(
              value: '$totalWorkouts',
              label: 'Workouts',
              icon: Icons.fitness_center_rounded,
              color: _HomeColors.blue,
            ),
            _DashboardStat(
              value: '${totalMins}m',
              label: 'Total Time',
              icon: Icons.timer_rounded,
              color: _HomeColors.primary,
            ),
            _DashboardStat(
              value: '$streak\u{1F525}',
              label: 'Streak',
              icon: Icons.local_fire_department_rounded,
              color: _HomeColors.amber,
            ),
          ];

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: stats[0]),
                    const SizedBox(width: 10),
                    Expanded(child: stats[1]),
                  ],
                ),
                const SizedBox(height: 10),
                stats[2],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: stats[0]),
              const SizedBox(width: 10),
              Expanded(child: stats[1]),
              const SizedBox(width: 10),
              Expanded(child: stats[2]),
            ],
          );
        },
      ),
    );
  }

  int _calculateStreak() {
    if (widget.history.isEmpty) return 0;
    final uniqueDays = <DateTime>{};
    for (final item in widget.history) {
      uniqueDays.add(DateTime(item.date.year, item.date.month, item.date.day));
    }

    final sorted = uniqueDays.toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    DateTime check = DateTime.now();

    for (final day in sorted) {
      final normalizedCheck = DateTime(check.year, check.month, check.day);
      final diff = normalizedCheck.difference(day).inDays;
      if (diff <= 1) {
        streak++;
        check = day;
      } else {
        break;
      }
    }
    return streak;
  }

  Widget _buildQuickStart() {
    final allWorkouts = _allWorkouts;
    if (allWorkouts.isEmpty) return const SizedBox.shrink();
    final quickWorkout = _quickWorkout(allWorkouts);
    final color = _getCategoryColor(quickWorkout.category);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startWorkout(quickWorkout),
          borderRadius: BorderRadius.circular(8),
          splashColor: color.withValues(alpha: 0.1),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _HomeColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final dial = _MiniWorkoutDial(
                  workout: quickWorkout,
                  color: color,
                  size: compact ? 96 : 116,
                );
                final details = Column(
                  crossAxisAlignment: compact
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    _TinyLabel(
                      label: 'Quick Start',
                      color: color,
                      icon: Icons.flash_on_rounded,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quickWorkout.name,
                      textAlign: compact ? TextAlign.center : TextAlign.start,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _HomeColors.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: compact
                          ? WrapAlignment.center
                          : WrapAlignment.start,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: Icons.repeat_rounded,
                          text: '${quickWorkout.rounds} rounds',
                          color: _HomeColors.amber,
                        ),
                        _InfoPill(
                          icon: Icons.layers_rounded,
                          text: '${quickWorkout.sets.length} sets',
                          color: _HomeColors.primary,
                        ),
                        _InfoPill(
                          icon: Icons.timer_rounded,
                          text: quickWorkout.totalDuration,
                          color: _HomeColors.blue,
                        ),
                      ],
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    children: [
                      dial,
                      const SizedBox(height: 14),
                      details,
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              label: 'Edit',
                              icon: Icons.edit_rounded,
                              color: _HomeColors.blue,
                              filled: false,
                              onTap: () => _openBuilder(workout: quickWorkout),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionButton(
                              label: 'Start',
                              icon: Icons.play_arrow_rounded,
                              color: color,
                              onTap: () => _startWorkout(quickWorkout),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    dial,
                    const SizedBox(width: 18),
                    Expanded(child: details),
                    const SizedBox(width: 14),
                    Column(
                      children: [
                        _SquareAction(
                          icon: Icons.edit_rounded,
                          color: _HomeColors.blue,
                          tooltip: 'Edit workout',
                          filled: false,
                          onTap: () => _openBuilder(workout: quickWorkout),
                        ),
                        const SizedBox(height: 10),
                        _SquareAction(
                          icon: Icons.play_arrow_rounded,
                          color: color,
                          tooltip: 'Start workout',
                          onTap: () => _startWorkout(quickWorkout),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Workout _quickWorkout(List<Workout> allWorkouts) {
    if (widget.history.isEmpty) return allWorkouts.first;
    final recent = [...widget.history]
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final workout in allWorkouts) {
      if (workout.name == recent.first.workoutName) return workout;
    }
    return allWorkouts.first;
  }

  Widget _buildCategoryFilter() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => _CategoryButton(
          label: _categories[index],
          selected: _selectedCategory == _categories[index],
          color: _getCategoryColor(_categories[index]),
          icon: _categoryIcon(_categories[index]),
          onTap: () => setState(() => _selectedCategory = _categories[index]),
        ),
      ),
    ),
  );

  Widget _buildWorkoutsHeading(int count) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _selectedCategory == 'All' ? 'Workouts' : _selectedCategory,
            style: const TextStyle(
              color: _HomeColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _HomeColors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _HomeColors.blue.withValues(alpha: 0.18)),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _HomeColors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (_selectedCategory != 'All') ...[
          const SizedBox(width: 8),
          _ClearFilterButton(
            onTap: () => setState(() => _selectedCategory = 'All'),
          ),
        ],
      ],
    ),
  );

  Widget _buildWorkoutList(List<Workout> workouts) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    sliver: SliverList.separated(
      itemCount: workouts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _WorkoutCard(
        workout: workouts[index],
        onStart: () => _startWorkout(workouts[index]),
        onEdit: () => _openBuilder(workout: workouts[index]),
        onDelete: widget.customWorkouts.contains(workouts[index])
            ? () => widget.onDeleteWorkout(workouts[index].id)
            : null,
        index: index,
      ),
    ),
  );

  Widget _buildWorkoutGrid(List<Workout> workouts) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _WorkoutCard(
          workout: workouts[index],
          onStart: () => _startWorkout(workouts[index]),
          onEdit: () => _openBuilder(workout: workouts[index]),
          onDelete: widget.customWorkouts.contains(workouts[index])
              ? () => widget.onDeleteWorkout(workouts[index].id)
              : null,
          index: index,
          grid: true,
        ),
        childCount: workouts.length,
      ),
    ),
  );

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'All':
        return Icons.all_inclusive_rounded;
      case 'HIIT':
        return Icons.local_fire_department_rounded;
      case 'Tabata':
        return Icons.bolt_rounded;
      case 'Circuit':
        return Icons.sync_rounded;
      case 'Beginner':
        return Icons.star_rounded;
      case 'Custom':
        return Icons.add_circle_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'HIIT':
        return _HomeColors.amber;
      case 'Tabata':
        return _HomeColors.purple;
      case 'Circuit':
        return _HomeColors.primary;
      case 'Beginner':
        return _HomeColors.blue;
      case 'Custom':
        return _HomeColors.rose;
      default:
        return _HomeColors.blue;
    }
  }
}

class _WorkoutCard extends StatefulWidget {
  final Workout workout;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final int index;
  final bool grid;

  const _WorkoutCard({
    required this.workout,
    required this.onStart,
    required this.onEdit,
    this.onDelete,
    required this.index,
    this.grid = false,
  });

  @override
  State<_WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<_WorkoutCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 360 + widget.index * 60),
    );
    _slide = Tween(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 45), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(widget.workout.category);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onStart,
            borderRadius: BorderRadius.circular(8),
            splashColor: color.withValues(alpha: 0.1),
            child: Ink(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _HomeColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _HomeColors.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 310;
                  if (compact || widget.grid) {
                    return _buildStacked(color);
                  }
                  return _buildRow(color);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(Color color) => Row(
    children: [
      _MiniWorkoutDial(workout: widget.workout, color: color, size: 82),
      const SizedBox(width: 14),
      Expanded(child: _buildDetails(color, center: false)),
      const SizedBox(width: 12),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SquareAction(
            icon: Icons.play_arrow_rounded,
            color: color,
            tooltip: 'Start workout',
            onTap: widget.onStart,
          ),
          const SizedBox(height: 8),
          _SquareAction(
            icon: Icons.more_horiz_rounded,
            color: _HomeColors.muted,
            tooltip: 'Workout options',
            filled: false,
            onTap: () => _showOptions(context),
          ),
        ],
      ),
    ],
  );

  Widget _buildStacked(Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _MiniWorkoutDial(workout: widget.workout, color: color, size: 70),
          const SizedBox(width: 12),
          Expanded(child: _buildDetails(color, center: false, tight: true)),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Start',
              icon: Icons.play_arrow_rounded,
              color: color,
              onTap: widget.onStart,
            ),
          ),
          const SizedBox(width: 8),
          _SquareAction(
            icon: Icons.more_horiz_rounded,
            color: _HomeColors.muted,
            tooltip: 'Workout options',
            filled: false,
            onTap: () => _showOptions(context),
          ),
        ],
      ),
    ],
  );

  Widget _buildDetails(
    Color color, {
    required bool center,
    bool tight = false,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        widget.workout.name,
        textAlign: center ? TextAlign.center : TextAlign.start,
        maxLines: tight ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _HomeColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          height: 1.12,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        alignment: center ? WrapAlignment.center : WrapAlignment.start,
        spacing: 6,
        runSpacing: 6,
        children: [
          _InfoPill(
            icon: Icons.category_rounded,
            text: widget.workout.category,
            color: color,
          ),
          _InfoPill(
            icon: Icons.trending_up_rounded,
            text: widget.workout.difficulty,
            color: widget.workout.difficultyColor,
          ),
        ],
      ),
      if (!tight) ...[
        const SizedBox(height: 8),
        Wrap(
          alignment: center ? WrapAlignment.center : WrapAlignment.start,
          spacing: 10,
          runSpacing: 6,
          children: [
            _MetaText(
              icon: Icons.repeat_rounded,
              text: '${widget.workout.rounds}R',
            ),
            _MetaText(
              icon: Icons.layers_rounded,
              text: '${widget.workout.sets.length}S',
            ),
            _MetaText(
              icon: Icons.timer_rounded,
              text: widget.workout.totalDuration,
            ),
          ],
        ),
      ],
    ],
  );

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _HomeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _HomeColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.play_arrow_rounded,
                color: _HomeColors.primary,
              ),
              title: const Text(
                'Start workout',
                style: TextStyle(color: _HomeColors.ink),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                Future.delayed(
                  const Duration(milliseconds: 180),
                  widget.onStart,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: _HomeColors.blue),
              title: const Text(
                'Edit workout',
                style: TextStyle(color: _HomeColors.ink),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                Future.delayed(
                  const Duration(milliseconds: 180),
                  widget.onEdit,
                );
              },
            ),
            if (widget.onDelete != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_rounded,
                  color: _HomeColors.danger,
                ),
                title: const Text(
                  'Delete workout',
                  style: TextStyle(color: _HomeColors.danger),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _HomeColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Delete workout?',
          style: TextStyle(color: _HomeColors.ink, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.workout.name}"? This action cannot be undone.',
          style: const TextStyle(color: _HomeColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: _HomeColors.muted),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (widget.onDelete != null) {
                widget.onDelete!();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: _HomeColors.primary,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Workout deleted',
                          style: TextStyle(color: _HomeColors.ink),
                        ),
                      ],
                    ),
                    backgroundColor: _HomeColors.surface,
                    behavior: SnackBarBehavior.floating,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: _HomeColors.line),
                    ),
                    margin: const EdgeInsets.all(16),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _HomeColors.danger,
              foregroundColor: _HomeColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'HIIT':
        return _HomeColors.amber;
      case 'Tabata':
        return _HomeColors.purple;
      case 'Circuit':
        return _HomeColors.primary;
      case 'Beginner':
        return _HomeColors.blue;
      case 'Custom':
        return _HomeColors.rose;
      default:
        return _HomeColors.blue;
    }
  }
}

class _DashboardStat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _DashboardStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: _homeSurfaceDecoration(shadowOpacity: 0.03),
    child: Row(
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: CustomPaint(
            painter: _StatRingPainter(color: color),
            child: Icon(icon, color: color, size: 19),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _HomeColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _HomeColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MiniWorkoutDial extends StatelessWidget {
  final Workout workout;
  final Color color;
  final double size;

  const _MiniWorkoutDial({
    required this.workout,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: _WorkoutDialPainter(color: color),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(workout.emoji, style: TextStyle(fontSize: size * 0.24)),
            const SizedBox(height: 3),
            Text(
              workout.totalDuration,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _HomeColors.ink,
                fontSize: size * 0.1,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _WorkoutDialPainter extends CustomPainter {
  final Color color;

  const _WorkoutDialPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 7) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, base);

    for (int i = 0; i < 24; i++) {
      final angle = -math.pi / 2 + math.pi * 2 * i / 24;
      final major = i % 6 == 0;
      final startRadius = radius - (major ? 12 : 8);
      final endRadius = radius - 3;
      final tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = major ? 2.2 : 1.2
        ..strokeCap = StrokeCap.round
        ..color = major
            ? color.withValues(alpha: 0.55)
            : _HomeColors.subtle.withValues(alpha: 0.32);
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * startRadius,
        center + Offset(math.cos(angle), math.sin(angle)) * endRadius,
        tickPaint,
      );
    }

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.45,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_WorkoutDialPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _StatRingPainter extends CustomPainter {
  final Color color;

  const _StatRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 5) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.16);
    canvas.drawCircle(center, radius, paint);
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.55,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_StatRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _HomeTooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Icon(icon, color: color, size: 23),
      ),
    ),
  );
}

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool filled;
  final VoidCallback onTap;

  const _SquareAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) => _HomeTooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: filled ? color : _HomeColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: filled ? color : _HomeColors.line),
        ),
        child: Icon(
          icon,
          color: filled ? _HomeColors.surface : color,
          size: 21,
        ),
      ),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: filled ? color : _HomeColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: filled ? color : _HomeColors.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: filled ? _HomeColors.surface : color, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: filled ? _HomeColors.surface : color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : _HomeColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.32) : _HomeColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? color : _HomeColors.muted, size: 16),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: selected ? color : _HomeColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClearFilterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearFilterButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _HomeColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _HomeColors.line),
      ),
      child: const Icon(
        Icons.close_rounded,
        color: _HomeColors.muted,
        size: 18,
      ),
    ),
  );
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _HomeColors.muted, size: 14),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(
          color: _HomeColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _TinyLabel extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _TinyLabel({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _HomeEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _HomeEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: _homeSurfaceDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _HomeColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _HomeColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(icon, color: _HomeColors.primary, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _HomeColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _HomeColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  label: actionLabel,
                  icon: Icons.add_rounded,
                  color: _HomeColors.primary,
                  onTap: onAction,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _HomeWorkoutPreviewDialog extends StatelessWidget {
  final Workout workout;
  final VoidCallback onStart;

  const _HomeWorkoutPreviewDialog({
    required this.workout,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(workout.category);
    final previewSets = workout.sets.take(3).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _homeSurfaceDecoration(
              borderColor: color.withValues(alpha: 0.24),
              shadowOpacity: 0.08,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MiniWorkoutDial(workout: workout, color: color, size: 92),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TinyLabel(
                            label: 'Review Workout',
                            color: color,
                            icon: Icons.visibility_rounded,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            workout.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _HomeColors.ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _InfoPill(
                                icon: Icons.category_rounded,
                                text: workout.category,
                                color: color,
                              ),
                              _InfoPill(
                                icon: Icons.trending_up_rounded,
                                text: workout.difficulty,
                                color: _difficultyColor(workout.difficulty),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SquareAction(
                      icon: Icons.close_rounded,
                      color: _HomeColors.muted,
                      tooltip: 'Close preview',
                      filled: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _PreviewStat(
                        label: 'Rounds',
                        value: '${workout.rounds}',
                        icon: Icons.repeat_rounded,
                        color: _HomeColors.amber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PreviewStat(
                        label: 'Sets',
                        value: '${workout.sets.length}',
                        icon: Icons.layers_rounded,
                        color: _HomeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PreviewStat(
                        label: 'Time',
                        value: workout.totalDuration,
                        icon: Icons.timer_rounded,
                        color: _HomeColors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Session plan',
                  style: TextStyle(
                    color: _HomeColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (previewSets.isEmpty)
                  const Text(
                    'No sets configured yet.',
                    style: TextStyle(color: _HomeColors.muted),
                  )
                else
                  ...previewSets.asMap().entries.map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.key == previewSets.length - 1 ? 0 : 8,
                      ),
                      child: _PreviewSetTile(
                        index: entry.key + 1,
                        set: entry.value,
                        color: color,
                      ),
                    ),
                  ),
                if (workout.sets.length > previewSets.length) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${workout.sets.length - previewSets.length} more sets',
                    style: const TextStyle(
                      color: _HomeColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Cancel',
                        icon: Icons.close_rounded,
                        color: _HomeColors.muted,
                        filled: false,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _ActionButton(
                        label: 'Start Workout',
                        icon: Icons.play_arrow_rounded,
                        color: color,
                        onTap: () {
                          Navigator.pop(context);
                          Future.microtask(onStart);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'HIIT':
        return _HomeColors.amber;
      case 'Tabata':
        return _HomeColors.purple;
      case 'Circuit':
        return _HomeColors.primary;
      case 'Beginner':
        return _HomeColors.blue;
      case 'Custom':
        return _HomeColors.rose;
      default:
        return _HomeColors.blue;
    }
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Hard':
        return _HomeColors.danger;
      case 'Medium':
        return _HomeColors.amber;
      default:
        return _HomeColors.primary;
    }
  }
}

class _PreviewStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PreviewStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _HomeColors.ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _HomeColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _PreviewSetTile extends StatelessWidget {
  final int index;
  final WorkoutSet set;
  final Color color;

  const _PreviewSetTile({
    required this.index,
    required this.set,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final name = set.name.isNotEmpty ? set.name : 'Set $index';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _HomeColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _HomeColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _HomeColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatShort(set.durationSeconds)} work',
            style: const TextStyle(
              color: _HomeColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (set.breakSeconds > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${_formatShort(set.breakSeconds)} rest',
              style: const TextStyle(
                color: _HomeColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatShort(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0 && secs > 0) return '${mins}m ${secs}s';
    if (mins > 0) return '${mins}m';
    return '${secs}s';
  }
}

class _HomeTooltip extends StatelessWidget {
  final String message;
  final Widget child;

  const _HomeTooltip({required this.message, required this.child});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    decoration: BoxDecoration(
      color: _HomeColors.ink,
      borderRadius: BorderRadius.circular(8),
    ),
    textStyle: const TextStyle(
      color: _HomeColors.surface,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: child,
  );
}
