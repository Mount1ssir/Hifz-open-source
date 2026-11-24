import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/domain/review_scheduler.dart';

void main() {
  final start = DateTime.utc(2026, 11, 18, 10);
  final scheduler = ReviewScheduler();

  test(
    'defaults produce three spaced reviews and weak recall shortens the gap',
    () {
      final settings = ReviewSettings();
      final initial = scheduler.pending(
        startedAt: start,
        attempts: [],
        settings: settings,
        now: start,
      );
      expect(initial.map((r) => r.dueAt.difference(start).inMinutes), [
        10,
        70,
        310,
      ]);
      for (final (rating, gap) in [
        (RecallRating.again, 15),
        (RecallRating.hard, 30),
        (RecallRating.good, 60),
        (RecallRating.easy, 90),
      ]) {
        final at = start.add(const Duration(minutes: 10));
        final next = scheduler.pending(
          startedAt: start,
          attempts: [RecallAttempt(at, rating)],
          settings: settings,
          now: at,
        );
        expect(next.first.ordinal, 1);
        expect(next.first.dueAt.difference(at).inMinutes, gap);
      }
    },
  );

  test('custom gaps override ratings and settings changes retain history', () {
    final at = start.add(const Duration(minutes: 2));
    final history = [RecallAttempt(at, RecallRating.again)];
    final settings = ReviewSettings(
      intervals: [const Duration(minutes: 2), const Duration(minutes: 7)],
      adaptive: false,
    );
    final next = scheduler.pending(
      startedAt: start,
      attempts: history,
      settings: settings,
      now: at,
    );
    expect(next.single.dueAt.difference(at).inMinutes, 7);
    expect(
      scheduler.pending(
        startedAt: start,
        attempts: history,
        settings: ReviewSettings(intervals: [const Duration(minutes: 1)]),
        now: at,
      ),
      isEmpty,
    );
  });

  test(
    'late reviews persist across midnight and future previews avoid a burst',
    () {
      final nextDay = start.add(const Duration(days: 1));
      final pending = scheduler.pending(
        startedAt: start,
        attempts: [],
        settings: ReviewSettings(),
        now: nextDay,
      );
      expect(pending.first.isDue(nextDay), isTrue);
      expect(pending[1].isDue(nextDay), isFalse);
      expect(pending[1].dueAt, nextDay.add(const Duration(hours: 1)));
      final offset = DateTime.parse('2026-11-19T12:00:00+02:00');
      expect(
        scheduler
            .pending(
              startedAt: start,
              attempts: [],
              settings: ReviewSettings(),
              now: offset,
            )
            .first
            .dueAt,
        pending.first.dueAt,
      );
    },
  );

  test('invalid intervals and reversed history are rejected', () {
    expect(() => ReviewSettings(intervals: []), throwsArgumentError);
    expect(
      () => ReviewSettings(intervals: [Duration.zero]),
      throwsArgumentError,
    );
    expect(
      () => ReviewSettings(intervals: [const Duration(days: 2)]),
      throwsArgumentError,
    );
    expect(
      () => scheduler.pending(
        startedAt: start,
        attempts: [
          RecallAttempt(
            start.subtract(const Duration(seconds: 1)),
            RecallRating.good,
          ),
        ],
        settings: ReviewSettings(),
        now: start,
      ),
      throwsArgumentError,
    );
  });
}
