import 'package:flutter/foundation.dart';
import 'package:smart_monadi/features/notifications/domain/entities/notification_route_intent.dart';

class ActiveTripState {
  const ActiveTripState({
    required this.tripId,
    required this.status,
    required this.type,
    required this.driverId,
    required this.source,
    required this.updatedAt,
  });

  final String tripId;
  final String status;
  final String type;
  final String driverId;
  final String source;
  final DateTime updatedAt;

  bool get hasTripId => tripId.isNotEmpty;

  ActiveTripState copyWith({
    String? tripId,
    String? status,
    String? type,
    String? driverId,
    String? source,
    DateTime? updatedAt,
  }) {
    return ActiveTripState(
      tripId: tripId ?? this.tripId,
      status: status ?? this.status,
      type: type ?? this.type,
      driverId: driverId ?? this.driverId,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TripStateUpdateResult {
  const TripStateUpdateResult({
    required this.updated,
    required this.shouldNavigate,
    required this.skippedDueToActiveContext,
    required this.message,
    this.state,
  });

  final bool updated;
  final bool shouldNavigate;
  final bool skippedDueToActiveContext;
  final String message;
  final ActiveTripState? state;
}

class ActiveTripController extends ValueNotifier<ActiveTripState?> {
  ActiveTripController() : super(null);

  static const Set<String> _terminalStatuses = <String>{
    'picked_up',
    'completed',
    'trip_completed',
    'cancelled',
    'canceled',
    'dropped_off',
    'done',
  };

  TripStateUpdateResult applyIntent(NotificationRouteIntent intent) {
    final previous = value;
    final hadActiveTrip = previous?.hasTripId ?? false;

    final next = _deriveState(previous, intent);
    if (next == null) {
      return const TripStateUpdateResult(
        updated: false,
        shouldNavigate: false,
        skippedDueToActiveContext: false,
        message: 'Missing trip context in payload.',
      );
    }

    if (previous != null &&
        previous.tripId.isNotEmpty &&
        next.tripId.isNotEmpty &&
        previous.tripId != next.tripId) {
      return const TripStateUpdateResult(
        updated: false,
        shouldNavigate: false,
        skippedDueToActiveContext: true,
        message: 'Active trip conflict detected; state overwrite prevented.',
      );
    }

    final isNoOp =
        previous != null &&
        previous.tripId == next.tripId &&
        previous.status == next.status &&
        previous.type == next.type &&
        previous.driverId == next.driverId;
    if (isNoOp) {
      return TripStateUpdateResult(
        updated: false,
        shouldNavigate: false,
        skippedDueToActiveContext: hadActiveTrip,
        message: 'Trip state unchanged; update skipped.',
        state: previous,
      );
    }

    if (_isTerminalStatus(next.status)) {
      if (previous == null) {
        return const TripStateUpdateResult(
          updated: false,
          shouldNavigate: false,
          skippedDueToActiveContext: false,
          message: 'Terminal trip state received with no active trip.',
        );
      }

      value = null;
      return const TripStateUpdateResult(
        updated: true,
        shouldNavigate: false,
        skippedDueToActiveContext: true,
        message: 'Trip reached terminal status; active trip cleared.',
        state: null,
      );
    }

    final isSameTrip =
        previous?.tripId.isNotEmpty == true &&
        next.tripId.isNotEmpty &&
        previous!.tripId == next.tripId;

    value = next;

    final shouldNavigate = !hadActiveTrip;
    return TripStateUpdateResult(
      updated: true,
      shouldNavigate: shouldNavigate,
      skippedDueToActiveContext: isSameTrip,
      message: shouldNavigate
          ? 'No active trip loaded; navigation may proceed.'
          : 'Active trip already loaded; navigation skipped.',
      state: next,
    );
  }

  bool _isTerminalStatus(String status) {
    return _terminalStatuses.contains(status.trim().toLowerCase());
  }

  ActiveTripState? _deriveState(
    ActiveTripState? previous,
    NotificationRouteIntent intent,
  ) {
    final payloadTripId = intent.tripId.trim();
    final fallbackTripId = previous?.tripId.trim() ?? '';
    final resolvedTripId = payloadTripId.isNotEmpty
        ? payloadTripId
        : fallbackTripId;

    if (resolvedTripId.isEmpty) {
      return null;
    }

    return ActiveTripState(
      tripId: resolvedTripId,
      status: intent.status.isNotEmpty
          ? intent.status
          : (previous?.status ?? ''),
      type: intent.type.isNotEmpty ? intent.type : (previous?.type ?? ''),
      driverId: intent.driverId.isNotEmpty
          ? intent.driverId
          : (previous?.driverId ?? ''),
      source: intent.source,
      updatedAt: DateTime.now(),
    );
  }
}
