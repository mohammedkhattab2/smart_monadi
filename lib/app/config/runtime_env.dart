import 'package:flutter_dotenv/flutter_dotenv.dart';

class RuntimeEnv {
  RuntimeEnv._();

  static String _dartDefine(String key) {
    if (key == 'ETA_SERVICE_URL') {
      return const String.fromEnvironment('ETA_SERVICE_URL').trim();
    }
    if (key == 'DIRECTIONS_API_KEY') {
      return const String.fromEnvironment('DIRECTIONS_API_KEY').trim();
    }
    if (key == 'DIRECTIONS_BACKEND_URL') {
      return const String.fromEnvironment('DIRECTIONS_BACKEND_URL').trim();
    }
    return '';
  }

  static String read(String key, {String fallback = ''}) {
    final defineValue = _dartDefine(key);
    if (defineValue.isNotEmpty) {
      return defineValue;
    }

    final value = dotenv.maybeGet(key)?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }

    return fallback;
  }

  static String get etaServiceUrl => read('ETA_SERVICE_URL');
  static String get directionsApiKey => read('DIRECTIONS_API_KEY');
  static String get directionsBackendUrl {
    final defineDirections = _dartDefine('DIRECTIONS_BACKEND_URL');
    if (defineDirections.isNotEmpty) {
      return defineDirections;
    }

    // Keep backend host consistent in device runs that only pass ETA_SERVICE_URL.
    final defineEta = _dartDefine('ETA_SERVICE_URL');
    if (defineEta.isNotEmpty) {
      return defineEta;
    }

    return read('DIRECTIONS_BACKEND_URL', fallback: etaServiceUrl);
  }
}
