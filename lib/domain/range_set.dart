/// Inclusive, positive dataset-local ayah IDs.
class AyahRange {
  AyahRange(this.first, this.last) {
    RangeError.checkValueInInterval(first, 1, 0x7fffffff, 'first');
    if (last < first) {
      throw ArgumentError('The last ayah must be at or after the first.');
    }
  }

  final int first;
  final int last;
  int get length => last - first + 1;
}

/// Immutable, sorted ranges with overlapping and adjacent ranges merged.
class RangeSet {
  factory RangeSet(Iterable<AyahRange> ranges) {
    final sorted = ranges.toList()..sort((a, b) => a.first.compareTo(b.first));
    final merged = <AyahRange>[];
    for (final range in sorted) {
      if (merged.isEmpty || range.first > merged.last.last + 1) {
        merged.add(range);
      } else if (range.last > merged.last.last) {
        merged[merged.length - 1] = AyahRange(merged.last.first, range.last);
      }
    }
    return RangeSet._(List.unmodifiable(merged));
  }

  const RangeSet._(this.ranges);
  final List<AyahRange> ranges;
  int get length => ranges.fold(0, (sum, range) => sum + range.length);

  Iterable<int> get ids sync* {
    for (final range in ranges) {
      for (var id = range.first; id <= range.last; id++) {
        yield id;
      }
    }
  }

  RangeSet merge(RangeSet other) => RangeSet([...ranges, ...other.ranges]);

  RangeSet subtract(RangeSet other) {
    final result = <AyahRange>[];
    for (final range in ranges) {
      var cursor = range.first;
      for (final removed in other.ranges) {
        if (removed.last < cursor) continue;
        if (removed.first > range.last) break;
        if (removed.first > cursor) {
          result.add(AyahRange(cursor, removed.first - 1));
        }
        cursor = removed.last + 1;
        if (cursor > range.last) break;
      }
      if (cursor <= range.last) result.add(AyahRange(cursor, range.last));
    }
    return RangeSet(result);
  }

  RangeSet complement(int totalAyahs) {
    RangeError.checkValueInInterval(totalAyahs, 1, 0x7fffffff, 'totalAyahs');
    if (ranges.isNotEmpty && ranges.last.last > totalAyahs) {
      throw RangeError('A memorized range extends beyond this dataset.');
    }
    return RangeSet([AyahRange(1, totalAyahs)]).subtract(this);
  }
}
