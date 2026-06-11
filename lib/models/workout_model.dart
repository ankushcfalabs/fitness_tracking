import 'package:flutter/material.dart';

class WorkoutSet {
  final int durationSeconds;
  final int breakSeconds;
  final String name;

  const WorkoutSet({this.durationSeconds = 30, this.breakSeconds = 10, this.name = ''});

  WorkoutSet copyWith({int? durationSeconds, int? breakSeconds, String? name}) =>
      WorkoutSet(
        durationSeconds: durationSeconds ?? this.durationSeconds,
        breakSeconds: breakSeconds ?? this.breakSeconds,
        name: name ?? this.name,
      );

  Map<String, dynamic> toJson() => {
        'durationSeconds': durationSeconds,
        'breakSeconds': breakSeconds,
        'name': name,
      };

  factory WorkoutSet.fromJson(Map<String, dynamic> j) =>
      WorkoutSet(
        durationSeconds: j['durationSeconds'],
        breakSeconds: j['breakSeconds'],
        name: j['name'] ?? '',
      );
}

class Workout {
  final String id;
  final String name;
  final String category;
  final int rounds;
  final List<WorkoutSet> sets;
  final int roundBreakSeconds;
  final String emoji;

  const Workout({
    required this.id,
    required this.name,
    this.category = 'Custom',
    this.rounds = 3,
    required this.sets,
    this.roundBreakSeconds = 60,
    this.emoji = '💪',
  });

  int get totalSeconds {
    final setTotal = sets.fold(0, (s, e) => s + e.durationSeconds + e.breakSeconds);
    return (setTotal * rounds) + (roundBreakSeconds * (rounds - 1));
  }

  String get totalDuration {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  String get difficulty {
    final avgWorkTime = sets.fold(0, (s, e) => s + e.durationSeconds) / sets.length;
    final avgBreakTime = sets.fold(0, (s, e) => s + e.breakSeconds) / sets.length;
    final ratio = avgWorkTime / (avgBreakTime + 1);
    if (ratio >= 3 || rounds >= 6) return 'Hard';
    if (ratio >= 2 || rounds >= 4) return 'Medium';
    return 'Easy';
  }

  Color get difficultyColor {
    switch (difficulty) {
      case 'Hard': return const Color(0xFFFF6B6B);
      case 'Medium': return const Color(0xFFFFB84D);
      default: return const Color(0xFF51CF66);
    }
  }

  Workout copyWith({
    String? name,
    String? category,
    int? rounds,
    List<WorkoutSet>? sets,
    int? roundBreakSeconds,
    String? emoji,
  }) =>
      Workout(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        rounds: rounds ?? this.rounds,
        sets: sets ?? this.sets,
        roundBreakSeconds: roundBreakSeconds ?? this.roundBreakSeconds,
        emoji: emoji ?? this.emoji,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'rounds': rounds,
        'sets': sets.map((s) => s.toJson()).toList(),
        'roundBreakSeconds': roundBreakSeconds,
        'emoji': emoji,
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'],
        name: j['name'],
        category: j['category'] ?? 'Custom',
        rounds: j['rounds'],
        sets: (j['sets'] as List).map((s) => WorkoutSet.fromJson(s)).toList(),
        roundBreakSeconds: j['roundBreakSeconds'],
        emoji: j['emoji'] ?? '💪',
      );
}

class WorkoutHistory {
  final String workoutName;
  final DateTime date;
  final int durationSeconds;
  final int roundsCompleted;
  final String emoji;

  const WorkoutHistory({
    required this.workoutName,
    required this.date,
    required this.durationSeconds,
    required this.roundsCompleted,
    this.emoji = '💪',
  });

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  Map<String, dynamic> toJson() => {
        'workoutName': workoutName,
        'date': date.toIso8601String(),
        'durationSeconds': durationSeconds,
        'roundsCompleted': roundsCompleted,
        'emoji': emoji,
      };

  factory WorkoutHistory.fromJson(Map<String, dynamic> j) => WorkoutHistory(
        workoutName: j['workoutName'],
        date: DateTime.parse(j['date']),
        durationSeconds: j['durationSeconds'],
        roundsCompleted: j['roundsCompleted'],
        emoji: j['emoji'] ?? '💪',
      );
}

final List<Workout> predefinedWorkouts = [
  Workout(
    id: 'hiit_1',
    name: 'HIIT Blast',
    category: 'HIIT',
    rounds: 4,
    sets: [
      const WorkoutSet(durationSeconds: 40, breakSeconds: 20),
      const WorkoutSet(durationSeconds: 40, breakSeconds: 20),
      const WorkoutSet(durationSeconds: 40, breakSeconds: 20),
    ],
    roundBreakSeconds: 60,
    emoji: '🔥',
  ),
  Workout(
    id: 'tabata_1',
    name: 'Tabata Classic',
    category: 'Tabata',
    rounds: 8,
    sets: [
      const WorkoutSet(durationSeconds: 20, breakSeconds: 10),
    ],
    roundBreakSeconds: 60,
    emoji: '⚡',
  ),
  Workout(
    id: 'circuit_1',
    name: 'Full Body Circuit',
    category: 'Circuit',
    rounds: 3,
    sets: [
      const WorkoutSet(durationSeconds: 60, breakSeconds: 15),
      const WorkoutSet(durationSeconds: 60, breakSeconds: 15),
      const WorkoutSet(durationSeconds: 60, breakSeconds: 15),
      const WorkoutSet(durationSeconds: 60, breakSeconds: 15),
    ],
    roundBreakSeconds: 90,
    emoji: '🏋️',
  ),
  Workout(
    id: 'beginner_1',
    name: 'Beginner Boost',
    category: 'Beginner',
    rounds: 2,
    sets: [
      const WorkoutSet(durationSeconds: 30, breakSeconds: 30),
      const WorkoutSet(durationSeconds: 30, breakSeconds: 30),
    ],
    roundBreakSeconds: 120,
    emoji: '🌟',
  ),
];
