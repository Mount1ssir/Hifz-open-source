import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/core/data/quran_repository.dart';
import 'package:hifz/core/data/user_database.dart';
import 'package:hifz/domain/riwayah.dart';
import 'package:hifz/domain/hifz_planner.dart';
import 'package:hifz/domain/range_set.dart';
import 'package:hifz/domain/review_scheduler.dart';

void main() {
  test('Baqarah baseline supersedes completed portion and allows the next portion today', () async {
    final dir = await Directory.systemTemp.createTemp('hifz-rebase');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/user.db');
    var db = UserDatabase(NativeDatabase(file));
    final now = DateTime.now();
    for (var id = 1; id <= 13; id++) {
      await db.markMemorized(
        Riwayah.hafs,
        id,
        now.subtract(const Duration(days: 1)),
      );
    }
    await db.completePortion(Riwayah.hafs, [14, 15, 16, 17, 18, 19, 20], now);
    expect(await db.completedToday(Riwayah.hafs, now), [
      14,
      15,
      16,
      17,
      18,
      19,
      20,
    ]);
    await db.saveMemorizedBaseline(Riwayah.hafs, {
      for (var id = 8; id <= 207; id++) id,
    });
    await db.close();
    db = UserDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.completedToday(Riwayah.hafs, now), isEmpty);
    final known = {
      ...await db.memorizedBaseline(Riwayah.hafs),
      ...(await db.progress(Riwayah.hafs)).map((a) => a.ayahId),
    };
    final plan = HifzPlanner().plan(
      riwayah: Riwayah.hafs,
      memorized: RangeSet(known.map((id) => AyahRange(id, id))),
      quota: DailyQuota.ayahs(5),
    );
    expect(plan.first.ayahs.ids.first, 208); // Al-Baqarah 201.
    await db.completePortion(Riwayah.hafs, plan.first.ayahs.ids, now);
    expect(await db.completedToday(Riwayah.hafs, now), [
      208,
      209,
      210,
      211,
      212,
    ]);
    expect((await db.sessions()).length, 2);
    await db.saveMemorizedBaseline(Riwayah.hafs, {
      for (var id = 8; id <= 207; id++) id,
    });
    expect(await db.completedToday(Riwayah.hafs, now), [
      208,
      209,
      210,
      211,
      212,
    ]);
  });

  test('correcting Al-Baqarah to 264 makes 265 available again', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const hafs = Riwayah.hafs;
    final through264 = {for (var i = 1; i <= 271; i++) i};
    final now = DateTime.now();
    await db.saveMemorizedBaseline(hafs, through264);
    await db.completePortion(hafs, [272, 273], now);
    await db.saveMemorizedBaseline(
      hafs,
      through264,
      removedProgress: {272, 273},
    );
    expect(await db.completedToday(hafs, now), isEmpty);
    final known = {
      ...await db.memorizedBaseline(hafs),
      ...(await db.progress(hafs)).map((row) => row.ayahId),
    };
    final portions = HifzPlanner().plan(
      riwayah: hafs,
      memorized: RangeSet(known.map((id) => AyahRange(id, id))),
      quota: DailyQuota.ayahs(2),
    );
    expect(portions.first.ayahs.ids, [272, 273]);
    expect(portions[1].ayahs.ids.first, 274);
    await db.completePortion(hafs, [272, 273], now);
    expect(await db.completedToday(hafs, now), [272, 273]);
    expect(await db.sessions(), hasLength(1));
  });

  test('review sessions and recall retries survive reopening', () async {
    final directory = await Directory.systemTemp.createTemp('hifz-reviews');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/user.db');
    var db = UserDatabase(NativeDatabase(file));
    final start = DateTime.utc(2026, 11, 18, 10);
    await db.completePortion(Riwayah.hafs, [1, 2], start);
    await db.completePortion(Riwayah.hafs, [1, 2], start);
    final session = (await db.sessions()).single;
    await expectLater(
      db.recordRecall(session.id, 0, RecallRating.good, start),
      throwsStateError,
    );
    final at = start.add(const Duration(minutes: 10));
    await db.recordRecall(session.id, 0, RecallRating.hard, at);
    await db.recordRecall(session.id, 0, RecallRating.hard, at);
    await db.saveReviewSettings(
      ReviewSettings(
        intervals: [const Duration(minutes: 3), const Duration(minutes: 15)],
        adaptive: false,
      ),
    );
    await db.saveReadingPage(44);
    await db.setBookmark(44, true);
    await db.setBookmark(604, true);
    await db.setBookmark(44, false);
    await db.close();
    db = UserDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.readingPage(), 44);
    expect(await db.bookmarks(), {604});
    expect((await db.sessions()).length, 1);
    expect((await db.attempts(session.id)).length, 1);
    expect((await db.progress(Riwayah.hafs)).length, 2);
    expect((await db.reviewSettings()).intervals.last.inMinutes, 15);
    expect((await db.reviewSettings()).adaptive, isFalse);
    final restored = (await db.sessions()).single;
    final pending = ReviewScheduler().pending(
      startedAt: restored.startedAt,
      attempts: [
        for (final a in await db.attempts(restored.id))
          RecallAttempt(a.completedAt, RecallRating.values[a.rating]),
      ],
      settings: await db.reviewSettings(),
      now: at,
    );
    expect(pending.single.ordinal, 1);
    expect(pending.single.dueAt, at.add(const Duration(minutes: 15)));
  });

  test(
    'previous memorization survives restart without completing today',
    () async {
      final directory = await Directory.systemTemp.createTemp('hifz-baseline');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/user.db');
      var db = UserDatabase(NativeDatabase(file));
      await db.markMemorized(Riwayah.hafs, 8, DateTime.utc(2026, 11, 19));
      await db.saveMemorizedBaseline(Riwayah.hafs, {1, 2, 3, 10, 11});
      await db.setDailyQuota(1, unit: QuotaUnit.halfPages);
      await db.close();
      db = UserDatabase(NativeDatabase(file));
      addTearDown(db.close);
      expect(await db.memorizedBaseline(Riwayah.hafs), {1, 2, 3, 10, 11});
      expect(await db.sessions(), isEmpty);
      expect((await db.progress(Riwayah.hafs)).single.ayahId, 8);
      expect(await db.dailyQuotaUnit(), QuotaUnit.halfPages);
      await db.saveMemorizedBaseline(Riwayah.hafs, {1, 2});
      expect(await db.memorizedBaseline(Riwayah.hafs), {1, 2});
      expect((await db.progress(Riwayah.hafs)).single.ayahId, 8);
    },
  );

  test('a completed portion advances across local midnight and an unfinished one carries over', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<List<int>> portion(DateTime at) async {
      final done = await db.completedToday(Riwayah.hafs, at);
      if (done.isNotEmpty) return done;
      final known = await db.progress(Riwayah.hafs);
      return HifzPlanner()
          .plan(
            riwayah: Riwayah.hafs,
            memorized: RangeSet(
              known.map((a) => AyahRange(a.ayahId, a.ayahId)),
            ),
            quota: DailyQuota.ayahs(2),
          )
          .first
          .ayahs
          .ids
          .toList();
    }

    final evening = DateTime(2026, 11, 20, 23, 59, 59);
    await db.completePortion(Riwayah.hafs, [1, 2], evening);
    expect(await portion(evening), [1, 2]);
    expect(await portion(DateTime(2026, 11, 21)), [3, 4]);
    expect(await portion(DateTime(2026, 11, 22)), [3, 4]);
  });

  test('first Hifz setup stays complete after restarting', () async {
    final directory = await Directory.systemTemp.createTemp('hifz-setup');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/user.db');
    final db = UserDatabase(NativeDatabase(file));
    expect(await db.needsHifzSetup(), isTrue);
    await db.finishHifzSetup();
    await db.close();
    final reopened = UserDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    expect(await reopened.needsHifzSetup(), isFalse);
  });

  test('version 1 progress survives the settings migration', () async {
    final directory = await Directory.systemTemp.createTemp('hifz-migration');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/user.db');
    final old = sqlite3.open(file.path);
    old.execute(
      'CREATE TABLE memorized_ayahs (riwayah TEXT NOT NULL, '
      'numbering TEXT NOT NULL, ayah_id INTEGER NOT NULL, '
      'completed_at INTEGER NOT NULL, PRIMARY KEY (riwayah, numbering, ayah_id))',
    );
    old.execute(
      "INSERT INTO memorized_ayahs VALUES ('hafs', 'hafs-kufi', 8, 0)",
    );
    old.execute('PRAGMA user_version = 1');
    old.close();
    final db = UserDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.needsHifzSetup(), isFalse);
    expect((await db.progress(Riwayah.hafs)).single.ayahId, 8);
    expect(await db.dailyQuota(), 5);
    expect(await db.dailyQuotaUnit(), QuotaUnit.ayahs);
    await db.setDailyQuota(12, unit: QuotaUnit.lines);
    expect(await db.dailyQuota(), 12);
    expect(await db.dailyQuotaUnit(), QuotaUnit.lines);
  });

  test('page quotas cover 604 pages in whole ayahs', () {
    final quran = QuranRepository.open(
      File('assets/data/quran.db'),
      riwayah: Riwayah.hafs,
    );
    addTearDown(quran.close);
    for (final halves in [1, 2]) {
      final plan = HifzPlanner().plan(
        riwayah: Riwayah.hafs,
        memorized: RangeSet([]),
        quota: DailyQuota.printedHalfPages(halves, quran.printedPageWeights),
      );
      expect(plan.length, 1208 ~/ halves);
      expect(
        plan.expand((p) => p.ayahs.ids),
        List.generate(6236, (i) => i + 1),
      );
      expect(plan.singleWhere((p) => p.ayahs.ids.contains(289)).ayahs.ids, [
        289,
      ]);
    }
  });

  test('bundled Quran exposes ordered ranges and validates bounds', () {
    final quran = QuranRepository.open(
      File('assets/data/quran.db'),
      riwayah: Riwayah.hafs,
    );
    addTearDown(quran.close);
    expect(quran.surahs().length, 114);
    expect(quran.surahs().last.page, 604);
    expect(quran.pageForJuz(30), 582);
    expect(quran.pageLines(44).length, 15);
    expect(quran.pagesForAyahs([1, 7, 8]), [1, 2]);
    expect(quran.linesPerPage, 15);
    expect(quran.lineWeights().length, Riwayah.hafs.totalAyahs);
    expect(quran.lineWeights().values.every((weight) => weight > 0), isTrue);
    expect(quran.readRange(1, Riwayah.hafs.totalAyahs).length, 6236);
    expect(quran.readRange(8, 8).single.basmalahPrefix, isNotEmpty);
    expect(() => quran.readRange(0, 1), throwsRangeError);
    expect(() => quran.readRange(3, 2), throwsArgumentError);
  });

  test(
    'progress survives reopen and repeated completion is idempotent',
    () async {
      final directory = await Directory.systemTemp.createTemp('hifz-progress');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/user.db');
      var db = UserDatabase(NativeDatabase(file));
      final at = DateTime.utc(2026, 11, 17);
      await db.markMemorized(Riwayah.hafs, 8, at);
      await db.markMemorized(Riwayah.hafs, 8, at);
      await db.close();
      db = UserDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final rows = await db.progress(Riwayah.hafs);
      expect(rows.single.ayahId, 8);
      expect(rows.single.completedAt.toUtc(), at);
      expect(() => db.markMemorized(Riwayah.hafs, 0, at), throwsRangeError);
    },
  );
}
