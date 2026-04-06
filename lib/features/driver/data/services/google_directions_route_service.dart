import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:smart_monadi/features/driver/domain/services/route_directions_service.dart';

class GoogleDirectionsRouteService implements RouteDirectionsService {
  GoogleDirectionsRouteService({required String apiKey, http.Client? client})
    : _apiKey = apiKey.trim(),
      _client = client ?? http.Client();

  final String _apiKey;
  final http.Client _client;

  @override
  Future<List<LatLng>?> getRoutePoints({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
  }) async {
    if (_apiKey.isEmpty) {
      return null;
    }

    final originParam = '${origin.latitude},${origin.longitude}';
    final destinationParam = '${destination.latitude},${destination.longitude}';
    final waypointParam = waypoints
        .map((p) => '${p.latitude},${p.longitude}')
        .join('|');

    final params = <String, String>{
      'origin': originParam,
      'destination': destinationParam,
      'key': _apiKey,
      'mode': 'driving',
    };
    if (waypointParam.isNotEmpty) {
      params['waypoints'] = waypointParam;
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      params,
    );

    final response = await _client
        .get(uri)
        .timeout(const Duration(milliseconds: 1800));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final status = (decoded['status'] ?? '').toString();
    if (status != 'OK') {
      return null;
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      return null;
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map<String, dynamic>) {
      return null;
    }

    final overview = firstRoute['overview_polyline'];
    if (overview is! Map<String, dynamic>) {
      return null;
    }

    final encoded = (overview['points'] ?? '').toString();
    if (encoded.isEmpty) {
      return null;
    }

    return _decodePolyline(encoded);
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;

      while (true) {
        final byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
        if (byte < 0x20) {
          break;
        }
      }

      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      while (true) {
        final byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
        if (byte < 0x20) {
          break;
        }
      }

      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
