import 'package:fitness_tracking/models/workout_model.dart';
import 'package:fitness_tracking/screens/home_screen.dart';
import 'package:fitness_tracking/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home screen shows workouts and main navigation', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'first_time_help': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(600, 1400)),
          child: HomeScreen(
            history: const <WorkoutHistory>[],
            customWorkouts: const <Workout>[],
            onWorkoutComplete: (_) {},
            onSaveWorkout: (_) {},
            onDeleteWorkout: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quick Start'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Builder'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('day streak counts unique workout days only', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'first_time_help': true,
    });

    final now = DateTime.now();
    final history = <WorkoutHistory>[
      WorkoutHistory(
        workoutName: 'Morning HIIT',
        date: now.subtract(const Duration(hours: 1)),
        durationSeconds: 600,
        roundsCompleted: 3,
      ),
      WorkoutHistory(
        workoutName: 'Evening HIIT',
        date: now.subtract(const Duration(hours: 5)),
        durationSeconds: 900,
        roundsCompleted: 4,
      ),
      WorkoutHistory(
        workoutName: 'Yesterday Core',
        date: now.subtract(const Duration(days: 1, hours: 2)),
        durationSeconds: 480,
        roundsCompleted: 2,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(600, 1400)),
          child: HomeScreen(
            history: history,
            customWorkouts: const <Workout>[],
            onWorkoutComplete: (_) {},
            onSaveWorkout: (_) {},
            onDeleteWorkout: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2🔥'), findsOneWidget);
  });
}
