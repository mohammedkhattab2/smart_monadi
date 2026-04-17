import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_monadi/app/di/app_dependencies.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/app/design/design_tokens.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';
import 'package:smart_monadi/features/driver/presentation/screens/driver_screen.dart';
import 'package:smart_monadi/features/driver/presentation/viewmodels/driver_live_view_model.dart';
import 'package:smart_monadi/features/notifications/domain/entities/notification_route_intent.dart';
import 'package:smart_monadi/features/operations/presentation/screens/operations_dashboard_screen.dart';
import 'package:smart_monadi/features/operations/presentation/viewmodels/operations_dashboard_view_model.dart';
import 'package:smart_monadi/features/parent/presentation/screens/parent_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.dependencies,
    required this.role,
    required this.currentUserId,
    required this.onSignOut,
    required this.onToggleLocale,
    required this.onToggleTheme,
  });

  final AppDependencies dependencies;
  final UserRole role;
  final String currentUserId;
  final Future<void> Function() onSignOut;
  final VoidCallback onToggleLocale;
  final VoidCallback onToggleTheme;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final DriverLiveViewModel _driverViewModel;
  late final OperationsDashboardViewModel _operationsViewModel;
  int _currentIndex = 0;
  String? _tripLockHint;
  Timer? _tripLockHintTimer;

  @override
  void initState() {
    super.initState();
    _driverViewModel = widget.dependencies.createDriverLiveViewModel();
    _operationsViewModel = widget.dependencies
        .createOperationsDashboardViewModel();
    widget.dependencies.notificationRouteIntent.addListener(
      _handleNotificationRouteIntent,
    );
    widget.dependencies.activeTripController.addListener(
      _handleActiveTripStateChanged,
    );
  }

  @override
  void dispose() {
    widget.dependencies.notificationRouteIntent.removeListener(
      _handleNotificationRouteIntent,
    );
    widget.dependencies.activeTripController.removeListener(
      _handleActiveTripStateChanged,
    );
    _tripLockHintTimer?.cancel();
    _driverViewModel.dispose();
    _operationsViewModel.dispose();
    super.dispose();
  }

  void _handleActiveTripStateChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleNotificationRouteIntent() {
    if (!mounted) {
      return;
    }

    final intent = widget.dependencies.notificationRouteIntent.value;
    if (intent == null) {
      return;
    }

    final updateResult = widget.dependencies.activeTripController.applyIntent(
      intent,
    );
    if (!updateResult.updated) {
      if (updateResult.skippedDueToActiveContext) {
        _log('📲 Navigation skipped due to active trip context');
        _showTripLockHint(updateResult.message);
      }
      _log('⚠️ Trip state update skipped: ${updateResult.message}');
      widget.dependencies.notificationRouteIntent.value = null;
      return;
    }

    final updatedTripId = updateResult.state?.tripId ?? '';
    if (updatedTripId.isEmpty) {
      _log('🟢 Active trip state cleared: ${updateResult.message}');
      _tripLockHint = null;
      widget.dependencies.notificationRouteIntent.value = null;
      setState(() {});
      return;
    }

    _log('📡 Trip state updated from notification: $updatedTripId');

    if (!updateResult.shouldNavigate) {
      _log('📲 Navigation skipped due to active trip context');
      _log('🎯 UI updated without navigation (live bind mode)');
      _showTripLockHint('Active trip locked: live update mode');
      widget.dependencies.notificationRouteIntent.value = null;
      return;
    }

    final targetIndex = _resolveIndexForIntent(intent);
    if (targetIndex != null && targetIndex != _currentIndex) {
      setState(() {
        _currentIndex = targetIndex;
      });
    } else {
      // Keep state in-place and refresh current flow for active trip updates.
      setState(() {});
    }

    final routeLabel = _resolveLiveScreenLabel(intent);
    _log(
      '📲 Navigating to LIVE SCREEN: $routeLabel '
      '(tripId=${intent.tripId}, status=${intent.status}, source=${intent.source})',
    );
    _log('📦 Payload routing decision: ${intent.payload}');

    widget.dependencies.notificationRouteIntent.value = null;
  }

  void _showTripLockHint(String message) {
    if (!mounted) {
      return;
    }

    _tripLockHintTimer?.cancel();
    setState(() {
      _tripLockHint = message;
    });

    _tripLockHintTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _tripLockHint = null;
      });
    });
  }

  int? _resolveIndexForIntent(NotificationRouteIntent intent) {
    if (widget.role == UserRole.parent) {
      return 0;
    }

    switch (intent.target) {
      case NotificationRouteTarget.tripDetails:
      case NotificationRouteTarget.liveTracking:
      case NotificationRouteTarget.eta:
        return 0;
      case NotificationRouteTarget.home:
        return null;
    }
  }

  String _resolveLiveScreenLabel(NotificationRouteIntent intent) {
    if (widget.role == UserRole.driver) {
      switch (intent.target) {
        case NotificationRouteTarget.tripDetails:
          return 'DriverScreen: Trip Details Flow';
        case NotificationRouteTarget.liveTracking:
          return 'DriverScreen: Live Tracking';
        case NotificationRouteTarget.eta:
          return 'DriverScreen: ETA Overlay';
        case NotificationRouteTarget.home:
          return 'HomeShell (current tab preserved)';
      }
    }

    switch (intent.target) {
      case NotificationRouteTarget.tripDetails:
        return 'ParentScreen: Trip Details';
      case NotificationRouteTarget.liveTracking:
        return 'ParentScreen: Live Tracking';
      case NotificationRouteTarget.eta:
        return 'ParentScreen: ETA View';
      case NotificationRouteTarget.home:
        return 'ParentScreen';
    }
  }

  void _log(String message) {
    // ignore: avoid_print
    print(message);
  }

  List<NavigationDestination> _bottomDestinations() {
    if (widget.role == UserRole.driver) {
      return [
        NavigationDestination(
          icon: const Icon(Icons.directions_bus_outlined),
          selectedIcon: const Icon(Icons.directions_bus),
          label: 'tabs.driver'.tr(),
        ),
        NavigationDestination(
          icon: const Icon(Icons.analytics_outlined),
          selectedIcon: const Icon(Icons.analytics),
          label: 'tabs.operations'.tr(),
        ),
      ];
    }

    return [
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: 'tabs.parent'.tr(),
      ),
    ];
  }

  List<NavigationRailDestination> _railDestinations() {
    final bottom = _bottomDestinations();
    return bottom
        .map(
          (d) => NavigationRailDestination(
            icon: d.icon,
            selectedIcon: d.selectedIcon,
            label: Text(d.label),
          ),
        )
        .toList(growable: false);
  }

  String _currentTabLabel() {
    if (widget.role == UserRole.parent) {
      return 'tabs.parent'.tr();
    }

    switch (_currentIndex) {
      case 0:
        return 'tabs.driver'.tr();
      default:
        return 'tabs.operations'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 980;
    final activeTrip = widget.dependencies.activeTripController.value;
    final hasLockedTrip = activeTrip?.hasTripId ?? false;
    final pages = widget.role == UserRole.driver
        ? [
            DriverScreen(
              viewModel: _driverViewModel,
              activeTripController: widget.dependencies.activeTripController,
            ),
            OperationsDashboardScreen(viewModel: _operationsViewModel),
          ]
        : [
            ParentScreen(
              repository: widget.dependencies.passengerRepository,
              locationRepository: widget.dependencies.locationRepository,
              currentUserId: widget.currentUserId,
              activeTripController: widget.dependencies.activeTripController,
            ),
          ];
    final hasMultipleTabs = pages.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('app.name'.tr()),
                  Text(
                    _currentTabLabel(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            AppStatusPill(
              label: widget.role == UserRole.driver
                  ? 'tabs.driver'.tr()
                  : 'tabs.parent'.tr(),
              icon: widget.role == UserRole.driver
                  ? Icons.badge_outlined
                  : Icons.person_outline,
            ),
            if (hasLockedTrip) ...[
              SizedBox(width: AppSpacing.xs.w),
              const AppStatusPill(
                label: 'Active Trip Locked',
                icon: Icons.lock_outline,
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'actions.switch_language'.tr(),
            onPressed: widget.onToggleLocale,
            icon: const Icon(Icons.language),
          ),
          IconButton(
            tooltip: 'actions.switch_theme'.tr(),
            onPressed: widget.onToggleTheme,
            icon: const Icon(Icons.brightness_6_outlined),
          ),
          IconButton(
            tooltip: 'actions.logout'.tr(),
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tripLockHint != null)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
              child: AppSectionCard(
                icon: Icons.info_outline,
                title: 'Live Trip Update',
                child: Text(_tripLockHint!),
              ),
            ),
          Expanded(
            child: isWide
                ? (hasMultipleTabs
                      ? Row(
                          children: [
                            Container(
                              width: 86.w,
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                border: Border(
                                  right: BorderSide(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              child: NavigationRail(
                                selectedIndex: _currentIndex,
                                onDestinationSelected: (index) {
                                  setState(() {
                                    _currentIndex = index;
                                  });
                                },
                                groupAlignment: -0.85,
                                labelType: NavigationRailLabelType.selected,
                                destinations: _railDestinations(),
                              ),
                            ),
                            Expanded(
                              child: AppFadeSlideIn(
                                key: ValueKey<int>(_currentIndex),
                                child: pages[_currentIndex],
                              ),
                            ),
                          ],
                        )
                      : pages.first)
                : (hasMultipleTabs
                      ? AnimatedSwitcher(
                          duration: AppMotion.medium,
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: KeyedSubtree(
                            key: ValueKey<int>(_currentIndex),
                            child: pages[_currentIndex],
                          ),
                        )
                      : pages.first),
          ),
        ],
      ),
      bottomNavigationBar: (!isWide && hasMultipleTabs)
          ? NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              destinations: _bottomDestinations(),
            )
          : null,
    );
  }
}
