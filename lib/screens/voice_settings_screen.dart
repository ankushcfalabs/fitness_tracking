import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final VoiceService _voice = VoiceService();
  final AudioService _audio = AudioService();
  String _language = 'en-IN';
  List<String> _availableLanguages = [];
  List<Map<String, String>> _availableVoices = [];
  Map<String, String>? _selectedVoice;
  AnnouncementType _announcementType = AnnouncementType.voiceAndBeeps;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await _voice.init();
      await _audio.init();
      final languages = await _voice.getAvailableLanguages();
      final voices = await _voice.getAvailableVoices();
      if (mounted) {
        setState(() {
          _language = _voice.currentLanguage;
          _availableLanguages = languages;
          _availableVoices = voices;
          _selectedVoice = _voice.selectedVoice;
          _announcementType = _audio.announcementType;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _testVoice() async {
    debugPrint('=== Test Voice Button Clicked ===');
    debugPrint('Current announcement type: $_announcementType');
    debugPrint(
      'Should play voice: ${_announcementType == AnnouncementType.voiceOnly || _announcementType == AnnouncementType.voiceAndBeeps}',
    );
    debugPrint(
      'Should play beeps: ${_announcementType == AnnouncementType.beepsOnly || _announcementType == AnnouncementType.voiceAndBeeps}',
    );

    if (_announcementType == AnnouncementType.voiceOnly ||
        _announcementType == AnnouncementType.voiceAndBeeps) {
      debugPrint('Playing voice announcement...');
      await _voice.speak(
        'This is a test of the voice guidance system. Workout starting in 3, 2, 1.',
      );
    }

    if (_announcementType == AnnouncementType.beepsOnly ||
        _announcementType == AnnouncementType.voiceAndBeeps) {
      debugPrint('Playing beep sequence: 3, 2, 1, GO!');
      await _audio.playCountdownBeep();
      await Future.delayed(const Duration(milliseconds: 400));
      await _audio.playCountdownBeep();
      await Future.delayed(const Duration(milliseconds: 400));
      await _audio.playCountdownBeep();
      await Future.delayed(const Duration(milliseconds: 400));
      await _audio.playStartBeep();
      debugPrint('Beep sequence complete');
    }

    if (_announcementType == AnnouncementType.silent) {
      debugPrint('Silent mode - no audio played');
    }

    debugPrint('=== Test Complete ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Voice Settings And Beeps',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Announcement Type',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _buildAnnouncementTypeOption(
                        AnnouncementType.voiceOnly,
                        'Voice Only',
                        'Spoken announcements',
                        Icons.record_voice_over_rounded,
                      ),
                      _buildAnnouncementTypeOption(
                        AnnouncementType.beepsOnly,
                        'Beeps Only',
                        'Audio tones without voice',
                        Icons.notifications_active_rounded,
                      ),
                      _buildAnnouncementTypeOption(
                        AnnouncementType.voiceAndBeeps,
                        'Voice + Beeps',
                        'Both voice and audio tones',
                        Icons.volume_up_rounded,
                      ),
                      _buildAnnouncementTypeOption(
                        AnnouncementType.silent,
                        'Silent',
                        'No audio announcements',
                        Icons.volume_off_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_availableVoices.isNotEmpty) ...[
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Voice Type',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Select your preferred voice',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _availableVoices.length > 15
                              ? 15
                              : _availableVoices.length,
                          itemBuilder: (context, index) {
                            final voice = _availableVoices[index];
                            final isSelected =
                                _selectedVoice?['name'] == voice['name'];
                            return InkWell(
                              onTap: () async {
                                setState(() => _selectedVoice = voice);
                                await _voice.setVoice(voice);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accent.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            voice['name'] ?? '',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppColors.accent
                                                  : AppColors.textPrimary,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            voice['locale'] ?? '',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_availableLanguages.isNotEmpty) ...[
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Language',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _availableLanguages.length > 10
                              ? 10
                              : _availableLanguages.length,
                          itemBuilder: (context, index) {
                            final lang = _availableLanguages[index];
                            final isSelected = _language == lang;
                            return InkWell(
                              onTap: () async {
                                setState(() => _language = lang);
                                await _voice.setLanguage(lang);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.accent.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      color: isSelected
                                          ? AppColors.accent
                                          : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _getLanguageName(lang),
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.accent
                                              : AppColors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _testVoice,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Test Voice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Settings',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingRow(
                          'Announcement Type',
                          _getAnnouncementTypeName(_announcementType),
                        ),
                        _buildSettingRow(
                          'Voice Enabled',
                          _audio.shouldPlayVoice ? 'Yes' : 'No',
                        ),
                        _buildSettingRow(
                          'Beeps Enabled',
                          _audio.shouldPlayBeeps ? 'Yes' : 'No',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Voice Announcements',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildAnnouncementItem('Workout start with details'),
                        _buildAnnouncementItem('Round start and end'),
                        _buildAnnouncementItem('Set start and end with names'),
                        _buildAnnouncementItem('Rest periods'),
                        _buildAnnouncementItem(
                          'Time remaining (10s, 5s, 3-2-1)',
                        ),
                        _buildAnnouncementItem('Halfway point for long sets'),
                        _buildAnnouncementItem('Pause and resume'),
                        _buildAnnouncementItem('Workout completion with stats'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAnnouncementTypeOption(
    AnnouncementType type,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _announcementType == type;
    return InkWell(
      onTap: () async {
        await _audio.setAnnouncementType(type);
        await _voice.reloadAnnouncementType();
        setState(() => _announcementType = type);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _buildAnnouncementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.accentGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    final names = {
      'en-US': '🇺🇸 English (United States)',
      'en-GB': '🇬🇧 English (United Kingdom)',
      'en-AU': '🇦🇺 English (Australia)',
      'en-CA': '🇨🇦 English (Canada)',
      'en-IN': '🇮🇳 English (India)',
      'es-ES': '🇪🇸 Spanish (Spain)',
      'es-MX': '🇲🇽 Spanish (Mexico)',
      'fr-FR': '🇫🇷 French (France)',
      'de-DE': '🇩🇪 German (Germany)',
      'it-IT': '🇮🇹 Italian (Italy)',
      'pt-BR': '🇧🇷 Portuguese (Brazil)',
      'ja-JP': '🇯🇵 Japanese (Japan)',
      'ko-KR': '🇰🇷 Korean (South Korea)',
      'zh-CN': '🇨🇳 Chinese (Simplified)',
      'ru-RU': '🇷🇺 Russian (Russia)',
      'ar-SA': '🇸🇦 Arabic (Saudi Arabia)',
      'hi-IN': '🇮🇳 Hindi (India)',
    };

    if (names.containsKey(code)) {
      return names[code]!;
    }

    final langCode = code.split('-').first.toLowerCase();
    final languageNames = {
      'en': '🌐 English',
      'es': '🌐 Spanish',
      'fr': '🌐 French',
      'de': '🌐 German',
      'it': '🌐 Italian',
      'pt': '🌐 Portuguese',
      'ja': '🌐 Japanese',
      'ko': '🌐 Korean',
      'zh': '🌐 Chinese',
      'ru': '🌐 Russian',
      'ar': '🌐 Arabic',
      'hi': '🌐 Hindi',
    };

    return languageNames[langCode] ?? '🌐 $code';
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getAnnouncementTypeName(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.voiceOnly:
        return 'Voice Only';
      case AnnouncementType.beepsOnly:
        return 'Beeps Only';
      case AnnouncementType.voiceAndBeeps:
        return 'Voice + Beeps';
      case AnnouncementType.silent:
        return 'Silent';
    }
  }
}
