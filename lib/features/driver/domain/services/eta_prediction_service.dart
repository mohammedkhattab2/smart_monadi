abstract class EtaPredictionService {
  Future<int?> predictEtaMinutes({
    required double busLat,
    required double busLng,
    required double passengerLat,
    required double passengerLng,
    required double speedMetersPerSecond,
  });
}
