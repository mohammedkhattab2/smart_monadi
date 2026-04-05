import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/app/design/design_tokens.dart';
import 'package:smart_monadi/features/automation/data/repositories/trip_event_repository.dart';
import 'package:smart_monadi/features/driver/presentation/viewmodels/driver_live_view_model.dart';
import 'package:smart_monadi/features/location/data/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/location/data/services/device_location_service.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/passenger/data/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key, required this.repository});

  final PassengerRepository repository;

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  late final DriverLiveViewModel _liveViewModel;
  final _tripEventRepository = TripEventRepository();
  final Set<String> _manualPickupInProgress = <String>{};
  StreamSubscription<List<Passenger>>? _passengerChangesSubscription;
  final Map<String, _PassengerScheduleSnapshot> _knownSchedules =
      <String, _PassengerScheduleSnapshot>{};
  final List<_ScheduleAlertItem> _scheduleAlerts = <_ScheduleAlertItem>[];

  @override
  void initState() {
    super.initState();
    _liveViewModel = DriverLiveViewModel(
      locationService: DeviceLocationService(),
      locationRepository: BusLocationRepository(),
      passengerRepository: widget.repository,
      tripEventRepository: TripEventRepository(),
    );
    _liveViewModel.startTracking();
    _passengerChangesSubscription = widget.repository.watchPassengers().listen(
      _onPassengerSchedulesSnapshot,
    );
  }

  @override
  void dispose() {
    _passengerChangesSubscription?.cancel();
    _liveViewModel.dispose();
    super.dispose();
  }

  void _onPassengerSchedulesSnapshot(List<Passenger> passengers) {
    final activeIds = <String>{};
    for (final passenger in passengers) {
      activeIds.add(passenger.id);

      final current = _PassengerScheduleSnapshot(
        pickupTime: passenger.pickupTime,
        returnTime: passenger.returnTime,
      );
      final previous = _knownSchedules[passenger.id];

      if (previous != null &&
          (previous.pickupTime != current.pickupTime ||
              previous.returnTime != current.returnTime)) {
        _scheduleAlerts.insert(
          0,
          _ScheduleAlertItem(
            passengerName: passenger.name,
            previousPickup: previous.pickupTime,
            currentPickup: current.pickupTime,
            previousReturn: previous.returnTime,
            currentReturn: current.returnTime,
          ),
        );
      }

      _knownSchedules[passenger.id] = current;
    }

    _knownSchedules.removeWhere((id, _) => !activeIds.contains(id));
    if (_scheduleAlerts.length > 8) {
      _scheduleAlerts.removeRange(8, _scheduleAlerts.length);
    }

    if (mounted) {
      setState(() {});
    }
  }

  String _formatScheduleAlert(_ScheduleAlertItem alert) {
    return '${alert.passengerName}\n'
        '${'driver.alert_pickup'.tr()}: ${alert.previousPickup} -> ${alert.currentPickup}\n'
        '${'driver.alert_return'.tr()}: ${alert.previousReturn} -> ${alert.currentReturn}';
  }

  String _buildEtaText(BusLocation? busLocation, double? lat, double? lng) {
    final eta = _etaMinutes(busLocation, lat, lng);
    if (eta == null) {
      return 'driver.eta_unavailable'.tr();
    }

    return 'driver.eta_format'.tr(args: ['${eta.clamp(1, 999)}']);
  }

  int? _etaMinutes(BusLocation? busLocation, double? lat, double? lng) {
    if (busLocation == null || lat == null || lng == null) {
      return null;
    }

    final distanceMeters = Geolocator.distanceBetween(
      busLocation.latitude,
      busLocation.longitude,
      lat,
      lng,
    );
    const averageSpeedMetersPerMinute = 500.0;
    return (distanceMeters / averageSpeedMetersPerMinute).ceil();
  }

  String _buildStatusText(Passenger passenger) {
    if (passenger.isPickedUp || passenger.geofenceState == 'picked_up') {
      return 'driver.status_picked_up'.tr();
    }
    if (passenger.geofenceState == 'approaching') {
      return 'driver.status_approaching'.tr();
    }
    return 'driver.status_waiting'.tr();
  }

  Color _statusColor(Passenger passenger, ColorScheme colorScheme) {
    if (passenger.isPickedUp || passenger.geofenceState == 'picked_up') {
      return colorScheme.primary;
    }
    if (passenger.geofenceState == 'approaching') {
      return colorScheme.tertiary;
    }
    return colorScheme.outline;
  }

  int _statusPriority(Passenger passenger) {
    if (passenger.geofenceState == 'approaching') {
      return 0;
    }
    if (passenger.isPickedUp || passenger.geofenceState == 'picked_up') {
      return 2;
    }
    return 1;
  }

  Future<void> _callPassenger(Passenger passenger) async {
    final uri = Uri(scheme: 'tel', path: passenger.phone.trim());
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('driver.call_failed'.tr())));
  }

  Future<void> _manualMarkPickedUp(Passenger passenger) async {
    if (_manualPickupInProgress.contains(passenger.id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('driver.manual_pickup_confirm_title'.tr()),
          content: Text(
            'driver.manual_pickup_confirm_body'.tr(args: [passenger.name]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('driver.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('driver.confirm'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _manualPickupInProgress.add(passenger.id);
    });

    try {
      await widget.repository.markPickedUp(passengerId: passenger.id);

      await _tripEventRepository.addPickupLog(
        passengerId: passenger.id,
        passengerPhone: passenger.phone,
        type: 'picked_up_manual',
        message: 'Passenger manually marked as picked up by driver',
        payload: {'source': 'driver_manual_action', 'name': passenger.name},
      );

      await _tripEventRepository.queueSms(
        passengerId: passenger.id,
        toPhone: passenger.phone,
        template: 'arrival_now',
        variables: {'name': passenger.name, 'pickupTime': passenger.pickupTime},
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('driver.manual_pickup_done'.tr())));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('driver.manual_pickup_failed'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _manualPickupInProgress.remove(passenger.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _liveViewModel,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
              child: AppFadeSlideIn(
                child: AppSectionCard(
                  icon: Icons.map_outlined,
                  title: 'driver.map_title'.tr(),
                  child: SizedBox(
                    height: 220.h,
                    child: StreamBuilder<BusLocation?>(
                      stream: _liveViewModel.watchBusLocation(),
                      builder: (context, snapshot) {
                        final busLocation = snapshot.data;

                        if (_liveViewModel.trackingError != null) {
                          return AppStateCard(
                            icon: Icons.location_off_outlined,
                            title: 'states.error_title'.tr(),
                            message: _liveViewModel.trackingError!.tr(),
                            actionLabel: 'actions.retry'.tr(),
                            onAction: _liveViewModel.startTracking,
                          );
                        }

                        if (snapshot.hasError) {
                          return AppStateCard(
                            icon: Icons.error_outline,
                            title: 'states.error_title'.tr(),
                            message: 'states.error_message'.tr(),
                            actionLabel: 'actions.retry'.tr(),
                            onAction: _liveViewModel.startTracking,
                          );
                        }

                        if (busLocation == null) {
                          return Padding(
                            padding: EdgeInsets.all(AppSpacing.xs.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSkeletonBox(
                                  height: 150.h,
                                  radius: AppRadius.sm,
                                ),
                                SizedBox(height: AppSpacing.xs.h),
                                AppSkeletonBox(height: 10.h, width: 160.w),
                              ],
                            ),
                          );
                        }

                        final busLatLng = LatLng(
                          busLocation.latitude,
                          busLocation.longitude,
                        );

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm.r),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: busLatLng,
                              zoom: 15,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId(
                                  'bus_current_location',
                                ),
                                position: busLatLng,
                              ),
                            },
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: false,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder(
                stream: widget.repository.watchPassengers(),
                builder: (context, snapshot) {
                  final passengers = snapshot.data ?? const [];
                  final busLocationSnapshot = _liveViewModel.watchBusLocation();

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: EdgeInsets.all(16.w),
                      child: const AppSkeletonList(itemCount: 4),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: EdgeInsets.all(16.w),
                      child: AppStateCard(
                        icon: Icons.error_outline,
                        title: 'states.error_title'.tr(),
                        message: 'states.error_message'.tr(),
                        actionLabel: 'actions.retry'.tr(),
                        onAction: () => setState(() {}),
                      ),
                    );
                  }

                  if (passengers.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.all(16.w),
                      child: AppStateCard(
                        icon: Icons.inbox_outlined,
                        title: 'states.empty_title'.tr(),
                        message: 'driver.empty'.tr(),
                      ),
                    );
                  }

                  return StreamBuilder<BusLocation?>(
                    stream: busLocationSnapshot,
                    builder: (context, busSnapshot) {
                      if (busSnapshot.hasError) {
                        return Padding(
                          padding: EdgeInsets.all(16.w),
                          child: AppStateCard(
                            icon: Icons.error_outline,
                            title: 'states.error_title'.tr(),
                            message: 'states.error_message'.tr(),
                            actionLabel: 'actions.retry'.tr(),
                            onAction: () => setState(() {}),
                          ),
                        );
                      }

                      final busLocation = busSnapshot.data;
                      final colorScheme = Theme.of(context).colorScheme;
                      final sortedPassengers =
                          passengers.toList(growable: false)..sort((a, b) {
                            final statusCompare = _statusPriority(
                              a,
                            ).compareTo(_statusPriority(b));
                            if (statusCompare != 0) {
                              return statusCompare;
                            }

                            final aEta = _etaMinutes(
                              busLocation,
                              a.latitude,
                              a.longitude,
                            );
                            final bEta = _etaMinutes(
                              busLocation,
                              b.latitude,
                              b.longitude,
                            );

                            if (aEta == null && bEta == null) {
                              return a.name.toLowerCase().compareTo(
                                b.name.toLowerCase(),
                              );
                            }
                            if (aEta == null) {
                              return 1;
                            }
                            if (bEta == null) {
                              return -1;
                            }
                            return aEta.compareTo(bEta);
                          });

                      final pickedUpCount = passengers
                          .where(
                            (p) =>
                                p.isPickedUp || p.geofenceState == 'picked_up',
                          )
                          .length;
                      final approachingCount = passengers
                          .where((p) => p.geofenceState == 'approaching')
                          .length;
                      final waitingCount =
                          passengers.length - pickedUpCount - approachingCount;
                      final hasAlerts = _scheduleAlerts.isNotEmpty;

                      return ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount:
                            sortedPassengers.length + 1 + (hasAlerts ? 1 : 0),
                        separatorBuilder: (context, index) =>
                            SizedBox(height: AppSpacing.xs.h),
                        itemBuilder: (context, index) {
                          if (hasAlerts && index == 0) {
                            return AppFadeSlideIn(
                              delay: const Duration(milliseconds: 80),
                              child: Card(
                                color: colorScheme.secondaryContainer,
                                child: Padding(
                                  padding: EdgeInsets.all(AppSpacing.sm.w),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'driver.schedule_updates_title'.tr(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      SizedBox(height: AppSpacing.xs.h),
                                      ..._scheduleAlerts
                                          .take(3)
                                          .map(
                                            (alert) => Padding(
                                              padding: EdgeInsets.only(
                                                bottom: AppSpacing.xs.h,
                                              ),
                                              child: Text(
                                                _formatScheduleAlert(alert),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final summaryIndex = hasAlerts ? 1 : 0;
                          if (index == summaryIndex) {
                            return AppFadeSlideIn(
                              delay: const Duration(milliseconds: 140),
                              child: Card(
                                elevation: 0,
                                color: colorScheme.surfaceContainerHigh,
                                child: Padding(
                                  padding: EdgeInsets.all(AppSpacing.sm.w),
                                  child: Wrap(
                                    spacing: AppSpacing.xs.w,
                                    runSpacing: AppSpacing.xs.h,
                                    children: [
                                      _DriverCountChip(
                                        label: 'driver.status_waiting'.tr(),
                                        value: waitingCount,
                                        color: colorScheme.outline,
                                      ),
                                      _DriverCountChip(
                                        label: 'driver.status_approaching'.tr(),
                                        value: approachingCount,
                                        color: colorScheme.tertiary,
                                      ),
                                      _DriverCountChip(
                                        label: 'driver.status_picked_up'.tr(),
                                        value: pickedUpCount,
                                        color: colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          final passenger =
                              sortedPassengers[index - summaryIndex - 1];
                          final statusColor = _statusColor(
                            passenger,
                            colorScheme,
                          );
                          final isManualUpdating = _manualPickupInProgress
                              .contains(passenger.id);
                          final canManualPickup =
                              !(passenger.isPickedUp ||
                                  passenger.geofenceState == 'picked_up');
                          return AppFadeSlideIn(
                            delay: Duration(
                              milliseconds:
                                  (summaryIndex * 40) +
                                  (index * 35).clamp(0, 320).toInt(),
                            ),
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.sm.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: statusColor
                                              .withValues(alpha: 0.16),
                                          child: Icon(
                                            Icons.person,
                                            color: statusColor,
                                          ),
                                        ),
                                        SizedBox(width: AppSpacing.xs.w),
                                        Expanded(
                                          child: Text(
                                            passenger.name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                        AppStatusPill(
                                          label: _buildStatusText(passenger),
                                          icon: Icons.route_outlined,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: AppSpacing.xs.h),
                                    Text(passenger.address),
                                    SizedBox(height: AppSpacing.xxs.h),
                                    Text(passenger.phone),
                                    SizedBox(height: AppSpacing.xxs.h),
                                    Text(
                                      _buildEtaText(
                                        busLocation,
                                        passenger.latitude,
                                        passenger.longitude,
                                      ),
                                    ),
                                    SizedBox(height: AppSpacing.xs.h),
                                    Wrap(
                                      spacing: AppSpacing.sm.w,
                                      runSpacing: AppSpacing.xxs.h,
                                      children: [
                                        Text(
                                          '${'driver.alert_pickup'.tr()}: ${passenger.pickupTime}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                        Text(
                                          '${'driver.alert_return'.tr()}: ${passenger.returnTime.isEmpty ? '--' : passenger.returnTime}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: AppSpacing.xs.h),
                                    Row(
                                      children: [
                                        IconButton.filledTonal(
                                          tooltip: 'driver.call'.tr(),
                                          onPressed: () =>
                                              _callPassenger(passenger),
                                          icon: const Icon(Icons.call_outlined),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        SizedBox(width: AppSpacing.xs.w),
                                        FilledButton.tonal(
                                          onPressed:
                                              (!canManualPickup ||
                                                  isManualUpdating)
                                              ? null
                                              : () => _manualMarkPickedUp(
                                                  passenger,
                                                ),
                                          style: FilledButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                            minimumSize: Size(0, 34.h),
                                          ),
                                          child: isManualUpdating
                                              ? SizedBox(
                                                  width: 12.w,
                                                  height: 12.w,
                                                  child:
                                                      const CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Text(
                                                  'driver.manual_pickup'.tr(),
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DriverCountChip extends StatelessWidget {
  const _DriverCountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PassengerScheduleSnapshot {
  const _PassengerScheduleSnapshot({
    required this.pickupTime,
    required this.returnTime,
  });

  final String pickupTime;
  final String returnTime;
}

class _ScheduleAlertItem {
  const _ScheduleAlertItem({
    required this.passengerName,
    required this.previousPickup,
    required this.currentPickup,
    required this.previousReturn,
    required this.currentReturn,
  });

  final String passengerName;
  final String previousPickup;
  final String currentPickup;
  final String previousReturn;
  final String currentReturn;
}
