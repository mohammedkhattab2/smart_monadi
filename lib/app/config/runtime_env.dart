import 'package:flutter_dotenv/flutter_dotenv.dart';

class RuntimeEnv {
  RuntimeEnv._();

  static String read(String key, {String fallback = ''}) {
    final value = dotenv.maybeGet(key)?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }

    constMapLookup:
    {
      // Fallback to --dart-define without hardcoding secrets in source.
      if (key == 'ETA_SERVICE_URL') {
        const val = String.fromEnvironment('ETA_SERVICE_URL');
        if (val.isNotEmpty) return val;
        break constMapLookup;
      }
      if (key == 'DIRECTIONS_API_KEY') {
        const val = String.fromEnvironment('DIRECTIONS_API_KEY');
        if (val.isNotEmpty) return val;
        break constMapLookup;
      }
      if (key == 'DIRECTIONS_BACKEND_URL') {
        const val = String.fromEnvironment('DIRECTIONS_BACKEND_URL');
        if (val.isNotEmpty) return val;
      }
    }

    return fallback;
  }

  static String get etaServiceUrl => read('ETA_SERVICE_URL');
  static String get directionsApiKey => read('DIRECTIONS_API_KEY');
  static String get directionsBackendUrl => read('DIRECTIONS_BACKEND_URL');
}
