import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'voice_service_new.dart';

/// Plays pre-recorded MP3 clips for English male/female announcements.
/// Returns false only when NO clip exists, so caller uses flutter_tts.
class EnglishVoiceService {
  static final EnglishVoiceService _instance = EnglishVoiceService._internal();
  factory EnglishVoiceService() => _instance;
  EnglishVoiceService._internal();

  AudioPlayer? _player;
  bool _stopped = false;

  // ── Male clip paths (AssetSource path — no leading 'assets/')
  static const _male = <String, String>{
    '1':                   'sounds/male/1-male.mp3',
    '2':                   'sounds/male/2-male.mp3',
    '3':                   'sounds/male/3-male.mp3',
    '5seconds':            'sounds/male/5-seconds-male.mp3',
    '10seconds':           'sounds/male/10-seconds-male.mp3',
    'begin':               'sounds/male/begin-male.mp3',
    'go':                  'sounds/male/go-male.mp3',
    'greatjob':            'sounds/male/great-job-male.mp3',
    'halfway':             'sounds/male/halfway-there-male.mp3',
    'paused':              'sounds/male/paused-male.mp3',
    'rest':                'sounds/male/rest-male.mp3',
    'resuming':            'sounds/male/resuming-male.mp3',
    'round1':              'sounds/male/round-1-male.mp3',
    'round2':              'sounds/male/round-2-male.mp3',
    'round1complete':      'sounds/male/round-1-complete-male.mp3',
    'set1complete':        'sounds/male/set-1-complete-male.mp3',
    'pushupcomplete':      'sounds/male/push-ups-complete-male.mp3',
    'workoutcomplete':     'sounds/male/workout-complete-male.mp3',
  };

  // ── Female clip paths
  static const _female = <String, String>{
    '1':                   'sounds/female/1-female.mp3',
    '2':                   'sounds/female/2-female.mp3',
    '3':                   'sounds/female/3-female.mp3',
    '5seconds':            'sounds/female/5-seconds-female.mp3',
    '10seconds':           'sounds/female/10-seconds-female.mp3',
    'begin':               'sounds/female/begin-female.mp3',
    'go':                  'sounds/female/go-female.mp3',
    'greatjob':            'sounds/female/great-job-female.mp3',
    'halfway':             'sounds/female/halfway-there-female.mp3',
    'paused':              'sounds/female/paused-female.mp3',
    'rest':                'sounds/female/rest-female.mp3',
    'resuming':            'sounds/female/resuming-female.mp3',
    'round1':              'sounds/female/round-1-female.mp3',
    'round2':              'sounds/female/round-2-female.mp3',
    'round1complete':      'sounds/female/round-1-complete-female.mp3',
    'set1complete':        'sounds/female/set-1-complete-female.mp3',
    'pushupcomplete':      'sounds/female/push-ups-complete-female.mp3',
    'workoutcomplete':     'sounds/female/workout-complete-female.mp3',
  };

  Map<String, String> _mapFor(VoiceType v) =>
      (v == VoiceType.male1 || v == VoiceType.male2) ? _male : _female;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Resolves [text] to ordered clip list and plays sequentially.
  /// Returns true if ≥1 clip played, false if no clip found.
  Future<bool> play(String text, VoiceType voiceType, double volume) async {
    final map = _mapFor(voiceType);
    final clips = _resolve(text.trim(), map);
    if (clips.isEmpty) return false;

    _stopped = false;

    // Dispose any previous player cleanly before creating a new one
    await _disposePlayer();

    for (final clip in clips) {
      if (_stopped) break;
      if (clip == '__skip__') continue;

      // Fresh player per clip — avoids Android IllegalStateException
      // on reused/disposed MediaPlayer instances
      final player = AudioPlayer();
      try {
        await player.setVolume(volume);
        await player.setReleaseMode(ReleaseMode.release);
        _player = player;
        await player.play(AssetSource(clip));
        await player.onPlayerComplete.first;
      } catch (e) {
        debugPrint('EnglishVoiceService: error playing $clip → $e');
      } finally {
        await player.dispose();
        if (_player == player) _player = null;
      }
    }
    return true;
  }

  Future<void> _disposePlayer() async {
    final p = _player;
    _player = null;
    if (p != null) {
      try { await p.stop(); } catch (_) {}
      try { await p.dispose(); } catch (_) {}
    }
  }

  Future<void> stop() async {
    _stopped = true;
    await _disposePlayer();
  }

  Future<void> dispose() async {
    _stopped = true;
    await _disposePlayer();
  }

  // ── Resolver ───────────────────────────────────────────────────────────────
  // Maps every exact string from VoiceServiceNew announce methods to clip keys.

  List<String> _resolve(String text, Map<String, String> map) {
    final t = text.toLowerCase().trim();

    // announceCountdown(n) + announceTimeRemaining(≤3)  →  speak('$n')
    if (t == '1') return _c(['1'], map);
    if (t == '2') return _c(['2'], map);
    if (t == '3') return _c(['3'], map);

    // announceTimeRemaining(10)  →  speak('10 seconds remaining.')
    if (t.startsWith('10 second')) return _c(['10seconds'], map);

    // announceTimeRemaining(5)  →  speak('5 seconds.')
    if (t.startsWith('5 second')) return _c(['5seconds'], map);

    // announceRoundStart(round, total)  →  speak('Round $round of $total. Begin!')
    final rsMatch = RegExp(r'^round (\d+) of \d+').firstMatch(t);
    if (rsMatch != null) {
      final n = rsMatch.group(1)!;
      final rKey = 'round$n';
      if (map.containsKey(rKey)) return _c([rKey, 'begin'], map);
      // round 3+ — no round clip yet, play begin only so gender stays correct
      return _c(['begin'], map);
    }

    // announceRoundEnd(round, total)  →  speak('Round $round complete.')
    final reMatch = RegExp(r'^round (\d+) complete\.?$').firstMatch(t);
    if (reMatch != null) {
      final n = reMatch.group(1)!;
      final key = 'round${n}complete';
      if (map.containsKey(key)) return _c([key], map);
      // No clip for this round number — skip TTS to avoid wrong gender
      return ['__skip__'];
    }

    // announceSetEnd(name)  →  speak('$name complete.')
    // 'set N complete.' — match any set number with regex
    final setMatch = RegExp(r'^set (\d+) complete\.$').firstMatch(t);
    if (setMatch != null) {
      final n = setMatch.group(1)!;
      final key = 'set${n}complete';
      // If we have a clip for this set number, play it
      if (map.containsKey(key)) return _c([key], map);
      // No clip for this set number — return [] but DO NOT fall to TTS
      // Caller will skip silently (set complete is not critical to announce)
      return ['__skip__'];
    }
    // Named set end e.g. 'push ups complete.' 'biceps complete.' etc.
    if (t == 'push ups complete.' || t == 'push-ups complete.') return _c(['pushupcomplete'], map);
    // Any other named set end — skip TTS to avoid wrong gender
    if (t.endsWith(' complete.') && !t.startsWith('round') &&
        !t.startsWith('workout') && !t.startsWith('final')) return ['__skip__'];

    // announceSetStart(name)  →  speak('$name. Go!')
    // Name is dynamic — play 'go' clip so gender is always correct
    if (t.endsWith('. go!'))          return _c(['go'], map);

    // announceHalfway()  →  speak('Halfway there!')
    if (t.startsWith('halfway'))      return _c(['halfway'], map);

    // announcePaused()  →  speak('Workout paused.')
    if (t.contains('workout paused')) return _c(['paused'], map);

    // announceResumed()  →  speak('Resuming.')
    if (t.startsWith('resum'))        return _c(['resuming'], map);

    // announceRest(seconds)
    //   ≤5  →  speak('Rest $n seconds.')
    //   >5  →  speak('Rest time. $n seconds.')
    if (t.startsWith('rest 5 second'))                          return _c(['rest', '5seconds'], map);
    if (t.startsWith('rest ') && !t.startsWith('rest time'))    return _c(['rest'], map);
    if (t.startsWith('rest time'))                              return _c(['rest'], map);

    // announceWorkoutComplete  →  speak('Workout complete! …Great job!')
    if (t.startsWith('workout complete')) return _c(['workoutcomplete', 'greatjob'], map);

    // For English: all remaining dynamic texts (workout start, round break,
    // final round complete) — skip TTS entirely to avoid wrong gender bleed.
    // Return ['__skip__'] so play() returns true and TTS is never called.
    return ['__skip__'];
  }

  /// Returns asset paths for [keys] that exist in [map], skipping missing ones.
  /// '__skip__' is a sentinel that tells play() to return true (handled) without
  /// playing anything — prevents TTS fallback for English unknown set names.
  List<String> _c(List<String> keys, Map<String, String> map) {
    final result = <String>[];
    for (final k in keys) {
      if (k == '__skip__') {
        result.add('__skip__');
        continue;
      }
      final path = map[k];
      if (path != null) result.add(path);
    }
    return result;
  }
}
