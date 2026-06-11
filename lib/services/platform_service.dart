import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformService {
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static bool get isWeb => kIsWeb;
  static bool get supportsWakeLock => isMobile;
  static bool get supportsHapticFeedback => isMobile;
}
