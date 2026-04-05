import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smart_monadi/app/design/app_primitives.dart';
import 'package:smart_monadi/app/design/design_tokens.dart';

class OperationsDashboardScreen extends StatefulWidget {
  const OperationsDashboardScreen({super.key});

  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  static final RegExp _e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');
  static final RegExp _timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  final _testPhoneController = TextEditingController();
  final _testNameController = TextEditingController(text: 'Test Passenger');
  final _testPickupTimeController = TextEditingController(text: '07:30');
  String _selectedTemplate = 'arriving_soon';
  bool _isEnqueuing = false;
  final Set<String> _requeueInProgress = <String>{};
  String _selectedEventTypeFilter = 'all';
  String _selectedTimeFilter = '24h';

  String _todayKey() => DateTime.now().toIso8601String().substring(0, 10);

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate().toLocal();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:$minute';
    }
    return '--';
  }

  @override
  void dispose() {
    _testPhoneController.dispose();
    _testNameController.dispose();
    _testPickupTimeController.dispose();
    super.dispose();
  }

  Future<void> _enqueueTestSms() async {
    final phone = _testPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ops.test.validation_phone'.tr())));
      return;
    }

    if (!_e164Regex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ops.test.validation_phone_format'.tr())),
      );
      return;
    }

    final pickupTime = _testPickupTimeController.text.trim();
    if (!_timeRegex.hasMatch(pickupTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ops.test.validation_pickup_time'.tr())),
      );
      return;
    }

    setState(() {
      _isEnqueuing = true;
    });

    try {
      await FirebaseFirestore.instance.collection('sms_outbox').add({
        'passengerId': 'manual-test',
        'toPhone': phone,
        'template': _selectedTemplate,
        'variables': {
          'name': _testNameController.text.trim(),
          'pickupTime': _testPickupTimeController.text.trim(),
        },
        'status': 'pending',
        'attempts': 0,
        'createdAt': Timestamp.now(),
        'nextRetryAt': Timestamp.now(),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ops.test.enqueued'.tr())));
      _testPhoneController.clear();
    } finally {
      if (mounted) {
        setState(() {
          _isEnqueuing = false;
        });
      }
    }
  }

  Future<void> _requeueDeadLetter(
    String deadLetterId,
    Map<String, dynamic> deadLetter,
  ) async {
    setState(() {
      _requeueInProgress.add(deadLetterId);
    });

    try {
      final originalPayloadRaw = deadLetter['originalPayload'];
      final originalPayload = originalPayloadRaw is Map
          ? originalPayloadRaw.map(
              (key, value) => MapEntry(key.toString(), value),
            )
          : const <String, dynamic>{};
      final toPhone =
          (originalPayload['toPhone'] ?? deadLetter['toPhone'] ?? '')
              .toString()
              .trim();
      final template =
          (originalPayload['template'] ??
                  deadLetter['template'] ??
                  'arriving_soon')
              .toString();
      final passengerId =
          (originalPayload['passengerId'] ??
                  deadLetter['passengerId'] ??
                  'manual-retry')
              .toString();
      final rawVariables =
          originalPayload['variables'] ?? deadLetter['variables'] ?? const {};
      final variables = rawVariables is Map
          ? rawVariables.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{};

      if (toPhone.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ops.retry.missing_phone'.tr())));
        return;
      }

      await FirebaseFirestore.instance.collection('sms_outbox').add({
        'passengerId': passengerId,
        'toPhone': toPhone,
        'template': template,
        'variables': variables,
        'status': 'pending',
        'attempts': 0,
        'createdAt': Timestamp.now(),
        'nextRetryAt': Timestamp.now(),
        'retrySource': 'dead_letter_manual',
        'deadLetterId': deadLetterId,
      });

      await FirebaseFirestore.instance
          .collection('sms_outbox_dead_letter')
          .doc(deadLetterId)
          .set({
            'lastRequeuedAt': Timestamp.now(),
            'requeueCount': FieldValue.increment(1),
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('sms_delivery_events').add({
        'messageId': deadLetterId,
        'type': 'requeued_manual',
        'payload': {
          'source': 'operations_dashboard',
          'toPhone': toPhone,
          'template': template,
        },
        'createdAt': Timestamp.now(),
      });

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ops.retry.success'.tr())));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ops.retry.failed'.tr())));
    } finally {
      if (mounted) {
        setState(() {
          _requeueInProgress.remove(deadLetterId);
        });
      }
    }
  }

  String _buildEventSubtitle(Map<String, dynamic> data) {
    final messageId = (data['messageId'] ?? '').toString();
    final createdAt = _formatTimestamp(data['createdAt']);
    final payloadRaw = data['payload'];
    final payload = payloadRaw is Map
        ? payloadRaw.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final errorCategory = (payload['errorCategory'] ?? '').toString();
    final errorUserMessage = (payload['errorUserMessage'] ?? '').toString();

    final parts = <String>[messageId];
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

  String _buildDeadLetterSubtitle(Map<String, dynamic> data) {
    final reason = (data['reason'] ?? '').toString();
    final movedAt = _formatTimestamp(data['movedAt']);
    final errorUserMessage = (data['errorUserMessage'] ?? '').toString();
    final errorMessage = (data['errorMessage'] ?? '').toString();
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

  DateTime? _timeFilterSince() {
    final now = DateTime.now();
    switch (_selectedTimeFilter) {
      case '1h':
        return now.subtract(const Duration(hours: 1));
      case '24h':
        return now.subtract(const Duration(hours: 24));
      case '7d':
        return now.subtract(const Duration(days: 7));
      default:
        return null;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _eventsStream(
    FirebaseFirestore firestore,
  ) {
    final since = _timeFilterSince();
    if (since == null) {
      return firestore
          .collection('sms_delivery_events')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    }

    return firestore
        .collection('sms_delivery_events')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
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
    final firestore = FirebaseFirestore.instance;
    final colorScheme = Theme.of(context).colorScheme;

    final metricsDoc = firestore.collection('sms_metrics').doc(_todayKey());
    final eventsStream = _eventsStream(firestore);
    final deadLetterStream = firestore
        .collection('sms_outbox_dead_letter')
        .orderBy('movedAt', descending: true)
        .limit(10)
        .snapshots();

    return ListView(
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
                  decoration: InputDecoration(labelText: 'ops.test.phone'.tr()),
                ),
                SizedBox(height: AppSpacing.xs.h),
                TextField(
                  controller: _testNameController,
                  decoration: InputDecoration(labelText: 'ops.test.name'.tr()),
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
                  initialValue: _selectedTemplate,
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
                    setState(() {
                      _selectedTemplate = value;
                    });
                  },
                ),
                SizedBox(height: AppSpacing.sm.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isEnqueuing ? null : _enqueueTestSms,
                    child: _isEnqueuing
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Text('ops.test.enqueue'.tr()),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.sm.h),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: metricsDoc.snapshots(),
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

            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final sent = (data['sentCount'] as num?)?.toInt() ?? 0;
            final failed = (data['failedCount'] as num?)?.toInt() ?? 0;
            final failedPermanent =
                (data['failedPermanentCount'] as num?)?.toInt() ?? 0;

            return AppFadeSlideIn(
              delay: const Duration(milliseconds: 120),
              child: Wrap(
                spacing: AppSpacing.xs.w,
                runSpacing: AppSpacing.xs.h,
                children: [
                  _MetricCard(
                    label: 'ops.metrics.sent'.tr(),
                    value: sent,
                    icon: Icons.check_circle_outline,
                    color: colorScheme.primary,
                  ),
                  _MetricCard(
                    label: 'ops.metrics.failed'.tr(),
                    value: failed,
                    icon: Icons.refresh_outlined,
                    color: colorScheme.tertiary,
                  ),
                  _MetricCard(
                    label: 'ops.metrics.failed_permanent'.tr(),
                    value: failedPermanent,
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
                        selected: _selectedTimeFilter == option.key,
                        onSelected: (_) {
                          setState(() {
                            _selectedTimeFilter = option.key;
                          });
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
                        selected: _selectedEventTypeFilter == option.key,
                        onSelected: (_) {
                          setState(() {
                            _selectedEventTypeFilter = option.key;
                          });
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: eventsStream,
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

            final docs = snapshot.data?.docs ?? const [];
            final filteredDocs = docs
                .where((doc) {
                  if (_selectedEventTypeFilter == 'all') {
                    return true;
                  }
                  return (doc.data()['type'] ?? '').toString() ==
                      _selectedEventTypeFilter;
                })
                .toList(growable: false);

            if (filteredDocs.isEmpty) {
              return AppStateCard(
                icon: Icons.inbox_outlined,
                title: 'states.empty_title'.tr(),
                message: 'ops.empty_events'.tr(),
              );
            }

            return Column(
              children: filteredDocs
                  .asMap()
                  .entries
                  .map((entry) {
                    final doc = entry.value;
                    final rowIndex = entry.key;
                    final data = doc.data();
                    final type = (data['type'] ?? '').toString();
                    final messageId = (data['messageId'] ?? '').toString();
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
                                    onPressed: () => _copyMessageId(messageId),
                                    icon: const Icon(Icons.copy_rounded),
                                  ),
                                ],
                              ),
                              SizedBox(height: AppSpacing.xs.h),
                              Text(
                                _buildEventSubtitle(data),
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
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: deadLetterStream,
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

            final docs = snapshot.data?.docs ?? const [];
            if (docs.isEmpty) {
              return AppStateCard(
                icon: Icons.inbox_outlined,
                title: 'states.empty_title'.tr(),
                message: 'ops.empty_dead_letter'.tr(),
              );
            }

            return Column(
              children: docs
                  .asMap()
                  .entries
                  .map((entry) {
                    final doc = entry.value;
                    final rowIndex = entry.key;
                    final data = doc.data();
                    final to = (data['toPhone'] ?? '').toString();
                    final attempts = (data['attempts'] as num?)?.toInt() ?? 0;
                    final isRequeueing = _requeueInProgress.contains(doc.id);
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
                                    label: '${'ops.attempts'.tr()}: $attempts',
                                    icon: Icons.numbers,
                                    color: deadColor,
                                  ),
                                ],
                              ),
                              SizedBox(height: AppSpacing.xs.h),
                              Text(
                                _buildDeadLetterSubtitle(data),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              SizedBox(height: AppSpacing.sm.h),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: OutlinedButton(
                                  onPressed: isRequeueing
                                      ? null
                                      : () => _requeueDeadLetter(doc.id, data),
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
