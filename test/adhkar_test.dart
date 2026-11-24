import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hifz/features/adhkar/adhkar_screen.dart';
import 'package:hifz/core/data/quran_repository.dart';
import 'package:hifz/domain/riwayah.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:hifz/features/adhkar/adhkar_store.dart';

void main() {
  testWidgets('daily and personal sessions work offline in the Arabic menu', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final quran = QuranRepository.open(
      File('assets/data/quran.db'),
      riwayah: Riwayah.hafs,
    );
    addTearDown(quran.close);
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: AdhkarScreen(quran: quran, directory: () async => dir),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('أذكار الصباح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل تكرار'));
    await tester.pumpAndSettle();
    expect(find.text('1 من 3'), findsOneWidget);
    for (final next in ['الفلق', 'الناس']) {
      while (find.text('تسجيل تكرار').evaluate().isNotEmpty) {
        await tester.tap(find.text('تسجيل تكرار'));
        await tester.pump();
      }
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.text('سُورَة $next'), findsOneWidget);
      expect(find.text('0 من 3'), findsOneWidget);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('أذكاري'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة ذكر'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'الحمد لله');
    await tester.pump();
    await tester.ensureVisible(find.text('حفظ'));
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('أذكاري'), findsOneWidget);
    await tester.tap(find.text('الحمد لله'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل تكرار'));
    await tester.pumpAndSettle();
    expect(find.text('بدء جولة جديدة'), findsOneWidget);
    await tester.tap(find.text('بدء جولة جديدة'));
    await tester.pumpAndSettle();
    expect(find.text('0 من 1'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إجراءات الذكر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('تكرار يومي'));
    await tester.tap(find.text('تكرار يومي'));
    await tester.ensureVisible(find.text('حفظ'));
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الأذكار اليومية').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('الحمد لله'));
    await tester.tap(find.text('الحمد لله'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تسجيل تكرار'));
    await tester.pumpAndSettle();
    expect(find.text('تم الذكر'), findsOneWidget);
    expect(find.text('بدء جولة جديدة'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  test(
    'daily personal rounds have distinct dates and preserve the manual round',
    () {
      var day = DateTime(2026, 11, 23, 23, 59);
      final store = AdhkarStore(sqlite3.openInMemory(), now: () => day);
      addTearDown(store.db.close);
      store.save('الحمد لله', 2);
      final d = store.personal().single;
      final manual = store.personalKey(d.id);
      store.start(manual, [d]);
      store.count(manual, store.entries(manual).single);
      store.save(d.text, 2, id: d.id, daily: true);
      final today = store.personalKey(d.id);
      store.start(today, [d]);
      store.count(today, store.entries(today).single);
      expect(store.recurringIds, {d.id});
      day = DateTime(2026, 11, 24);
      final tomorrow = store.personalKey(d.id);
      store.start(tomorrow, [d]);
      expect(store.entries(tomorrow).single.count, 0);
      expect(store.dailyHistory()[1].count, 1);
      expect(store.entries(today).single.count, 1);
      store.save(d.text, 2, id: d.id, daily: false);
      expect(store.personalKey(d.id), manual);
      expect(store.entries(manual).single.count, 1);
    },
  );
  const item = (id: 'first', text: 'ذكر', target: 2, source: 'شخصي');
  test('committed repetitions survive restart, retries, and midnight with independent collections', () {
    final dir = Directory.systemTemp.createTempSync();
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/adhkar.db';
    var now = DateTime(2026, 11, 23, 23, 59);
    var repo = AdhkarStore(sqlite3.open(path), now: () => now);
    final morning = repo.dailyKey('morning'),
        evening = repo.dailyKey('evening');
    repo.start(morning, [item]);
    repo.start(evening, [item]);
    final first = repo.entries(morning).single;
    repo.count(morning, first);
    repo.count(morning, first);
    expect(repo.entries(morning).single.count, 1);
    repo.db.close();
    now = DateTime(2026, 11, 24);
    repo = AdhkarStore(sqlite3.open(path), now: () => now);
    addTearDown(repo.db.close);
    final next = repo.dailyKey('morning');
    repo.start(next, [item]);
    repo.start(morning, [(id: 'other', text: 'تحديث', target: 5, source: '')]);
    final resumed = repo.entries(morning).single;
    expect(resumed.id, item.id);
    expect(resumed.count, 1);
    repo.count(morning, resumed);
    final full = repo.entries(morning).single;
    repo.count(morning, full);
    expect(repo.entries(morning).single.count, 2);
    repo.count(morning, full, undo: true);
    repo.count(morning, full, undo: true);
    expect(repo.entries(morning).single.count, 1);
    expect(repo.entries(next).single.count, 0);
    expect(repo.entries(evening).single.count, 0);
    final history = repo.dailyHistory();
    expect(history.length, 7);
    expect(history.first.count, 0);
    expect(history[1].count, 1);
  });
  test('archive and edits preserve the snapshot and a new round uses the edited target', () {
    final store = AdhkarStore(sqlite3.openInMemory());
    addTearDown(store.db.close);
    store.save('الأول', 1);
    final item = store.personal().single, id = item.id;
    final first = store.personalKey(id);
    store.start(first, [item]);
    store.count(first, store.entries(first).single);
    store.save('الثاني', 3, id: id);
    store.nextRound(id);
    final next = store.personalKey(id);
    store.start(next, store.personal());
    expect(store.entries(next).single.target, 3);
    expect(store.entries(next).single.count, 0);
    store.archive(id);
    expect(store.personal(), isEmpty);
    expect(store.entries(first).single.text, 'الأول');
    expect(store.entries(first).single.count, 1);
  });
}
