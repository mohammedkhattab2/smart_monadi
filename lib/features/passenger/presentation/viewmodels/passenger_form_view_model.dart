import 'package:flutter/foundation.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/domain/usecases/save_passenger_profile_use_case.dart';

class PassengerFormViewModel extends ChangeNotifier {
  PassengerFormViewModel(this._savePassengerProfileUseCase);

  factory PassengerFormViewModel.fromRepository(
    PassengerRepository repository,
  ) {
    return PassengerFormViewModel(SavePassengerProfileUseCase(repository));
  }

  final SavePassengerProfileUseCase _savePassengerProfileUseCase;

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
      await _savePassengerProfileUseCase(
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
