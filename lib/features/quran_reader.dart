import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';

import '../core/data/quran_repository.dart';
import '../domain/review_scheduler.dart';
import 'mushaf_page.dart';
import 'recitation_button.dart';
import 'reader_controls.dart';
import '../core/arabic.dart';

class QuranReader extends StatefulWidget {
  const QuranReader({
    super.key,
    required this.quran,
    required this.ayahs,
    required this.title,
    this.startHidden = false,
    this.onComplete,
    this.onRecall,
    this.onRecited,
    this.actions = const [],
    this.embedded = false,
    this.onFocusChanged,
    this.onSaved,
    this.status,
    this.onReview,
    this.dueReviews,
    this.showPreviousAyah = false,
    this.showNextAyah = false,
    this.nextLink,
    this.fitPortion = false,
  });
  final QuranRepository quran;
  final List<QuranAyah> ayahs;
  final String title;
  final Future<void> Function(int, Set<int>)? onRecited;
  final bool startHidden;
  final bool showPreviousAyah;
  final bool showNextAyah;
  final int? nextLink;
  final bool fitPortion;
  final bool embedded;
  final List<Widget> actions;
  final ValueChanged<bool>? onFocusChanged;
  final Future<void> Function()? onSaved;
  final String? status;
  final VoidCallback? onReview;
  final ValueListenable<int>? dueReviews;
  final Future<void> Function()? onComplete;
  final Future<void> Function(RecallRating)? onRecall;

  @override
  State<QuranReader> createState() => _QuranReaderState();
}

class _QuranReaderState extends State<QuranReader> {
  late final List<int> _printedPages = widget.quran.pagesForAyahs({
    ...widget.ayahs.map((a) => a.id),
    ..._context,
  });
  late final List<int> _additionalPages = _fittingContinuation();
  late final List<int> _pages = _additionalPages.isEmpty
      ? _printedPages
      : [_printedPages.first];
  Iterable<MushafLine> _lines(int page) sync* {
    for (final source in [page, ..._additionalPages]) {
      yield* widget.quran.pageLines(source);
    }
  }

  List<int> _fittingContinuation() {
    if (!widget.fitPortion ||
        _printedPages.length < 2 ||
        _printedPages.length > widget.quran.linesPerPage) {
      return [];
    }
    final included = {..._context, ..._assigned};
    var lines = 0;
    for (final page in _printedPages) {
      lines += widget.quran
          .pageLines(page)
          .where(
            (line) => line.words.any((word) => included.contains(word.ayahId)),
          )
          .length;
      if (lines > widget.quran.linesPerPage) return [];
    }
    return _printedPages.sublist(1);
  }

  late final Set<int> _visible = widget.startHidden ? {} : _pages.toSet();
  late final int _initialIndex =
      widget.ayahs.isEmpty || _additionalPages.isNotEmpty
      ? 0
      : _pages.indexOf(widget.ayahs.first.page);
  late final PageController _controller = PageController(
    initialPage: _initialIndex,
  );
  late int _index = _initialIndex;
  bool _reciting = false;
  (int, int?)? _spoken;
  int _voiceKey = 0;
  bool _saving = false;
  bool _focus = false;
  final Map<int, int> _revealed = {};
  late final Set<int> _context = {
    if (widget.showPreviousAyah &&
        widget.ayahs.isNotEmpty &&
        widget.ayahs.first.id > 1)
      widget.ayahs.first.id - 1,
    if (widget.showNextAyah &&
        widget.ayahs.isNotEmpty &&
        widget.ayahs.last.id < widget.quran.riwayah.totalAyahs)
      widget.nextLink ?? widget.ayahs.last.id + 1,
  };
  late final Set<int> _assigned = widget.ayahs.map((a) => a.id).toSet();
  final _wordCounts = <int, int>{};
  int _wordCount(int page) => _wordCounts.putIfAbsent(
    page,
    () =>
        _lines(page)
            .expand((line) => line.words)
            .where((w) => _assigned.contains(w.ayahId))
            .length,
  );

  int? _advanceRecitation(int page) {
    final nextIndex = _pages.indexOf(page) + 1;
    if (nextIndex >= _pages.length || _wordCount(_pages[nextIndex]) == 0) {
      return null;
    }
    final next = _pages[nextIndex];
    _visible.remove(next);
    _revealed[next] = 0;
    _controller.jumpToPage(nextIndex);
    return next;
  }

  void _stepAyah(int page, bool reveal) {
    final words = _lines(page)
        .expand((line) => line.words)
        .where((word) => _assigned.contains(word.ayahId))
        .toList();
    var cursor = _revealed[page] ?? 0;
    if (reveal && cursor < words.length) {
      final id = words[cursor].ayahId;
      while (cursor < words.length && words[cursor].ayahId == id) {
        cursor++;
      }
    } else if (!reveal && cursor > 0) {
      final id = words[cursor - 1].ayahId;
      while (cursor > 0 && words[cursor - 1].ayahId == id) {
        cursor--;
      }
    }
    setState(() => _revealed[page] = cursor);
  }

  void _toggleFocus() {
    setState(() => _focus = !_focus);
    widget.onFocusChanged?.call(_focus);
  }

  bool _compared(int page) =>
      _visible.contains(page) || (_revealed[page] ?? 0) >= _wordCount(page);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({RecallRating? rating}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (rating != null) {
        await widget.onRecall!(rating);
      } else {
        await widget.onComplete!();
      }
      if (!mounted) return;
      if (widget.embedded) {
        await widget.onSaved?.call();
        if (mounted) setState(() => _saving = false);
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر الحفظ. أعد المحاولة أو ارجع لتحديث الجدول.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) {
      return Scaffold(
        appBar: _focus
            ? null
            : AppBar(
                automaticallyImplyLeading: !widget.embedded,
                actions: widget.actions,
                title: Text(widget.title),
              ),
        body: const Center(child: Text('لا توجد آيات في هذا الورد.')),
      );
    }
    final page = _pages[_index];
    final shown = _visible.contains(page);
    return PopScope(
      canPop: !_saving && !_focus,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving && _focus) _toggleFocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xfffaf9f6),
        body: SafeArea(
          child: Column(
            children: [
              ReaderControls(
                visible: !_focus,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          if (!widget.embedded) const BackButton(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                widget.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          ...widget.actions,
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'الورد · ${widget.ayahs.first.surah}:${widget.ayahs.first.number} – ${widget.ayahs.last.surah}:${widget.ayahs.last.number}',
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                          if (widget.status != null)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Tooltip(
                                message: 'اكتمل حفظ الورد',
                                child: Icon(
                                  Icons.check,
                                  color: Color(0xff28b835),
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _saving ? null : _toggleFocus,
                  child: PageView.builder(
                    allowImplicitScrolling: true,
                    controller: _controller,
                    reverse: false,
                    itemCount: _pages.length,
                    physics: _saving
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (_, index) => MushafPage(
                      quran: widget.quran,
                      page: _pages[index],
                      spokenGlyph: _spoken?.$1 == _pages[index]
                          ? _spoken?.$2
                          : null,
                      selectedAyahs: _assigned,
                      fitPortion: widget.fitPortion,
                      additionalPages: _additionalPages,
                      contextAyahs: _reciting
                          ? _context
                                .where((id) => id < widget.ayahs.first.id)
                                .toSet()
                          : _context,
                      fullContrastContext: widget.showNextAyah,
                      revealedWordCount: _revealed[_pages[index]] ?? 0,
                      hidden: !_visible.contains(_pages[index]),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
              ReaderControls(
                visible: !_focus,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!shown)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            textDirection: TextDirection.ltr,
                            children: [
                              IconButton(
                                tooltip: 'إظهار الآية التالية',
                                onPressed:
                                    _saving ||
                                        (_revealed[page] ?? 0) >=
                                            _wordCount(page)
                                    ? null
                                    : () => _stepAyah(page, true),
                                icon: const Icon(
                                  Icons.keyboard_double_arrow_left,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              IconButton(
                                tooltip: 'إظهار الكلمة التالية',
                                onPressed:
                                    _saving ||
                                        (_revealed[page] ?? 0) >=
                                            _wordCount(page)
                                    ? null
                                    : () => setState(
                                        () => _revealed[page] =
                                            (_revealed[page] ?? 0) + 1,
                                      ),
                                icon: const Icon(
                                  Icons.chevron_left,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              Text(
                                '${_revealed[page] ?? 0}/${_wordCounts[page]}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              IconButton(
                                tooltip: 'إخفاء الكلمة السابقة',
                                onPressed:
                                    _saving || (_revealed[page] ?? 0) == 0
                                    ? null
                                    : () => setState(
                                        () => _revealed[page] =
                                            (_revealed[page] ?? 0) - 1,
                                      ),
                                icon: const Icon(
                                  Icons.chevron_right,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              IconButton(
                                tooltip: 'إخفاء الآية السابقة',
                                onPressed:
                                    _saving || (_revealed[page] ?? 0) == 0
                                    ? null
                                    : () => _stepAyah(page, false),
                                icon: const Icon(
                                  Icons.keyboard_double_arrow_right,
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        textDirection: TextDirection.ltr,
                        children: [
                          Text(
                            _additionalPages.isEmpty
                                ? '$page'
                                : '$page–${_additionalPages.last}',
                          ),
                          IconButton(
                            tooltip: shown ? 'إخفاء الآيات' : 'إظهار الآيات',
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                    _voiceKey++;
                                    _reciting = false;
                                    _spoken = null;
                                    if (shown) {
                                      _visible.remove(page);
                                      _revealed[page] = 0;
                                    } else {
                                      _visible.add(page);
                                    }
                                  }),
                            icon: Icon(
                              shown
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          if (_index == _pages.length - 1 &&
                              widget.onComplete != null)
                            IconButton(
                              tooltip: _saving ? 'جارٍ الحفظ…' : 'تم حفظ الورد',
                              onPressed: _saving ? null : () => _save(),
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                          if (widget.onReview != null)
                            IconButton(
                              tooltip: 'مراجعة ورد اليوم',
                              onPressed: _saving ? null : widget.onReview,
                              icon: widget.dueReviews == null
                                  ? const Icon(Icons.history)
                                  : ValueListenableBuilder<int>(
                                      valueListenable: widget.dueReviews!,
                                      builder: (_, count, _) => Badge(
                                        isLabelVisible: count > 0,
                                        child: const Icon(Icons.history),
                                      ),
                                    ),
                            ),
                          const Spacer(),
                          RecitationButton(
                            key: ValueKey(_voiceKey),
                            onStart: () => setState(() {
                              _reciting = true;
                              _visible.remove(page);
                            }),
                            onSpoken: (p, glyph) => setState(() {
                              _spoken = (p, glyph);
                              if (glyph == null) _reciting = false;
                            }),
                            advancePage: _advanceRecitation,
                            quran: widget.quran,
                            page: page,
                            selected: _assigned,
                            additionalPages: _additionalPages,
                            onRecited: widget.onRecited,
                            revealed: _revealed[page] ?? 0,
                            onReveal: (p, n) =>
                                setState(() => _revealed[p] = n),
                          ),
                        ],
                      ),
                      if (_index == _pages.length - 1 &&
                          widget.onRecall != null)
                        !_pages.every(_compared)
                            ? const Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'أظهر كل صفحة للمقارنة قبل تقييم التذكر.',
                                ),
                              )
                            : Wrap(
                                spacing: 4,
                                children: [
                                  for (final rating in RecallRating.values)
                                    TextButton(
                                      onPressed: _saving
                                          ? null
                                          : () => _save(rating: rating),
                                      child: Text(recallLabel(rating)),
                                    ),
                                ],
                              ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
