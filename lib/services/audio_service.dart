import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:math';

enum AnnouncementType { voiceOnly, beepsOnly, voiceAndBeeps, silent }

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  bool _enabled = true;
  AnnouncementType _announcementType = AnnouncementType.voiceAndBeeps;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('sound_enabled') ?? true;
    final typeIndex = prefs.getInt('announcement_type') ?? 2;
    _announcementType = AnnouncementType.values[typeIndex];
    debugPrint(
      'AudioService: Initialized - enabled: $_enabled, type: $_announcementType (index: $typeIndex)',
    );
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', enabled);
  }
  
  Future<void> setAnnouncementType(AnnouncementType type) async {
    _announcementType = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('announcement_type', type.index);
    debugPrint(
      'AudioService: Set announcement type to $type (index: ${type.index})',
    );
  }

  bool get enabled => _enabled;
  AnnouncementType get announcementType => _announcementType;
  
  bool get shouldPlayVoice => 
    _enabled &&
    (_announcementType == AnnouncementType.voiceOnly || 
    _announcementType == AnnouncementType.voiceAndBeeps);
    
  bool get shouldPlayBeeps => 
    _enabled &&
    (_announcementType == AnnouncementType.beepsOnly || 
    _announcementType == AnnouncementType.voiceAndBeeps);

  // Countdown beeps (3-2-1)
  Future<void> playCountdownBeep() async {
    if (!shouldPlayBeeps) {
      debugPrint('AudioService: Skipping beep (announcement type: $_announcementType)');
      return;
    }
    debugPrint('AudioService: Playing countdown beep');
    await _playTone(800, 0.15);
  }

  // Warning beep (time running out)
  Future<void> playWarningBeep() async {
    if (!shouldPlayBeeps) {
      debugPrint('AudioService: Skipping warning beep (type: $_announcementType)');
      return;
    }
    debugPrint('AudioService: Playing warning beep (1000Hz)');
    await _playTone(1000, 0.2);
  }

  // Work start beep (high pitch)
  Future<void> playStartBeep() async {
    if (!shouldPlayBeeps) {
      debugPrint('AudioService: Skipping start beep (type: $_announcementType)');
      return;
    }
    debugPrint('AudioService: Playing start beep (1200Hz - HIGH)');
    await _playTone(1200, 0.3);
  }

  // Rest/End beep (low pitch)
  Future<void> playEndBeep() async {
    if (!shouldPlayBeeps) {
      debugPrint('AudioService: Skipping end beep (type: $_announcementType)');
      return;
    }
    debugPrint('AudioService: Playing end beep (600Hz - LOW)');
    await _playTone(600, 0.3);
  }

  // Round complete (double beep)
  Future<void> playRoundCompleteBeep() async {
    if (!shouldPlayBeeps) {
      debugPrint('AudioService: Skipping round complete beep (type: $_announcementType)');
      return;
    }
    debugPrint('AudioService: Playing round complete beep (DOUBLE)');
    await _playTone(900, 0.2);
    await Future.delayed(const Duration(milliseconds: 150));
    await _playTone(900, 0.2);
  }

  // Workout complete (success chime)
  Future<void> playSuccessChime() async {
    if (!shouldPlayBeeps) {
      debugPrint('AudioService: Skipping success chime (type: $_announcementType)');
      return;
    }
    debugPrint('AudioService: Playing success chime (TRIPLE)');
    await _playTone(800, 0.15);
    await Future.delayed(const Duration(milliseconds: 100));
    await _playTone(1000, 0.15);
    await Future.delayed(const Duration(milliseconds: 100));
    await _playTone(1200, 0.3);
  }

  // Halfway beep
  Future<void> playHalfwayBeep() async {
    if (!shouldPlayBeeps) {
      debugPrint('AudioService: Skipping halfway beep (type: $_announcementType)');
      return;
    }
    debugPrint('AudioService: Playing halfway beep (1000Hz)');
    await _playTone(1000, 0.25);
  }

  Future<void> _playTone(int frequency, double duration) async {
    try {
      debugPrint(
        'AudioService: _playTone called - frequency: $frequency, duration: $duration',
      );
      
      // Create a new player for each beep to avoid state issues
      final player = AudioPlayer();
      
      try {
        await player.setVolume(1.0);
        await player.setReleaseMode(ReleaseMode.stop);
        
        // Generate simple beep using data URL
        final beepData = _generateBeepData(frequency, duration);
        await player.play(BytesSource(Uint8List.fromList(beepData)));
        
        // Add haptic feedback
        if (frequency >= 1000) {
          await HapticFeedback.heavyImpact();
        } else if (frequency >= 800) {
          await HapticFeedback.mediumImpact();
        } else {
          await HapticFeedback.lightImpact();
        }
        
        await Future.delayed(Duration(milliseconds: (duration * 1000).toInt()));
        debugPrint('AudioService: Beep played successfully');
      } finally {
        // Dispose player after use
        await player.dispose();
      }
    } catch (e) {
      debugPrint('AudioService: Error playing beep: $e');
      // Fallback to system sound
      try {
        await SystemSound.play(SystemSoundType.click);
        await HapticFeedback.heavyImpact();
      } catch (e2) {
        debugPrint('AudioService: Fallback also failed: $e2');
      }
    }
  }
  
  List<int> _generateBeepData(int frequency, double duration) {
    // Generate a simple sine wave beep
    const int sampleRate = 44100;
    final int numSamples = (sampleRate * duration).toInt();
    final List<int> samples = [];
    
    // WAV header
    samples.addAll([82, 73, 70, 70]); // "RIFF"
    samples.addAll(_intToBytes(36 + numSamples * 2, 4)); // File size
    samples.addAll([87, 65, 86, 69]); // "WAVE"
    samples.addAll([102, 109, 116, 32]); // "fmt "
    samples.addAll(_intToBytes(16, 4)); // Subchunk size
    samples.addAll(_intToBytes(1, 2)); // Audio format (PCM)
    samples.addAll(_intToBytes(1, 2)); // Num channels (mono)
    samples.addAll(_intToBytes(sampleRate, 4)); // Sample rate
    samples.addAll(_intToBytes(sampleRate * 2, 4)); // Byte rate
    samples.addAll(_intToBytes(2, 2)); // Block align
    samples.addAll(_intToBytes(16, 2)); // Bits per sample
    samples.addAll([100, 97, 116, 97]); // "data"
    samples.addAll(_intToBytes(numSamples * 2, 4)); // Data size
    
    // Generate sine wave samples
    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double value = 0.5 * 32767 * (i < numSamples * 0.9 ? 1.0 : (numSamples - i) / (numSamples * 0.1)); // Fade out
      final int sample = (value * sin(3.14159 * 2 * frequency * t)).toInt();
      samples.addAll(_intToBytes(sample, 2));
    }
    
    return samples;
  }
  
  List<int> _intToBytes(int value, int numBytes) {
    final List<int> bytes = [];
    for (int i = 0; i < numBytes; i++) {
      bytes.add((value >> (8 * i)) & 0xFF);
    }
    return bytes;
  }

  void dispose() {
    // No need to dispose player as we create new ones for each beep
  }
}
