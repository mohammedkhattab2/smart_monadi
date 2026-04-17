enum NotificationRouteTarget { home, tripDetails, liveTracking, eta }

class NotificationRouteIntent {
  const NotificationRouteIntent({
    required this.target,
    required this.payload,
    required this.source,
  });

  final NotificationRouteTarget target;
  final Map<String, String> payload;
  final String source;

  String get type => _readFirst(['type', 'eventType']).toLowerCase();
  String get status => _readFirst(['status', 'tripStatus']).toLowerCase();
  String get tripId => _readFirst(['tripId', 'trip_id', 'tripID']);
  String get driverId => _readFirst(['driverId', 'driver_id', 'driverID']);

  bool get hasTripContext => tripId.isNotEmpty || type.contains('trip');

  String _readFirst(List<String> keys) {
    for (final key in keys) {
      final value = payload[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
}

extension NotificationRouteTargetLabel on NotificationRouteTarget {
  String get screenLabel {
    switch (this) {
      case NotificationRouteTarget.home:
        return 'HomeScreen';
      case NotificationRouteTarget.tripDetails:
        return 'TripDetailsScreen';
      case NotificationRouteTarget.liveTracking:
        return 'LiveTrackingScreen';
      case NotificationRouteTarget.eta:
        return 'EtaOverlay';
    }
  }
}
