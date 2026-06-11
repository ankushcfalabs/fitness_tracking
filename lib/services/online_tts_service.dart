import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class OnlineTTSService {
  static final OnlineTTSService _instance = OnlineTTSService._internal();
  factory OnlineTTSService() => _instance;
  OnlineTTSService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Directory? _cacheDir;

  Future<void> _initCache() async {
    if (_cacheDir != null) return;
    final tempDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${tempDir.path}/tts_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  String _getCacheKey(String text, String languageCode) {
    final content = '$text-$languageCode';
    return md5.convert(utf8.encode(content)).toString();
  }

  Future<File?> _getCachedFile(String cacheKey) async {
    await _initCache();
    final file = File('${_cacheDir!.path}/$cacheKey.mp3');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<File> _cacheFile(String cacheKey, List<int> bytes) async {
    await _initCache();
    final file = File('${_cacheDir!.path}/$cacheKey.mp3');
    await file.writeAsBytes(bytes);
    return file;
  }

  // Map language codes to Google TTS language codes
  String _getGoogleLanguageCode(String languageCode) {
    final mapping = {
      'en-IN': 'en',
      'hi-IN': 'hi',
      'bn-IN': 'bn',
      'te-IN': 'te',
      'mr-IN': 'mr',
      'ta-IN': 'ta',
      'gu-IN': 'gu',
      'kn-IN': 'kn',
      'ml-IN': 'ml',
      'pa-IN': 'pa',
      'or-IN': 'or',
      'as-IN': 'as',
      'ur-IN': 'ur',
      'ne-NP': 'ne',
      'si-LK': 'si',
    };
    return mapping[languageCode] ?? languageCode.split('-')[0];
  }

  Future<bool> speak(String text, String languageCode) async {
    if (_isPlaying) {
      await stop();
    }

    try {
      final lang = _getGoogleLanguageCode(languageCode);
      final cacheKey = _getCacheKey(text, lang);
      
      // Check cache first
      File? audioFile = await _getCachedFile(cacheKey);
      
      if (audioFile == null) {
        // Download from online TTS
        final url = Uri.parse(
          'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$lang&q=${Uri.encodeComponent(text)}'
        );

        debugPrint('OnlineTTS: Downloading audio for "$text" in $lang');
        
        final response = await http.get(
          url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          // Cache the audio file
          audioFile = await _cacheFile(cacheKey, response.bodyBytes);
          debugPrint('OnlineTTS: Audio cached at ${audioFile.path}');
        } else {
          debugPrint('OnlineTTS: HTTP error ${response.statusCode}');
          return false;
        }
      } else {
        debugPrint('OnlineTTS: Using cached audio for "$text"');
      }

      // Play audio
      _isPlaying = true;
      await _audioPlayer.play(DeviceFileSource(audioFile.path));
      
      // Wait for completion
      await _audioPlayer.onPlayerComplete.first;
      _isPlaying = false;

      debugPrint('OnlineTTS: Successfully played audio');
      return true;
    } catch (e) {
      debugPrint('OnlineTTS: Error: $e');
      _isPlaying = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('OnlineTTS: Error stopping: $e');
    }
  }

  Future<void> preloadCommonPhrases(String languageCode) async {
    final commonPhrases = [
      'Starting workout',
      'Round 1',
      'Round 2',
      'Round 3',
      'Round 4',
      'Rest',
      'Get ready',
      'Workout complete',
      '3',
      '2',
      '1',
      'Go',
      'Halfway there',
    ];

    debugPrint('OnlineTTS: Preloading common phrases for $languageCode');
    for (final phrase in commonPhrases) {
      try {
        final lang = _getGoogleLanguageCode(languageCode);
        final cacheKey = _getCacheKey(phrase, lang);
        final cached = await _getCachedFile(cacheKey);
        
        if (cached == null) {
          final url = Uri.parse(
            'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=$lang&q=${Uri.encodeComponent(phrase)}'
          );
          
          final response = await http.get(
            url,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          ).timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            await _cacheFile(cacheKey, response.bodyBytes);
            debugPrint('OnlineTTS: Preloaded "$phrase"');
          }
        }
      } catch (e) {
        debugPrint('OnlineTTS: Error preloading "$phrase": $e');
      }
    }
    debugPrint('OnlineTTS: Preloading complete');
  }

  Future<void> clearCache() async {
    await _initCache();
    if (await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
      debugPrint('OnlineTTS: Cache cleared');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
