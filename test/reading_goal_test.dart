import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/core/data/user_database.dart';

void main() {
  test(
    'editing a partially read goal keeps its start date, readings and log',
    () async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createReadingGoal(
        'الأول',
        false,
        [1, 2, 3, 4],
        0,
        1,
        durationDays: 2,
      );
      final old = (await db.readingGoals()).single;
      await db.logGoalRange(old, 2, 2);
      await db.editReadingGoal(old.id, 'المراجعة', 3, true, [1, 1, 2, 3]);
      final goal = (await db.readingGoals()).single;
      expect(
        (
          goal.id,
          goal.startDay,
          goal.read,
          goal.name,
          goal.durationDays,
          goal.repeat,
        ),
        (old.id, old.startDay, 1, 'المراجعة', 3, true),
      );
      expect(goal.unread, [1, 3, 4]);
      expect(await db.goalHistory(old.id), hasLength(1));
    },
  );

  test(
    'a weighted revision plan preserves its preview, catch-up and completion',
    () async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createReadingGoal(
        'مراجعة المحفوظ',
        false,
        [1, 2, 10, 11],
        0,
        1,
        durationDays: 4,
        assignedDays: [1, 1, 3, 4],
      );
      final goal = (await db.readingGoals()).single;
      expect(goal.plannedAyahs(2), isEmpty);
      expect(goal.sessionAyahs(goal.startDay + 2), [1, 2, 10]);
      await db.completeGoalDay(goal, goal.startDay);
      final updated = (await db.readingGoals()).single;
      expect(updated.plannedAyahs(1), [1, 2]);
      expect(updated.due(goal.startDay), 0);
      expect(updated.sessionAyahs(goal.startDay + 2), [10]);
    },
  );

  test(
    'swipe completion credits only the due unread ayahs and is safe to repeat',
    () async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createReadingGoal(
        'ورد',
        false,
        [1, 2, 3, 4, 5, 6],
        0,
        1,
        durationDays: 2,
      );
      final goal = (await db.readingGoals()).single;
      await db.logGoalRange(goal, 2, 2);
      await db.completeGoalDay(goal, goal.startDay);
      await db.completeGoalDay(goal, goal.startDay);
      final saved = (await db.readingGoals()).single;
      expect(saved.recorded, {1, 2, 3});
      expect(saved.unread, [4, 5, 6]);
    },
  );

  test('daily sessions distribute leftovers, carry missed ayahs and restart next day', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createReadingGoal(
      'خطة',
      false,
      [1, 2, 3, 4, 5, 6, 7],
      0,
      1,
      durationDays: 3,
      repeat: true,
    );
    var goal = (await db.readingGoals()).single;
    final start = goal.startDay;
    expect(goal.sessionAyahs(start), [1, 2, 3]);
    await db.logGoalRange(goal, 4, 4);
    goal = (await db.readingGoals()).single;
    expect(goal.sessionAyahs(start + 1), [1, 2, 3, 5]);
    await db.logGoalRange(goal, 1, 7);
    expect((await db.readingGoals()).single.remaining, 0);
    final now = DateTime.now();
    final next = (await db.readingGoals(
      at: DateTime(now.year, now.month, now.day + 1),
    )).single;
    expect(next.startDay, start + 1);
    expect(next.due(start), 0);
    expect(next.sessionAyahs(start + 1), [1, 2, 3]);
    expect(await db.goalHistory(next.id), hasLength(2));
    expect(await db.creditRecitation(1, {1}, {1}), isFalse);
  });

  test('reciting An-Nas advances all matching goals once and completes a page only when fully recited', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final nas = {for (var i = 6231; i <= 6236; i++) i};
    final page = {for (var i = 6222; i <= 6236; i++) i};
    await db.createReadingGoal('الناس', false, nas.toList(), 0, 1);
    await db.createReadingGoal('جزء عم', false, page.toList(), 0, 1);
    await db.createReadingGoal('صفحة', true, [page.first], 1, 1);
    expect(await db.creditRecitation(604, page, {6231}), isTrue);
    expect(await db.creditRecitation(604, page, {6231}), isFalse);
    await db.creditRecitation(604, page, nas);
    var goals = {for (final g in await db.readingGoals()) g.name: g};
    expect(goals['الناس']!.remaining, 0);
    expect(goals['جزء عم']!.read, 6);
    expect(goals['صفحة']!.read, 0);
    await db.creditRecitation(604, page, page.difference(nas));
    goals = {for (final g in await db.readingGoals()) g.name: g};
    expect(goals['صفحة']!.read, 1);
    expect(await db.creditRecitation(604, page, nas), isFalse);
  });

  test('open goals count overlapping passages once and retain the first unread ayah', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.createReadingGoal('مراجعة', false, [1, 2, 3, 4, 5], 0, 1);
    var goal = (await db.readingGoals()).single;
    expect(goal.due(goal.startDay + 3), 0);
    await db.logGoalRange(goal, 4, 5);
    goal = (await db.readingGoals()).single;
    expect(goal.unread, [1, 2, 3]);
    await db.logGoalRange(goal, 2, 4);
    goal = (await db.readingGoals()).single;
    expect(goal.read, 4);
    expect(goal.unread, [1]);
    expect((await db.goalHistory(goal.id)).first.$2, 2);
  });

  test('deleting one goal removes only its reading history', () async {
    final db = UserDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final name in ['الأول', 'الثاني']) {
      await db.createReadingGoal(name, false, [1, 2], 0, 1);
    }
    final goals = await db.readingGoals();
    for (final goal in goals) {
      await db.logGoalRange(goal, 1, 1);
    }
    await db.deleteReadingGoal(goals.first.id);
    expect((await db.readingGoals()).single.id, goals.last.id);
    expect(await db.goalHistory(goals.first.id), isEmpty);
    expect(await db.goalHistory(goals.last.id), hasLength(1));
  });

  test(
    'missed portions carry forward and partial logs advance the next page',
    () async {
      final db = UserDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.createReadingGoal('هدف', true, [1, 8, 13, 25, 34], 2, 1);
      var g = (await db.readingGoals()).single;
      expect(g.due(g.startDay + 1), 4);
      await db.logGoalReading(g, 3);
      await expectLater(db.logGoalReading(g, 1), throwsStateError);
      g = (await db.readingGoals()).single;
      expect(g.due(g.startDay + 1), 1);
      expect(g.anchors[g.read], 25);
      expect((await db.goalHistory(g.id)).single.$2, 3);
      await db.logGoalReading(g, 2);
      expect((await db.readingGoals()).single.remaining, 0);
    },
  );
}
