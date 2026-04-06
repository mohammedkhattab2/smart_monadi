import 'package:smart_monadi/features/auth/data/services/auth_service.dart';
import 'package:smart_monadi/features/auth/domain/repositories/auth_repository.dart';
import 'package:smart_monadi/features/automation/data/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/automation/domain/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/driver/domain/usecases/calculate_eta_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/manual_mark_picked_up_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/run_geofence_automation_use_case.dart';
import 'package:smart_monadi/features/driver/domain/usecases/sort_passengers_use_case.dart';
import 'package:smart_monadi/features/driver/data/services/http_python_eta_prediction_service.dart';
import 'package:smart_monadi/features/driver/presentation/viewmodels/driver_live_view_model.dart';
import 'package:smart_monadi/features/location/data/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/location/data/services/device_location_service.dart';
import 'package:smart_monadi/features/location/domain/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/location/domain/services/device_location_service.dart';
import 'package:smart_monadi/features/notifications/data/services/push_notification_service.dart';
import 'package:smart_monadi/features/operations/data/repositories/firestore_operations_repository.dart';
import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';
import 'package:smart_monadi/features/operations/domain/usecases/enqueue_test_sms_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/requeue_dead_letter_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_dead_letters_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_events_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_metrics_use_case.dart';
import 'package:smart_monadi/features/operations/presentation/viewmodels/operations_dashboard_view_model.dart';
import 'package:smart_monadi/features/passenger/data/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/domain/usecases/save_passenger_profile_use_case.dart';
import 'package:smart_monadi/features/passenger/domain/usecases/watch_passenger_profile_use_case.dart';
import 'package:smart_monadi/features/passenger/domain/usecases/watch_passenger_timeline_use_case.dart';

class AppDependencies {
  AppDependencies._({
    required this.authRepository,
    required this.passengerRepository,
    required this.operationsRepository,
    required this.tripEventRepository,
    required this.locationRepository,
    required this.locationService,
    required this.pushNotificationService,
  });

  factory AppDependencies.create() {
    final authRepository = AuthService();
    final passengerRepository = FirestorePassengerRepository();
    final operationsRepository = FirestoreOperationsRepository();
    final tripEventRepository = FirestoreTripEventRepository();
    final locationRepository = FirestoreBusLocationRepository();
    final locationService = GeolocatorDeviceLocationService();
    final pushNotificationService = PushNotificationService();

    return AppDependencies._(
      authRepository: authRepository,
      passengerRepository: passengerRepository,
      operationsRepository: operationsRepository,
      tripEventRepository: tripEventRepository,
      locationRepository: locationRepository,
      locationService: locationService,
      pushNotificationService: pushNotificationService,
    );
  }

  final AuthRepository authRepository;
  final PassengerRepository passengerRepository;
  final OperationsRepository operationsRepository;
  final TripEventRepository tripEventRepository;
  final BusLocationRepository locationRepository;
  final DeviceLocationService locationService;
  final PushNotificationService pushNotificationService;

  DriverLiveViewModel createDriverLiveViewModel() {
    const calculateEtaUseCase = CalculateEtaUseCase();
    final sortPassengersUseCase = SortPassengersUseCase(calculateEtaUseCase);
    const etaServiceUrl = String.fromEnvironment('ETA_SERVICE_URL');
    final etaPredictionService = HttpPythonEtaPredictionService(
      baseUrl: etaServiceUrl,
    );
    final manualMarkPickedUpUseCase = ManualMarkPickedUpUseCase(
      passengerRepository: passengerRepository,
      tripEventRepository: tripEventRepository,
    );
    final runGeofenceAutomationUseCase = RunGeofenceAutomationUseCase(
      passengerRepository: passengerRepository,
      tripEventRepository: tripEventRepository,
      etaPredictionService: etaPredictionService,
    );

    return DriverLiveViewModel(
      locationService: locationService,
      locationRepository: locationRepository,
      passengerRepository: passengerRepository,
      calculateEtaUseCase: calculateEtaUseCase,
      sortPassengersUseCase: sortPassengersUseCase,
      manualMarkPickedUpUseCase: manualMarkPickedUpUseCase,
      runGeofenceAutomationUseCase: runGeofenceAutomationUseCase,
    );
  }

  OperationsDashboardViewModel createOperationsDashboardViewModel() {
    return OperationsDashboardViewModel(
      watchMetricsUseCase: WatchOperationsMetricsUseCase(operationsRepository),
      watchEventsUseCase: WatchOperationsEventsUseCase(operationsRepository),
      watchDeadLettersUseCase: WatchOperationsDeadLettersUseCase(
        operationsRepository,
      ),
      enqueueTestSmsUseCase: EnqueueTestSmsUseCase(operationsRepository),
      requeueDeadLetterUseCase: RequeueDeadLetterUseCase(operationsRepository),
    );
  }

  SavePassengerProfileUseCase createSavePassengerProfileUseCase() {
    return SavePassengerProfileUseCase(passengerRepository);
  }

  WatchPassengerProfileUseCase createWatchPassengerProfileUseCase() {
    return WatchPassengerProfileUseCase(passengerRepository);
  }

  WatchPassengerTimelineUseCase createWatchPassengerTimelineUseCase() {
    return WatchPassengerTimelineUseCase(passengerRepository);
  }
}
