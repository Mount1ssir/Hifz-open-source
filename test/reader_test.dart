import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hifz/core/data/quran_repository.dart';
import 'package:hifz/domain/riwayah.dart';
import 'package:hifz/domain/review_scheduler.dart';
import 'package:hifz/features/quran_reader.dart';
import 'package:hifz/features/mushaf_page.dart';

void main() {
  late QuranRepository quran;
  setUp(
    () => quran = QuranRepository.open(
      File('assets/data/quran.db'),
      riwayah: Riwayah.hafs,
    ),
  );
  tearDown(() => quran.close());

  testWidgets(
    'tajweed uses the same nominal glyph size on opening and dense pages',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      quran.tajweed.value = true;
      final sizes = <double?>{};
      for (final page in [1, 44, 604]) {
        await tester.runAsync(() => MushafPage.preload(quran, page));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MushafPage(quran: quran, page: page),
            ),
          ),
        );
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'A prefetched tajweed page is ready on its first frame.',
        );
        final glyphs = tester.widgetList<Text>(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.style?.fontFamily?.startsWith('Tajweed') ?? false),
          ),
        );
        expect(glyphs, isNotEmpty);
        sizes.addAll(glyphs.map((w) => w.style!.fontSize));
      }
      expect(sizes, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Mushaf switches between offline tajweed and plain glyphs', (
    tester,
  ) async {
    await tester.runAsync(() => MushafPage.preload(quran, 44));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MushafPage(quran: quran, page: 44)),
      ),
    );
    await tester.runAsync(() async {
      quran.tajweed.value = true;
      await tester.pump();
      for (
        var i = 0;
        i < 100 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
      }
    });
    final colors = find.byWidgetPredicate(
      (w) => w is Text && w.style?.fontFamily == 'Tajweed44',
    );
    expect(colors, findsWidgets);
    quran.tajweed.value = false;
    await tester.pumpAndSettle();
    expect(colors, findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Text && w.style?.fontFamily == 'QpcPage44',
      ),
      findsWidgets,
    );
  });

  testWidgets(
    'a 13-line Hifz portion fits across the boundary of pages 44 and 45',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => Future.wait([
          for (final p in [44, 45]) MushafPage.preload(quran, p),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: QuranReader(
            quran: quran,
            ayahs: quran.readRange(272, 272),
            title: 'ورد اليوم',
            fitPortion: true,
            showPreviousAyah: true,
            showNextAyah: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final page = tester.widget<PageView>(find.byType(PageView));
      expect(page.childrenDelegate.estimatedChildCount, 1);
      expect(find.byType(SingleChildScrollView), findsNothing);
      for (final source in [44, 45]) {
        final words = quran
            .pageLines(source)
            .expand((line) => line.words)
            .where((w) => [271, 272, 273].contains(w.ayahId));
        for (final word in words) {
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.data == word.glyph &&
                  w.style?.fontFamily == 'QpcPage$source',
            ),
            findsWidgets,
          );
        }
      }
      expect(tester.getRect(find.byTooltip('بدء التسميع')).right, 352);
      await tester.tap(find.byTooltip('إخفاء الآيات'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byTooltip('بدء التسميع')).right, 352);
    },
  );

  test(
    'offline verse search accepts ordinary Arabic and returns the mushaf page',
    () async {
      final results = await quran.searchVerses('الحمد لله رب العالمين');
      final verse = results.first;
      expect((verse.surah, verse.number, verse.page), (1, 2, 1));
      expect((await quran.searchVerses(verse.text)).first.id, verse.id);
      expect(await quran.searchVerses('َ'), isEmpty);
    },
  );

  test(
    'goal ranges split at gaps and surah boundaries, including legacy pages',
    () {
      expect(quran.readRangesBySurah([6, 7, 8, 10], pages: false), [
        'الفاتحة · 6–7',
        'البقرة · 1، 3',
      ]);
      expect(quran.readRangesBySurah([1], pages: true), ['الفاتحة · 1–7']);
    },
  );

  testWidgets(
    'page recall requires revealing the assigned page before rating',
    (tester) async {
      RecallRating? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: QuranReader(
            quran: quran,
            ayahs: quran.readRange(1, 7),
            title: 'Recall',
            startHidden: true,
            onRecall: (rating) async {
              saved = rating;
            },
          ),
        ),
      );
      // Font decoding runs outside the widget test's fake clock.
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('جيد'), findsNothing);
      expect(find.text('Cards'), findsNothing);
      await tester.tap(find.byTooltip('إظهار الآيات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('جيد'));
      await tester.pumpAndSettle();
      expect(saved, RecallRating.good);
    },
  );

  testWidgets('assigned pages omit surrounding verses and fit above a footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final words = quran.pageLines(44).expand((line) => line.words).toList();
    final selected = words[words.length ~/ 2].ayahId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: MushafPage(
                  quran: quran,
                  page: 44,
                  selectedAyahs: {selected},
                ),
              ),
              const SizedBox(height: 100, child: Text('Footer')),
            ],
          ),
        ),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (final word in words.where((word) => word.ayahId != selected)) {
      expect(find.text(word.glyph), findsNothing);
    }
    final visible = words.where((word) => word.ayahId == selected).last;
    expect(find.text(visible.glyph), findsWidgets);
    expect(
      tester.getBottomLeft(find.text(visible.glyph).last).dy,
      lessThanOrEqualTo(540),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: MushafPage(quran: quran, page: 44)),
              const SizedBox(height: 100, child: Text('Footer')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsNothing);
    final lastLine = find.textContaining(words.last.glyph);
    expect(tester.getBottomLeft(lastLine.last).dy, lessThanOrEqualTo(540));
    expect(tester.takeException(), isNull);
    final pageSize = tester.widget<Text>(lastLine.last).style!.fontSize;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MushafPage(quran: quran, page: 44)),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(lastLine.last).style!.fontSize, pageSize);
  });

  testWidgets(
    'inline reading reveals words progressively and restores controls',
    (tester) async {
      var focused = false;
      var saved = 0;
      final words = quran.pageLines(1).expand((line) => line.words).toList();
      await tester.pumpWidget(
        MaterialApp(
          home: QuranReader(
            quran: quran,
            ayahs: quran.readRange(1, 7),
            title: 'Today',
            embedded: true,
            startHidden: true,
            onFocusChanged: (value) => focused = value,
            onComplete: () async {
              saved++;
            },
            onSaved: () async {},
            actions: [
              IconButton(
                tooltip: 'Settings',
                onPressed: () {},
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
        ),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text(words.first.glyph), findsNothing);
      final reveal = find.byTooltip('إظهار الكلمة التالية');
      final hide = find.byTooltip('إخفاء الكلمة السابقة');
      expect(tester.getCenter(reveal).dx, lessThan(tester.getCenter(hide).dx));
      expect(
        find.descendant(of: reveal, matching: find.byIcon(Icons.chevron_left)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hide, matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('إظهار الآية التالية'));
      await tester.pumpAndSettle();
      expect(
        find.text(words.lastWhere((w) => w.ayahId == words.first.ayahId).glyph),
        findsWidgets,
      );
      expect(
        find.text(
          words.firstWhere((w) => w.ayahId != words.first.ayahId).glyph,
        ),
        findsNothing,
      );
      await tester.tap(find.byTooltip('إخفاء الآية السابقة'));
      await tester.pumpAndSettle();
      expect(find.text(words.first.glyph), findsNothing);
      await tester.tap(find.byTooltip('إظهار الكلمة التالية'));
      await tester.pumpAndSettle();
      expect(find.text(words.first.glyph), findsOneWidget);
      final practiceSize = tester
          .widget<Text>(find.text(words.first.glyph))
          .style!
          .fontSize;
      expect(find.text(words[1].glyph), findsNothing);
      await tester.tap(find.byTooltip('إظهار الكلمة التالية'));
      await tester.pumpAndSettle();
      expect(find.text(words[1].glyph), findsOneWidget);
      await tester.tap(find.byTooltip('إخفاء الكلمة السابقة'));
      await tester.pumpAndSettle();
      expect(find.text(words[1].glyph), findsNothing);
      await tester.tap(find.byType(MushafPage));
      await tester.pumpAndSettle();
      expect(focused, isTrue);
      expect(
        tester.widget<Text>(find.text(words.first.glyph)).style!.fontSize,
        practiceSize,
      );
      expect(find.byType(AppBar), findsNothing);
      expect(
        find.byTooltip('إظهار الكلمة التالية').hitTestable(),
        findsNothing,
      );
      await tester.tap(find.byType(MushafPage));
      await tester.pumpAndSettle();
      expect(focused, isFalse);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text(words.first.glyph), findsOneWidget);
      await tester.tap(find.byTooltip('إظهار الآيات'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text(words.first.glyph)).style!.fontSize,
        practiceSize,
      );
      await tester.tap(find.byTooltip('تم حفظ الورد'));
      await tester.pumpAndSettle();
      expect(saved, 1);
      expect(find.byType(QuranReader), findsOneWidget);
    },
  );

  testWidgets('linking verses stay visible outside the assigned recall range', (
    tester,
  ) async {
    final words = quran.pageLines(1).expand((line) => line.words).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: QuranReader(
          quran: quran,
          ayahs: quran.readRange(3, 3),
          title: 'ورد اليوم',
          showPreviousAyah: true,
          showNextAyah: true,
          startHidden: true,
        ),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (final word in words.where((w) => w.ayahId == 2 || w.ayahId == 4)) {
      expect(find.text(word.glyph), findsOneWidget);
    }
    for (final word in words.where((w) => w.ayahId != 2 && w.ayahId != 4)) {
      expect(find.text(word.glyph), findsNothing);
    }
    await tester.tap(find.byTooltip('إظهار الكلمة التالية'));
    await tester.pumpAndSettle();
    expect(
      find.text(words.firstWhere((w) => w.ayahId == 3).glyph),
      findsOneWidget,
    );
    expect(
      tester
          .widget<QuranReader>(find.byType(QuranReader))
          .ayahs
          .map((a) => a.id),
      [3],
    );
  });

  testWidgets('empty portions show an explicit message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuranReader(quran: quran, ayahs: const [], title: 'Reader'),
      ),
    );
    expect(find.text('لا توجد آيات في هذا الورد.'), findsOneWidget);
  });
}
