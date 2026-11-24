import 'dart:async';
import 'dart:io';

import 'package:hifz/core/data/quran_repository.dart';
import 'package:hifz/core/data/user_database.dart';
import 'package:hifz/core/notifications/review_reminders.dart';
import 'package:hifz/domain/riwayah.dart';
import 'package:hifz/domain/reading_goal.dart';
import 'package:hifz/features/quran_screen.dart';
import 'package:hifz/features/goals_screen.dart';
import 'package:hifz/domain/review_scheduler.dart';
import 'package:hifz/features/reviews_screen.dart';
import 'package:hifz/features/mushaf_page.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hifz/app_modules.dart';
import 'package:hifz/core/data/app_databases.dart';

void main() {
  testWidgets(
    'custom ayah range starts at Baqarah 1 and divides its first two printed pages exactly',
    (tester) async {
      final db = _ReaderData();
      addTearDown(db.quran.close);
      await tester.pumpWidget(
        MaterialApp(
          home: GoalsScreen(databases: db, onOpenAyah: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('هدف جديد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('القرآن كاملًا').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('نطاقات محددة').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('من الفاتحة، آية 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 · البقرة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلى البقرة، آية 1'));
      await tester.pumpAndSettle();
      final wheel = tester.widget<ListWheelScrollView>(
        find.byType(ListWheelScrollView).last,
      );
      (wheel.controller! as FixedExtentScrollController).jumpToItem(15);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();
      expect(find.text('إلى البقرة، آية 16'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '2');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('عرض جدول المراجعة'));
      await tester.tap(find.byTooltip('عرض جدول المراجعة'));
      await tester.pumpAndSettle();
      expect(find.text('البقرة · 1–5'), findsWidgets);
      expect(find.text('البقرة · 6–16'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Arabic revision setup previews memorized ranges at large text size',
    (tester) async {
      final db = _ReaderData();
      addTearDown(db.quran.close);
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: GoalsScreen(databases: db, onOpenAyah: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('هدف جديد'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('القرآن كاملًا').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('محفوظي').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '3');

      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('عرض جدول المراجعة'));
      await tester.tap(find.byTooltip('عرض جدول المراجعة'));
      await tester.pumpAndSettle();
      expect(find.textContaining('اليوم 1'), findsOneWidget);
      expect(find.textContaining('اليوم 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'starting a goal opens the Quran tab at Baqarah 13 on the full third page',
    (tester) async {
      final db = _ReaderData();
      addTearDown(db.quran.close);
      await tester.runAsync(
        () => Future.wait([
          for (final p in [2, 3, 4, 43, 44, 45])
            MushafPage.preload(db.quran, p),
        ]),
      );
      await tester.pumpWidget(HifzApp(openDatabases: () async => db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التثبيت'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مراجعة'));
      await tester.pumpAndSettle();
      expect(find.text('تسميع'), findsNothing);
      await tester.tap(find.text('بدء الجلسة'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      final reader = tester.widget<QuranScreen>(find.byType(QuranScreen));
      expect((reader.initialPage, reader.initialAyah), (3, 20));
      final page = tester.widget<MushafPage>(
        find.byWidgetPredicate((w) => w is MushafPage && w.page == 3),
      );
      expect(page.selectedAyahs, isNull);
      expect(page.highlightedAyah, 20);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('review screen shows default, custom and weak-recall due times', (
    tester,
  ) async {
    final db = _ReaderData();
    addTearDown(db.quran.close);
    addTearDown(db.reminders.dispose);
    final start = db.user.start;
    Future<void> check(int revision, int expectedMinutes, int count) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewsScreen(key: ValueKey(revision), databases: db),
        ),
      );
      await tester.pumpAndSettle();
      final labels = MaterialLocalizations.of(
        tester.element(find.byType(ReviewsScreen)),
      );
      final due = start.add(Duration(minutes: expectedMinutes));
      final date = labels.formatShortDate(due);
      final time = labels.formatTimeOfDay(TimeOfDay.fromDateTime(due));
      expect(find.text('الجلسة التالية · $date · $time'), findsOneWidget);
      expect(find.textContaining('$count جلسات لكل ورد'), findsOneWidget);
      expect(find.text('الفاتحة · 1–2'), findsOneWidget);
    }

    await check(1, 10, 3);
    db.user.settings = ReviewSettings(
      intervals: [const Duration(minutes: 8), const Duration(minutes: 20)],
    );
    await check(2, 8, 2);
    db.user.history.add(
      ReviewAttempt(
        sessionId: 'r',
        ordinal: 0,
        rating: RecallRating.again.index,
        completedAt: start.add(const Duration(minutes: 8)),
      ),
    );
    await check(3, 13, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('page 44 stays in place while reader controls fade', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final db = _ReaderData();
    addTearDown(db.quran.close);
    await tester.runAsync(
      () => Future.wait([
        for (final page in [43, 44, 45]) MushafPage.preload(db.quran, page),
      ]),
    );
    await tester.pumpWidget(HifzApp(openDatabases: () async => db));
    await tester.pump();
    await tester.pump();
    final page = find.byWidgetPredicate((w) => w is MushafPage && w.page == 44);
    final bounds = tester.getRect(page);
    final mic = find.byTooltip('بدء التسميع');
    expect(tester.getRect(mic).right, greaterThan(340));
    expect(tester.getRect(mic).top, greaterThanOrEqualTo(bounds.bottom));
    for (final visible in [false, true]) {
      await tester.tapAt(bounds.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(page), bounds);
      await tester.pump(const Duration(milliseconds: 140));
      expect(tester.getRect(page), bounds);
      expect(mic.hitTestable(), visible ? findsOneWidget : findsNothing);
    }
    final readerState = tester.state(find.byType(QuranScreen));
    await tester.tap(find.text('الأذكار'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('الأذكار اليومية'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(QuranScreen)), same(readerState));
    expect(tester.getRect(page), bounds);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'the Quran index marks the current surah and accepts Arabic page digits',
    (tester) async {
      final db = _ReaderData();
      addTearDown(db.quran.close);
      await tester.runAsync(
        () => Future.wait([
          for (final page in [42, 43, 44, 45])
            MushafPage.preload(db.quran, page),
        ]),
      );
      await tester.pumpWidget(HifzApp(openDatabases: () async => db));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('البقرة').first);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is ListTile && w.selected && (w.title as Text).data == 'البقرة',
        ),
        findsOneWidget,
      );
      final field = find.byType(TextFormField);
      await tester.enterText(field, '٦٠٥');
      await tester.pump();
      expect(find.text('أدخل صفحة بين 1 و604'), findsOneWidget);
      await tester.enterText(field, '٤٣');
      await tester.pump();
      await tester.tap(find.byTooltip('انتقل إلى الصفحة'));
      await tester.pumpAndSettle();
      expect(find.text('تصفح القرآن'), findsNothing);
      expect(find.textContaining('صفحة 43 ·'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('shows loading and a retry action when startup fails', (
    tester,
  ) async {
    final opening = Completer<AppDatabases>();
    await tester.pumpWidget(HifzApp(openDatabases: () => opening.future));
    expect(find.text('حفظ'), findsOneWidget);
    expect(find.text('جارٍ فتح القرآن…'), findsOneWidget);
    opening.completeError(StateError('Unavailable database'));
    await tester.pumpAndSettle();
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}

class _ReaderUser extends Fake implements UserDatabase {
  @override
  Future<Set<int>> memorizedBaseline(Riwayah riwayah) async => {1, 2, 3, 4, 7};
  @override
  Future<List<MemorizedAyah>> progress(Riwayah riwayah) async => [];

  @override
  Future<List<ReadingGoal>> readingGoals({DateTime? at}) async => [
    ReadingGoal(
      1,
      'مراجعة',
      false,
      [20, 21],
      0,
      1,
      ReadingGoal.day(DateTime.now()),
      0,
      null,
      2,
    ),
  ];
  @override
  Future<void> saveReadingPage(int page) async {}
  final start = DateTime.now().add(const Duration(days: 1));
  ReviewSettings settings = ReviewSettings();
  final history = <ReviewAttempt>[];
  @override
  Future<ReviewSettings> reviewSettings() async => settings;
  @override
  Future<List<ReviewSession>> sessions() async => [
    ReviewSession(id: 'r', ayahIds: '[1,2]', startedAt: start),
  ];
  @override
  Future<List<ReviewAttempt>> attempts(String id) async => history;

  @override
  Future<int> readingPage() async => 44;
  @override
  Future<Set<int>> bookmarks() async => {};
}

class _ReaderData extends Fake implements AppDatabases {
  @override
  final quran = QuranRepository.open(
    File('assets/data/quran.db'),
    riwayah: Riwayah.hafs,
  );
  @override
  final _ReaderUser user = _ReaderUser();
  @override
  final goalProgress = ValueNotifier<int>(0);
  @override
  late final reminders = ReviewReminders(user);
  @override
  Duration get openTime => Duration.zero;
}
