import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AnnouncementMode {
  voiceOnly,
  beepsOnly,
  voiceAndBeeps,
  silent,
}

enum VoiceType {
  male1,
  male2,
  female1,
  female2,
}

class VoiceServiceNew {
  static final VoiceServiceNew _instance = VoiceServiceNew._internal();
  factory VoiceServiceNew() => _instance;
  VoiceServiceNew._internal();

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  double _speechRate = 0.52;
  double _volume = 1.0;
  String _language = 'en-IN';
  List<dynamic> _availableVoices = [];
  String? _selectedVoice;
  AnnouncementMode _announcementMode = AnnouncementMode.voiceAndBeeps;
  VoiceType _voiceType = VoiceType.female1;

  bool get enabled => _enabled;
  double get volume => _volume;
  double get speechRate => _speechRate;
  String get language => _language;
  List<dynamic> get availableVoices => _availableVoices;
  String? get selectedVoice => _selectedVoice;
  AnnouncementMode get announcementMode => _announcementMode;
  VoiceType get voiceType => _voiceType;
  
  bool get shouldPlayVoice => _enabled && (_announcementMode == AnnouncementMode.voiceOnly || _announcementMode == AnnouncementMode.voiceAndBeeps);
  bool get shouldPlayBeeps => _enabled && (_announcementMode == AnnouncementMode.beepsOnly || _announcementMode == AnnouncementMode.voiceAndBeeps);

  Future<void> init() async {
    await _loadSettings();
    await _loadAvailableVoices();
    await _applySettings();
  }

  Future<void> _loadAvailableVoices() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        _availableVoices = voices;
      }
    } catch (e) {
      _availableVoices = [];
    }
  }

  Future<void> _applySettings() async {
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(_volume);
    
    // Apply pitch based on voice type
    final pitchValue = _getVoiceTypePitch();
    await _tts.setPitch(pitchValue);
    
    // Try to find and set appropriate voice based on language and voice type
    await _setVoiceForLanguageAndType();
    
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ],
      IosTextToSpeechAudioMode.spokenAudio,
    );
  }
  
  Future<void> _setVoiceForLanguageAndType() async {
    if (_availableVoices.isEmpty) {
      await _loadAvailableVoices();
    }
    
    final isMale = _voiceType == VoiceType.male1 || _voiceType == VoiceType.male2;
    final baseLanguage = _language.split('-')[0];
    
    // Find voices matching the current language
    final matchingVoices = _availableVoices.where((voice) {
      final locale = voice['locale']?.toString() ?? '';
      return locale.startsWith(baseLanguage) || locale.startsWith(_language);
    }).toList();
    
    if (matchingVoices.isEmpty) return;
    
    // Try to find voice matching gender preference
    dynamic selectedVoice;
    
    for (final voice in matchingVoices) {
      final name = voice['name']?.toString().toLowerCase() ?? '';
      
      if (isMale) {
        // Look for male voice indicators
        if (name.contains('male') && !name.contains('female')) {
          selectedVoice = voice;
          break;
        }
      } else {
        // Look for female voice indicators
        if (name.contains('female')) {
          selectedVoice = voice;
          break;
        }
      }
    }
    
    // If no gender-specific voice found, use first available voice for language
    selectedVoice ??= matchingVoices.first;
    
    try {
      await _tts.setVoice({
        "name": selectedVoice['name'],
        "locale": selectedVoice['locale']
      });
      _selectedVoice = selectedVoice['name'];
    } catch (e) {
      // Voice setting failed, will use default
    }
  }
  
  double _getVoiceTypePitch() {
    switch (_voiceType) {
      case VoiceType.male1:
        return 0.5;
      case VoiceType.male2:
        return 0.65;
      case VoiceType.female1:
        return 1.1;
      case VoiceType.female2:
        return 1.2;
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('voice_enabled') ?? true;
    _speechRate = prefs.getDouble('voice_speed') ?? 0.52;
    _volume = prefs.getDouble('voice_volume') ?? 1.0;
    _language = prefs.getString('voice_language') ?? 'en-IN';
    _selectedVoice = prefs.getString('selected_voice');
    
    final modeIndex = prefs.getInt('announcement_mode') ?? 2;
    _announcementMode = AnnouncementMode.values[modeIndex.clamp(0, 3)];
    
    final voiceTypeIndex = prefs.getInt('voice_type') ?? 2;
    _voiceType = VoiceType.values[voiceTypeIndex.clamp(0, 3)];
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_enabled', _enabled);
    await prefs.setDouble('voice_speed', _speechRate);
    await prefs.setDouble('voice_volume', _volume);
    await prefs.setString('voice_language', _language);
    if (_selectedVoice != null) {
      await prefs.setString('selected_voice', _selectedVoice!);
    }
    await prefs.setInt('announcement_mode', _announcementMode.index);
    await prefs.setInt('announcement_type', _announcementMode.index);
    await prefs.setInt('voice_type', _voiceType.index);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _saveSettings();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 2.0);
    await _tts.setSpeechRate(_speechRate);
    await _saveSettings();
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
    await _saveSettings();
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    await _tts.setLanguage(_language);
    await _setVoiceForLanguageAndType();
    await _saveSettings();
  }

  Future<void> setVoiceType(VoiceType type) async {
    _voiceType = type;
    await _applySettings();
    await _saveSettings();
  }
  
  Future<void> setAnnouncementMode(AnnouncementMode mode) async {
    _announcementMode = mode;
    await _saveSettings();
  }
  
  Future<void> setVoice(String voiceName) async {
    _selectedVoice = voiceName;
    await _applySettings();
    await _saveSettings();
  }

  Future<void> speak(String text) async {
    if (!_enabled || text.isEmpty || _announcementMode == AnnouncementMode.silent) return;
    if (!shouldPlayVoice) return;
    await _tts.stop();
    await _tts.speak(text);
  }
  
  String getVoiceTypeName(VoiceType type) {
    switch (type) {
      case VoiceType.male1:
        return '👨 Male Voice 1 (Deep)';
      case VoiceType.male2:
        return '👨 Male Voice 2 (Standard)';
      case VoiceType.female1:
        return '👩 Female Voice 1 (Standard)';
      case VoiceType.female2:
        return '👩 Female Voice 2 (High)';
    }
  }
  
  String getAnnouncementModeName(AnnouncementMode mode) {
    switch (mode) {
      case AnnouncementMode.voiceOnly:
        return '🗣️ Voice Only';
      case AnnouncementMode.beepsOnly:
        return '🔔 Beeps Only';
      case AnnouncementMode.voiceAndBeeps:
        return '🔊 Voice + Beeps';
      case AnnouncementMode.silent:
        return '🔇 Silent';
    }
  }
  
  String getAnnouncementModeDescription(AnnouncementMode mode) {
    switch (mode) {
      case AnnouncementMode.voiceOnly:
        return 'Spoken announcements only';
      case AnnouncementMode.beepsOnly:
        return 'Audio tones without voice';
      case AnnouncementMode.voiceAndBeeps:
        return 'Voice with sound effects';
      case AnnouncementMode.silent:
        return 'No audio announcements';
    }
  }

  Future<void> announceWorkoutStart(String name, int rounds, int sets) =>
      speak('Starting $name. $rounds rounds, $sets sets per round. Get ready!');

  Future<void> announceCountdown(int seconds) => speak('$seconds');

  Future<void> announceRoundStart(int round, int total) =>
      speak('Round $round of $total. Begin!');

  Future<void> announceSetStart(String name) => speak('$name. Go!');

  Future<void> announceSetEnd(String name) => speak('$name complete.');

  Future<void> announceRest(int seconds) {
    if (seconds <= 5) {
      return speak('Rest $seconds seconds.');
    }
    return speak('Rest time. $seconds seconds.');
  }

  Future<void> announceRoundEnd(int round, int total) =>
      speak('Round $round complete.');

  Future<void> announceRoundBreak(int seconds, int nextRound, int total) {
    if (nextRound <= total) {
      return speak('Round break. $seconds seconds. Next: round $nextRound.');
    }
    return speak('Final round complete. Rest $seconds seconds.');
  }

  Future<void> announceTimeRemaining(int seconds) {
    if (seconds == 10) {
      return speak('10 seconds remaining.');
    } else if (seconds == 5) {
      return speak('5 seconds.');
    } else if (seconds <= 3) {
      return speak('$seconds');
    }
    return Future.value();
  }

  Future<void> announceHalfway() => speak('Halfway there!');

  Future<void> announcePaused() => speak('Workout paused.');

  Future<void> announceResumed() => speak('Resuming.');

  Future<void> announceWorkoutComplete(String name, int duration) {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    final timeStr = minutes > 0 
        ? '$minutes minute${minutes > 1 ? 's' : ''} ${seconds > 0 ? 'and $seconds seconds' : ''}'
        : '$seconds seconds';
    return speak('Workout complete! You finished $name in $timeStr. Great job!');
  }

  Future<void> stop() => _tts.stop();

  Future<void> dispose() => _tts.stop();
}
