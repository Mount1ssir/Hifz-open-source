import '../core/data/quran_repository.dart';

final _alefs = RegExp('[أإآٱٲٳ]');
final _yas = RegExp('[ىئېیے]');
final _nonLetters = RegExp('[^ءابتثجحخدذرزسشصضطظعغفقكلمنهوي]');

String recitationSpelling(String text) => text
    .replaceAll(_alefs, 'ا')
    .replaceAll(_yas, 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ة', 'ه')
    .replaceAll(_nonLetters, '')
    .replaceAll('ءا', 'ا');

// Opening letters can be transcribed as a printed group or as spoken names.
const _openingNames = {
  'الم': 'الفلامميم',
  'المص': 'الفلامميمصاد',
  'الر': 'الفلامرا',
  'المر': 'الفلامميمرا',
  'كهيعص': 'كافهاياعينصاد',
  'طه': 'طاها',
  'طسم': 'طاسينميم',
  'طس': 'طاسين',
  'يس': 'ياسين',
  'ص': 'صاد',
  'حم': 'حاميم',
  'عسق': 'عينسينقاف',
  'ق': 'قاف',
  'ن': 'نون',
};

class RecitationWord {
  const RecitationWord(
    this.spelling,
    this.glyphEnd,
    this.ayahId,
    this.position,
    this.length,
    this.page,
    this.alternate, [
    this.openingNames,
  ]);
  final String spelling, alternate;
  final String? openingNames;
  final int glyphEnd, ayahId, position, length, page;
}

/// QPC includes a final glyph for the verse number. Reveal it with the last word.
List<RecitationWord> pageRecitationWords(
  QuranRepository quran,
  int page,
  Set<int>? selected, {
  List<int> additionalPages = const [],
}) {
  final result = <RecitationWord>[];
  for (final source in [page, ...additionalPages]) {
    result.addAll(
      _printedWords(quran, source, selected, result.lastOrNull?.glyphEnd ?? 0),
    );
  }
  return result;
}

List<RecitationWord> _printedWords(
  QuranRepository quran,
  int page,
  Set<int>? selected,
  int offset,
) {
  final counts = <int, int>{};
  for (final line in quran.pageLines(page)) {
    for (final word in line.words) {
      if (selected == null || selected.contains(word.ayahId)) {
        counts.update(word.ayahId, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }
  if (counts.isEmpty) return [];
  final words = <RecitationWord>[];

  for (final ayah in quran.readRange(counts.keys.first, counts.keys.last)) {
    final count = counts[ayah.id];
    if (count == null) continue;
    final text = ayah.text.substring(ayah.basmalahPrefix.length);
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((s) => recitationSpelling(s).isNotEmpty)
        .toList();
    for (var i = 0; i < tokens.length; i++) {
      // QPC prints إل ياسين as one glyph in 37:130.
      final glyph = ayah.surah == 37 && ayah.number == 130 && i == 2
          ? i
          : i + 1;
      final spelling = recitationSpelling(tokens[i]);
      final isOpening =
          i == 0 &&
          (ayah.number == 1 || (ayah.surah == 42 && ayah.number == 2));
      words.add(
        RecitationWord(
          spelling,
          offset + (i == tokens.length - 1 ? count : glyph),
          ayah.id,
          i,
          tokens.length,
          page,
          recitationSpelling(
            tokens[i].replaceAll('وٰ', 'ا').replaceAll('ٰ', 'ا'),
          ),
          isOpening ? _openingNames[spelling] : null,
        ),
      );
    }
    offset += count;
  }
  return words;
}

class RecitationFollower {
  RecitationFollower(this.words, int revealed, {this.lastTime = -1000}) {
    while (index < words.length && words[index].glyphEnd <= revealed) {
      index++;
    }
  }
  final List<RecitationWord> words;
  int index = 0;
  // Only these positions are eligible for goal credit after a match.
  int matchedFrom = 0;
  final _recent = <(String, int)>[];

  bool _matches(int position, String heard) =>
      words[position].spelling == heard || words[position].alternate == heard;

  int? _recover(String heard, int time) {
    if (_recent.isNotEmpty) {
      if (time <= _recent.last.$2 + 65) return null;
      if (time - _recent.last.$2 > 4000) _recent.clear();
    }
    _recent.add((heard, time));
    if (_recent.length > 3) _recent.removeAt(0);
    if (_recent.length < 3) return null;
    int? found;
    for (
      var start = index + 1;
      start <= index + 3 && start + 2 < words.length;
      start++
    ) {
      // Never bypass a whole verse or seek to another printed page.
      if (words[start - 1].ayahId != words[index].ayahId ||
          words[start + 2].page != words[index].page ||
          (words[index].position == 0 &&
              words[start].ayahId != words[index].ayahId)) {
        break;
      }
      if (_matches(start, _recent[0].$1) &&
          _matches(start + 1, _recent[1].$1) &&
          _matches(start + 2, _recent[2].$1)) {
        if (found != null) return null;
        found = start;
      }
    }
    if (found == null) return null;
    matchedFrom = found;
    index = found + 3;
    lastTime = time;
    _recent.clear();
    _prefix = '';
    return words[index - 1].glyphEnd;
  }

  int lastTime;
  String _prefix = '';
  int _prefixTime = -1000;
  bool get finished => index == words.length;
  int? hear(String text, int milliseconds) {
    if (finished || milliseconds <= lastTime + 65) return null;
    var heard = recitationSpelling(text);
    if (heard.isEmpty) return null;
    final expected = words[index];
    final opening = expected.openingNames;
    if (opening != null) {
      // ASR may transcribe حا and its letter name حاء with the final hamza.
      heard = heard.replaceAllMapped(
        RegExp('[حطهير]اء'),
        (m) => m[0]!.substring(0, 2),
      );
    }
    final continued =
        milliseconds > _prefixTime + 65 &&
            milliseconds - _prefixTime < (opening == null ? 1500 : 8000)
        ? _prefix + heard
        : heard;
    final forms = [expected.spelling, expected.alternate, ?opening];
    // A CTC decode may omit a word boundary. Accept both words only when
    // their complete spellings match consecutive words of this ayah.
    var consumed = 1;
    if (!forms.contains(heard) && !forms.contains(continued)) {
      if (index + 1 < words.length &&
          words[index + 1].ayahId == expected.ayahId) {
        final next = words[index + 1];
        final merged = forms.any(
          (prefix) =>
              heard == prefix + next.spelling ||
              heard == prefix + next.alternate,
        );
        if (merged) consumed = 2;
      }
      if (consumed == 1) {
        if (milliseconds > _prefixTime + 65) {
          _prefix = forms.any((s) => s.startsWith(continued))
              ? continued
              : forms.any((s) => s.startsWith(heard))
              ? heard
              : '';
          _prefixTime = milliseconds;
        }
        return _recover(heard, milliseconds);
      }
    }
    matchedFrom = index;
    _recent.clear();
    _prefix = '';
    lastTime = milliseconds;
    index += consumed;
    return words[index - 1].glyphEnd;
  }
}
