enum RecallRating { again, hard, good, easy }

class ReviewSettings {
  ReviewSettings({
    Iterable<Duration> intervals = const [
      Duration(minutes: 10),
      Duration(hours: 1),
      Duration(hours: 4),
    ],
    this.adaptive = true,
  }) : intervals = List.unmodifiable(intervals) {
    if (this.intervals.isEmpty ||
        this.intervals.length > 8 ||
        this.intervals.any(
          (gap) => gap.inMinutes < 1 || gap.inMinutes > 1440,
        )) {
      throw ArgumentError('Choose 1–8 intervals of 1–1440 minutes.');
    }
  }
  final List<Duration> intervals;
  final bool adaptive;
}

class RecallAttempt {
  const RecallAttempt(this.completedAt, this.rating);
  final DateTime completedAt;
  final RecallRating rating;
}

class ScheduledReview {
  const ScheduledReview(this.ordinal, this.dueAt);
  final int ordinal;
  final DateTime dueAt;
  bool isDue(DateTime now) => !dueAt.isAfter(now.toUtc());
}

/// An intraday learning schedule inspired by Leitner's rating-based progression.
/// The default minute intervals are product defaults requiring learner validation.
class ReviewScheduler {
  List<ScheduledReview> pending({
    required DateTime startedAt,
    required List<RecallAttempt> attempts,
    required ReviewSettings settings,
    required DateTime now,
  }) {
    var anchor = startedAt.toUtc();
    for (final attempt in attempts) {
      if (attempt.completedAt.toUtc().isBefore(anchor)) {
        throw ArgumentError('Recall history must be chronological.');
      }
      anchor = attempt.completedAt.toUtc();
    }
    final pending = <ScheduledReview>[];
    for (
      var index = attempts.length;
      index < settings.intervals.length;
      index++
    ) {
      var minutes = settings.intervals[index].inMinutes;
      if (settings.adaptive &&
          index == attempts.length &&
          attempts.isNotEmpty) {
        minutes = switch (attempts.last.rating) {
          RecallRating.again => (minutes / 4).ceil(),
          RecallRating.hard => (minutes / 2).ceil(),
          RecallRating.good => minutes,
          RecallRating.easy => (minutes * 1.5).ceil(),
        };
      }
      final due = anchor.add(Duration(minutes: minutes));
      pending.add(ScheduledReview(index, due));
      // Only the next review can be overdue. Later times are estimates anchored
      // to the earliest time the outstanding review could actually be completed.
      anchor = due.isBefore(now.toUtc()) ? now.toUtc() : due;
    }
    return List.unmodifiable(pending);
  }
}
