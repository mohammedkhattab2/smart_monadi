import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:smart_monadi/features/driver/domain/services/eta_prediction_service.dart';

class HttpPythonEtaPredictionService implements EtaPredictionService {
  HttpPythonEtaPredictionService({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.trim(),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<int?> predictEtaMinutes({
    required double busLat,
    required double busLng,
    required double passengerLat,
    required double passengerLng,
    required double speedMetersPerSecond,
  }) async {
    if (_baseUrl.isEmpty) {
      return null;
    }

    final uri = Uri.parse('$_baseUrl/predict');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'busLat': busLat,
            'busLng': busLng,
            'passengerLat': passengerLat,
            'passengerLng': passengerLng,
            'speedMetersPerSecond': speedMetersPerSecond,
          }),
        )
        .timeout(const Duration(milliseconds: 1200));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final value = decoded['etaMinutes'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.ceil();
    }

    return null;
  }
}
