class Passenger {
  const Passenger({
    required this.id,
    this.parentId = '',
    this.shortId = '',
    this.studentNationalId = '',
    this.birthDate = '',
    required this.name,
    this.dependentName = '',
    required this.phone,
    required this.address,
    required this.pickupTime,
    this.returnTime = '',
    this.latitude,
    this.longitude,
    this.isPickedUp = false,
    this.geofenceState = 'idle',
    this.lastDistanceMeters,
    required this.updatedAtMillis,
  });

  final String id;
  final String parentId;
  final String shortId;
  final String studentNationalId;
  final String birthDate;
  final String name;
  final String dependentName;
  final String phone;
  final String address;
  final String pickupTime;
  final String returnTime;
  final double? latitude;
  final double? longitude;
  final bool isPickedUp;
  final String geofenceState;
  final double? lastDistanceMeters;
  final int updatedAtMillis;
}
