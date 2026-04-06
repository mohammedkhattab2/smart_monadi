import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/app/design/design_tokens.dart';
import 'package:smart_monadi/features/driver/data/services/google_directions_route_service.dart';
import 'package:smart_monadi/features/driver/domain/services/route_directions_service.dart';
import 'package:smart_monadi/features/driver/presentation/viewmodels/driver_live_view_model.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key, required this.viewModel});

  final DriverLiveViewModel viewModel;

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen>
    with WidgetsBindingObserver {
  static const _directionsApiKey = String.fromEnvironment(
    'DIRECTIONS_API_KEY',
    defaultValue: 'AIzaSyDpOwdvxDkDUlRlWCeHaXI-b2RdCJf62BY',
  );

  late final DriverLiveViewModel _liveViewModel;
  late final RouteDirectionsService? _routeDirectionsService;
  StreamSubscription<List<Passenger>>? _passengerChangesSubscription;
  final Map<String, Future<Set<Polyline>>> _routePolylineCache =
      <String, Future<Set<Polyline>>>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _liveViewModel = widget.viewModel;
    _routeDirectionsService = _directionsApiKey.isEmpty
        ? null
        : GoogleDirectionsRouteService(apiKey: _directionsApiKey);
    _liveViewModel.startTracking();
    _passengerChangesSubscription = _liveViewModel.watchPassengers().listen(
      _liveViewModel.onPassengerSchedulesSnapshot,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _liveViewModel.startTracking();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passengerChangesSubscription?.cancel();
    _routePolylineCache.clear();
    super.dispose();
  }

  String _formatScheduleAlert(DriverScheduleAlert alert) {
    return '${alert.passengerName}\n'
        '${'driver.alert_pickup'.tr()}: ${alert.previousPickup} -> ${alert.currentPickup}\n'
        '${'driver.alert_return'.tr()}: ${alert.previousReturn} -> ${alert.currentReturn}';
  }

  String _buildEtaText(BusLocation? busLocation, double? lat, double? lng) {
    final eta = _liveViewModel.etaMinutes(busLocation, lat, lng);
    if (eta == null) {
      return 'driver.eta_unavailable'.tr();
    }

    return 'driver.eta_format'.tr(args: ['${eta.clamp(1, 999)}']);
  }

  String _buildStatusText(Passenger passenger) {
    return _liveViewModel.statusKey(passenger).tr();
  }

  List<Passenger> _routePassengers(
    List<Passenger> passengers,
    BusLocation? busLocation,
  ) {
    final active = _scheduledPassengers(passengers)
        .where((p) {
          return !(p.isPickedUp || p.geofenceState == 'picked_up') &&
              p.latitude != null &&
              p.longitude != null;
        })
        .toList(growable: false);

    final sorted = _liveViewModel.sortPassengers(active, busLocation);
    return sorted.take(5).toList(growable: false);
  }

  List<Passenger> _scheduledPassengers(List<Passenger> passengers) {
    final now = DateTime.now();
    return passengers
        .where((p) => _isScheduledNow(p, now))
        .toList(growable: false);
  }

  bool _isScheduledNow(Passenger passenger, DateTime now) {
    final pickupMinutes = _parseHm(passenger.pickupTime);
    final returnMinutes = _parseHm(passenger.returnTime);
    if (pickupMinutes == null && returnMinutes == null) {
      return false;
    }

    final nowMinutes = now.hour * 60 + now.minute;
    const tolerance = 90;

    if (pickupMinutes != null &&
        (nowMinutes - pickupMinutes).abs() <= tolerance) {
      return true;
    }

    if (returnMinutes != null &&
        (nowMinutes - returnMinutes).abs() <= tolerance) {
      return true;
    }

    return false;
  }

  int? _parseHm(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return null;
    }

    final parts = raw.split(':');
    if (parts.length != 2) {
      return null;
    }

    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }

    return h * 60 + m;
  }

  Set<Marker> _buildMapMarkers(BusLocation busLocation, List<Passenger> route) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('bus_current_location'),
        position: LatLng(busLocation.latitude, busLocation.longitude),
      ),
    };

    for (final passenger in route) {
      markers.add(
        Marker(
          markerId: MarkerId('passenger_${passenger.id}'),
          position: LatLng(passenger.latitude!, passenger.longitude!),
          infoWindow: InfoWindow(title: passenger.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildStraightRoutePolyline(
    BusLocation busLocation,
    List<Passenger> route,
  ) {
    if (route.isEmpty) {
      return const <Polyline>{};
    }

    final points = <LatLng>[
      LatLng(busLocation.latitude, busLocation.longitude),
      ...route.map((p) => LatLng(p.latitude!, p.longitude!)),
    ];

    return {
      Polyline(
        polylineId: const PolylineId('driver_route_preview'),
        points: points,
        width: 5,
        geodesic: true,
        color: Theme.of(context).colorScheme.primary,
      ),
    };
  }

  Future<Set<Polyline>> _resolveRoutePolylines(
    BusLocation busLocation,
    List<Passenger> route,
  ) {
    final key = _routeKey(busLocation, route);
    final cached = _routePolylineCache[key];
    if (cached != null) {
      return cached;
    }

    final future = _loadRoutePolylines(busLocation, route);
    _routePolylineCache[key] = future;
    if (_routePolylineCache.length > 24) {
      final firstKey = _routePolylineCache.keys.first;
      _routePolylineCache.remove(firstKey);
    }
    return future;
  }

  Future<Set<Polyline>> _loadRoutePolylines(
    BusLocation busLocation,
    List<Passenger> route,
  ) async {
    final fallback = _buildStraightRoutePolyline(busLocation, route);
    final routeColor = Theme.of(context).colorScheme.primary;
    final service = _routeDirectionsService;
    if (service == null || route.isEmpty) {
      return fallback;
    }

    final origin = LatLng(busLocation.latitude, busLocation.longitude);
    final destination = LatLng(route.last.latitude!, route.last.longitude!);
    final waypoints = route
        .take(route.length - 1)
        .map((p) => LatLng(p.latitude!, p.longitude!))
        .toList(growable: false);

    try {
      final points = await service.getRoutePoints(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );
      if (points == null || points.length < 2) {
        return fallback;
      }

      return {
        Polyline(
          polylineId: const PolylineId('driver_route_directions'),
          points: points,
          width: 5,
          geodesic: true,
          color: routeColor,
        ),
      };
    } catch (_) {
      return fallback;
    }
  }

  String _routeKey(BusLocation busLocation, List<Passenger> route) {
    final origin =
        '${busLocation.latitude.toStringAsFixed(5)},${busLocation.longitude.toStringAsFixed(5)}';
    final stops = route
        .map(
          (p) =>
              '${p.id}:${p.latitude!.toStringAsFixed(5)},${p.longitude!.toStringAsFixed(5)}',
        )
        .join('|');
    return '$origin->$stops';
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

    final errorKey = await _liveViewModel.manualMarkPickedUp(passenger);

    if (!mounted) {
      return;
    }

    if (errorKey != null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorKey.tr())));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('driver.manual_pickup_done'.tr())));
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

                        return StreamBuilder<List<Passenger>>(
                          stream: _liveViewModel.watchPassengers(),
                          builder: (context, passengerSnapshot) {
                            final passengers =
                                passengerSnapshot.data ?? const <Passenger>[];
                            final route = _routePassengers(
                              passengers,
                              busLocation,
                            );
                            final markers = _buildMapMarkers(
                              busLocation,
                              route,
                            );
                            return FutureBuilder<Set<Polyline>>(
                              future: _resolveRoutePolylines(
                                busLocation,
                                route,
                              ),
                              initialData: _buildStraightRoutePolyline(
                                busLocation,
                                route,
                              ),
                              builder: (context, routeSnapshot) {
                                final polylines =
                                    routeSnapshot.data ?? const <Polyline>{};
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm.r,
                                  ),
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: busLatLng,
                                      zoom: 15,
                                    ),
                                    markers: markers,
                                    polylines: polylines,
                                    myLocationEnabled: true,
                                    myLocationButtonEnabled: true,
                                    zoomControlsEnabled: false,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder(
                stream: _liveViewModel.watchPassengers(),
                builder: (context, snapshot) {
                  final allPassengers = snapshot.data ?? const [];
                  final passengers = _scheduledPassengers(allPassengers);
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
                      final sortedPassengers = _liveViewModel.sortPassengers(
                        passengers,
                        busLocation,
                      );

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
                      final alerts = _liveViewModel.scheduleAlerts;
                      final hasAlerts = alerts.isNotEmpty;

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
                                      ...alerts
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
                          final isManualUpdating = _liveViewModel
                              .isManualPickupInProgress(passenger.id);
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
