import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/app/design/design_tokens.dart';
import 'package:smart_monadi/features/location/domain/entities/bus_location.dart';
import 'package:smart_monadi/features/location/domain/repositories/bus_location_repository.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger.dart';
import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';
import 'package:smart_monadi/features/passenger/domain/usecases/watch_passenger_profile_use_case.dart';
import 'package:smart_monadi/features/passenger/domain/usecases/watch_passenger_timeline_use_case.dart';
import 'package:smart_monadi/features/passenger/presentation/viewmodels/passenger_form_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

class PassengerScreen extends StatefulWidget {
  const PassengerScreen({
    super.key,
    required this.repository,
    required this.locationRepository,
    required this.currentUserId,
  });

  final PassengerRepository repository;
  final BusLocationRepository locationRepository;
  final String currentUserId;

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  late final PassengerFormViewModel _viewModel;
  late final WatchPassengerProfileUseCase _watchPassengerProfileUseCase;
  late final WatchPassengerTimelineUseCase _watchPassengerTimelineUseCase;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pickupTimeController = TextEditingController();
  final _returnTimeController = TextEditingController();
  StreamSubscription<List<PassengerTimelineEvent>>? _timelineSubscription;
  Timer? _timelineSnackDebounce;
  final Set<String> _seenTimelineEventIds = <String>{};
  final List<String> _pendingTimelineLabels = <String>[];
  bool _timelinePrimed = false;
  String _timelineWindow = '24h';
  bool _didPrefill = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isResolvingLocation = false;

  @override
  void initState() {
    super.initState();
    _viewModel = PassengerFormViewModel.fromRepository(widget.repository);
    _watchPassengerProfileUseCase = WatchPassengerProfileUseCase(
      widget.repository,
    );
    _watchPassengerTimelineUseCase = WatchPassengerTimelineUseCase(
      widget.repository,
    );
    _listenForNewTimelineEvents();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pickupTimeController.dispose();
    _returnTimeController.dispose();
    _timelineSubscription?.cancel();
    _timelineSnackDebounce?.cancel();
    super.dispose();
  }

  void _listenForNewTimelineEvents() {
    _timelineSubscription =
        _watchPassengerTimelineUseCase(
          passengerId: widget.currentUserId,
          limit: 5,
        ).listen(
          (events) {
            if (!_timelinePrimed) {
              for (final event in events) {
                _seenTimelineEventIds.add(event.id);
              }
              _timelinePrimed = true;
              return;
            }

            for (final event in events.reversed) {
              if (_seenTimelineEventIds.contains(event.id)) {
                continue;
              }
              _seenTimelineEventIds.add(event.id);

              if (!mounted) {
                return;
              }

              final label = _timelineEventLabel(event.type);
              _queueTimelineUpdateNotification(label);
            }
          },
          onError: (_) {
            // Keep UI responsive even if timeline query is temporarily unavailable.
          },
        );
  }

  void _queueTimelineUpdateNotification(String label) {
    _pendingTimelineLabels.add(label);
    _timelineSnackDebounce?.cancel();
    _timelineSnackDebounce = Timer(
      const Duration(milliseconds: 1200),
      _flushTimelineNotifications,
    );
  }

  void _flushTimelineNotifications() {
    if (!mounted || _pendingTimelineLabels.isEmpty) {
      return;
    }

    final labels = List<String>.from(_pendingTimelineLabels);
    _pendingTimelineLabels.clear();
    final uniquePreview = labels.toSet().take(2).join(' • ');

    final message = labels.length == 1
        ? 'passenger.timeline_new_update'.tr(args: [labels.first])
        : 'passenger.timeline_new_updates'.tr(
            args: ['${labels.length}', uniquePreview],
          );

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  int? _estimateEtaMinutes(Passenger passenger, BusLocation? busLocation) {
    if (busLocation == null ||
        passenger.latitude == null ||
        passenger.longitude == null) {
      return null;
    }

    final distanceMeters = Geolocator.distanceBetween(
      busLocation.latitude,
      busLocation.longitude,
      passenger.latitude!,
      passenger.longitude!,
    );
    const averageSpeedMetersPerMinute = 500.0;
    return (distanceMeters / averageSpeedMetersPerMinute).ceil().clamp(1, 999);
  }

  void _prefillFromProfile(Passenger passenger) {
    if (_didPrefill) {
      return;
    }

    _nameController.text = passenger.name;
    _phoneController.text = passenger.phone;
    _addressController.text = passenger.address;
    _pickupTimeController.text = passenger.pickupTime;
    _returnTimeController.text = passenger.returnTime;
    _selectedLatitude = passenger.latitude;
    _selectedLongitude = passenger.longitude;
    _didPrefill = true;
  }

  void _queuePrefillFromProfile(Passenger passenger) {
    if (_didPrefill) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didPrefill) {
        return;
      }
      _prefillFromProfile(passenger);
    });
  }

  Future<void> _onSave() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('passenger.validation'.tr())));
      return;
    }

    if (_selectedLatitude == null || _selectedLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('passenger.location_required'.tr())),
      );
      return;
    }

    final success = await _viewModel.savePassenger(
      id: widget.currentUserId,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      pickupTime: _pickupTimeController.text.trim(),
      returnTime: _returnTimeController.text.trim(),
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('passenger.saved'.tr())));
    }
  }

  Future<Position?> _resolveCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('passenger.location_service_disabled');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw StateError('passenger.location_permission_denied');
    }

    if (permission == LocationPermission.deniedForever) {
      throw StateError('passenger.location_permission_denied_forever');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _setCurrentLocation() async {
    if (_isResolvingLocation) {
      return;
    }

    setState(() {
      _isResolvingLocation = true;
    });

    try {
      final position = await _resolveCurrentPosition();
      if (!mounted || position == null) {
        return;
      }

      setState(() {
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final key = error is StateError
          ? error.message
          : 'passenger.location_unknown_error';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(key.tr())));
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingLocation = false;
        });
      }
    }
  }

  Future<void> _pickLocationOnMap() async {
    final initialTarget =
        (_selectedLatitude != null && _selectedLongitude != null)
        ? LatLng(_selectedLatitude!, _selectedLongitude!)
        : const LatLng(30.0444, 31.2357);

    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => _PassengerMapPickerScreen(
          initialTarget: initialTarget,
          initialSelection:
              (_selectedLatitude != null && _selectedLongitude != null)
              ? LatLng(_selectedLatitude!, _selectedLongitude!)
              : null,
        ),
      ),
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() {
      _selectedLatitude = picked.latitude;
      _selectedLongitude = picked.longitude;
    });
  }

  Future<void> _openInGoogleMaps() async {
    final lat = _selectedLatitude;
    final lng = _selectedLongitude;
    if (lat == null || lng == null) {
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('states.error_message'.tr())));
    }
  }

  String _coordinatesSummary() {
    final lat = _selectedLatitude;
    final lng = _selectedLongitude;
    if (lat == null || lng == null) {
      return 'passenger.coordinates_not_set'.tr();
    }

    return 'passenger.coordinates_selected'.tr(
      args: [lat.toStringAsFixed(6), lng.toStringAsFixed(6)],
    );
  }

  Stream<Passenger?> _passengerProfileStream() {
    return _watchPassengerProfileUseCase(widget.currentUserId);
  }

  Stream<List<PassengerTimelineEvent>> _passengerLogsStream() {
    final since = _timelineSince();
    return _watchPassengerTimelineUseCase(
      passengerId: widget.currentUserId,
      since: since,
      limit: 12,
    );
  }

  DateTime? _timelineSince() {
    final now = DateTime.now();
    if (_timelineWindow == '24h') {
      return now.subtract(const Duration(hours: 24));
    }
    if (_timelineWindow == '7d') {
      return now.subtract(const Duration(days: 7));
    }
    return null;
  }

  String _timelineEventLabel(String type) {
    if (type == 'approaching') {
      return 'passenger.timeline_event_approaching'.tr();
    }
    if (type == 'picked_up_auto') {
      return 'passenger.timeline_event_picked_auto'.tr();
    }
    if (type == 'picked_up_manual') {
      return 'passenger.timeline_event_picked_manual'.tr();
    }
    return type;
  }

  IconData _timelineEventIcon(String type) {
    if (type == 'approaching') {
      return Icons.near_me_outlined;
    }
    if (type == 'picked_up_auto') {
      return Icons.check_circle_outline;
    }
    if (type == 'picked_up_manual') {
      return Icons.verified_outlined;
    }
    return Icons.info_outline;
  }

  String _formatTimelineTime(DateTime? value) {
    if (value == null) {
      return '--';
    }

    final date = value;
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFadeSlideIn(
                  child: AppGradientHeaderCard(
                    icon: Icons.person_add_alt_1,
                    title: 'passenger.title'.tr(),
                    subtitle: 'passenger.live_title'.tr(),
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                AppFadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: AppSectionCard(
                    icon: Icons.badge_outlined,
                    title: 'passenger.title'.tr(),
                    child: Column(
                      children: [
                        StreamBuilder<Passenger?>(
                          stream: _passengerProfileStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const AppSkeletonList(
                                itemCount: 1,
                                compact: true,
                              );
                            }

                            if (snapshot.hasError) {
                              return AppStateCard(
                                icon: Icons.error_outline,
                                title: 'states.error_title'.tr(),
                                message: 'states.error_message'.tr(),
                                actionLabel: 'actions.retry'.tr(),
                                onAction: () => setState(() {}),
                              );
                            }

                            final passenger = snapshot.data;
                            if (passenger != null) {
                              _queuePrefillFromProfile(passenger);
                            }

                            return _PassengerLiveStatusCard(
                              passenger: passenger,
                              locationRepository: widget.locationRepository,
                              estimateEtaMinutes: _estimateEtaMinutes,
                            );
                          },
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        _buildField(
                          controller: _nameController,
                          label: 'passenger.name'.tr(),
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        _buildField(
                          controller: _phoneController,
                          label: 'passenger.phone'.tr(),
                          helperText: 'passenger.id_hint'.tr(),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        _buildField(
                          controller: _addressController,
                          label: 'passenger.address'.tr(),
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        _buildField(
                          controller: _pickupTimeController,
                          label: 'passenger.pickup_time'.tr(),
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        _buildField(
                          controller: _returnTimeController,
                          label: 'passenger.return_time'.tr(),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                AppFadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: AppSectionCard(
                    icon: Icons.location_on_outlined,
                    title: 'passenger.coordinates_title'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _coordinatesSummary(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        Text(
                          'passenger.coordinates_hint'.tr(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        Wrap(
                          spacing: AppSpacing.xs.w,
                          runSpacing: AppSpacing.xs.h,
                          children: [
                            FilledButton.icon(
                              onPressed: _isResolvingLocation
                                  ? null
                                  : _setCurrentLocation,
                              icon: _isResolvingLocation
                                  ? SizedBox(
                                      width: 14.w,
                                      height: 14.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.my_location_outlined),
                              label: Text(
                                'passenger.location_use_current'.tr(),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _pickLocationOnMap,
                              icon: const Icon(Icons.map_outlined),
                              label: Text('passenger.location_pick_map'.tr()),
                            ),
                            if (_selectedLatitude != null &&
                                _selectedLongitude != null)
                              OutlinedButton.icon(
                                onPressed: _openInGoogleMaps,
                                icon: const Icon(Icons.open_in_new),
                                label: Text(
                                  'passenger.location_open_google_maps'.tr(),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm.r),
                          child: SizedBox(
                            height: 170.h,
                            child: GoogleMap(
                              key: ValueKey(
                                'passenger_preview_${_selectedLatitude ?? 30.0444}_${_selectedLongitude ?? 31.2357}',
                              ),
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  _selectedLatitude ?? 30.0444,
                                  _selectedLongitude ?? 31.2357,
                                ),
                                zoom:
                                    _selectedLatitude != null &&
                                        _selectedLongitude != null
                                    ? 15
                                    : 11,
                              ),
                              markers:
                                  _selectedLatitude != null &&
                                      _selectedLongitude != null
                                  ? {
                                      Marker(
                                        markerId: const MarkerId(
                                          'passenger_selected_location',
                                        ),
                                        position: LatLng(
                                          _selectedLatitude!,
                                          _selectedLongitude!,
                                        ),
                                      ),
                                    }
                                  : const <Marker>{},
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                              myLocationEnabled: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                AppFadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: AppSectionCard(
                    icon: Icons.history,
                    title: 'passenger.timeline_title'.tr(),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _timelineWindow,
                          decoration: InputDecoration(
                            labelText: 'passenger.timeline_filter_label'.tr(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: '24h',
                              child: Text('passenger.timeline_filter_24h'.tr()),
                            ),
                            DropdownMenuItem(
                              value: '7d',
                              child: Text('passenger.timeline_filter_7d'.tr()),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('passenger.timeline_filter_all'.tr()),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _timelineWindow = value;
                            });
                          },
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        StreamBuilder<List<PassengerTimelineEvent>>(
                          stream: _passengerLogsStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const AppSkeletonList(
                                itemCount: 3,
                                compact: true,
                              );
                            }

                            if (snapshot.hasError) {
                              return AppStateCard(
                                icon: Icons.error_outline,
                                title: 'states.error_title'.tr(),
                                message: 'states.error_message'.tr(),
                                actionLabel: 'actions.retry'.tr(),
                                onAction: () => setState(() {}),
                              );
                            }

                            final events =
                                snapshot.data ??
                                const <PassengerTimelineEvent>[];
                            if (events.isEmpty) {
                              return Text('passenger.timeline_empty'.tr());
                            }

                            return Column(
                              children: events
                                  .map((event) {
                                    final type = event.type;
                                    final message = event.message;
                                    final when = _formatTimelineTime(
                                      event.createdAt,
                                    );

                                    return AppTimelineTile(
                                      icon: _timelineEventIcon(type),
                                      title: _timelineEventLabel(type),
                                      message: message,
                                      whenLabel:
                                          '${'passenger.timeline_when'.tr()}: $when',
                                    );
                                  })
                                  .toList(growable: false),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _viewModel.isSaving ? null : _onSave,
                    child: _viewModel.isSaving
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text('actions.save'.tr()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? helperText,
    TextInputType keyboardType = TextInputType.text,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return '';
        }
        return null;
      },
    );
  }
}

class _PassengerLiveStatusCard extends StatelessWidget {
  const _PassengerLiveStatusCard({
    required this.passenger,
    required this.locationRepository,
    required this.estimateEtaMinutes,
  });

  final Passenger? passenger;
  final BusLocationRepository locationRepository;
  final int? Function(Passenger passenger, BusLocation? busLocation)
  estimateEtaMinutes;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (passenger == null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Text('passenger.live_profile_hint'.tr()),
      );
    }

    return StreamBuilder<BusLocation?>(
      stream: locationRepository.watchBusLocation(),
      builder: (context, snapshot) {
        final bus = snapshot.data;
        final eta = estimateEtaMinutes(passenger!, bus);

        final statusText = passenger!.isPickedUp
            ? 'driver.status_picked_up'.tr()
            : passenger!.geofenceState == 'approaching'
            ? 'driver.status_approaching'.tr()
            : 'driver.status_waiting'.tr();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.sm.w),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'passenger.live_title'.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.xs.h),
              AppStatusPill(label: statusText, icon: Icons.directions_bus),
              SizedBox(height: AppSpacing.xs.h),
              Text(
                eta == null
                    ? 'driver.eta_unavailable'.tr()
                    : 'driver.eta_format'.tr(args: ['${eta.clamp(1, 999)}']),
                style: TextStyle(color: colorScheme.onPrimaryContainer),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PassengerMapPickerScreen extends StatefulWidget {
  const _PassengerMapPickerScreen({
    required this.initialTarget,
    this.initialSelection,
  });

  final LatLng initialTarget;
  final LatLng? initialSelection;

  @override
  State<_PassengerMapPickerScreen> createState() =>
      _PassengerMapPickerScreenState();
}

class _PassengerMapPickerScreenState extends State<_PassengerMapPickerScreen> {
  late LatLng _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection ?? widget.initialTarget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('passenger.map_picker_title'.tr())),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.initialTarget,
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('picked_location'),
                  position: _selected,
                ),
              },
              onTap: (position) {
                setState(() {
                  _selected = position;
                });
              },
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'passenger.map_picker_hint'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(height: AppSpacing.sm.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('driver.cancel'.tr()),
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs.w),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(_selected),
                        child: Text('passenger.map_picker_confirm'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
