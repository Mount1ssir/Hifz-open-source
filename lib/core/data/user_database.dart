import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:drift/drift.dart';

import '../../domain/review_scheduler.dart';

import '../../domain/riwayah.dart';
import '../../domain/reading_goal.dart';
import '../../domain/hifz_planner.dart';

part 'user_database.g.dart';

class MemorizedAyahs extends Table {
  TextColumn get riwayah => text()();
  TextColumn get numbering => text()();
  IntColumn get ayahId => integer()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {riwayah, numbering, ayahId};
}

class Preferences extends Table {
  TextColumn get key => text()();
  IntColumn get value => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class ReviewSessions extends Table {
  TextColumn get id => text()();
  TextColumn get ayahIds => text()();
  DateTimeColumn get startedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ReviewAttempts extends Table {
  TextColumn get sessionId => text().references(ReviewSessions, #id)();
  IntColumn get ordinal => integer()();
  IntColumn get rating => integer()();
  DateTimeColumn get completedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {sessionId, ordinal};
}

@DriftDatabase(
  tables: [MemorizedAyahs, Preferences, ReviewSessions, ReviewAttempts],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(preferences).insert(
        PreferencesCompanion.insert(key: 'hifz_setup_pending', value: 1),
      );
      await _createGoals();
      await _addGoalRanges();
      await _createRecitedPageAyahs();
      await _addGoalSchedule();
      await _addRevisionDays();
    },
    onUpgrade: (m, from, to) async {
      if (from < 4) await _createGoals();
      if (from < 8) await _addRevisionDays();
      if (from < 7) await _addGoalSchedule();
      if (from < 6) await _createRecitedPageAyahs();
      if (from < 5) await _addGoalRanges();
      if (from < 2) await m.createTable(preferences);
      if (from < 3) {
        await m.createTable(reviewSessions);
        await m.createTable(reviewAttempts);
      }
    },
  );

  Future<void> _addRevisionDays() => customStatement(
    'ALTER TABLE reading_goals ADD COLUMN assigned_days TEXT',
  );

  Future<void> _addGoalSchedule() async {
    await customStatement(
      'ALTER TABLE reading_goals ADD COLUMN duration_days INTEGER NOT NULL DEFAULT 0',
    );
    await customStatement(
      'ALTER TABLE reading_goals ADD COLUMN restart_day INTEGER',
    );
    await customStatement(
      'ALTER TABLE reading_goals ADD COLUMN repeat_goal INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _createRecitedPageAyahs() => customStatement(
    'CREATE TABLE recited_page_ayahs (goal INTEGER NOT NULL REFERENCES reading_goals(id), page INTEGER NOT NULL, ayah INTEGER NOT NULL, PRIMARY KEY(goal,page,ayah))',
  );
  Future<void> _addGoalRanges() =>
      customStatement('ALTER TABLE reading_goals ADD COLUMN recorded TEXT');
  Future<void> _createGoals() async {
    await customStatement(
      'CREATE TABLE reading_goals (id INTEGER PRIMARY KEY, name TEXT NOT NULL, pages INTEGER NOT NULL, anchors TEXT NOT NULL, quota INTEGER NOT NULL, interval_days INTEGER NOT NULL, start_day INTEGER NOT NULL, total INTEGER NOT NULL, read_units INTEGER NOT NULL DEFAULT 0)',
    );
    await customStatement(
      'CREATE TABLE goal_logs (id INTEGER PRIMARY KEY, goal INTEGER NOT NULL REFERENCES reading_goals(id), units INTEGER NOT NULL, logged_at INTEGER NOT NULL)',
    );
  }

  Future<void> createReadingGoal(
    String name,
    bool pages,
    List<int> anchors,
    int quota,
    int interval, {
    int durationDays = 0,
    bool repeat = false,
    List<int>? assignedDays,
  }) async {
    if (assignedDays != null &&
        (assignedDays.length != anchors.length ||
            assignedDays.indexed.any(
              (pair) =>
                  pair.$2 < 1 ||
                  pair.$2 > durationDays ||
                  (pair.$1 > 0 && pair.$2 < assignedDays[pair.$1 - 1]),
            ))) {
      throw ArgumentError.value(assignedDays);
    }
    if (durationDays < 0 || repeat && durationDays == 0) throw ArgumentError();
    if (name.trim().isEmpty || anchors.isEmpty || quota < 0 || interval < 1) {
      throw ArgumentError();
    }
    await customStatement(
      'INSERT INTO reading_goals(name,pages,anchors,quota,interval_days,start_day,total,duration_days,repeat_goal,assigned_days) VALUES(?,?,?,?,?,?,?,?,?,?)',
      [
        name.trim(),
        pages ? 1 : 0,
        jsonEncode(anchors),
        quota,
        interval,
        ReadingGoal.day(DateTime.now()),
        anchors.length,
        durationDays,
        repeat ? 1 : 0,
        assignedDays == null ? null : jsonEncode(assignedDays),
      ],
    );
  }

  Future<List<ReadingGoal>> readingGoals({DateTime? at}) => transaction(
    () async {
      await customStatement(
        'UPDATE reading_goals SET start_day=restart_day, restart_day=NULL, read_units=0, recorded=NULL WHERE restart_day<=?',
        [ReadingGoal.day(at ?? DateTime.now())],
      );
      return (await customSelect('SELECT * FROM reading_goals ORDER BY id DESC')
              .get())
          .map(
            (r) => ReadingGoal(
              r.read<int>('id'),
              r.read<String>('name'),
              r.read<int>('pages') == 1,
              (jsonDecode(r.read<String>('anchors')) as List).cast<int>(),
              r.read<int>('quota'),
              r.read<int>('interval_days'),
              r.read<int>('start_day'),
              r.read<int>('read_units'),
              r.readNullable<String>('recorded') == null
                  ? null
                  : (jsonDecode(r.read<String>('recorded')) as List)
                        .cast<int>()
                        .toSet(),
              r.read<int>('duration_days'),
              r.read<int>('repeat_goal') == 1,
              r.readNullable<String>('assigned_days') == null
                  ? null
                  : (jsonDecode(r.read<String>('assigned_days')) as List)
                        .cast<int>(),
            ),
          )
          .toList();
    },
  );

  Future<void> logGoalReading(ReadingGoal goal, int units) async {
    if (units < 1 || units > goal.remaining) throw RangeError.value(units);
    await logGoalRange(
      goal,
      goal.unread.take(units).first,
      goal.unread.take(units).last,
    );
  }

  Future<void> completeGoalDay(ReadingGoal displayed, int day) =>
      transaction(() async {
        if (day != ReadingGoal.day(DateTime.now())) return;
        final current = (await readingGoals())
            .where(
              (g) => g.id == displayed.id && g.startDay == displayed.startDay,
            )
            .firstOrNull;
        if (current == null) return;
        final due = displayed.unread
            .take(displayed.due(day))
            .toSet()
            .intersection(current.unread.take(current.due(day)).toSet());
        if (due.isNotEmpty) await _recordGoalUnits(current, due);
      });

  Future<void> logGoalRange(ReadingGoal goal, int first, int last) =>
      transaction(() async {
        final additions = goal.unread
            .where((id) => id >= first && id <= last)
            .toSet();
        await _recordGoalUnits(goal, additions);
      });

  Future<void> _recordGoalUnits(ReadingGoal goal, Set<int> additions) async {
    if (additions.isEmpty) throw StateError('Already recorded');
    final today = ReadingGoal.day(DateTime.now());
    if (goal.startDay > today) throw StateError('Cycle has not started');
    final units = additions.length;
    final recorded = {
      ...?goal.recorded,
      if (goal.recorded == null) ...goal.anchors.take(goal.read),
      ...additions,
    };
    await customStatement(
      'UPDATE reading_goals SET recorded=?, read_units=read_units+? WHERE id=? AND read_units=? AND start_day=? AND read_units+?<=total',
      [
        jsonEncode(recorded.toList()),
        units,
        goal.id,
        goal.read,
        goal.startDay,
        units,
      ],
    );
    if ((await customSelect(
          'SELECT changes() AS n',
        ).getSingle()).read<int>('n') !=
        1) {
      throw StateError('Stale goal');
    }
    await customStatement(
      'INSERT INTO goal_logs(goal,units,logged_at) VALUES(?,?,?)',
      [goal.id, units, DateTime.now().millisecondsSinceEpoch],
    );
    if (goal.repeat && recorded.length == goal.anchors.length) {
      await customStatement(
        'UPDATE reading_goals SET restart_day=? WHERE id=?',
        [today + 1, goal.id],
      );
    }
  }

  Future<bool> creditRecitation(
    int page,
    Set<int> pageAyahs,
    Set<int> recited,
  ) => transaction(() async {
    if (recited.isEmpty || !pageAyahs.containsAll(recited)) return false;
    var changed = false;
    for (final goal in await readingGoals()) {
      if (goal.remaining == 0 ||
          goal.startDay > ReadingGoal.day(DateTime.now())) {
        continue;
      }
      final unread = goal.unread.toSet();
      final additions = <int>{};
      if (goal.pages) {
        final anchors = unread.intersection(pageAyahs);
        if (anchors.isEmpty) continue;
        for (final id in recited) {
          await customStatement(
            'INSERT OR IGNORE INTO recited_page_ayahs(goal,page,ayah) VALUES(?,?,?)',
            [goal.id, page, id],
          );
        }
        final row = await customSelect(
          'SELECT COUNT(*) AS n FROM recited_page_ayahs WHERE goal=? AND page=?',
          variables: [Variable.withInt(goal.id), Variable.withInt(page)],
        ).getSingle();
        if (row.read<int>('n') < pageAyahs.length) continue;
        additions.addAll(anchors);
        await customStatement(
          'DELETE FROM recited_page_ayahs WHERE goal=? AND page=?',
          [goal.id, page],
        );
      } else {
        additions.addAll(unread.intersection(recited));
      }
      if (additions.isNotEmpty) {
        await _recordGoalUnits(goal, additions);
        changed = true;
      }
    }
    return changed;
  });

  Future<void> editReadingGoal(
    int id,
    String name,
    int days,
    bool repeat,
    List<int>? assignedDays,
  ) async {
    if (name.trim().isEmpty || days < 0 || (repeat && days == 0)) {
      throw ArgumentError();
    }
    await customStatement(
      'UPDATE reading_goals SET name=?, duration_days=?, repeat_goal=?, assigned_days=?, restart_day=CASE WHEN ?=0 THEN NULL WHEN read_units=total THEN COALESCE(restart_day,?) ELSE NULL END WHERE id=?',
      [
        name.trim(),
        days,
        repeat ? 1 : 0,
        assignedDays == null ? null : jsonEncode(assignedDays),
        repeat ? 1 : 0,
        ReadingGoal.day(DateTime.now()) + 1,
        id,
      ],
    );
  }

  Future<void> deleteReadingGoal(int id) => transaction(() async {
    await customStatement('DELETE FROM recited_page_ayahs WHERE goal=?', [id]);
    await customStatement('DELETE FROM goal_logs WHERE goal=?', [id]);
    await customStatement('DELETE FROM reading_goals WHERE id=?', [id]);
  });

  Future<List<(DateTime, int)>> goalHistory(int id) async =>
      (await customSelect(
            'SELECT logged_at,units FROM goal_logs WHERE goal=? ORDER BY id DESC',
            variables: [Variable.withInt(id)],
          ).get())
          .map(
            (r) => (
              DateTime.fromMillisecondsSinceEpoch(r.read<int>('logged_at')),
              r.read<int>('units'),
            ),
          )
          .toList();

  Future<bool> needsHifzSetup() async =>
      (await (select(
        preferences,
      )..where((p) => p.key.equals('hifz_setup_pending'))).getSingleOrNull()) !=
      null;

  Future<void> finishHifzSetup() async {
    await (delete(
      preferences,
    )..where((p) => p.key.equals('hifz_setup_pending'))).go();
  }

  Future<int> readingPage() async {
    final row = await (select(
      preferences,
    )..where((p) => p.key.equals('reading_page'))).getSingleOrNull();
    return row?.value ?? 1;
  }

  Future<void> saveReadingPage(int page) async {
    RangeError.checkValueInInterval(page, 1, 604, 'page');
    await into(preferences).insertOnConflictUpdate(
      PreferencesCompanion.insert(key: 'reading_page', value: page),
    );
  }

  Future<Set<int>> bookmarks() async =>
      (await (select(
            preferences,
          )..where((p) => p.key.like('bookmark_page_%'))).get())
          .map((row) => row.value)
          .toSet();

  Future<void> setBookmark(int page, bool enabled) async {
    RangeError.checkValueInInterval(page, 1, 604, 'page');
    final key = 'bookmark_page_$page';
    if (enabled) {
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: key, value: page),
      );
    } else {
      await (delete(preferences)..where((p) => p.key.equals(key))).go();
    }
  }

  Future<Set<int>> memorizedBaseline(Riwayah riwayah) async =>
      (await (select(
            preferences,
          )..where((p) => p.key.like('baseline_${riwayah.id}_%'))).get())
          .map((row) => row.value)
          .toSet();

  Future<void> saveMemorizedBaseline(
    Riwayah riwayah,
    Set<int> ids, {
    Set<int> removedProgress = const {},
  }) => transaction(() async {
    final previous = await memorizedBaseline(riwayah);
    if (removedProgress.isEmpty &&
        ids.length == previous.length &&
        ids.containsAll(previous)) {
      return;
    }
    for (final id in ids) {
      riwayah.validateAyah(id);
    }
    await batch((batch) {
      for (final id in removedProgress) {
        batch.deleteWhere(
          memorizedAyahs,
          (row) =>
              row.riwayah.equals(riwayah.id) &
              row.numbering.equals(riwayah.numbering) &
              row.ayahId.equals(id),
        );
      }
    });
    await into(preferences).insertOnConflictUpdate(
      PreferencesCompanion.insert(
        key: 'baseline_revision_${riwayah.id}',
        value: (await preference('baseline_revision_${riwayah.id}')) + 1,
      ),
    );
    await (delete(
      preferences,
    )..where((p) => p.key.like('baseline_${riwayah.id}_%'))).go();
    await batch(
      (batch) => batch.insertAll(preferences, [
        for (final id in ids)
          PreferencesCompanion.insert(
            key: 'baseline_${riwayah.id}_$id',
            value: id,
          ),
      ]),
    );
  });

  Future<int> preference(String key, {int fallback = 0}) async =>
      (await (select(
        preferences,
      )..where((p) => p.key.equals(key))).getSingleOrNull())?.value ??
      fallback;

  Future<void> setPreference(String key, int value) => into(
    preferences,
  ).insertOnConflictUpdate(PreferencesCompanion.insert(key: key, value: value));

  /// Editing the baseline supersedes today's displayed portion, never its history.
  Future<List<int>> completedToday(Riwayah riwayah, DateTime now) async {
    final baseline = await memorizedBaseline(riwayah);
    final revision = await preference('baseline_revision_${riwayah.id}');
    if (await preference('completion_revision_${riwayah.id}') != revision) {
      return [];
    }
    final active =
        (await (select(preferences)
                  ..where((p) => p.key.like('active_portion_${riwayah.id}_%')))
                .get())
            .map((p) => p.value)
            .toSet();
    return (await progress(riwayah))
        .where((entry) {
          final date = entry.completedAt.toLocal();
          return !baseline.contains(entry.ayahId) &&
              (active.isEmpty || active.contains(entry.ayahId)) &&
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        })
        .map((entry) => entry.ayahId)
        .toList();
  }

  Future<int> dailyQuota() async {
    final row = await (select(
      preferences,
    )..where((row) => row.key.equals('daily_ayah_quota'))).getSingleOrNull();
    return row?.value ?? 5;
  }

  Future<QuotaUnit> dailyQuotaUnit() async {
    final row = await (select(
      preferences,
    )..where((row) => row.key.equals('daily_quota_unit'))).getSingleOrNull();
    final index = row?.value ?? 0;
    if (index < 0 || index >= QuotaUnit.values.length) {
      throw StateError('Unrecognized saved quota unit.');
    }
    return QuotaUnit.values[index];
  }

  Future<void> setDailyQuota(
    int count, {
    QuotaUnit unit = QuotaUnit.ayahs,
  }) async {
    RangeError.checkValueInInterval(count, 1, 100, 'quota');
    await transaction(() async {
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: 'daily_ayah_quota', value: count),
      );
      await into(preferences).insertOnConflictUpdate(
        PreferencesCompanion.insert(key: 'daily_quota_unit', value: unit.index),
      );
    });
  }

  Future<void> completePortion(
    Riwayah riwayah,
    Iterable<int> ids,
    DateTime at,
  ) => transaction(() async {
    final ayahs = ids.toSet().toList()..sort();
    if (ayahs.isEmpty) throw ArgumentError('A portion must contain ayahs.');
    for (final id in ayahs) {
      riwayah.validateAyah(id);
    }
    final local = at.toLocal();
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode(ayahs)))
        .toString()
        .substring(0, 16);
    final key =
        '${riwayah.id}:${local.year}-${local.month}-${local.day}:$fingerprint';
    final existing = await (select(
      reviewSessions,
    )..where((s) => s.id.equals(key))).getSingleOrNull();
    final revision = await preference('baseline_revision_${riwayah.id}');
    if (existing != null &&
        await preference('completion_revision_${riwayah.id}') == revision) {
      return;
    }
    await setPreference('completion_revision_${riwayah.id}', revision);
    await (delete(
      preferences,
    )..where((p) => p.key.like('active_portion_${riwayah.id}_%'))).go();
    await batch(
      (b) => b.insertAll(preferences, [
        for (final id in ayahs)
          PreferencesCompanion.insert(
            key: 'active_portion_${riwayah.id}_$id',
            value: id,
          ),
      ]),
    );
    for (final id in ayahs) {
      await markMemorized(riwayah, id, at);
    }
    if (existing != null) return;
    await into(reviewSessions).insert(
      ReviewSessionsCompanion.insert(
        id: key,
        ayahIds: jsonEncode(ayahs),
        startedAt: at.toUtc(),
      ),
    );
  });

  Future<void> startReviews(
    Riwayah riwayah,
    Iterable<int> ids,
    DateTime at,
  ) async {
    final ayahs = ids.toSet().toList()..sort();
    if (ayahs.isEmpty) return;
    for (final id in ayahs) {
      riwayah.validateAyah(id);
    }
    final date = at.toLocal();
    await into(reviewSessions).insert(
      ReviewSessionsCompanion.insert(
        id: '${riwayah.id}:${date.year}-${date.month}-${date.day}',
        ayahIds: jsonEncode(ayahs),
        startedAt: at.toUtc(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<ReviewSettings> reviewSettings() async {
    final values = {
      for (final row in await select(preferences).get()) row.key: row.value,
    };
    final count = values['review_count'];
    if (count == null) return ReviewSettings();
    return ReviewSettings(
      intervals: [
        for (var i = 0; i < count; i++)
          Duration(minutes: values['review_gap_$i'] ?? 10),
      ],
      adaptive: values['review_adaptive'] == 1,
    );
  }

  Future<void> saveReviewSettings(ReviewSettings settings) =>
      transaction(() async {
        final values = {
          'review_count': settings.intervals.length,
          'review_adaptive': settings.adaptive ? 1 : 0,
          for (var i = 0; i < settings.intervals.length; i++)
            'review_gap_$i': settings.intervals[i].inMinutes,
        };
        for (final entry in values.entries) {
          await into(preferences).insertOnConflictUpdate(
            PreferencesCompanion.insert(key: entry.key, value: entry.value),
          );
        }
      });

  Future<List<ReviewSession>> sessions() => (select(
    reviewSessions,
  )..orderBy([(s) => OrderingTerm.asc(s.startedAt)])).get();

  Future<List<ReviewAttempt>> attempts(String sessionId) =>
      (select(reviewAttempts)
            ..where((a) => a.sessionId.equals(sessionId))
            ..orderBy([(a) => OrderingTerm.asc(a.ordinal)]))
          .get();

  Future<void> recordRecall(
    String sessionId,
    int ordinal,
    RecallRating rating,
    DateTime at,
  ) => transaction(() async {
    final session = await (select(
      reviewSessions,
    )..where((s) => s.id.equals(sessionId))).getSingle();
    final history = await attempts(sessionId);
    // A second tap or retry of an already saved attempt has no side effects.
    if (ordinal < history.length) return;
    final pending = ReviewScheduler().pending(
      startedAt: session.startedAt,
      attempts: [
        for (final a in history)
          RecallAttempt(a.completedAt, RecallRating.values[a.rating]),
      ],
      settings: await reviewSettings(),
      now: at,
    );
    if (pending.isEmpty ||
        ordinal != pending.first.ordinal ||
        !pending.first.isDue(at)) {
      throw StateError(
        'This review is not currently due. Refresh the schedule.',
      );
    }
    await into(reviewAttempts).insert(
      ReviewAttemptsCompanion.insert(
        sessionId: sessionId,
        ordinal: ordinal,
        rating: rating.index,
        completedAt: at.toUtc(),
      ),
    );
  });

  Future<void> markMemorized(Riwayah riwayah, int ayahId, DateTime at) {
    riwayah.validateAyah(ayahId);
    return into(memorizedAyahs).insertOnConflictUpdate(
      MemorizedAyahsCompanion.insert(
        riwayah: riwayah.id,
        numbering: riwayah.numbering,
        ayahId: ayahId,
        completedAt: at.toUtc(),
      ),
    );
  }

  Future<List<MemorizedAyah>> progress(Riwayah riwayah) =>
      (select(memorizedAyahs)
            ..where(
              (row) =>
                  row.riwayah.equals(riwayah.id) &
                  row.numbering.equals(riwayah.numbering),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.ayahId)]))
          .get();
}
