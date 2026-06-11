class VoiceLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const VoiceLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}

const List<VoiceLanguage> indianLanguages = [
  VoiceLanguage(code: 'en-IN', name: 'English (India)', nativeName: 'English', flag: '🇮🇳'),
  VoiceLanguage(code: 'hi-IN', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
  VoiceLanguage(code: 'bn-IN', name: 'Bengali', nativeName: 'বাংলা', flag: '🇮🇳'),
  VoiceLanguage(code: 'te-IN', name: 'Telugu', nativeName: 'తెలుగు', flag: '🇮🇳'),
  VoiceLanguage(code: 'mr-IN', name: 'Marathi', nativeName: 'मराठी', flag: '🇮🇳'),
  VoiceLanguage(code: 'ta-IN', name: 'Tamil', nativeName: 'தமிழ்', flag: '🇮🇳'),
  VoiceLanguage(code: 'gu-IN', name: 'Gujarati', nativeName: 'ગુજરાતી', flag: '🇮🇳'),
  VoiceLanguage(code: 'kn-IN', name: 'Kannada', nativeName: 'ಕನ್ನಡ', flag: '🇮🇳'),
  VoiceLanguage(code: 'ml-IN', name: 'Malayalam', nativeName: 'മലയാളം', flag: '🇮🇳'),
  VoiceLanguage(code: 'pa-IN', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', flag: '🇮🇳'),
  VoiceLanguage(code: 'or-IN', name: 'Odia', nativeName: 'ଓଡ଼ିଆ', flag: '🇮🇳'),
  VoiceLanguage(code: 'as-IN', name: 'Assamese', nativeName: 'অসমীয়া', flag: '🇮🇳'),
  VoiceLanguage(code: 'ur-IN', name: 'Urdu', nativeName: 'اردو', flag: '🇮🇳'),
  VoiceLanguage(code: 'ne-NP', name: 'Nepali', nativeName: 'नेपाली', flag: '🇳🇵'),
  VoiceLanguage(code: 'si-LK', name: 'Sinhala', nativeName: 'සිංහල', flag: '🇱🇰'),
];
