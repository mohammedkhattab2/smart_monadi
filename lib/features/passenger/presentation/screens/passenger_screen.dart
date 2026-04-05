import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
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
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  StreamSubscription<List<PassengerTimelineEvent>>? _timelineSubscription;
  Timer? _timelineSnackDebounce;
  final Set<String> _seenTimelineEventIds = <String>{};
  final List<String> _pendingTimelineLabels = <String>[];
  bool _timelinePrimed = false;
  String _timelineWindow = '24h';
  bool _didPrefill = false;

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
    _latitudeController.dispose();
    _longitudeController.dispose();
    _timelineSubscription?.cancel();
    _timelineSnackDebounce?.cancel();
    super.dispose();
  }

  void _listenForNewTimelineEvents() {
    _timelineSubscription =
        _watchPassengerTimelineUseCase(
          passengerId: widget.currentUserId,
          limit: 5,
        ).listen((events) {
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
        });
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

  double? _parseCoordinate(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text);
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
    _latitudeController.text = passenger.latitude?.toString() ?? '';
    _longitudeController.text = passenger.longitude?.toString() ?? '';
    _didPrefill = true;
  }

  Future<void> _onSave() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('passenger.validation'.tr())));
      return;
    }

    final success = await _viewModel.savePassenger(
      id: widget.currentUserId,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      pickupTime: _pickupTimeController.text.trim(),
      returnTime: _returnTimeController.text.trim(),
      latitude: _parseCoordinate(_latitudeController.text),
      longitude: _parseCoordinate(_longitudeController.text),
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
                              _prefillFromProfile(passenger);
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
                    title: 'passenger.coordinates_hint'.tr(),
                    child: Column(
                      children: [
                        _buildField(
                          controller: _latitudeController,
                          label: 'passenger.latitude'.tr(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          required: false,
                        ),
                        SizedBox(height: AppSpacing.sm.h),
                        _buildField(
                          controller: _longitudeController,
                          label: 'passenger.longitude'.tr(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          required: false,
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
