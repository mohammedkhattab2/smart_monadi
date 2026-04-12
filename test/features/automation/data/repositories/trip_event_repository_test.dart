import 'package:flutter_test/flutter_test.dart';
import 'package:smart_monadi/features/automation/data/repositories/trip_event_repository.dart';

void main() {
  group('FirestoreTripEventRepository.normalizeIdempotencyKeyForDocId', () {
    test('returns fallback for empty key', () {
      final value =
          FirestoreTripEventRepository.normalizeIdempotencyKeyForDocId('   ');

      expect(value, 'sms_key_unknown');
    });

    test('normalizes key and appends stable hash suffix', () {
      final value =
          FirestoreTripEventRepository.normalizeIdempotencyKeyForDocId(
            'Approaching:Passenger#1',
          );

      expect(value, startsWith('approaching_passenger_1_'));
      expect(value.length, lessThanOrEqualTo(128));
      expect(value.split('_').last.length, 8);
    });

    test('keeps deterministic output for same input', () {
      final first =
          FirestoreTripEventRepository.normalizeIdempotencyKeyForDocId(
            'arrival_p1_2026-04-12_07:30',
          );
      final second =
          FirestoreTripEventRepository.normalizeIdempotencyKeyForDocId(
            'arrival_p1_2026-04-12_07:30',
          );

      expect(first, second);
    });

    test('prevents collision for similarly normalized long keys', () {
      final keyA = 'ARRIVAL__p1__2026-04-12__07:30__${'X' * 200}__A';
      final keyB = 'ARRIVAL__p1__2026-04-12__07:30__${'X' * 200}__B';

      final a = FirestoreTripEventRepository.normalizeIdempotencyKeyForDocId(
        keyA,
      );
      final b = FirestoreTripEventRepository.normalizeIdempotencyKeyForDocId(
        keyB,
      );

      expect(a, isNot(b));
      expect(a.length, lessThanOrEqualTo(128));
      expect(b.length, lessThanOrEqualTo(128));
    });
  });
}
