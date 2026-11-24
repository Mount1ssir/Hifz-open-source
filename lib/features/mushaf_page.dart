import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../core/data/quran_repository.dart';
import 'surah_heading.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.quran,
    required this.page,
    this.selectedAyahs,
    this.additionalPages = const [],
    this.fitPortion = false,
    this.highlightedAyah,
    this.swipeSnapshot,
    this.spokenGlyph,
    this.contextAyahs = const {},
    this.fullContrastContext = false,
    this.hidden = false,
    this.revealedWordCount = 0,
    this.revealFrom = 0,
  });
  final QuranRepository quran;
  final int page;
  final List<int> additionalPages;
  final bool fitPortion;
  final SnapshotController? swipeSnapshot;
  final int? highlightedAyah, spokenGlyph;
  final Set<int>? selectedAyahs;
  final Set<int> contextAyahs;
  final bool fullContrastContext;
  final bool hidden;
  final int revealedWordCount, revealFrom;

  static Future<void> preload(QuranRepository quran, int page) async {
    if (page < 1 || page > 604) return;
    await Future.wait([
      _MushafPageState.loadFont(page),
      if (quran.tajweed.value) _MushafPageState.prepareColorPage(page),
    ]);
    quran.pageLines(page);
  }

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  static final Map<int, Future<void>> _fonts = {};
  static final Set<int> _loadedFonts = {};
  late Future<void> _ready = _load();
  late Map<MushafLine, String> _lineFonts = _readLines();
  Iterable<MushafLine> get _lines => _lineFonts.keys;
  Map<MushafLine, String> _readLines() => {
    for (final page in [widget.page, ...widget.additionalPages])
      for (final line in widget.quran.pageLines(page)) line: 'QpcPage$page',
  };

  final _colored = <MushafWord, (String, String)>{};
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    widget.quran.tajweed.addListener(_changeEdition);
  }

  void _changeEdition() {
    setState(() {
      _maxWidth = null;
      _colored.clear();
      _ready = _load();
    });
  }

  @override
  void dispose() {
    widget.quran.tajweed.removeListener(_changeEdition);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final pages = [widget.page, ...widget.additionalPages];
    final colored = widget.quran.tajweed.value;
    if (pages.any((page) => !_loadedFonts.contains(page))) {
      await Future.wait([for (final page in pages) loadFont(page)]);
    }
    if (!colored || !mounted || generation != _generation) return;
    final rows = <(String, String)>[];
    for (final page in pages) {
      rows.addAll(_colorPages[page] ?? await prepareColorPage(page));
      if (!mounted || generation != _generation) return;
    }
    var i = 0;
    for (final word in _lines.expand((line) => line.words)) {
      _colored[word] = rows[i++];
    }
    _maxWidth = null;
  }

  static final _colorPages = <int, List<(String, String)>>{};
  static final _loadingColors = <int, Future<List<(String, String)>>>{};

  static Future<List<(String, String)>> prepareColorPage(int page) {
    final cached = _colorPages[page];
    if (cached != null) return Future.value(cached);
    return _loadingColors.putIfAbsent(page, () async {
      try {
        final raw = jsonDecode(
          await rootBundle.loadString(
            'assets/tajweed/p$page.json',
            cache: false,
          ),
        ) as List;
        final fonts = {for (final row in raw) row[0] as int};
        await Future.wait([
          for (final font in fonts) loadFont(font, color: true),
        ]);
        final rows = [
          for (final row in raw) ('Tajweed${row[0]}', row[1] as String),
        ];
        if (_colorPages.length >= 7) _colorPages.remove(_colorPages.keys.first);
        return _colorPages[page] = rows;
      } finally {
        _loadingColors.remove(page);
      }
    });
  }

  static Future<void> loadFont(int page, {bool color = false}) {
    final key = color ? -page : page;
    if (_loadedFonts.contains(key)) return Future<void>.value();
    return _fonts.putIfAbsent(key, () async {
      final loader = FontLoader(color ? 'Tajweed$page' : 'QpcPage$page');
      final dir = color ? 'tajweed' : 'quran_fonts';
      loader.addFont(rootBundle.load('assets/$dir/p$page.ttf'));
      try {
        await loader.load();
        _loadedFonts.add(key);
      } catch (_) {
        _fonts.remove(key);
        rethrow;
      }
    });
  }

  final Map<(String, String), double> _widths = {};
  double? _maxWidth;
  MushafWord? _spoken;
  Set<MushafWord> _revealedWords = {};

  @override
  void didUpdateWidget(MushafPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page ||
        !listEquals(oldWidget.additionalPages, widget.additionalPages)) {
      _widths.clear();
      _maxWidth = null;
      _lineFonts = _readLines();
      _colored.clear();
      _ready = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: () => setState(() => _ready = _load()),
            child: const Text('إعادة تحميل خط الصفحة'),
          ),
        );
      }
      if (((widget.quran.tajweed.value && _colored.isEmpty) ||
              !_loadedFonts.contains(widget.page) ||
              !widget.additionalPages.every(_loadedFonts.contains)) &&
          snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(100.0, constraints.maxWidth - 24);

          final fixedEdition =
              widget.selectedAyahs == null && _colored.isNotEmpty;
          if (!fixedEdition) {
            _maxWidth ??= _lines
                .where((line) => line.kind == 'ayah')
                .fold<double>(
                  1,
                  (widest, line) => math.max(widest, _naturalWidth(line, 32)),
                );
          }
          final selected = _lines
              .expand((line) => line.words)
              .where(
                (word) => widget.selectedAyahs?.contains(word.ayahId) ?? true,
              );
          _spoken = widget.spokenGlyph == null
              ? null
              : selected.elementAtOrNull(widget.spokenGlyph! - 1);
          _revealedWords = selected
              .take(widget.revealedWordCount)
              .skip(widget.revealFrom)
              .toSet();
          final lines = widget.selectedAyahs == null
              ? _lines
              : _lines
                    .where(
                      (line) =>
                          line.kind == 'ayah' &&
                          line.words.any(
                            (word) =>
                                (widget.selectedAyahs!.contains(word.ayahId) ||
                                widget.contextAyahs.contains(word.ayahId)),
                          ),
                    )
                    .toList();
          final widthSize = fixedEdition ? width / 13 : 32 * width / _maxWidth!;
          // Use the physical window, never the changing space left by controls.
          // Reserve compact chrome once in both focus and practice modes.
          final window = MediaQuery.sizeOf(context);
          final insets = MediaQuery.viewPaddingOf(context);
          final stableHeight = math.max(
            180.0,
            window.height - insets.vertical - 208,
          );
          final heightSize =
              stableHeight /
              (fixedEdition ? 15 : math.max(8, lines.length)) /
              1.85;
          final fullPage = widget.selectedAyahs == null || widget.fitPortion;
          final padding = fullPage
              ? math.min(16.0, constraints.maxHeight * .03)
              : 24.0;
          final fittedSize =
              (constraints.maxHeight - padding * 2) /
              (fixedEdition ? 15 : math.max(1, lines.length)) /
              1.85;
          final preferred = math.min(widthSize, math.max(12.0, heightSize));
          final fontSize = fullPage
              ? math.min(preferred, fittedSize)
              : preferred;
          final rowHeight = fontSize * 1.85;
          final pageHeight = math.max(
            rowHeight * lines.length + 48,
            constraints.maxHeight,
          );
          final printed = SizedBox(
            height: fullPage ? constraints.maxHeight : pageHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final line in lines)
                    SizedBox(
                      height: rowHeight,
                      child: fixedEdition && line.kind == "ayah"
                          ? _fixedLine(line, fontSize, width, rowHeight)
                          : _line(line, _lineFonts[line]!, fontSize),
                    ),
                ],
              ),
            ),
          );
          final controller = widget.swipeSnapshot;
          if (controller != null &&
              !widget.hidden &&
              widget.spokenGlyph == null) {
            return SnapshotWidget(
              controller: controller,
              autoresize: true,
              child: printed,
            );
          }
          return fullPage ? printed : SingleChildScrollView(child: printed);
        },
      );
    },
  );

  double _naturalWidth(MushafLine line, double size) {
    if (_singleFontLine(line)) {
      return _wordWidth(_lineText(line), _lineFont(line), size);
    }
    return line.words.fold<double>(
          0,
          (sum, w) => sum + _wordWidth(_colored[w]!.$2, _colored[w]!.$1, size),
        ) +
        math.max(0, line.words.length - 1) *
            _wordWidth(' ', _lineFonts[line]!, size);
  }

  // Only compress the horizontal axis of a dense line. Preserve the page grid.
  Widget _fixedLine(MushafLine line, double size, double width, double height) {
    final content = _line(line, _lineFonts[line]!, size);
    final natural = _naturalWidth(line, size);
    if (natural <= width) return content;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(width: natural, height: height, child: content),
    );
  }

  Widget _line(MushafLine line, String font, double size) {
    if (line.kind == 'surah_name') {
      return Padding(
        padding: const EdgeInsets.all(2),
        child: SurahHeading(name: line.heading ?? '', fontSize: size * .78),
      );
    }
    if (line.kind == 'basmallah') {
      return Center(
        child: Text(
          'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: size * .7),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final words = line.words;
        if (_singleFontLine(line) &&
            !widget.hidden &&
            widget.selectedAyahs == null &&
            widget.highlightedAyah == null &&
            _spoken == null) {
          final text = _lineText(line);
          final lineFont = _lineFont(line);
          final extra = line.centered || words.length < 2
              ? 0.0
              : (constraints.maxWidth - _wordWidth(text, lineFont, size)) /
                    (words.length - 1);
          return Align(
            alignment: line.centered ? Alignment.center : Alignment.centerRight,
            child: Text(
              '\u202e$text\u202c',
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: lineFont,
                fontSize: size,
                height: 1.4,
                wordSpacing: extra,
                letterSpacing: 0,
                color: const Color(0xff111b15),
              ),
            ),
          );
        }
        final widths = [
          for (final word in words)
            _wordWidth(
              _colored[word]?.$2 ?? word.glyph,
              _colored[word]?.$1 ?? font,
              size,
            ),
        ];
        final space = line.centered
            ? _wordWidth(' ', font, size)
            : math.max(
                0.0,
                (constraints.maxWidth - widths.fold(0.0, (a, b) => a + b)) /
                    math.max(1, words.length - 1),
              );
        bool masked(int i) =>
            widget.hidden &&
            (widget.selectedAyahs?.contains(words[i].ayahId) ?? true) &&
            !_revealedWords.contains(words[i]);
        final pieces = <Widget>[];
        for (var i = 0; i < words.length; i++) {
          if (i > 0) pieces.add(SizedBox(width: space));
          final word = words[i];
          var width = widths[i];
          if (masked(i)) {
            while (i + 1 < words.length && masked(i + 1)) {
              width += space + widths[++i];
            }
            pieces.add(
              Container(
                width: width,
                height: size * .6,
                decoration: BoxDecoration(
                  color: const Color(0xffd5dfd8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          } else {
            final visible =
                widget.selectedAyahs == null ||
                widget.selectedAyahs!.contains(word.ayahId) ||
                widget.contextAyahs.contains(word.ayahId);
            pieces.add(
              SizedBox(
                width: width,
                child: visible
                    ? Text(
                        identical(word, _spoken)
                            ? word.glyph
                            : _colored[word]?.$2 ?? word.glyph,
                        textDirection: TextDirection.rtl,
                        textScaler: TextScaler.noScaling,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          backgroundColor: widget.highlightedAyah == word.ayahId
                              ? const Color(0xffd4e9d9)
                              : null,
                          fontFamily: identical(word, _spoken)
                              ? font
                              : _colored[word]?.$1 ?? font,
                          fontSize: size,
                          height: 1.4,
                          color: identical(word, _spoken)
                              ? const Color(0xff00844c)
                              : !widget.fullContrastContext &&
                                    widget.selectedAyahs != null &&
                                    !widget.selectedAyahs!.contains(word.ayahId)
                              ? const Color(0xff828984)
                              : const Color(0xff111b15),
                        ),
                      )
                    : null,
              ),
            );
          }
        }
        return Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: line.centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: pieces,
        );
      },
    );
  }

  bool _singleFontLine(MushafLine line) {
    if (_colored.isEmpty || line.words.isEmpty) return true;
    final font = _colored[line.words.first]!.$1;
    return line.words.every(
      (w) => _colored[w]!.$1 == font && !_colored[w]!.$2.contains(' '),
    );
  }

  String _lineText(MushafLine line) =>
      line.words.map((w) => _colored[w]?.$2 ?? w.glyph).join(' ');
  String _lineFont(MushafLine line) =>
      _colored[line.words.firstOrNull]?.$1 ?? _lineFonts[line]!;
  double _wordWidth(String glyph, String font, double size) {
    final cached = _widths[(font, glyph)];
    if (cached != null) return cached * size / 32;
    final painter = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(fontFamily: font, fontSize: 32),
      ),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
    )..layout();
    final width = painter.width;
    painter.dispose();
    _widths[(font, glyph)] = width;
    return width * size / 32;
  }
}
