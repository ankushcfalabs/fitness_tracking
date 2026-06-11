import 'package:flutter/foundation.dart';

class ErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _logError(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _logError(error, stack);
      return true;
    };
  }

  static void _logError(Object error, StackTrace? stack) {
    if (kDebugMode) {
      debugPrint('Error: $error');
      debugPrint('Stack: $stack');
    }
    // In production, you would send to crash reporting service
    // like Firebase Crashlytics, Sentry, etc.
  }

  static void handleError(Object error, StackTrace stack) {
    _logError(error, stack);
  }
}
