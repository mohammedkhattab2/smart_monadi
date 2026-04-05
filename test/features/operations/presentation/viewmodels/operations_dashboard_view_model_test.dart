import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/operations/domain/entities/operations_models.dart';
import 'package:smart_monadi/features/operations/domain/repositories/operations_repository.dart';
import 'package:smart_monadi/features/operations/domain/usecases/enqueue_test_sms_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/requeue_dead_letter_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_dead_letters_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_events_use_case.dart';
import 'package:smart_monadi/features/operations/domain/usecases/watch_operations_metrics_use_case.dart';
import 'package:smart_monadi/features/operations/presentation/viewmodels/operations_dashboard_view_model.dart';

void main() {
  group('OperationsDashboardViewModel', () {
    late _FakeOperationsRepository repository;
    late OperationsDashboardViewModel viewModel;

    setUp(() {
      repository = _FakeOperationsRepository();
      viewModel = OperationsDashboardViewModel(
        watchMetricsUseCase: WatchOperationsMetricsUseCase(repository),
        watchEventsUseCase: WatchOperationsEventsUseCase(repository),
        watchDeadLettersUseCase: WatchOperationsDeadLettersUseCase(repository),
        enqueueTestSmsUseCase: EnqueueTestSmsUseCase(repository),
        requeueDeadLetterUseCase: RequeueDeadLetterUseCase(repository),
      );
    });

    test('enqueueTestSms validates phone format', () async {
      final error = await viewModel.enqueueTestSms(
        phone: '012345',
        name: 'Ali',
        pickupTime: '07:30',
      );

      expect(error, 'ops.test.validation_phone_format');
      expect(repository.enqueueCalled, isFalse);
    });

    test('enqueueTestSms validates empty phone', () async {
      final error = await viewModel.enqueueTestSms(
        phone: '   ',
        name: 'Ali',
        pickupTime: '07:30',
      );

      expect(error, 'ops.test.validation_phone');
      expect(repository.enqueueCalled, isFalse);
    });

    test('enqueueTestSms validates pickup time format', () async {
      final error = await viewModel.enqueueTestSms(
        phone: '+201234567890',
        name: 'Ali',
        pickupTime: '7:30',
      );

      expect(error, 'ops.test.validation_pickup_time');
      expect(repository.enqueueCalled, isFalse);
    });

    test('enqueueTestSms calls use case when input is valid', () async {
      final error = await viewModel.enqueueTestSms(
        phone: '+201234567890',
        name: 'Ali',
        pickupTime: '07:30',
      );

      expect(error, isNull);
      expect(viewModel.isEnqueuing, isFalse);
      expect(repository.enqueueCalled, isTrue);
      expect(repository.lastPhone, '+201234567890');
      expect(repository.lastTemplate, 'arriving_soon');
      expect(repository.lastName, 'Ali');
      expect(repository.lastPickupTime, '07:30');
    });

    test('filterEvents keeps only selected type', () {
      const events = [
        OperationsDeliveryEvent(
          id: '1',
          type: 'sent',
          messageId: 'm1',
          createdAt: null,
          payload: {},
        ),
        OperationsDeliveryEvent(
          id: '2',
          type: 'failed',
          messageId: 'm2',
          createdAt: null,
          payload: {},
        ),
      ];

      viewModel.setEventTypeFilter('failed');
      final filtered = viewModel.filterEvents(events);

      expect(filtered.map((e) => e.id), ['2']);
    });

    test('requeueDeadLetter validates missing phone', () async {
      const deadLetter = OperationsDeadLetter(
        id: 'd1',
        toPhone: '',
        attempts: 2,
        reason: 'missing',
        movedAt: null,
        errorUserMessage: '',
        errorMessage: '',
        originalPayload: {},
      );

      final error = await viewModel.requeueDeadLetter(deadLetter);

      expect(error, 'ops.retry.missing_phone');
      expect(repository.requeueCalled, isFalse);
      expect(viewModel.requeueInProgress, isEmpty);
    });

    test('requeueDeadLetter returns failure on repository exception', () async {
      repository.throwOnRequeue = true;
      const deadLetter = OperationsDeadLetter(
        id: 'd2',
        toPhone: '+201234567890',
        attempts: 2,
        reason: 'failed',
        movedAt: null,
        errorUserMessage: '',
        errorMessage: '',
        originalPayload: {},
      );

      final error = await viewModel.requeueDeadLetter(deadLetter);

      expect(error, 'ops.retry.failed');
      expect(repository.requeueCalled, isTrue);
      expect(viewModel.requeueInProgress, isEmpty);
    });

    test('timeFilterSince returns null for all filter', () {
      viewModel.setTimeFilter('all');

      final since = viewModel.timeFilterSince();

      expect(since, isNull);
    });

    test('setTemplate updates selectedTemplate', () {
      viewModel.setTemplate('arrival_now');

      expect(viewModel.selectedTemplate, 'arrival_now');
    });
  });
}

class _FakeOperationsRepository implements OperationsRepository {
  bool enqueueCalled = false;
  bool requeueCalled = false;
  bool throwOnRequeue = false;
  String? lastPhone;
  String? lastTemplate;
  String? lastName;
  String? lastPickupTime;

  @override
  Future<void> addDeliveryEvent({
    required String messageId,
    required String type,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<void> enqueueTestSms({
    required String phone,
    required String template,
    required String name,
    required String pickupTime,
  }) async {
    enqueueCalled = true;
    lastPhone = phone;
    lastTemplate = template;
    lastName = name;
    lastPickupTime = pickupTime;
  }

  @override
  Future<void> requeueDeadLetter(OperationsDeadLetter deadLetter) async {
    requeueCalled = true;
    if (throwOnRequeue) {
      throw StateError('requeue failure');
    }
  }

  @override
  Stream<List<OperationsDeadLetter>> watchDeadLetters({int limit = 10}) {
    return Stream.value(const <OperationsDeadLetter>[]);
  }

  @override
  Stream<List<OperationsDeliveryEvent>> watchDeliveryEvents({
    DateTime? since,
    int limit = 50,
  }) {
    return Stream.value(const <OperationsDeliveryEvent>[]);
  }

  @override
  Stream<OperationsMetrics> watchMetricsForDay(String dayKey) {
    return Stream.value(
      const OperationsMetrics(sent: 0, failed: 0, failedPermanent: 0),
    );
  }
}
