import 'package:flutter/material.dart';
import 'package:smart_monadi/features/location/domain/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/notifications/domain/controllers/active_trip_controller.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/presentation/screens/passenger_screen.dart';

class ParentScreen extends StatelessWidget {
  const ParentScreen({
    super.key,
    required this.repository,
    required this.locationRepository,
    required this.currentUserId,
    required this.activeTripController,
  });

  final PassengerRepository repository;
  final BusLocationRepository locationRepository;
  final String currentUserId;
  final ActiveTripController activeTripController;

  @override
  Widget build(BuildContext context) {
    // Transitional wrapper so parent UX can evolve independently
    // while reusing the existing passenger implementation.
    return PassengerScreen(
      repository: repository,
      locationRepository: locationRepository,
      currentUserId: currentUserId,
      activeTripController: activeTripController,
    );
  }
}
