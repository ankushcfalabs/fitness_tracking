import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/voice_language.dart';
import '../services/battery_optimization_service.dart';
import '../services/voice_service.dart';
import 'voice_settings_screen_new.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _voiceService = VoiceService();
  final _batteryService = BatteryOptimizationService();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  bool _voiceEnabled = true;
  String _selectedLanguage = 'en-IN';
  bool _backgroundProtectionEnabled = true;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadSettings();
    _loadBackgroundStatus();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('voice_enabled') ?? true;
      final language = prefs.getString('voice_language') ?? 'en-IN';

      if (mounted) {
        setState(() {
          _voiceEnabled = enabled;
          _selectedLanguage = language;
        });
      }

      await _voiceService.setEnabled(_voiceEnabled);
      await _voiceService.setLanguage(_selectedLanguage);
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _loadBackgroundStatus() async {
    final isProtected =
        await _batteryService.isIgnoringBatteryOptimizations();
    if (mounted) {
      setState(() => _backgroundProtectionEnabled = isProtected);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('voice_enabled', _voiceEnabled);
      await prefs.setString('voice_language', _selectedLanguage);
      await _voiceService.setEnabled(_voiceEnabled);
      await _voiceService.setLanguage(_selectedLanguage);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _testVoice() async {
    try {
      await _voiceService.announceTest();
    } catch (e) {
      debugPrint('Error testing voice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Voice test failed. Some languages may not be installed on your device.',
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Install',
              onPressed: () async {
                // Open TTS settings
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Go to Settings → Language & Input → Text-to-Speech to install language voices',
                      ),
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _configureBackgroundMode() async {
    final success = _backgroundProtectionEnabled
        ? await _batteryService.openBatteryOptimizationSettings()
        : await _batteryService.requestIgnoreBatteryOptimizations();

    if (!mounted) return;

    await _loadBackgroundStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Background running settings opened.'
              : 'Unable to update background running settings.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: Colors.white, // Light background
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Settings',
            style: TextStyle(
              color: AppColors.bg, // Darker text for contrast
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          automaticallyImplyLeading: false,
          iconTheme: IconThemeData(color: AppColors.bg), // Dark icons
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildVoiceSection()),
            SliverToBoxAdapter(child: _buildReliabilitySection()),
            SliverToBoxAdapter(child: _buildLanguageSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Voice Guidance',
          style: TextStyle(
            color: AppColors.bg, // Darker text for contrast
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VoiceSettingsScreenNew()),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50], // Light grey background
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50], // Light accent background
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.settings_voice_rounded,
                    color: Colors.blue, // Blue icon
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Settings',
                        style: TextStyle(
                          color: AppColors.bg,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Voice type, beeps, and announcements',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50], // Light grey background
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50], // Light green background
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: Colors.green, // Green icon
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable Voice',
                      style: TextStyle(
                        color: AppColors.bg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Announces workout phases',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _voiceEnabled,
                onChanged: (v) {
                  setState(() => _voiceEnabled = v);
                  _saveSettings();
                },
                activeTrackColor: Colors.green[200], // Light green track
                activeColor: Colors.green, // Green thumb
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildLanguageSection() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Voice Language',
              style: TextStyle(
                color: AppColors.bg,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _voiceEnabled ? _testVoice : null,
              icon: Icon(Icons.play_arrow_rounded, size: 18, color: Colors.blue),
              label: const Text('Test', style: TextStyle(color: Colors.blue)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                disabledForegroundColor: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...indianLanguages.map(
          (lang) => _LanguageCard(
            language: lang,
            selected: _selectedLanguage == lang.code,
            available: true,
            onTap: () {
              setState(() => _selectedLanguage = lang.code);
              _saveSettings();
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50], // Light blue background
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue[100]!), // Light blue border
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Regional languages download voice files on first use for faster playback.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildReliabilitySection() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workout Reliability',
          style: TextStyle(
            color: AppColors.bg,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50], // Light grey background
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_backgroundProtectionEnabled
                          ? Colors.green[50]
                          : Colors.orange[50])!,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _backgroundProtectionEnabled
                      ? Icons.verified_user_rounded
                      : Icons.battery_alert_rounded,
                  color: _backgroundProtectionEnabled
                      ? Colors.green // Green for enabled
                      : Colors.orange, // Orange for disabled
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _backgroundProtectionEnabled
                          ? 'Background running is enabled'
                          : 'Background running may be restricted',
                      style: const TextStyle(
                        color: AppColors.bg,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _backgroundProtectionEnabled
                          ? 'Your timer is less likely to pause when the screen locks.'
                          : 'Allow background running so timers and announcements stay reliable.',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _configureBackgroundMode,
                child: Text(
                  _backgroundProtectionEnabled ? 'Manage' : 'Enable',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LanguageCard extends StatelessWidget {
  final VoiceLanguage language;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? Colors.blue[50] // Light blue for selected
                : Colors.grey[50], // Light grey for unselected
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.blue : Colors.grey[200]!,
              width: selected ? 2 : 1,
            ),
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
              Text(language.flag, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.name,
                      style: TextStyle(
                        color: available
                            ? AppColors.bg // Darker text for available
                            : Colors.grey, // Grey for unavailable
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      language.nativeName,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!available)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Not Available',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                )
              else if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.blue, // Blue checkmark
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}