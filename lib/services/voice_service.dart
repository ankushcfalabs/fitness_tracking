import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'online_tts_service.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  final OnlineTTSService _onlineTts = OnlineTTSService();
  bool _isInitialized = false;
  String _currentLanguage = 'en-IN';
  bool _isEnabled = true;
  Map<String, String>? _selectedVoice;
  int _announcementType = 2; // 0=voiceOnly, 1=beepsOnly, 2=voiceAndBeeps, 3=silent
  bool _useOnlineTTS = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString('voice_language') ?? 'en-IN';
      _isEnabled = prefs.getBool('voice_enabled') ?? true;
      _announcementType =
          prefs.getInt('announcement_type') ??
          prefs.getInt('announcement_mode') ??
          2;
      final speechRate = prefs.getDouble('voice_speed') ?? 0.5;
      final volume = prefs.getDouble('voice_volume') ?? 1.0;
      final voiceTypeIndex = prefs.getInt('voice_type') ?? 2;
      
      await _tts.setVolume(volume.clamp(0.0, 1.0));
      await _tts.setSpeechRate(speechRate.clamp(0.1, 2.0));
      await _tts.setPitch(_pitchForVoiceType(voiceTypeIndex));
      
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          await _tts.setEngine('com.google.android.tts');
          // Set shared instance to true for better language support
          await _tts.setSharedInstance(true);
        }
      }
      
      // Try to set language with fallback
      await _setLanguageWithFallback(_currentLanguage);
      
      // Load saved voice
      final voiceName = prefs.getString('voice_name');
      final voiceLocale = prefs.getString('voice_locale');
      if (voiceName != null && voiceLocale != null) {
        _selectedVoice = {'name': voiceName, 'locale': voiceLocale};
        try {
          await _tts.setVoice(_selectedVoice!);
        } catch (e) {
          debugPrint('VoiceService: Could not set saved voice: $e');
        }
      }
      
      await _tts.awaitSpeakCompletion(true);
      _isInitialized = true;
      debugPrint('VoiceService: Initialized successfully with language: $_currentLanguage');
    } catch (e) {
      debugPrint('VoiceService: Initialization error: $e');
      _isInitialized = false;
    }
  }

  Future<void> init() async => await initialize();

  Future<void> _setLanguageWithFallback(String languageCode) async {
    try {
      // Try full locale first (e.g., "te-IN")
      var result = await _tts.setLanguage(languageCode);
      debugPrint('VoiceService: setLanguage($languageCode) result: $result');
      
      if (result == 0) {
        // Try base language (e.g., "te")
        final baseLanguage = languageCode.split('-')[0];
        debugPrint('VoiceService: Trying base language: $baseLanguage');
        result = await _tts.setLanguage(baseLanguage);
        debugPrint('VoiceService: setLanguage($baseLanguage) result: $result');
        
        if (result == 0) {
          // Try to find and set a matching voice
          final voices = await _tts.getVoices;
          if (voices != null && voices is List) {
            final matchingVoice = voices.firstWhere(
              (voice) {
                final locale = voice['locale']?.toString() ?? '';
                return locale.startsWith(baseLanguage) || locale.startsWith(languageCode);
              },
              orElse: () => null,
            );
            
            if (matchingVoice != null) {
              debugPrint('VoiceService: Found matching voice: ${matchingVoice['name']}');
              await _tts.setVoice({
                'name': matchingVoice['name'],
                'locale': matchingVoice['locale']
              });
              return;
            }
          }
          
          // Last resort: use English
          debugPrint('VoiceService: No voice found, using English fallback');
          await _tts.setLanguage('en-IN');
        }
      }
    } catch (e) {
      debugPrint('VoiceService: Error in _setLanguageWithFallback: $e');
      try {
        await _tts.setLanguage('en-IN');
      } catch (e2) {
        debugPrint('VoiceService: Even English fallback failed: $e2');
      }
    }
  }

  Future<void> setLanguage(String languageCode) async {
    try {
      _currentLanguage = languageCode;
      await _setLanguageWithFallback(languageCode);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('voice_language', languageCode);
      
      // Preload common phrases for regional languages
      final isRegionalLanguage = !languageCode.startsWith('en') && 
                                  !languageCode.startsWith('hi');
      if (isRegionalLanguage) {
        _onlineTts.preloadCommonPhrases(languageCode);
      }
      
      debugPrint('VoiceService: Language set to: $languageCode');
    } catch (e) {
      debugPrint('VoiceService: Error setting language: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_enabled', enabled);
  }
  
  Future<void> reloadAnnouncementType() async {
    final prefs = await SharedPreferences.getInstance();
    _announcementType =
        prefs.getInt('announcement_type') ??
        prefs.getInt('announcement_mode') ??
        2;
    debugPrint('VoiceService: Reloaded announcement type: $_announcementType');
  }
  
  Future<List<Map<String, String>>> getAvailableVoices() async {
    try {
      final voices = await _tts.getVoices;
      if (voices == null || voices is! List) return [];
      return voices.map((v) => {
        'name': v['name']?.toString() ?? '',
        'locale': v['locale']?.toString() ?? '',
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  Future<void> setVoice(Map<String, String> voice) async {
    try {
      _selectedVoice = voice;
      await _tts.setVoice(voice);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('voice_name', voice['name'] ?? '');
      await prefs.setString('voice_locale', voice['locale'] ?? '');
    } catch (e) {
      // Fallback to default
    }
  }
  
  Map<String, String>? get selectedVoice => _selectedVoice;

  bool get isEnabled => _isEnabled;
  String get currentLanguage => _currentLanguage;
  
  bool get _shouldPlayVoice {
    // 0=voiceOnly, 1=beepsOnly, 2=voiceAndBeeps, 3=silent
    return _announcementType == 0 || _announcementType == 2;
  }

  double _pitchForVoiceType(int voiceTypeIndex) {
    switch (voiceTypeIndex) {
      case 0:
        return 0.5;
      case 1:
        return 0.65;
      case 2:
        return 1.1;
      case 3:
        return 1.2;
      default:
        return 1.0;
    }
  }

  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    if (!_shouldPlayVoice) {
      debugPrint(
        'VoiceService: Skipping voice (announcement type: $_announcementType)',
      );
      return;
    }
    
    try {
      // For non-English/Hindi languages, always try online TTS first
      final isRegionalLanguage = !_currentLanguage.startsWith('en') && 
                                  !_currentLanguage.startsWith('hi');
      
      if (isRegionalLanguage || _useOnlineTTS) {
        debugPrint('VoiceService: Trying online TTS for $_currentLanguage');
        final success = await _onlineTts.speak(text, _currentLanguage);
        if (success) {
          debugPrint('VoiceService: Online TTS succeeded');
          return;
        }
        debugPrint('VoiceService: Online TTS failed, trying local TTS');
      }
      
      // Use local TTS
      await _tts.stop();
      await _setLanguageWithFallback(_currentLanguage);
      debugPrint('VoiceService: Speaking "$text" in $_currentLanguage');
      await _tts.speak(text);
    } catch (e) {
      debugPrint('VoiceService: Error: $e');
    }
  }

  String _getLocalizedText(String key, {Map<String, dynamic>? params}) {
    final texts = _languageTexts[_currentLanguage] ?? _languageTexts['en-IN']!;
    String text = texts[key] ?? key;
    
    if (params != null) {
      params.forEach((key, value) {
        text = text.replaceAll('{$key}', value.toString());
      });
    }
    
    return text;
  }

  static final Map<String, Map<String, String>> _languageTexts = {
    'en-IN': {
      'starting': 'Starting {workout}. {rounds} rounds, {sets} sets per round.',
      'round_start': 'Round {current} of {total}',
      'round_complete': 'Round {current} complete',
      'set_start': '{set}, go!',
      'set_complete': '{set} complete',
      'rest': 'Rest for {seconds} seconds',
      'round_break': 'Round break. Next round {next} of {total} in {seconds} seconds',
      'halfway': 'Halfway there',
      'paused': 'Paused',
      'resumed': 'Resumed',
      'complete': 'Workout complete! Total time: {minutes} minutes and {seconds} seconds. Great job!',
      'test': 'Workout starting in 3, 2, 1',
    },
    'hi-IN': {
      'starting': '{workout} शुरू हो रहा है। {rounds} राउंड, प्रति राउंड {sets} सेट।',
      'round_start': 'राउंड {current} का {total}',
      'round_complete': 'राउंड {current} पूरा हुआ',
      'set_start': '{set}, शुरू करें!',
      'set_complete': '{set} पूरा हुआ',
      'rest': '{seconds} सेकंड के लिए आराम करें',
      'round_break': 'राउंड ब्रेक। अगला राउंड {next} का {total}, {seconds} सेकंड में',
      'halfway': 'आधा रास्ता पूरा',
      'paused': 'रुका हुआ',
      'resumed': 'फिर से शुरू',
      'complete': 'वर्कआउट पूरा! कुल समय: {minutes} मिनट और {seconds} सेकंड। बहुत बढ़िया!',
      'test': 'वर्कआउट 3, 2, 1 में शुरू हो रहा है',
    },
    'bn-IN': {
      'starting': '{workout} শুরু হচ্ছে। {rounds} রাউন্ড, প্রতি রাউন্ডে {sets} সেট।',
      'round_start': 'রাউন্ড {current} এর {total}',
      'round_complete': 'রাউন্ড {current} সম্পূর্ণ',
      'set_start': '{set}, শুরু করুন!',
      'set_complete': '{set} সম্পূর্ণ',
      'rest': '{seconds} সেকেন্ডের জন্য বিশ্রাম নিন',
      'round_break': 'রাউন্ড বিরতি। পরবর্তী রাউন্ড {next} এর {total}, {seconds} সেকেন্ডে',
      'halfway': 'অর্ধেক পথ সম্পন্ন',
      'paused': 'থামানো হয়েছে',
      'resumed': 'আবার শুরু',
      'complete': 'ওয়ার্কআউট সম্পূর্ণ! মোট সময়: {minutes} মিনিট এবং {seconds} সেকেন্ড। দুর্দান্ত!',
      'test': 'ওয়ার্কআউট 3, 2, 1 এ শুরু হচ্ছে',
    },
    'te-IN': {
      'starting': '{workout} ప్రారంభమవుతోంది। {rounds} రౌండ్లు, ప్రతి రౌండ్‌కు {sets} సెట్లు।',
      'round_start': 'రౌండ్ {current} లో {total}',
      'round_complete': 'రౌండ్ {current} పూర్తయింది',
      'set_start': '{set}, ప్రారంభించండి!',
      'set_complete': '{set} పూర్తయింది',
      'rest': '{seconds} సెకన్ల పాటు విశ్రాంతి తీసుకోండి',
      'round_break': 'రౌండ్ విరామం। తదుపరి రౌండ్ {next} లో {total}, {seconds} సెకన్లలో',
      'halfway': 'సగం దూరం పూర్తయింది',
      'paused': 'పాజ్ చేయబడింది',
      'resumed': 'మళ్లీ ప్రారంభించబడింది',
      'complete': 'వర్కౌట్ పూర్తయింది! మొత్తం సమయం: {minutes} నిమిషాలు మరియు {seconds} సెకన్లు। అద్భుతం!',
      'test': 'వర్కౌట్ 3, 2, 1 లో ప్రారంభమవుతోంది',
    },
    'mr-IN': {
      'starting': '{workout} सुरू होत आहे। {rounds} राउंड, प्रत्येक राउंडमध्ये {sets} सेट।',
      'round_start': 'राउंड {current} चा {total}',
      'round_complete': 'राउंड {current} पूर्ण झाला',
      'set_start': '{set}, सुरू करा!',
      'set_complete': '{set} पूर्ण झाला',
      'rest': '{seconds} सेकंदांसाठी विश्रांती घ्या',
      'round_break': 'राउंड ब्रेक। पुढील राउंड {next} चा {total}, {seconds} सेकंदांत',
      'halfway': 'अर्धा मार्ग पूर्ण',
      'paused': 'थांबवले',
      'resumed': 'पुन्हा सुरू',
      'complete': 'वर्कआउट पूर्ण! एकूण वेळ: {minutes} मिनिटे आणि {seconds} सेकंद। उत्तम!',
      'test': 'वर्कआउट 3, 2, 1 मध्ये सुरू होत आहे',
    },
    'ta-IN': {
      'starting': '{workout} தொடங்குகிறது। {rounds} சுற்றுகள், ஒவ்வொரு சுற்றுக்கும் {sets} செட்கள்।',
      'round_start': 'சுற்று {current} இல் {total}',
      'round_complete': 'சுற்று {current} முடிந்தது',
      'set_start': '{set}, தொடங்குங்கள்!',
      'set_complete': '{set} முடிந்தது',
      'rest': '{seconds} விநாடிகள் ஓய்வு எடுங்கள்',
      'round_break': 'சுற்று இடைவெளி। அடுத்த சுற்று {next} இல் {total}, {seconds} விநாடிகளில்',
      'halfway': 'பாதி தூரம் முடிந்தது',
      'paused': 'இடைநிறுத்தப்பட்டது',
      'resumed': 'மீண்டும் தொடங்கப்பட்டது',
      'complete': 'உடற்பயிற்சி முடிந்தது! மொத்த நேரம்: {minutes} நிமிடங்கள் மற்றும் {seconds} விநாடிகள். அருமை!',
      'test': 'உடற்பயிற்சி 3, 2, 1 இல் தொடங்குகிறது',
    },
    'gu-IN': {
      'starting': '{workout} શરૂ થઈ રહ્યું છે। {rounds} રાઉન્ડ, દરેક રાઉન્ડમાં {sets} સેટ।',
      'round_start': 'રાઉન્ડ {current} નો {total}',
      'round_complete': 'રાઉન્ડ {current} પૂર્ણ થયો',
      'set_start': '{set}, શરૂ કરો!',
      'set_complete': '{set} પૂર્ણ થયો',
      'rest': '{seconds} સેકન્ડ માટે આરામ કરો',
      'round_break': 'રાઉન્ડ બ્રેક। આગામી રાઉન્ડ {next} નો {total}, {seconds} સેકન્ડમાં',
      'halfway': 'અડધો રસ્તો પૂર્ણ',
      'paused': 'થોભાવ્યું',
      'resumed': 'ફરી શરૂ',
      'complete': 'વર્કઆઉટ પૂર્ણ! કુલ સમય: {minutes} મિનિટ અને {seconds} સેકન્ડ। ખૂબ સરસ!',
      'test': 'વર્કઆઉટ 3, 2, 1 માં શરૂ થઈ રહ્યું છે',
    },
    'kn-IN': {
      'starting': '{workout} ಪ್ರಾರಂಭವಾಗುತ್ತಿದೆ। {rounds} ಸುತ್ತುಗಳು, ಪ್ರತಿ ಸುತ್ತಿಗೆ {sets} ಸೆಟ್‌ಗಳು।',
      'round_start': 'ಸುತ್ತು {current} ರ {total}',
      'round_complete': 'ಸುತ್ತು {current} ಪೂರ್ಣಗೊಂಡಿದೆ',
      'set_start': '{set}, ಪ್ರಾರಂಭಿಸಿ!',
      'set_complete': '{set} ಪೂರ್ಣಗೊಂಡಿದೆ',
      'rest': '{seconds} ಸೆಕೆಂಡುಗಳ ಕಾಲ ವಿಶ್ರಾಂತಿ ಪಡೆಯಿರಿ',
      'round_break': 'ಸುತ್ತಿನ ವಿರಾಮ। ಮುಂದಿನ ಸುತ್ತು {next} ರ {total}, {seconds} ಸೆಕೆಂಡುಗಳಲ್ಲಿ',
      'halfway': 'ಅರ್ಧ ದೂರ ಪೂರ್ಣಗೊಂಡಿದೆ',
      'paused': 'ವಿರಾಮಗೊಳಿಸಲಾಗಿದೆ',
      'resumed': 'ಮತ್ತೆ ಪ್ರಾರಂಭಿಸಲಾಗಿದೆ',
      'complete': 'ವರ್ಕೌಟ್ ಪೂರ್ಣಗೊಂಡಿದೆ! ಒಟ್ಟು ಸಮಯ: {minutes} ನಿಮಿಷಗಳು ಮತ್ತು {seconds} ಸೆಕೆಂಡುಗಳು। ಅದ್ಭುತ!',
      'test': 'ವರ್ಕೌಟ್ 3, 2, 1 ರಲ್ಲಿ ಪ್ರಾರಂಭವಾಗುತ್ತಿದೆ',
    },
    'ml-IN': {
      'starting': '{workout} ആരംഭിക്കുന്നു। {rounds} റൗണ്ടുകൾ, ഓരോ റൗണ്ടിനും {sets} സെറ്റുകൾ।',
      'round_start': 'റൗണ്ട് {current} ന്റെ {total}',
      'round_complete': 'റൗണ്ട് {current} പൂർത്തിയായി',
      'set_start': '{set}, ആരംഭിക്കൂ!',
      'set_complete': '{set} പൂർത്തിയായി',
      'rest': '{seconds} സെക്കൻഡ് വിശ്രമിക്കൂ',
      'round_break': 'റൗണ്ട് ഇടവേള। അടുത്ത റൗണ്ട് {next} ന്റെ {total}, {seconds} സെക്കൻഡിൽ',
      'halfway': 'പകുതി ദൂരം പൂർത്തിയായി',
      'paused': 'താൽക്കാലികമായി നിർത്തി',
      'resumed': 'വീണ്ടും ആരംഭിച്ചു',
      'complete': 'വർക്കൗട്ട് പൂർത്തിയായി! ആകെ സമയം: {minutes} മിനിറ്റും {seconds} സെക്കൻഡും। മികച്ചത്!',
      'test': 'വർക്കൗട്ട് 3, 2, 1 ൽ ആരംഭിക്കുന്നു',
    },
    'pa-IN': {
      'starting': '{workout} ਸ਼ੁਰੂ ਹੋ ਰਿਹਾ ਹੈ। {rounds} ਰਾਉਂਡ, ਹਰ ਰਾਉਂਡ ਵਿੱਚ {sets} ਸੈੱਟ।',
      'round_start': 'ਰਾਉਂਡ {current} ਦਾ {total}',
      'round_complete': 'ਰਾਉਂਡ {current} ਪੂਰਾ ਹੋਇਆ',
      'set_start': '{set}, ਸ਼ੁਰੂ ਕਰੋ!',
      'set_complete': '{set} ਪੂਰਾ ਹੋਇਆ',
      'rest': '{seconds} ਸਕਿੰਟਾਂ ਲਈ ਆਰਾਮ ਕਰੋ',
      'round_break': 'ਰਾਉਂਡ ਬ੍ਰੇਕ। ਅਗਲਾ ਰਾਉਂਡ {next} ਦਾ {total}, {seconds} ਸਕਿੰਟਾਂ ਵਿੱਚ',
      'halfway': 'ਅੱਧਾ ਰਸਤਾ ਪੂਰਾ',
      'paused': 'ਰੋਕਿਆ ਗਿਆ',
      'resumed': 'ਦੁਬਾਰਾ ਸ਼ੁਰੂ',
      'complete': 'ਵਰਕਆਉਟ ਪੂਰਾ! ਕੁੱਲ ਸਮਾਂ: {minutes} ਮਿੰਟ ਅਤੇ {seconds} ਸਕਿੰਟ। ਬਹੁਤ ਵਧੀਆ!',
      'test': 'ਵਰਕਆਉਟ 3, 2, 1 ਵਿੱਚ ਸ਼ੁਰੂ ਹੋ ਰਿਹਾ ਹੈ',
    },
    'ur-IN': {
      'starting': '{workout} شروع ہو رہا ہے۔ {rounds} راؤنڈز، ہر راؤنڈ میں {sets} سیٹس۔',
      'round_start': 'راؤنڈ {current} کا {total}',
      'round_complete': 'راؤنڈ {current} مکمل ہوا',
      'set_start': '{set}، شروع کریں!',
      'set_complete': '{set} مکمل ہوا',
      'rest': '{seconds} سیکنڈ کے لیے آرام کریں',
      'round_break': 'راؤنڈ بریک۔ اگلا راؤنڈ {next} کا {total}، {seconds} سیکنڈ میں',
      'halfway': 'آدھا راستہ مکمل',
      'paused': 'روکا گیا',
      'resumed': 'دوبارہ شروع',
      'complete': 'ورک آؤٹ مکمل! کل وقت: {minutes} منٹ اور {seconds} سیکنڈ۔ بہت اچھا!',
      'test': 'ورک آؤٹ 3، 2، 1 میں شروع ہو رہا ہے',
    },
    'or-IN': {
      'starting': '{workout} ଆରମ୍ଭ ହେଉଛି। {rounds} ରାଉଣ୍ଡ, ପ୍ରତି ରାଉଣ୍ଡରେ {sets} ସେଟ୍।',
      'round_start': 'ରାଉଣ୍ଡ {current} ର {total}',
      'round_complete': 'ରାଉଣ୍ଡ {current} ସମ୍ପୂର୍ଣ୍ଣ',
      'set_start': '{set}, ଆରମ୍ଭ କରନ୍ତୁ!',
      'set_complete': '{set} ସମ୍ପୂର୍ଣ୍ଣ',
      'rest': '{seconds} ସେକେଣ୍ଡ ପାଇଁ ବିଶ୍ରାମ କରନ୍ତୁ',
      'round_break': 'ରାଉଣ୍ଡ ବିରତି। ପରବର୍ତ୍ତୀ ରାଉଣ୍ଡ {next} ର {total}, {seconds} ସେକେଣ୍ଡରେ',
      'halfway': 'ଅଧା ଦୂରତା ସମ୍ପୂର୍ଣ୍ଣ',
      'paused': 'ବିରତ',
      'resumed': 'ପୁନଃ ଆରମ୍ଭ',
      'complete': 'ୱାର୍କଆଉଟ୍ ସମ୍ପୂର୍ଣ୍ଣ! ମୋଟ ସମୟ: {minutes} ମିନିଟ୍ ଏବଂ {seconds} ସେକେଣ୍ଡ। ବହୁତ ଭଲ!',
      'test': 'ୱାର୍କଆଉଟ୍ 3, 2, 1 ରେ ଆରମ୍ଭ ହେଉଛି',
    },
    'as-IN': {
      'starting': '{workout} আৰম্ভ হৈছে। {rounds} ৰাউণ্ড, প্ৰতি ৰাউণ্ডত {sets} ছেট।',
      'round_start': 'ৰাউণ্ড {current} ৰ {total}',
      'round_complete': 'ৰাউণ্ড {current} সম্পূৰ্ণ',
      'set_start': '{set}, আৰম্ভ কৰক!',
      'set_complete': '{set} সম্পূৰ্ণ',
      'rest': '{seconds} ছেকেণ্ডৰ বাবে জিৰণি লওক',
      'round_break': 'ৰাউণ্ড বিৰতি। পৰৱৰ্তী ৰাউণ্ড {next} ৰ {total}, {seconds} ছেকেণ্ডত',
      'halfway': 'আধা দূৰত্ব সম্পূৰ্ণ',
      'paused': 'বিৰতি',
      'resumed': 'পুনৰ আৰম্ভ',
      'complete': 'ৱৰ্কআউট সম্পূৰ্ণ! মুঠ সময়: {minutes} মিনিট আৰু {seconds} ছেকেণ্ড। অতি উত্তম!',
      'test': 'ৱৰ্কআউট 3, 2, 1 ত আৰম্ভ হৈছে',
    },
    'ne-NP': {
      'starting': '{workout} सुरु भइरहेको छ। {rounds} राउन्ड, प्रत्येक राउन्डमा {sets} सेट।',
      'round_start': 'राउन्ड {current} को {total}',
      'round_complete': 'राउन्ड {current} पूरा भयो',
      'set_start': '{set}, सुरु गर्नुहोस्!',
      'set_complete': '{set} पूरा भयो',
      'rest': '{seconds} सेकेन्डको लागि आराम गर्नुहोस्',
      'round_break': 'राउन्ड ब्रेक। अर्को राउन्ड {next} को {total}, {seconds} सेकेन्डमा',
      'halfway': 'आधा दूरी पूरा',
      'paused': 'रोकिएको',
      'resumed': 'फेरि सुरु',
      'complete': 'वर्कआउट पूरा! कुल समय: {minutes} मिनेट र {seconds} सेकेन्ड। धेरै राम्रो!',
      'test': 'वर्कआउट 3, 2, 1 मा सुरु भइरहेको छ',
    },
    'si-LK': {
      'starting': '{workout} ආරම්භ වෙමින්. {rounds} වටයන්, එක් වටයකට {sets} කට්ටල.',
      'round_start': 'වටය {current} හි {total}',
      'round_complete': 'වටය {current} සම්පූර්ණයි',
      'set_start': '{set}, ආරම්භ කරන්න!',
      'set_complete': '{set} සම්පූර්ණයි',
      'rest': 'තත්පර {seconds} ක් විවේක ගන්න',
      'round_break': 'වටය විවේකය. ඊළඟ වටය {next} හි {total}, තත්පර {seconds} කින්',
      'halfway': 'අඩක් දුර සම්පූර්ණයි',
      'paused': 'නවතා ඇත',
      'resumed': 'නැවත ආරම්භ කළා',
      'complete': 'ව්‍යායාමය සම්පූර්ණයි! මුළු කාලය: මිනිත්තු {minutes} සහ තත්පර {seconds}. විශිෂ්ටයි!',
      'test': 'ව්‍යායාමය 3, 2, 1 හි ආරම්භ වෙමින්',
    },
  };

  Future<void> stop() async {
    await _tts.stop();
    await _onlineTts.stop();
  }

  void setUseOnlineTTS(bool value) {
    _useOnlineTTS = value;
    debugPrint('VoiceService: Online TTS ${value ? "enabled" : "disabled"}');
  }

  bool get useOnlineTTS => _useOnlineTTS;

  Future<List<String>> getAvailableLanguages() async {
    try {
      final languages = await _tts.getLanguages;
      if (languages == null) {
        debugPrint('VoiceService: getLanguages returned null');
        return [];
      }
      final langList = languages.cast<String>();
      debugPrint('VoiceService: Available languages: $langList');
      return langList;
    } catch (e) {
      debugPrint('VoiceService: Error getting languages: $e');
      return [];
    }
  }

  Future<void> announceWorkoutStart(String workoutName, int rounds, int sets) async {
    await speak(_getLocalizedText('starting', params: {'workout': workoutName, 'rounds': rounds, 'sets': sets}));
  }

  Future<void> announceCountdown(int seconds) async {
    await speak('$seconds');
  }

  Future<void> announceRoundStart(int current, int total) async {
    await speak(_getLocalizedText('round_start', params: {'current': current, 'total': total}));
  }

  Future<void> announceRoundEnd(int current, int total) async {
    await speak(_getLocalizedText('round_complete', params: {'current': current}));
  }

  Future<void> announceSetStart(String setName) async {
    await speak(_getLocalizedText('set_start', params: {'set': setName}));
  }

  Future<void> announceSetEnd(String setName) async {
    await speak(_getLocalizedText('set_complete', params: {'set': setName}));
  }

  Future<void> announceRest(int seconds) async {
    await speak(_getLocalizedText('rest', params: {'seconds': seconds}));
  }

  Future<void> announceRoundBreak(int seconds, int nextRound, int total) async {
    await speak(_getLocalizedText('round_break', params: {'next': nextRound, 'total': total, 'seconds': seconds}));
  }

  Future<void> announceHalfway() async {
    await speak(_getLocalizedText('halfway'));
  }

  Future<void> announceTimeRemaining(int seconds) async {
    await speak('$seconds');
  }

  Future<void> announcePaused() async {
    await speak(_getLocalizedText('paused'));
  }

  Future<void> announceResumed() async {
    await speak(_getLocalizedText('resumed'));
  }

  Future<void> announceWorkoutComplete(String workoutName, int totalSeconds) async {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    await speak(_getLocalizedText('complete', params: {'minutes': minutes, 'seconds': seconds}));
  }

  Future<void> announceTest() async {
    await speak(_getLocalizedText('test'));
  }

  void dispose() {
    _tts.stop();
    _onlineTts.dispose();
  }
}
