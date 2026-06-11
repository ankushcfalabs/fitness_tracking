import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/battery_optimization_service.dart';

class BatteryOptimizationDialog {
  static const _promptShownKey = 'battery_optimization_prompt_shown';

  static Future<void> show(BuildContext context) async {
    final battery = BatteryOptimizationService();
    final isIgnoring = await battery.isIgnoringBatteryOptimizations();
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_promptShownKey) ?? false;
    
    if (isIgnoring || alreadyPrompted) return; // Already exempted or prompt already shown
    
    if (!context.mounted) return;
    
    final shouldRequestPermission = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.battery_charging_full, color: AppColors.accentGreen, size: 28),
            SizedBox(width: 12),
            Text(
              'Background Running',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For uninterrupted workouts, allow this app to run in the background.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            SizedBox(height: 16),
            Text(
              'Benefits:',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            _BenefitItem(
              icon: Icons.timer,
              text: 'Timer continues when screen is locked',
            ),
            _BenefitItem(
              icon: Icons.volume_up,
              text: 'Voice announcements work in background',
            ),
            _BenefitItem(
              icon: Icons.apps,
              text: 'Switch to other apps during workout',
            ),
            _BenefitItem(
              icon: Icons.notifications_active,
              text: 'Persistent notification with controls',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Not Now',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              foregroundColor: AppColors.bg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    ) ?? false;

    await prefs.setBool(_promptShownKey, true);
    if (shouldRequestPermission) {
      await battery.requestIgnoreBatteryOptimizations();
    }
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentGreen, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
