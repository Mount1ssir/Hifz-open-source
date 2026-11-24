import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/domain/hifz_planner.dart';
import 'package:hifz/domain/range_set.dart';
import 'package:hifz/domain/revision_partitioner.dart';
import 'package:hifz/domain/riwayah.dart';

void main() {
  test(
    'ranges normalize overlaps and adjacency, then subtract and complement',
    () {
      final ranges = RangeSet([
        AyahRange(5, 8),
        AyahRange(1, 3),
        AyahRange(3, 4),
      ]);
      expect(ranges.length, 8);
      expect(ranges.ranges.length, 1);
      expect(ranges.subtract(RangeSet([AyahRange(3, 6)])).ids, [1, 2, 7, 8]);
      expect(ranges.complement(10).ids, [9, 10]);
      expect(ranges.merge(RangeSet([AyahRange(10, 10)])).ids, [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        10,
      ]);
      expect(() => AyahRange(0, 1), throwsRangeError);
      expect(() => AyahRange(3, 2), throwsArgumentError);
      expect(() => ranges.complement(4), throwsRangeError);
      expect(RangeSet([]).complement(3).ids, [1, 2, 3]);
      expect(ranges.subtract(RangeSet([AyahRange(1, 10)])).length, 0);
      expect(ranges.subtract(RangeSet([AyahRange(20, 30)])).length, 8);
    },
  );

  test('range subtraction matches set arithmetic across small inputs', () {
    for (var mask = 0; mask < 64; mask++) {
      final source = {
        for (var i = 1; i <= 6; i++)
          if (mask & (1 << (i - 1)) != 0) i,
      };
      for (var other = 0; other < 64; other++) {
        final removed = {
          for (var i = 1; i <= 6; i++)
            if (other & (1 << (i - 1)) != 0) i,
        };
        final a = RangeSet(source.map((id) => AyahRange(id, id)));
        final b = RangeSet(removed.map((id) => AyahRange(id, id)));
        expect(a.subtract(b).ids.toSet(), source.difference(removed));
      }
    }
  });

  final planner = HifzPlanner();
  final last = Riwayah.hafs.totalAyahs;

  test('planner fills holes and handles oversized and final quotas', () {
    final plan = planner.plan(
      riwayah: Riwayah.hafs,
      memorized: RangeSet([AyahRange(2, 2), AyahRange(7, last)]),
      quota: DailyQuota.ayahs(3),
    );
    expect(plan.map((s) => s.ayahs.ids.toList()).toList(), [
      [1, 3, 4],
      [5, 6],
    ]);
    expect(plan.map((s) => s.weight), [3, 2]);
    expect(
      planner
          .plan(
            riwayah: Riwayah.hafs,
            memorized: RangeSet([]),
            quota: DailyQuota.ayahs(last + 5),
          )
          .single
          .ayahs
          .length,
      last,
    );
    expect(
      planner.plan(
        riwayah: Riwayah.hafs,
        memorized: RangeSet([AyahRange(1, last)]),
        quota: DailyQuota.ayahs(1),
      ),
      isEmpty,
    );
  });

  test('backward and custom strategies determine selection order', () {
    final remaining = RangeSet([AyahRange(1, 5)]);
    expect(const BackwardOrder().arrange(remaining), [5, 4, 3, 2, 1]);
    final custom = CustomOrder([
      AyahRange(4, 5),
      AyahRange(2, 4),
      AyahRange(1, 1),
    ]);
    expect(custom.arrange(remaining), [4, 5, 2, 3, 1]);
    expect(
      () => CustomOrder([AyahRange(1, 2)]).arrange(remaining),
      throwsArgumentError,
    );
    final plan = planner.plan(
      riwayah: Riwayah.hafs,
      memorized: RangeSet([AyahRange(6, last)]),
      quota: DailyQuota.ayahs(2),
      order: const BackwardOrder(),
    );
    expect(plan.first.ayahs.ids, [4, 5]);
    expect(plan.last.ayahs.ids, [1]);
  });

  test('weighted quotas preserve whole ayahs, including oversized ayahs', () {
    final plan = planner.plan(
      riwayah: Riwayah.hafs,
      memorized: RangeSet([AyahRange(5, last)]),
      quota: DailyQuota.lines(3, {1: 7, 2: 1, 3: 1, 4: 2}),
    );
    expect(plan.map((s) => s.weight), [7, 4]);
    expect(plan.first.ayahs.ids, [1]);
    expect(DailyQuota.pages(2, {1: 4}, linesPerPage: 15).target, 30);
    expect(() => DailyQuota.ayahs(0), throwsRangeError);
    expect(() => DailyQuota.pages(1, {}, linesPerPage: 0), throwsRangeError);
    expect(() => DailyQuota.lines(1, {}).weight(1), throwsStateError);
    expect(() => DailyQuota.lines(1, {1: 0}).weight(1), throwsStateError);
    expect(
      () => planner.plan(
        riwayah: Riwayah.hafs,
        memorized: RangeSet([AyahRange(last + 1, last + 1)]),
        quota: DailyQuota.ayahs(1),
      ),
      throwsRangeError,
    );
  });

  test('revision partitions preserve coverage with bounded weight error', () {
    final partitioner = RevisionPartitioner();
    final ayahs = RangeSet([AyahRange(1, 2), AyahRange(5, 7)]);
    const weights = {1: 2, 2: 10, 5: 1, 6: 3, 7: 2};
    for (var days = 1; days <= 10; days++) {
      final chunks = partitioner.partition(ayahs, days: days, weights: weights);
      expect(chunks.length, days);
      final ids = chunks.expand((s) => s.ayahs.ids).toList();
      expect(ids, ayahs.ids.toList());
      expect(ids.toSet().length, ayahs.length);
      for (final chunk in chunks) {
        expect((chunk.weight - 18 / days).abs(), lessThanOrEqualTo(10));
      }
    }
    expect(
      partitioner
          .partition(RangeSet([]), days: 3, weights: {})
          .every((s) => s.ayahs.length == 0),
      isTrue,
    );
    expect(
      () => partitioner.partition(ayahs, days: 0, weights: weights),
      throwsRangeError,
    );
    expect(
      () => partitioner.partition(ayahs, days: 2, weights: {}),
      throwsArgumentError,
    );
    expect(
      () => partitioner.partition(
        RangeSet([AyahRange(1, 1)]),
        days: 1,
        weights: {1: -1},
      ),
      throwsArgumentError,
    );
  });
}
