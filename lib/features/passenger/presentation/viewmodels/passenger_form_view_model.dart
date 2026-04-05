import 'package:flutter/foundation.dart';
import 'package:smart_monadi/features/passenger/data/repositories/passenger_repository.dart';

class PassengerFormViewModel extends ChangeNotifier {
  PassengerFormViewModel(this._repository);

  final PassengerRepository _repository;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  Future<bool> savePassenger({
    required String id,
    required String name,
    required String phone,
    required String address,
    required String pickupTime,
    String returnTime = '',
    double? latitude,
    double? longitude,
  }) async {
    if (_isSaving) {
      return false;
    }

    _isSaving = true;
    notifyListeners();

    try {
      await _repository.upsertPassenger(
        id: id,
        name: name,
        phone: phone,
        address: address,
        pickupTime: pickupTime,
        returnTime: returnTime,
        latitude: latitude,
        longitude: longitude,
      );
      return true;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
