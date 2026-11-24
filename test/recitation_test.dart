import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hifz/features/recitation_button.dart';
import 'package:hifz/core/data/quran_repository.dart';
import 'package:hifz/domain/recitation.dart';
import 'package:hifz/domain/riwayah.dart';

void main() {
  late QuranRepository quran;
  setUp(
    () => quran = QuranRepository.open(
      File('assets/data/quran.db'),
      riwayah: Riwayah.hafs,
    ),
  );
  tearDown(() => quran.close());

  test('an hour of timestamped words survives local recognition gaps without granting credit for them', () {
    var time = 0, page = 1, recoveries = 0;
    while (time < 3600000) {
      final words = pageRecitationWords(quran, page++, null);
      final tracker = RecitationFollower(words, 0, lastTime: time - 1000);
      for (var i = 0; i < words.length; i++) {
        time += 850;
        if (words[i].position == 2 &&
            words[i].length >= 7 &&
            words.skip(i).take(4).map((w) => w.spelling).toSet().length == 4) {
          tracker.hear('خطأ', time);
          final missing = i;
          for (var j = 0; j < 3; j++) {
            time += 850;
            tracker.hear(words[++i].spelling, time);
          }
          expect(
            tracker.index,
            i + 1,
            reason:
                "page ${page - 1}, ${words.skip(missing).take(5).map((w) => w.spelling)}",
          );
          expect(tracker.matchedFrom, greaterThan(missing));
          recoveries++;
        } else {
          expect(tracker.hear(words[i].spelling, time), words[i].glyphEnd);
        }
      }
      expect(tracker.finished, isTrue);
    }
    expect(recoveries, greaterThan(10));
  });

  test(
    'follows ordinary alif spelling and split ASR words without skipping',
    () {
      final words = pageRecitationWords(quran, 1, {2});
      final follower = RecitationFollower(words, 0);
      expect(follower.hear('خطأ', 100), isNull);
      expect(follower.hear('الحمد', 200), isNotNull);
      expect(follower.hear('لله', 600), isNotNull);
      expect(follower.hear('رب', 850), isNotNull);
      expect(follower.hear('العا', 1000), isNull);
      expect(follower.hear('لمين', 1200), words.last.glyphEnd);
    },
  );

  test(
    'opening letters wait for the last spoken name through a long recitation',
    () {
      final words = pageRecitationWords(quran, 2, {8});
      final tracker = RecitationFollower(words, 0);
      expect(tracker.hear('ألف', 200), isNull);
      expect(tracker.hear('لام', 2600), isNull);
      expect(tracker.index, 0);
      expect(tracker.hear('ميم', 6400), words.single.glyphEnd);
      expect(tracker.finished, isTrue);
      expect(recitationSpelling('ٱلْقُرْءَانِ'), recitationSpelling('القرآن'));
    },
  );

  test('merged tokens advance exactly two fully spoken adjacent words', () {
    final tracker = RecitationFollower(pageRecitationWords(quran, 1, {1}), 0);
    expect(tracker.hear('بسمالرحمن', 500), isNull);
    expect(tracker.hear('بسمالله', 800), 2);
    expect(tracker.index, 2);
  });

  testWidgets('one microphone batch can finish one page and start the next', (
    tester,
  ) async {
    const channel = MethodChannel('hifz/recitation');
    final messenger = tester.binding.defaultBinaryMessenger;
    final commands = <String>[];
    int? session;
    messenger.setMockMethodCallHandler(channel, (call) async {
      commands.add(call.method);
      session = call.arguments as int;
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final words = pageRecitationWords(quran, 1, null);
    final next = pageRecitationWords(quran, 2, null);
    var page = 1;
    final counts = {1: words[words.length - 2].glyphEnd, 2: 0};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, update) => RecitationButton(
              quran: quran,
              page: page,
              revealed: counts[page]!,
              onReveal: (p, n) => update(() => counts[p] = n),
              advancePage: (p) {
                update(() => page = p + 1);
                return page;
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('بدء التسميع'));
    await tester.pump();
    await messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('words', {
          'id': session,
          'words': [
            {'text': words.last.spelling, 'ms': 300},
            {'text': next.first.spelling, 'ms': 900},
          ],
        }),
      ),
      null,
    );
    await tester.pump();
    expect(page, 2);
    expect(counts[2], next.first.glyphEnd);
    expect(commands, ['start']);
    await tester.tap(find.byTooltip('إيقاف التسميع'));
    await tester.pump();
    expect(commands, ['start', 'stop']);
  });

  testWidgets(
    'recognized batches reveal immediately and credit only fully spoken ayahs',
    (tester) async {
      const channel = MethodChannel('hifz/recitation');
      final messenger = tester.binding.defaultBinaryMessenger;
      int? session;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'start') session = call.arguments as int;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final credits = <int>[];
      var revealed = 1; // The first word of 114:1 was revealed by hand.
      final verses = {for (var id = 6231; id <= 6236; id++) id};
      final words = pageRecitationWords(quran, 604, verses);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecitationButton(
              quran: quran,
              page: 604,
              selected: verses,
              revealed: revealed,
              onReveal: (_, n) => revealed = n,
              onRecited: (page, ids) async {
                expect(page, 604);
                credits.addAll(ids);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('بدء التسميع'));
      await tester.pump();
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('words', {
            'id': session,
            'words': [
              for (var i = 1; i < words.length; i++)
                {'text': words[i].spelling, 'ms': i * 300},
            ],
          }),
        ),
        null,
      );
      expect(revealed, words.last.glyphEnd);
      expect(credits, [6232, 6233, 6234, 6235, 6236]);
    },
  );

  test('overlapping audio reveals only the next matching words and their verse marker', () {
    final words = pageRecitationWords(quran, 1, {1});
    final tracker = RecitationFollower(words, 0);
    expect(tracker.hear('الحمد', 100), isNull);
    expect(tracker.hear('بسم', 120), 1);
    expect(tracker.hear('بسم', 120), isNull);
    expect(tracker.hear('الله', 680), 2);
    expect(tracker.hear('الرحمن', 1320), 3);
    expect(tracker.hear('الرحيم', 2200), 5);
    expect(tracker.finished, isTrue);
  });

  test(
    'every page maps spoken words to displayed glyphs without extra basmalahs',
    () {
      for (var page = 1; page <= 604; page++) {
        final words = pageRecitationWords(quran, page, null);
        expect(
          words.last.glyphEnd,
          quran.pageLines(page).expand((line) => line.words).length,
        );
        var previous = 0;
        for (final word in words) {
          expect(word.glyphEnd, inInclusiveRange(previous, previous + 2));
          previous = word.glyphEnd;
        }
      }
      expect(pageRecitationWords(quran, 2, {8}).map((w) => w.spelling), [
        'الم',
      ]);
    },
  );
}
