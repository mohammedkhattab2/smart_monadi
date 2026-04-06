import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class RouteDirectionsService {
  Future<List<LatLng>?> getRoutePoints({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
  });
}
