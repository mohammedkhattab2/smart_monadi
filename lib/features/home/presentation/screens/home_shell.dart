import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_monadi/app/di/app_dependencies.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/app/design/design_tokens.dart';
import 'package:smart_monadi/features/auth/domain/user_role.dart';
import 'package:smart_monadi/features/driver/presentation/screens/driver_screen.dart';
import 'package:smart_monadi/features/driver/presentation/viewmodels/driver_live_view_model.dart';
import 'package:smart_monadi/features/operations/presentation/screens/operations_dashboard_screen.dart';
import 'package:smart_monadi/features/operations/presentation/viewmodels/operations_dashboard_view_model.dart';
import 'package:smart_monadi/features/passenger/presentation/screens/passenger_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _driverViewModel = widget.dependencies.createDriverLiveViewModel();
    _operationsViewModel = widget.dependencies
        .createOperationsDashboardViewModel();
  }

  @override
  void dispose() {
    _driverViewModel.dispose();
    _operationsViewModel.dispose();
    super.dispose();
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
        label: 'tabs.passenger'.tr(),
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
    if (widget.role == UserRole.passenger) {
      return 'tabs.passenger'.tr();
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
    final pages = widget.role == UserRole.driver
        ? [
            DriverScreen(viewModel: _driverViewModel),
            OperationsDashboardScreen(viewModel: _operationsViewModel),
          ]
        : [
            PassengerScreen(
              repository: widget.dependencies.passengerRepository,
              locationRepository: widget.dependencies.locationRepository,
              currentUserId: widget.currentUserId,
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
                  : 'tabs.passenger'.tr(),
              icon: widget.role == UserRole.driver
                  ? Icons.badge_outlined
                  : Icons.person_outline,
            ),
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
      body: isWide
          ? (hasMultipleTabs
                ? Row(
                    children: [
                      Container(
                        width: 86.w,
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          border: Border(
                            right: BorderSide(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
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
