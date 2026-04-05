import 'package:flutter/foundation.dart';
import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';
import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';
import 'package:smart_monadi/features/operations/domain/usecases/enqueue_test_sms_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/requeue_dead_letter_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_dead_letters_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_events_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_metrics_use_case.dart';

class OperationsDashboardViewModel extends ChangeNotifier {
  OperationsDashboardViewModel({
    required WatchOperationsMetricsUseCase watchMetricsUseCase,
    required WatchOperationsEventsUseCase watchEventsUseCase,
    required WatchOperationsDeadLettersUseCase watchDeadLettersUseCase,
    required EnqueueTestSmsUseCase enqueueTestSmsUseCase,
    required RequeueDeadLetterUseCase requeueDeadLetterUseCase,
  }) : _watchMetricsUseCase = watchMetricsUseCase,
       _watchEventsUseCase = watchEventsUseCase,
       _watchDeadLettersUseCase = watchDeadLettersUseCase,
       _enqueueTestSmsUseCase = enqueueTestSmsUseCase,
       _requeueDeadLetterUseCase = requeueDeadLetterUseCase;

  factory OperationsDashboardViewModel.fromRepository(
    OperationsRepository repository,
  ) {
    return OperationsDashboardViewModel(
      watchMetricsUseCase: WatchOperationsMetricsUseCase(repository),
      watchEventsUseCase: WatchOperationsEventsUseCase(repository),
      watchDeadLettersUseCase: WatchOperationsDeadLettersUseCase(repository),
      enqueueTestSmsUseCase: EnqueueTestSmsUseCase(repository),
      requeueDeadLetterUseCase: RequeueDeadLetterUseCase(repository),
    );
  }

  final WatchOperationsMetricsUseCase _watchMetricsUseCase;
  final WatchOperationsEventsUseCase _watchEventsUseCase;
  final WatchOperationsDeadLettersUseCase _watchDeadLettersUseCase;
  final EnqueueTestSmsUseCase _enqueueTestSmsUseCase;
  final RequeueDeadLetterUseCase _requeueDeadLetterUseCase;

  static final RegExp e164Regex = RegExp(r'^\+[1-9]\d{7,14}$');
  static final RegExp timeRegex = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  String selectedTemplate = 'arriving_soon';
  String selectedEventTypeFilter = 'all';
  String selectedTimeFilter = '24h';
  bool isEnqueuing = false;
  final Set<String> requeueInProgress = <String>{};

  String todayKey() => DateTime.now().toIso8601String().substring(0, 10);

  DateTime? timeFilterSince() {
    final now = DateTime.now();
    switch (selectedTimeFilter) {
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

  Stream<OperationsMetrics> watchMetrics() {
    return _watchMetricsUseCase(todayKey());
  }

  Stream<List<OperationsDeliveryEvent>> watchEvents() {
    return _watchEventsUseCase(since: timeFilterSince());
  }

  Stream<List<OperationsDeadLetter>> watchDeadLetters() {
    return _watchDeadLettersUseCase();
  }

  List<OperationsDeliveryEvent> filterEvents(
    List<OperationsDeliveryEvent> events,
  ) {
    if (selectedEventTypeFilter == 'all') {
      return events;
    }
    return events
        .where((e) => e.type == selectedEventTypeFilter)
        .toList(growable: false);
  }

  void setTemplate(String value) {
    selectedTemplate = value;
    notifyListeners();
  }

  void setTimeFilter(String value) {
    selectedTimeFilter = value;
    notifyListeners();
  }

  void setEventTypeFilter(String value) {
    selectedEventTypeFilter = value;
    notifyListeners();
  }

  Future<String?> enqueueTestSms({
    required String phone,
    required String name,
    required String pickupTime,
  }) async {
    if (phone.trim().isEmpty) {
      return 'ops.test.validation_phone';
    }
    if (!e164Regex.hasMatch(phone.trim())) {
      return 'ops.test.validation_phone_format';
    }
    if (!timeRegex.hasMatch(pickupTime.trim())) {
      return 'ops.test.validation_pickup_time';
    }

    isEnqueuing = true;
    notifyListeners();
    try {
      await _enqueueTestSmsUseCase(
        phone: phone.trim(),
        template: selectedTemplate,
        name: name.trim(),
        pickupTime: pickupTime.trim(),
      );
      return null;
    } finally {
      isEnqueuing = false;
      notifyListeners();
    }
  }

  Future<String?> requeueDeadLetter(OperationsDeadLetter deadLetter) async {
    final originalPayload = deadLetter.originalPayload;
    final toPhone = (originalPayload['toPhone'] ?? deadLetter.toPhone)
        .toString()
        .trim();
    if (toPhone.isEmpty) {
      return 'ops.retry.missing_phone';
    }

    requeueInProgress.add(deadLetter.id);
    notifyListeners();

    try {
      await _requeueDeadLetterUseCase(deadLetter);
      return null;
    } catch (_) {
      return 'ops.retry.failed';
    } finally {
      requeueInProgress.remove(deadLetter.id);
      notifyListeners();
    }
  }
}
