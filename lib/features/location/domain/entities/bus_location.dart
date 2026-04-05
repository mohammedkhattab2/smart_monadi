class BusLocation {
  const BusLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAtMillis,
    this.speedMetersPerSecond,
  });

  final double latitude;
  final double longitude;
  final int updatedAtMillis;
  final double? speedMetersPerSecond;
}
