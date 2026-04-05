import 'package:smart_monadi/features/passenger/domain/entities/passenger_timeline_event.dart';
import 'package:smart_monadi/features/passenger/domain/repositories/passenger_repository.dart';

class WatchPassengerTimelineUseCase {
  const WatchPassengerTimelineUseCase(this._repository);

  final PassengerRepository _repository;

  Stream<List<PassengerTimelineEvent>> call({
    required String passengerId,
    DateTime? since,
    int limit = 12,
  }) {
    return _repository.watchPassengerTimeline(
      passengerId: passengerId,
      since: since,
      limit: limit,
    );
  }
}
