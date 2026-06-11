import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/workout_model.dart';
import '../widgets/common_widgets.dart';

class HistoryScreen extends StatefulWidget {
  final List<WorkoutHistory> history;

  const HistoryScreen({super.key, required this.history});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getStatsText() {
    if (widget.history.isEmpty) return 'No workout data yet';

    final totalWorkouts = widget.history.length;
    final totalMinutes = widget.history.fold(0, (sum, h) => sum + h.durationSeconds) ~/ 60;
    final totalRounds = widget.history.fold(0, (sum, h) => sum + h.roundsCompleted);

    return '''Workout Statistics
━━━━━━━━━━━━━━━━━━━━
Total Workouts: $totalWorkouts
Total Time: ${totalMinutes}m
Total Rounds: $totalRounds

Workout History:
${widget.history.reversed.map((h) => '• ${h.workoutName} - ${h.formattedDuration} (${h.roundsCompleted} rounds) - ${_formatDate(h.date)}').join('\n')}''';
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  void _shareStats() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Share Statistics',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatsText(),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await Share.share(
                        _getStatsText(),
                        subject: 'My Fitness Workout Statistics',
                      );
                      if (!mounted) return;
                      Navigator.pop(context);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to share: $e'),
                          backgroundColor: AppColors.accentOrange,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.history]..sort((a, b) => b.date.compareTo(a.date));
    final filtered = _searchQuery.isEmpty
        ? sorted
        : sorted.where((h) => h.workoutName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.white, // Light background
      body: CustomScrollView(
        slivers: [
          // Header section
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Workout History',
                style: TextStyle(
                  color: AppColors.bg, // Darker text for contrast
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              titlePadding: EdgeInsets.only(
                left: 20,
                bottom: 16,
                right: 20,
              ),
            ),
            actions: [
              if (widget.history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    icon: const Icon(
                      Icons.share_rounded,
                      color: AppColors.accent,
                      size: 24,
                    ),
                    onPressed: _shareStats,
                  ),
                ),
            ],
          ),
          
          // Summary Cards Section
          if (sorted.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryCard(
                      title: 'Workouts',
                      value: widget.history.length.toString(),
                      icon: Icons.fitness_center_outlined,
                      color: Colors.blue[100]!,
                    ),
                    _buildSummaryCard(
                      title: 'Time',
                      value: '${(widget.history.fold(0, (sum, h) => sum + h.durationSeconds) ~/ 60)}m',
                      icon: Icons.timer_outlined,
                      color: Colors.green[100]!,
                    ),
                    _buildSummaryCard(
                      title: 'Rounds',
                      value: widget.history.fold(0, (sum, h) => sum + h.roundsCompleted).toString(),
                      icon: Icons.repeat_outlined,
                      color: Colors.purple[100]!,
                    ),
                  ],
                ),
              ),
            ),
          
          // Search Field
          if (sorted.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(color: AppColors.bg, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search workouts...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600], size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: Colors.grey[600], size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),
          
          // Empty States
          if (sorted.isEmpty)
            SliverFillRemaining(
              child: EmptyStateWidget(
                emoji: '🏃',
                title: 'No Workouts Yet',
                subtitle: 'Complete a workout to see it here',
              ),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: EmptyStateWidget(
                emoji: '🔍',
                title: 'No Results',
                subtitle: 'Try a different search term',
              ),
            )
          // History List
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _HistoryCard(history: filtered[i], index: i),
                childCount: filtered.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // Helper method to build summary cards
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.bg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final WorkoutHistory history;
  final int index;

  const _HistoryCard({required this.history, required this.index});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.index * 60),
    );
    _slide = Tween(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, // Light card background
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!), // Light border
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.blue[50], // Light accent background
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        widget.history.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.history.workoutName,
                          style: const TextStyle(
                            color: AppColors.bg, // Darker text
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                color: Colors.grey[600], size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatDate(widget.history.date)} · ${_formatTime(widget.history.date)}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.history.formattedDuration,
                        style: const TextStyle(
                          color: Colors.green, // Green for duration
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.history.roundsCompleted} rounds',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
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