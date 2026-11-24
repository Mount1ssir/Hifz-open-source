import 'hifz_planner.dart';
import 'range_set.dart';

class RevisionPartitioner {
  /// The first day each whole ayah is due, balancing cumulative printed weight.
  List<int> assignedDays(List<int> weights, int days) {
    RangeError.checkValueInInterval(days, 1, 0x7fffffff, 'days');
    if (weights.any((weight) => weight <= 0)) {
      throw ArgumentError('Revision weights must be positive.');
    }
    final total = weights.fold(0, (sum, weight) => sum + weight);
    var previous = 0;
    final result = <int>[];
    for (final weight in weights) {
      result.add(previous * days ~/ total + 1);
      previous += weight;
    }
    return result;
  }

  List<PlannedPortion> partition(
    RangeSet memorized, {
    required int days,
    required Map<int, int> weights,
  }) {
    final ids = memorized.ids.toList();
    final assigned = assignedDays([
      for (final id in ids) weights[id] ?? 0,
    ], days);
    var cursor = 0;
    final portions = <PlannedPortion>[];
    for (var day = 1; day <= days; day++) {
      final ranges = <AyahRange>[];
      var portionWeight = 0;
      while (cursor < ids.length && assigned[cursor] == day) {
        final id = ids[cursor++];
        ranges.add(AyahRange(id, id));
        portionWeight += weights[id]!;
      }
      portions.add(PlannedPortion(RangeSet(ranges), portionWeight));
    }
    return List.unmodifiable(portions);
  }
}
