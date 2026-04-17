import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/notifications/domain/controllers/active_trip_controller.dart';
import 'package:smart_monadi/features/notifications/domain/entities/notification_route_intent.dart';

void main() {
  group('ActiveTripController', () {
    test('applies first intent and requests navigation', () {
      final controller = ActiveTripController();
      final intent = NotificationRouteIntent(
        target: NotificationRouteTarget.tripDetails,
        payload: const {
          'type': 'trip_update',
          'tripId': 'trip_1',
          'status': 'driver_arriving',
          'driverId': 'drv_11',
        },
        source: 'test',
      );

      final result = controller.applyIntent(intent);

      expect(result.updated, isTrue);
      expect(result.shouldNavigate, isTrue);
      expect(controller.value?.tripId, 'trip_1');
      expect(controller.value?.status, 'driver_arriving');
      expect(controller.value?.driverId, 'drv_11');
    });

    test('updates same trip without navigation', () {
      final controller = ActiveTripController();
      controller.applyIntent(
        NotificationRouteIntent(
          target: NotificationRouteTarget.tripDetails,
          payload: const {'tripId': 'trip_1', 'type': 'trip_update'},
          source: 'test',
        ),
      );

      final result = controller.applyIntent(
        NotificationRouteIntent(
          target: NotificationRouteTarget.eta,
          payload: const {
            'tripId': 'trip_1',
            'type': 'eta_update',
            'status': 'eta_update',
          },
          source: 'test_2',
        ),
      );

      expect(result.updated, isTrue);
      expect(result.shouldNavigate, isFalse);
      expect(controller.value?.tripId, 'trip_1');
      expect(controller.value?.type, 'eta_update');
    });

    test('prevents overwrite on different active trip', () {
      final controller = ActiveTripController();
      controller.applyIntent(
        NotificationRouteIntent(
          target: NotificationRouteTarget.tripDetails,
          payload: const {'tripId': 'trip_1', 'type': 'trip_update'},
          source: 'test',
        ),
      );

      final result = controller.applyIntent(
        NotificationRouteIntent(
          target: NotificationRouteTarget.tripDetails,
          payload: const {'tripId': 'trip_2', 'type': 'trip_update'},
          source: 'test_conflict',
        ),
      );

      expect(result.updated, isFalse);
      expect(result.skippedDueToActiveContext, isTrue);
      expect(controller.value?.tripId, 'trip_1');
    });

    test('clears active trip on terminal status', () {
      final controller = ActiveTripController();
      controller.applyIntent(
        NotificationRouteIntent(
          target: NotificationRouteTarget.tripDetails,
          payload: const {'tripId': 'trip_1', 'type': 'trip_update'},
          source: 'test',
        ),
      );

      final result = controller.applyIntent(
        NotificationRouteIntent(
          target: NotificationRouteTarget.tripDetails,
          payload: const {
            'tripId': 'trip_1',
            'type': 'trip_update',
            'status': 'completed',
          },
          source: 'test_done',
        ),
      );

      expect(result.updated, isTrue);
      expect(result.shouldNavigate, isFalse);
      expect(controller.value, isNull);
    });

    test('supports alternative payload keys', () {
      final controller = ActiveTripController();
      final intent = NotificationRouteIntent(
        target: NotificationRouteTarget.tripDetails,
        payload: const {
          'trip_id': 'trip_9',
          'tripStatus': 'driver_arriving',
          'eventType': 'trip_update',
          'driver_id': 'drv_9',
        },
        source: 'test_alt_keys',
      );

      final result = controller.applyIntent(intent);

      expect(result.updated, isTrue);
      expect(controller.value?.tripId, 'trip_9');
      expect(controller.value?.status, 'driver_arriving');
      expect(controller.value?.type, 'trip_update');
      expect(controller.value?.driverId, 'drv_9');
    });
  });
}
