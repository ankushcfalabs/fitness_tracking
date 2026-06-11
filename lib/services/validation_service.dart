import '../models/workout_model.dart';

class ValidationService {
  static bool isValidWorkout(Workout workout) {
    if (workout.name.trim().isEmpty) return false;
    if (workout.rounds < 1 || workout.rounds > 50) return false;
    if (workout.sets.isEmpty || workout.sets.length > 20) return false;
    if (workout.roundBreakSeconds < 0 || workout.roundBreakSeconds > 600) return false;
    
    for (final set in workout.sets) {
      if (!isValidSet(set)) return false;
    }
    
    return true;
  }

  static bool isValidSet(WorkoutSet set) {
    if (set.durationSeconds < 5 || set.durationSeconds > 7200) return false;
    if (set.breakSeconds < 0 || set.breakSeconds > 7200) return false;
    if (set.name.length > 50) return false;
    return true;
  }

  static bool isValidHistory(WorkoutHistory history) {
    if (history.workoutName.trim().isEmpty) return false;
    if (history.durationSeconds < 0 || history.durationSeconds > 86400) return false;
    if (history.roundsCompleted < 0 || history.roundsCompleted > 100) return false;
    return true;
  }

  static String sanitizeString(String input, {int maxLength = 100}) {
    return input.trim().substring(0, input.length > maxLength ? maxLength : input.length);
  }

  static int clampInt(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static Workout sanitizeWorkout(Workout workout) {
    return Workout(
      id: workout.id,
      name: sanitizeString(workout.name, maxLength: 40),
      category: workout.category,
      rounds: clampInt(workout.rounds, 1, 50),
      sets: workout.sets.map((s) => sanitizeSet(s)).toList(),
      roundBreakSeconds: clampInt(workout.roundBreakSeconds, 0, 600),
      emoji: workout.emoji,
    );
  }

  static WorkoutSet sanitizeSet(WorkoutSet set) {
    return WorkoutSet(
      durationSeconds: clampInt(set.durationSeconds, 5, 7200),
      breakSeconds: clampInt(set.breakSeconds, 0, 7200),
      name: sanitizeString(set.name, maxLength: 50),
    );
  }
}
