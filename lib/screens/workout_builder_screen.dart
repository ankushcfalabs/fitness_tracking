import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workout_model.dart';
import '../widgets/common_widgets.dart';
import '../services/validation_service.dart';

class _BuilderColors {
  static const bg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEEF2F8);
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

class WorkoutBuilderScreen extends StatefulWidget {
  final Workout? workout;
  final void Function(Workout)? onSave;
  final bool embedded;

  const WorkoutBuilderScreen({
    super.key,
    this.workout,
    this.onSave,
    this.embedded = false,
  });

  @override
  State<WorkoutBuilderScreen> createState() => _WorkoutBuilderScreenState();
}

class _WorkoutBuilderScreenState extends State<WorkoutBuilderScreen> {
  late TextEditingController _nameCtrl;
  late int _rounds;
  late int _roundBreak;
  late List<WorkoutSet> _sets;
  late String _emoji;
  late String _category;

  final _emojis = ['💪', '🔥', '⚡', '🏋️', '🌟', '🚀', '🎯', '🏃', '🥊', '🧘'];
  final _categories = ['Custom', 'HIIT', 'Tabata', 'Circuit', 'Beginner'];

  @override
  void initState() {
    super.initState();
    final w = widget.workout;
    _nameCtrl = TextEditingController(text: w?.name ?? '');
    _rounds = w?.rounds ?? 3;
    _roundBreak = w?.roundBreakSeconds ?? 60;
    _sets =
        w?.sets.map((s) => s.copyWith()).toList() ??
        [const WorkoutSet(durationSeconds: 30, breakSeconds: 10)];
    _emoji = w?.emoji ?? '💪';
    _category = w?.category ?? 'Custom';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Workout get _previewWorkout => Workout(
    id: widget.workout?.id ?? 'preview',
    name: _nameCtrl.text.trim().isEmpty
        ? 'Your Workout'
        : _nameCtrl.text.trim(),
    category: _category,
    rounds: _rounds,
    sets: _sets,
    roundBreakSeconds: _roundBreak,
    emoji: _emoji,
  );

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) {
      ErrorSnackBar.show(context, 'Please enter a workout name');
      return;
    }
    if (_nameCtrl.text.trim().length > 30) {
      ErrorSnackBar.show(context, 'Workout name is too long (max 30 characters)');
      return;
    }
    if (_sets.isEmpty) {
      ErrorSnackBar.show(context, 'Please add at least one set');
      return;
    }
    if (_sets.length > 20) {
      ErrorSnackBar.show(context, 'Too many sets (max 20 sets)');
      return;
    }

    final workout = Workout(
      id: widget.workout?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      category: _category,
      rounds: _rounds,
      sets: _sets,
      roundBreakSeconds: _roundBreak,
      emoji: _emoji,
    );

    if (!ValidationService.isValidWorkout(workout)) {
      String errorMsg = 'Invalid workout configuration';
      if (_rounds < 1 || _rounds > 50) {
        errorMsg = 'Rounds must be between 1 and 50';
      } else if (_roundBreak < 0 || _roundBreak > 600) {
        errorMsg = 'Round break must be between 0 and 600 seconds';
      } else {
        for (int i = 0; i < _sets.length; i++) {
          final set = _sets[i];
          if (set.durationSeconds < 5 || set.durationSeconds > 7200) {
            errorMsg = 'Set ${i + 1}: Work time must be between 5 seconds and 2 hours';
            break;
          } else if (set.breakSeconds < 0 || set.breakSeconds > 7200) {
            errorMsg = 'Set ${i + 1}: Break time must be between 0 and 2 hours';
            break;
          } else if (set.name.length > 50) {
            errorMsg = 'Set ${i + 1}: Name is too long (max 50 characters)';
            break;
          }
        }
      }
      ErrorSnackBar.show(context, errorMsg);
      return;
    }

    final sanitizedWorkout = ValidationService.sanitizeWorkout(workout);

    if (widget.embedded && widget.onSave != null) {
      widget.onSave!(sanitizedWorkout);
      SuccessSnackBar.show(
        context,
        widget.workout == null ? 'Workout saved successfully!' : 'Workout updated successfully!',
      );
    } else {
      Navigator.pop(context, sanitizedWorkout);
      SuccessSnackBar.show(
        context,
        widget.workout == null ? 'Workout saved successfully!' : 'Workout updated successfully!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _BuilderColors.bg,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: _BuilderColors.bg,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              iconTheme: const IconThemeData(color: _BuilderColors.ink),
              title: Text(
                widget.workout == null ? 'New Workout' : 'Edit Workout',
                style: const TextStyle(
                  color: _BuilderColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _PrimaryButton(
                    label: 'Save',
                    icon: Icons.check_rounded,
                    onTap: _save,
                  ),
                ),
              ],
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      if (widget.embedded) SliverToBoxAdapter(child: _buildEmbeddedHeader()),
      SliverToBoxAdapter(child: _buildSummaryCard()),
      SliverToBoxAdapter(child: _buildDetailsSection()),
      SliverToBoxAdapter(child: _buildStructureSection()),
      SliverToBoxAdapter(child: _buildSetsSection()),
      const SliverToBoxAdapter(child: SizedBox(height: 120)),
    ],
  );

  // ---------- Embedded header ----------
  Widget _buildEmbeddedHeader() => Padding(
    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Builder',
                style: TextStyle(
                  color: _BuilderColors.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Design a timer-ready workout',
                style: TextStyle(color: _BuilderColors.muted, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        _PrimaryButton(label: 'Save', icon: Icons.check_rounded, onTap: _save),
      ],
    ),
  );

  // ---------- Summary card (combines watch preview + bottom summary) ----------
  Widget _buildSummaryCard() {
    final workout = _previewWorkout;
    final workSeconds = _sets.fold<int>(0, (sum, s) => sum + s.durationSeconds) * _rounds;
    final progress = workout.totalSeconds == 0 ? 0.0 : workSeconds / workout.totalSeconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final dial = _WatchDial(
              emoji: _emoji,
              timeLabel: workout.totalDuration,
              subtitle: 'total',
              progress: progress.clamp(0.0, 1.0),
              color: _getCategoryColor(_category),
              size: math.min(constraints.maxWidth * 0.42, 190),
            );

            final rightColumn = Column(
              crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Tag(label: workout.difficulty, color: _getDifficultyColor(workout.difficulty)),
                    const SizedBox(width: 8),
                    _Tag(label: _category, color: _getCategoryColor(_category)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _nameCtrl.text.trim().isEmpty ? 'Your Workout' : _nameCtrl.text.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BuilderColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                _StatRow(
                  items: [
                    _StatItem(icon: Icons.layers_rounded, label: 'Sets', value: '${_sets.length}', color: _BuilderColors.primary),
                    _StatItem(icon: Icons.repeat_rounded, label: 'Rounds', value: '$_rounds', color: _BuilderColors.amber),
                    _StatItem(icon: Icons.coffee_rounded, label: 'Break', value: _formatShortSeconds(_roundBreak), color: _BuilderColors.purple),
                  ],
                ),
                const SizedBox(height: 14),
                _SummaryBar(
                  items: [
                    _SummaryBarItem(label: 'Total', value: workout.totalDuration, color: _BuilderColors.blue),
                    _SummaryBarItem(label: 'Work', value: _formatShortSeconds(workSeconds), color: _BuilderColors.primary),
                    _SummaryBarItem(label: 'Difficulty', value: workout.difficulty, color: _getDifficultyColor(workout.difficulty)),
                  ],
                ),
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  dial,
                  const SizedBox(width: 24),
                  Expanded(child: rightColumn),
                ],
              );
            }
            return Column(children: [dial, const SizedBox(height: 16), rightColumn]);
          },
        ),
      ),
    );
  }

  // ---------- Details section (name + emoji + category) ----------
  Widget _buildDetailsSection() => _SectionCard(
    title: 'Details',
    icon: Icons.tune_rounded,
    color: _BuilderColors.blue,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNameField(),
        const SizedBox(height: 16),
        _SectionLabel('Icon'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emojis
              .map((e) => _EmojiChip(emoji: e, selected: _emoji == e, onTap: () => setState(() => _emoji = e)))
              .toList(),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Category'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories
              .map((c) => _ChoiceChip(
                    label: c,
                    selected: _category == c,
                    color: _getCategoryColor(c),
                    onTap: () => setState(() => _category = c),
                  ))
              .toList(),
        ),
      ],
    ),
  );

  Widget _buildNameField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel('Name'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: _BuilderColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _BuilderColors.line),
        ),
        child: TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: _BuilderColors.ink, fontSize: 16, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter workout name',
            filled: false,
            hintStyle: TextStyle(color: _BuilderColors.muted, fontSize: 15),
            prefixIcon: const Icon(Icons.edit_note_rounded, color: _BuilderColors.muted),
            suffixIcon: _nameCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: _BuilderColors.muted, size: 20),
                    tooltip: 'Clear',
                    onPressed: () => setState(_nameCtrl.clear),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: InputBorder.none,
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(30)],
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${_nameCtrl.text.length}/30',
          style: const TextStyle(color: _BuilderColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  // ---------- Structure section (rounds + round break) ----------
  Widget _buildStructureSection() => _SectionCard(
    title: 'Structure',
    icon: Icons.repeat_rounded,
    color: _BuilderColors.amber,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 620;
        final roundsCard = _buildRoundsCard();
        final breakCard = _buildRoundBreakCard();

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: roundsCard),
              const SizedBox(width: 12),
              Expanded(child: breakCard),
            ],
          );
        }
        return Column(children: [roundsCard, const SizedBox(height: 12), breakCard]);
      },
    ),
  );

  Widget _buildRoundsCard() => _SubCard(
    title: 'Rounds',
    subtitle: 'Repeat the set list',
    icon: Icons.repeat_rounded,
    color: _BuilderColors.amber,
    child: Row(
      children: [
        _ValueDisplay(value: '$_rounds', label: 'rounds', color: _BuilderColors.amber, progress: (_rounds - 1) / 19),
        const Spacer(),
        _Stepper(
          color: _BuilderColors.amber,
          canAdd: _rounds < 20,
          canRemove: _rounds > 1,
          onAdd: () => setState(() => _rounds++),
          onRemove: () => setState(() => _rounds--),
        ),
      ],
    ),
  );

  Widget _buildRoundBreakCard() {
    const presets = [0, 15, 30, 45, 60, 90, 120];
    return _SubCard(
      title: 'Round Break',
      subtitle: 'Pause before next round',
      icon: Icons.coffee_rounded,
      color: _BuilderColors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ValueDisplay(
                value: _formatClock(_roundBreak),
                label: 'break',
                color: _BuilderColors.purple,
                progress: (_roundBreak / 120).clamp(0.0, 1.0),
              ),
              const Spacer(),
              _Stepper(
                color: _BuilderColors.purple,
                canAdd: _roundBreak < 600,
                canRemove: _roundBreak > 0,
                onAdd: () => setState(() => _roundBreak = math.min(_roundBreak + 15, 600)),
                onRemove: () => setState(() => _roundBreak = math.max(_roundBreak - 15, 0)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map((s) => _ChoiceChip(
                      label: s == 0 ? 'None' : '${s}s',
                      selected: _roundBreak == s,
                      color: _BuilderColors.purple,
                      onTap: () => setState(() => _roundBreak = s),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ---------- Sets section ----------
  Widget _buildSetsSection() => _SectionCard(
    title: 'Sets',
    icon: Icons.layers_rounded,
    color: _BuilderColors.primary,
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    trailing: _TextButton(
      label: 'Add Set',
      icon: Icons.add_rounded,
      enabled: _sets.length < 20,
      onTap: () => setState(() => _sets.add(const WorkoutSet())),
    ),
    child: _sets.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(Icons.fitness_center_rounded, color: _BuilderColors.muted.withValues(alpha: 0.7), size: 36),
                const SizedBox(height: 8),
                const Text('No sets yet', style: TextStyle(color: _BuilderColors.muted, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tap "Add Set" to begin', style: TextStyle(color: _BuilderColors.subtle, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        : Column(
            children: List.generate(
              _sets.length,
              (i) => _SetTile(
                index: i,
                set: _sets[i],
                canDelete: _sets.length > 1,
                onChanged: (s) => setState(() => _sets[i] = s),
                onDelete: () => setState(() => _sets.removeAt(i)),
              ),
            ),
          ),
  );

  // ---------- Helpers ----------
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: _BuilderColors.surface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _BuilderColors.line),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8))],
  );

  Color _getCategoryColor(String c) {
    switch (c) {
      case 'HIIT': return _BuilderColors.amber;
      case 'Tabata': return _BuilderColors.purple;
      case 'Circuit': return _BuilderColors.primary;
      case 'Beginner': return _BuilderColors.blue;
      default: return _BuilderColors.rose;
    }
  }

  Color _getDifficultyColor(String d) {
    switch (d) {
      case 'Hard': return _BuilderColors.danger;
      case 'Medium': return _BuilderColors.amber;
      default: return _BuilderColors.primary;
    }
  }

  String _formatClock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatShortSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
    return '${s}s';
  }
}

// ============================================================================
// Shared widgets
// ============================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final EdgeInsetsGeometry padding;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.padding,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _BuilderColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _BuilderColors.line),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(color: _BuilderColors.ink, fontSize: 16, fontWeight: FontWeight.w900)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _SubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _BuilderColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _BuilderColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: const TextStyle(color: _BuilderColors.muted, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(color: _BuilderColors.muted, fontSize: 12, fontWeight: FontWeight.w800),
  );
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : _BuilderColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: selected ? color.withValues(alpha: 0.3) : _BuilderColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(color: selected ? color : _BuilderColors.muted, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _EmojiChip extends StatelessWidget {
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _EmojiChip({required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: selected ? _BuilderColors.blue.withValues(alpha: 0.15) : _BuilderColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _BuilderColors.blue : _BuilderColors.line, width: selected ? 2 : 1),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    ),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
  );
}

class _StatRow extends StatelessWidget {
  final List<_StatItem> items;
  const _StatRow({required this.items});

  @override
  Widget build(BuildContext context) => Row(
    children: items.map((i) => Expanded(child: i)).toList(),
  );
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      color: _BuilderColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Flexible(
              child: Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: _BuilderColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _SummaryBar extends StatelessWidget {
  final List<_SummaryBarItem> items;
  const _SummaryBar({required this.items});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: _BuilderColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _BuilderColors.line),
    ),
    child: Row(
      children: items.map((item) {
        final isLast = items.last == item;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: item.color, fontSize: 15, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(height: 3),
                    Text(item.label, style: const TextStyle(color: _BuilderColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (!isLast) Container(width: 1, height: 36, color: _BuilderColors.line),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class _SummaryBarItem {
  final String label;
  final String value;
  final Color color;
  const _SummaryBarItem({required this.label, required this.value, required this.color});
}

class _ValueDisplay extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double progress;

  const _ValueDisplay({required this.value, required this.label, required this.color, required this.progress});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 80,
    width: 90,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 5,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(color: _BuilderColors.ink, fontSize: 18, fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()])),
            Text(label, style: const TextStyle(color: _BuilderColors.muted, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    ),
  );
}

class _Stepper extends StatelessWidget {
  final Color color;
  final bool canAdd;
  final bool canRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _Stepper({required this.color, required this.canAdd, required this.canRemove, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _StepBtn(icon: Icons.add_rounded, color: color, enabled: canAdd, onTap: onAdd),
      const SizedBox(height: 10),
      _StepBtn(icon: Icons.remove_rounded, color: color, enabled: canRemove, onTap: onRemove),
    ],
  );
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _StepBtn({required this.icon, required this.color, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: enabled ? color : _BuilderColors.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: enabled ? color : _BuilderColors.line),
      ),
      child: Icon(icon, color: enabled ? _BuilderColors.surface : _BuilderColors.muted, size: 20),
    ),
  );
}

class _WatchDial extends StatelessWidget {
  final String emoji;
  final String timeLabel;
  final String subtitle;
  final double progress;
  final Color color;
  final double size;

  const _WatchDial({required this.emoji, required this.timeLabel, required this.subtitle, required this.progress, required this.color, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(size: Size.square(size), painter: _DialPainter(progress: progress, color: color, strokeWidth: 10)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: size * 0.15)),
            const SizedBox(height: 6),
            Text(timeLabel, style: TextStyle(color: _BuilderColors.ink, fontSize: size * 0.17, fontWeight: FontWeight.w900, height: 1, fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    ),
  );
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _DialPainter({required this.progress, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.1);
    canvas.drawCircle(center, radius, basePaint);

    // Tick marks
    final tickPaint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (int i = 0; i < 60; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 * i / 60);
      final major = i % 5 == 0;
      final ts = major ? 14 : 8;
      final start = center + Offset(math.cos(angle), math.sin(angle)) * (radius - ts);
      final end = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 3);
      tickPaint
        ..strokeWidth = major ? 2.2 : 1.0
        ..color = major ? color.withValues(alpha: 0.45) : _BuilderColors.subtle.withValues(alpha: 0.2);
      canvas.drawLine(start, end, tickPaint);
    }

    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    if (sweep > 0.001) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, p);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.progress != progress || old.color != color;
}

// ============================================================================
// SET TILE (the per-set card)
// ============================================================================

class _SetTile extends StatefulWidget {
  final int index;
  final WorkoutSet set;
  final bool canDelete;
  final void Function(WorkoutSet) onChanged;
  final VoidCallback onDelete;

  const _SetTile({required this.index, required this.set, required this.canDelete, required this.onChanged, required this.onDelete});

  @override
  State<_SetTile> createState() => _SetTileState();
}

class _SetTileState extends State<_SetTile> {
  late TextEditingController _workMinCtrl;
  late TextEditingController _workSecCtrl;
  late TextEditingController _breakMinCtrl;
  late TextEditingController _breakSecCtrl;

  @override
  void initState() {
    super.initState();
    final wm = widget.set.durationSeconds ~/ 60;
    final ws = widget.set.durationSeconds % 60;
    final bm = widget.set.breakSeconds ~/ 60;
    final bs = widget.set.breakSeconds % 60;

    _workMinCtrl = TextEditingController(text: wm > 0 ? wm.toString() : '');
    _workSecCtrl = TextEditingController(text: ws > 0 ? ws.toString() : (wm == 0 ? '30' : ''));
    _breakMinCtrl = TextEditingController(text: bm > 0 ? bm.toString() : '');
    _breakSecCtrl = TextEditingController(text: bs > 0 ? bs.toString() : (bm == 0 ? '10' : ''));
  }

  @override
  void dispose() {
    _workMinCtrl.dispose();
    _workSecCtrl.dispose();
    _breakMinCtrl.dispose();
    _breakSecCtrl.dispose();
    super.dispose();
  }

  void _updateWork() {
    final m = int.tryParse(_workMinCtrl.text) ?? 0;
    final s = int.tryParse(_workSecCtrl.text) ?? 0;
    int total = m * 60 + s;
    if (total > 7200) { total = 7200; _workMinCtrl.text = '120'; _workSecCtrl.text = '00'; }
    widget.onChanged(widget.set.copyWith(durationSeconds: total));
  }

  void _updateBreak() {
    final m = int.tryParse(_breakMinCtrl.text) ?? 0;
    final s = int.tryParse(_breakSecCtrl.text) ?? 0;
    int total = m * 60 + s;
    if (total > 3599) { total = 3599; _breakMinCtrl.text = '59'; _breakSecCtrl.text = '59'; }
    widget.onChanged(widget.set.copyWith(breakSeconds: total));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _BuilderColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _BuilderColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: _BuilderColors.primary, borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text('${widget.index + 1}', style: const TextStyle(color: _BuilderColors.surface, fontSize: 13, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: widget.set.name,
                  maxLength: 30,
                  style: const TextStyle(color: _BuilderColors.ink, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Set name (optional)',
                    hintStyle: TextStyle(color: _BuilderColors.muted, fontSize: 13),
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: _BuilderColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => widget.onChanged(widget.set.copyWith(name: v)),
                ),
              ),
              if (widget.canDelete) ...[
                const SizedBox(width: 8),
                _IconBtn(icon: Icons.delete_outline_rounded, color: _BuilderColors.danger, tooltip: 'Delete set', onTap: widget.onDelete),
              ],
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final work = _timeBox(
                icon: Icons.fitness_center_rounded,
                label: 'Work',
                color: _BuilderColors.primary,
                minCtrl: _workMinCtrl,
                secCtrl: _workSecCtrl,
                onChanged: _updateWork,
              );
              final rest = _timeBox(
                icon: Icons.coffee_rounded,
                label: 'Break',
                color: _BuilderColors.blue,
                minCtrl: _breakMinCtrl,
                secCtrl: _breakSecCtrl,
                onChanged: _updateBreak,
              );
              if (stacked) return Column(children: [work, const SizedBox(height: 8), rest]);
              return Row(children: [Expanded(child: work), const SizedBox(width: 10), Expanded(child: rest)]);
            },
          ),
        ],
      ),
    ),
  );

  Widget _timeBox({
    required IconData icon,
    required String label,
    required Color color,
    required TextEditingController minCtrl,
    required TextEditingController secCtrl,
    required VoidCallback onChanged,
  }) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _BuilderColors.surface,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, color: color, size: 15), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800))]),
        const SizedBox(height: 8),
        Row(
          children: [
            _TinyInput(ctrl: minCtrl, hint: '00', suffix: 'm', onChanged: onChanged),
            const SizedBox(width: 4),
            const Text(':', style: TextStyle(color: _BuilderColors.muted, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            _TinyInput(ctrl: secCtrl, hint: '00', suffix: 's', onChanged: onChanged),
          ],
        ),
      ],
    ),
  );
}

class _TinyInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final String suffix;
  final VoidCallback onChanged;

  const _TinyInput({required this.ctrl, required this.hint, required this.suffix, required this.onChanged});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 42,
      decoration: BoxDecoration(
        color: _BuilderColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _BuilderColors.line),
      ),
      child: Center(
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _BuilderColors.ink, fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            hintText: hint,
            hintStyle: TextStyle(color: _BuilderColors.subtle, fontSize: 16, fontWeight: FontWeight.w800),
            suffixText: suffix,
            suffixStyle: TextStyle(color: _BuilderColors.muted, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
          onChanged: (_) => onChanged(),
        ),
      ),
    ),
  );
}

// ============================================================================
// Button widgets
// ============================================================================

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _BuilderColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _BuilderColors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, color: _BuilderColors.surface, size: 17),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: _BuilderColors.surface, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    ),
  );
}

class _TextButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _TextButton({required this.label, required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled ? _BuilderColors.primary.withValues(alpha: 0.1) : _BuilderColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: enabled ? _BuilderColors.primary.withValues(alpha: 0.3) : _BuilderColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: enabled ? _BuilderColors.primary : _BuilderColors.muted, size: 16),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: enabled ? _BuilderColors.primary : _BuilderColors.muted, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    decoration: BoxDecoration(color: _BuilderColors.ink, borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(color: _BuilderColors.surface, fontSize: 12, fontWeight: FontWeight.w700),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    ),
  );
}
