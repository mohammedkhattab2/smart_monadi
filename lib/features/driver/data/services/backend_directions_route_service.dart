import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:smart_monadi/features/driver/domain/services/route_directions_service.dart';

class BackendDirectionsRouteService implements RouteDirectionsService {
  BackendDirectionsRouteService({required String baseUrl, http.Client? client})
    : _baseUrl = baseUrl.trim(),
      _client = client ?? http.Client();

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<List<LatLng>?> getRoutePoints({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
  }) async {
    if (_baseUrl.isEmpty) {
      return null;
    }

    final stops = <LatLng>[origin, ...waypoints, destination];
    if (stops.length < 2) {
      return null;
    }

    final points = <LatLng>[];
    for (var i = 0; i < stops.length - 1; i += 1) {
      final from = stops[i];
      final to = stops[i + 1];
      final segment = await _fetchSegment(from: from, to: to);
      if (segment == null || segment.length < 2) {
        return null;
      }

      if (points.isEmpty) {
        points.addAll(segment);
      } else {
        // Avoid duplicate endpoint between contiguous segments.
        points.addAll(segment.skip(1));
      }
    }

    return points.length >= 2 ? points : null;
  }

  Future<List<LatLng>?> _fetchSegment({
    required LatLng from,
    required LatLng to,
  }) async {
    final uri = Uri.parse('$_baseUrl/directions').replace(
      queryParameters: {
        'from_lat': from.latitude.toString(),
        'from_lng': from.longitude.toString(),
        'to_lat': to.latitude.toString(),
        'to_lng': to.longitude.toString(),
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 5));
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
