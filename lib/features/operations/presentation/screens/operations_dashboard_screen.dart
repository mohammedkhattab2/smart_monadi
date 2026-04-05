import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/app/design/design_tokens.dart';
import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';
import 'package:smart_monadi/features/operations/presentation/viewmodels/operations_dashboard_view_model.dart';

class OperationsDashboardScreen extends StatefulWidget {
  const OperationsDashboardScreen({super.key, required this.viewModel});

  final OperationsDashboardViewModel viewModel;

  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  final _testPhoneController = TextEditingController();
  final _testNameController = TextEditingController(text: 'Test Passenger');
  final _testPickupTimeController = TextEditingController(text: '07:30');
  late final OperationsDashboardViewModel _viewModel;

  String _formatTimestamp(DateTime? value) {
    if (value != null) {
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute';
    }
    return '--';
  }

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel;
  }

  @override
  void dispose() {
    _testPhoneController.dispose();
    _testNameController.dispose();
    _testPickupTimeController.dispose();
    super.dispose();
  }

  Future<void> _enqueueTestSms() async {
    final errorKey = await _viewModel.enqueueTestSms(
      phone: _testPhoneController.text,
      name: _testNameController.text,
      pickupTime: _testPickupTimeController.text,
    );

    if (!mounted) {
      return;
    }

    if (errorKey != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorKey.tr())));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ops.test.enqueued'.tr())));
    _testPhoneController.clear();
  }

  Future<void> _requeueDeadLetter(OperationsDeadLetter deadLetter) async {
    final errorKey = await _viewModel.requeueDeadLetter(deadLetter);
    if (!mounted) {
      return;
    }

    if (errorKey != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorKey.tr())));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ops.retry.success'.tr())));
  }

  String _buildEventSubtitle(OperationsDeliveryEvent event) {
    final createdAt = _formatTimestamp(event.createdAt);
    final errorCategory = (event.payload['errorCategory'] ?? '').toString();
    final errorUserMessage = (event.payload['errorUserMessage'] ?? '')
        .toString();

    final parts = <String>[event.messageId];
    parts.add('${'ops.when'.tr()}: $createdAt');
    if (errorCategory.isNotEmpty) {
      parts.add('${'ops.error_category'.tr()}: $errorCategory');
    }
    if (errorUserMessage.isNotEmpty) {
      parts.add(errorUserMessage);
    }
    return parts.join('\n');
  }

  Future<void> _copyMessageId(String messageId) async {
    if (messageId.trim().isEmpty) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: messageId));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('ops.copy.copied'.tr())));
  }

  String _buildDeadLetterSubtitle(OperationsDeadLetter deadLetter) {
    final reason = deadLetter.reason;
    final movedAt = _formatTimestamp(deadLetter.movedAt);
    final errorUserMessage = deadLetter.errorUserMessage;
    final errorMessage = deadLetter.errorMessage;
    final parts = <String>[
      '${'ops.reason'.tr()}: $reason',
      '${'ops.when'.tr()}: $movedAt',
    ];

    if (errorUserMessage.isNotEmpty) {
      parts.add(errorUserMessage);
    } else if (errorMessage.isNotEmpty) {
      parts.add(errorMessage);
    }

    return parts.join('\n');
  }

  Color _eventColor(String type, ColorScheme colorScheme) {
    if (type == 'sent') {
      return colorScheme.primary;
    }
    if (type == 'failed_permanent') {
      return colorScheme.error;
    }
    if (type == 'failed_retry_scheduled') {
      return colorScheme.tertiary;
    }
    if (type == 'requeued_manual') {
      return colorScheme.secondary;
    }
    return colorScheme.outline;
  }

  IconData _eventIcon(String type) {
    if (type == 'sent') {
      return Icons.check_circle_outline;
    }
    if (type == 'failed_permanent') {
      return Icons.error_outline;
    }
    if (type == 'failed_retry_scheduled') {
      return Icons.refresh_outlined;
    }
    if (type == 'requeued_manual') {
      return Icons.redo;
    }
    return Icons.info_outline;
  }

  List<MapEntry<String, String>> _timeFilterOptions(BuildContext context) {
    return [
      MapEntry('1h', 'ops.time_filter.last_1h'.tr()),
      MapEntry('24h', 'ops.time_filter.last_24h'.tr()),
      MapEntry('7d', 'ops.time_filter.last_7d'.tr()),
      MapEntry('all', 'ops.time_filter.all'.tr()),
    ];
  }

  List<MapEntry<String, String>> _eventFilterOptions(BuildContext context) {
    return [
      MapEntry('all', 'ops.filter.all'.tr()),
      MapEntry('sent', 'ops.filter.sent'.tr()),
      MapEntry('failed_retry_scheduled', 'ops.filter.failed_retry'.tr()),
      MapEntry('failed_permanent', 'ops.filter.failed_permanent'.tr()),
      MapEntry('requeued_manual', 'ops.filter.requeued'.tr()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          AppFadeSlideIn(
            child: AppGradientHeaderCard(
              icon: Icons.dashboard_customize_outlined,
              title: 'ops.title'.tr(),
              subtitle: 'ops.recent_events'.tr(),
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          AppFadeSlideIn(
            delay: const Duration(milliseconds: 70),
            child: AppSectionCard(
              icon: Icons.sms_outlined,
              title: 'ops.test.title'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _testPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'ops.test.phone'.tr(),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  TextField(
                    controller: _testNameController,
                    decoration: InputDecoration(
                      labelText: 'ops.test.name'.tr(),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  TextField(
                    controller: _testPickupTimeController,
                    decoration: InputDecoration(
                      labelText: 'ops.test.pickup_time'.tr(),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  DropdownButtonFormField<String>(
                    initialValue: _viewModel.selectedTemplate,
                    decoration: InputDecoration(
                      labelText: 'ops.test.template'.tr(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'arriving_soon',
                        child: Text('ops.test.template_arriving'.tr()),
                      ),
                      DropdownMenuItem(
                        value: 'arrival_now',
                        child: Text('ops.test.template_arrived'.tr()),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      _viewModel.setTemplate(value);
                    },
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _viewModel.isEnqueuing
                          ? null
                          : _enqueueTestSms,
                      child: _viewModel.isEnqueuing
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Text('ops.test.enqueue'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          StreamBuilder<OperationsMetrics>(
            stream: _viewModel.watchMetrics(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppStateCard(
                  icon: Icons.error_outline,
                  title: 'states.error_title'.tr(),
                  message: 'states.error_message'.tr(),
                  actionLabel: 'actions.retry'.tr(),
                  onAction: () => setState(() {}),
                );
              }

              final metrics =
                  snapshot.data ??
                  const OperationsMetrics(
                    sent: 0,
                    failed: 0,
                    failedPermanent: 0,
                  );

              return AppFadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: Wrap(
                  spacing: AppSpacing.xs.w,
                  runSpacing: AppSpacing.xs.h,
                  children: [
                    _MetricCard(
                      label: 'ops.metrics.sent'.tr(),
                      value: metrics.sent,
                      icon: Icons.check_circle_outline,
                      color: colorScheme.primary,
                    ),
                    _MetricCard(
                      label: 'ops.metrics.failed'.tr(),
                      value: metrics.failed,
                      icon: Icons.refresh_outlined,
                      color: colorScheme.tertiary,
                    ),
                    _MetricCard(
                      label: 'ops.metrics.failed_permanent'.tr(),
                      value: metrics.failedPermanent,
                      icon: Icons.error_outline,
                      color: colorScheme.error,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: AppSpacing.md.h),
          AppSectionCard(
            icon: Icons.tune,
            title: 'ops.recent_events'.tr(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ops.time_filter.label'.tr(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                SizedBox(height: AppSpacing.xs.h),
                Wrap(
                  spacing: AppSpacing.xs.w,
                  runSpacing: AppSpacing.xxs.h,
                  children: _timeFilterOptions(context)
                      .map(
                        (option) => ChoiceChip(
                          label: Text(option.value),
                          selected: _viewModel.selectedTimeFilter == option.key,
                          onSelected: (_) {
                            _viewModel.setTimeFilter(option.key);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  'ops.filter.label'.tr(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                SizedBox(height: AppSpacing.xs.h),
                Wrap(
                  spacing: AppSpacing.xs.w,
                  runSpacing: AppSpacing.xxs.h,
                  children: _eventFilterOptions(context)
                      .map(
                        (option) => ChoiceChip(
                          label: Text(option.value),
                          selected:
                              _viewModel.selectedEventTypeFilter == option.key,
                          onSelected: (_) {
                            _viewModel.setEventTypeFilter(option.key);
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          StreamBuilder<List<OperationsDeliveryEvent>>(
            stream: _viewModel.watchEvents(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppSkeletonList(itemCount: 3);
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

              final events = snapshot.data ?? const <OperationsDeliveryEvent>[];
              final filteredEvents = _viewModel.filterEvents(events);

              if (filteredEvents.isEmpty) {
                return AppStateCard(
                  icon: Icons.inbox_outlined,
                  title: 'states.empty_title'.tr(),
                  message: 'ops.empty_events'.tr(),
                );
              }

              return Column(
                children: filteredEvents
                    .asMap()
                    .entries
                    .map((entry) {
                      final event = entry.value;
                      final rowIndex = entry.key;
                      final type = event.type;
                      final messageId = event.messageId;
                      final eventColor = _eventColor(type, colorScheme);
                      return AppFadeSlideIn(
                        delay: Duration(
                          milliseconds:
                              150 + (rowIndex * 40).clamp(0, 280).toInt(),
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
                                      radius: 16.r,
                                      backgroundColor: eventColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      child: Icon(
                                        _eventIcon(type),
                                        color: eventColor,
                                        size: 18,
                                      ),
                                    ),
                                    SizedBox(width: AppSpacing.xs.w),
                                    Expanded(
                                      child: AppStatusPill(
                                        label: type,
                                        icon: Icons.info_outline,
                                        color: eventColor,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'ops.copy.action'.tr(),
                                      onPressed: () =>
                                          _copyMessageId(messageId),
                                      icon: const Icon(Icons.copy_rounded),
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppSpacing.xs.h),
                                Text(
                                  _buildEventSubtitle(event),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            'ops.dead_letter'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: AppSpacing.xs.h),
          StreamBuilder<List<OperationsDeadLetter>>(
            stream: _viewModel.watchDeadLetters(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppSkeletonList(itemCount: 2);
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

              final deadLetters =
                  snapshot.data ?? const <OperationsDeadLetter>[];
              if (deadLetters.isEmpty) {
                return AppStateCard(
                  icon: Icons.inbox_outlined,
                  title: 'states.empty_title'.tr(),
                  message: 'ops.empty_dead_letter'.tr(),
                );
              }

              return Column(
                children: deadLetters
                    .asMap()
                    .entries
                    .map((entry) {
                      final deadLetter = entry.value;
                      final rowIndex = entry.key;
                      final to = deadLetter.toPhone;
                      final attempts = deadLetter.attempts;
                      final isRequeueing = _viewModel.requeueInProgress
                          .contains(deadLetter.id);
                      final deadColor = attempts >= 3
                          ? colorScheme.error
                          : colorScheme.tertiary;

                      return AppFadeSlideIn(
                        delay: Duration(
                          milliseconds:
                              170 + (rowIndex * 45).clamp(0, 320).toInt(),
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
                                      radius: 16.r,
                                      backgroundColor: deadColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      child: Icon(
                                        Icons.sms_failed_outlined,
                                        color: deadColor,
                                        size: 18,
                                      ),
                                    ),
                                    SizedBox(width: AppSpacing.xs.w),
                                    Expanded(
                                      child: Text(
                                        to,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    AppStatusPill(
                                      label:
                                          '${'ops.attempts'.tr()}: $attempts',
                                      icon: Icons.numbers,
                                      color: deadColor,
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppSpacing.xs.h),
                                Text(
                                  _buildDeadLetterSubtitle(deadLetter),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                SizedBox(height: AppSpacing.sm.h),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: OutlinedButton(
                                    onPressed: isRequeueing
                                        ? null
                                        : () => _requeueDeadLetter(deadLetter),
                                    child: isRequeueing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text('ops.retry.action'.tr()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 114.w,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(height: 6.h),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
          SizedBox(height: 6.h),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
