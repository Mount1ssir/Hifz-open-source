class ReadingGoal {
  const ReadingGoal(
    this.id,
    this.name,
    this.pages,
    this.anchors,
    this.quota,
    this.interval,
    this.startDay,
    this.read, [
    this.recorded,
    this.durationDays = 0,
    this.repeat = false,
    this.assignedDays,
  ]);
  final int id, quota, interval, startDay, read;
  final Set<int>? recorded;
  final int durationDays;
  final bool repeat;
  final List<int>? assignedDays;
  Iterable<int> get unread => recorded == null
      ? anchors.skip(read)
      : anchors.where((id) => !recorded!.contains(id));
  bool get flexible => durationDays == 0 && quota == 0;
  final String name;
  final bool pages;
  // One next-ayah anchor per selected page or verse, in reading order.
  final List<int> anchors;
  int get remaining => anchors.length - read;
  String get unit => pages ? 'صفحة' : 'آية';
  static int day(DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(1970)).inDays;
  Iterable<int> sessionAyahs(int today) {
    if (today < startDay) return const [];
    if (durationDays == 0) return unread;
    final elapsed = (today - startDay + 1).clamp(1, durationDays);
    final end = _endOfDay(elapsed);
    return anchors
        .take(end)
        .skip(recorded == null ? read : 0)
        .where((id) => !(recorded?.contains(id) ?? false));
  }

  int _endOfDay(int elapsed) {
    if (elapsed == 0) return 0;
    final assigned = assignedDays;
    if (assigned != null) {
      var low = 0, high = assigned.length;
      while (low < high) {
        final mid = (low + high) ~/ 2;
        if (assigned[mid] <= elapsed) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      return low;
    }
    final base = anchors.length ~/ durationDays;
    final extra = anchors.length % durationDays;
    return base == 0
        ? 1 + (elapsed - 1) * (anchors.length - 1) ~/ (durationDays - 1)
        : elapsed * base + elapsed.clamp(0, extra);
  }

  List<int> plannedAyahs(int day) =>
      anchors.sublist(_endOfDay(day - 1), _endOfDay(day));

  int due(int today) {
    if (durationDays > 0) return sessionAyahs(today).length;
    if (flexible || today < startDay) return 0;
    final scheduled = (1 + (today - startDay) ~/ interval) * quota;
    return (scheduled - read).clamp(0, remaining);
  }

  int get sessions => durationDays > 0
      ? durationDays
      : flexible
      ? 0
      : (anchors.length + quota - 1) ~/ quota;
}
