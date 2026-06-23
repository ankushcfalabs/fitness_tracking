import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/voice_service_new.dart';
import '../theme/app_theme.dart';

class VoiceSettingsScreenNew extends StatefulWidget {
  const VoiceSettingsScreenNew({super.key});

  @override
  State<VoiceSettingsScreenNew> createState() => _VoiceSettingsScreenNewState();
}

class _VoiceSettingsScreenNewState extends State<VoiceSettingsScreenNew> {
  final VoiceServiceNew _voice = VoiceServiceNew();
  final AudioService _audio = AudioService();
  bool _enabled = true;
  double _volume = 1.0;
  double _speechRate = 0.52;
  AnnouncementMode _announcementMode = AnnouncementMode.voiceAndBeeps;
  VoiceType _voiceType = VoiceType.female1;
  bool _loading = true;
  bool _testing = false;

  // Chill color palette
  static const Color _primaryColor = Color(0xFF6C8DFF); // Soft blue
  static const Color _secondaryColor = Color(0xFF98C9FF); // Light blue
  static const Color _accentColor = Color(0xFF8AFFD7); // Mint green
  static const Color _surfaceColor = Color(0xFFF8FBFF); // Very light blue
  static const Color _cardColor = Color(0xFFFFFFFF); // White
  static const Color _textColor = Color(0xFF1A2B4D); // Dark blue
  static const Color _textSecondary = Color(0xFF6B7B9D); // Grey blue
  static const Color _successColor = Color(0xFF4CAF50); // Green
  static const Color _borderColor = Color(0xFFE0EDFF); // Light blue border

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _voice.init();
    await _audio.init();
    setState(() {
      _enabled = _voice.enabled;
      _volume = _voice.volume;
      _speechRate = _voice.speechRate;
      _announcementMode = _voice.announcementMode;
      _voiceType = _voice.voiceType;
      _loading = false;
    });
  }

  Future<void> _testVoice() async {
    setState(() => _testing = true);
    debugPrint('=== Test Voice Started ===');
    debugPrint('Announcement Mode: $_announcementMode');

    if (_announcementMode == AnnouncementMode.voiceOnly ||
        _announcementMode == AnnouncementMode.voiceAndBeeps) {
      debugPrint('Playing voice...');
      await _voice.speak(
        'This is a test of the voice guidance system. Workout starting in 3, 2, 1.',
      );
      // Wait for voice to complete before playing beeps
      if (_announcementMode == AnnouncementMode.voiceAndBeeps) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (_announcementMode == AnnouncementMode.beepsOnly ||
        _announcementMode == AnnouncementMode.voiceAndBeeps) {
      debugPrint('Playing beeps sequence...');
      await _audio.playCountdownBeep();
      await Future.delayed(const Duration(milliseconds: 400));
      await _audio.playCountdownBeep();
      await Future.delayed(const Duration(milliseconds: 400));
      await _audio.playCountdownBeep();
      await Future.delayed(const Duration(milliseconds: 400));
      await _audio.playStartBeep();
      debugPrint('Beeps complete');
    }

    debugPrint('=== Test Voice Complete ===');
    setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _primaryColor, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Voice Settings',
          style: TextStyle(
            color: AppColors.bg, // Darker text for contrast
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 2,
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeaderSection()),
                SliverToBoxAdapter(child: _buildEnabledToggle()),
                SliverToBoxAdapter(child: _buildAnnouncementTypeSection()),
                SliverToBoxAdapter(child: _buildVoiceTypeSection()),
                SliverToBoxAdapter(child: _buildVoiceControlsSection()),
                SliverToBoxAdapter(child: _buildTestButton()),
                SliverToBoxAdapter(child: _buildAnnouncementsList()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
    );
  }

  Widget _buildHeaderSection() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.volume_up_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Guidance',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize your workout audio experience',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildEnabledToggle() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: _buildCard(
      child: SwitchListTile.adaptive(
        tileColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        value: _enabled,
        onChanged: (value) async {
          setState(() => _enabled = value);
          await _voice.setEnabled(value);
        },
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Enable Voice Guidance',
              style: TextStyle(
                color: _textColor,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Voice announcements during workouts',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ),
        ),
        activeThumbColor: _primaryColor,
        activeTrackColor: _primaryColor.withOpacity(0.3),
        inactiveThumbColor: _textSecondary,
        inactiveTrackColor: _borderColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    ),
  );

  Widget _buildAnnouncementTypeSection() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Announcement Type',
              style: TextStyle(
                color: _textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...AnnouncementMode.values.map((mode) => _buildModeOption(mode)),
        ],
      ),
    ),
  );

  Widget _buildModeOption(AnnouncementMode mode) {
    final isSelected = _announcementMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() => _announcementMode = mode);
          await _voice.setAnnouncementMode(mode);
          final audioType = mode == AnnouncementMode.voiceOnly
              ? AnnouncementType.voiceOnly
              : mode == AnnouncementMode.beepsOnly
              ? AnnouncementType.beepsOnly
              : mode == AnnouncementMode.voiceAndBeeps
              ? AnnouncementType.voiceAndBeeps
              : AnnouncementType.silent;
          await _audio.setAnnouncementType(audioType);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _primaryColor : _borderColor,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primaryColor,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _voice.getAnnouncementModeName(mode),
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _voice.getAnnouncementModeDescription(mode),
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  Widget _buildVoiceTypeSection() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Voice Type',
              style: TextStyle(
                color: _textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...VoiceType.values.map((type) => _buildVoiceOption(type)),
        ],
      ),
    ),
  );

  Widget _buildVoiceOption(VoiceType type) {
    final isSelected = _voiceType == type;
    final iconColor = isSelected ? _primaryColor : _textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() => _voiceType = type);
          await _voice.setVoiceType(type);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? _primaryColor : _borderColor,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _primaryColor,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Icon(
                type == VoiceType.male1 || type == VoiceType.male2
                    ? Icons.mic_rounded
                    : Icons.mic_none_rounded,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _voice.getVoiceTypeName(type),
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceControlsSection() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              'Voice Controls',
              style: TextStyle(
                color: _textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Adjust the voice settings to your preference',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ),
          _buildVoiceSlider(
            label: 'Volume',
            icon: Icons.volume_up_rounded,
            value: _volume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: (value) async {
              setState(() => _volume = value);
              await _voice.setVolume(value);
            },
            valueLabel: '${(_volume * 100).toInt()}%',
          ),
          _buildVoiceSlider(
            label: 'Speech Rate',
            icon: Icons.speed_rounded,
            value: _speechRate,
            min: 0.1,
            max: 2.0,
            divisions: 19,
            onChanged: (value) async {
              setState(() => _speechRate = value);
              await _voice.setSpeechRate(value);
            },
            valueLabel: '${_speechRate.toStringAsFixed(1)}x',
          ),
        ],
      ),
    ),
  );

  Widget _buildVoiceSlider({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Function(double) onChanged,
    required String valueLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: _primaryColor,
              inactiveTrackColor: _borderColor,
              thumbColor: _primaryColor,
              overlayColor: _primaryColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _testing ? null : _testVoice,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_testing)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      backgroundColor: Colors.white.withOpacity(0.3),
                    ),
                  )
                else
                  const Icon(
                    Icons.play_circle_filled_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                const SizedBox(width: 12),
                Text(
                  _testing ? 'Testing Voice...' : 'Test Voice Settings',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildAnnouncementsList() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
    child: _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Voice Announcements',
              style: TextStyle(
                color: _textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'All voice features included:',
              style: TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ),
          _buildAnnouncementItem('Workout start with details'),
          _buildAnnouncementItem('Round start and end'),
          _buildAnnouncementItem('Set start and end with names'),
          _buildAnnouncementItem('Rest periods'),
          _buildAnnouncementItem('Time remaining (10s, 5s, 3-2-1)'),
          _buildAnnouncementItem('Halfway point for long sets'),
          _buildAnnouncementItem('Pause and resume'),
          _buildAnnouncementItem('Workout completion with stats'),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );

  Widget _buildAnnouncementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: _accentColor.withOpacity(0.4)),
            ),
            child: Icon(Icons.check_rounded, color: _successColor, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
