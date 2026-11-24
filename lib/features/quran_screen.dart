import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import 'mushaf_page.dart';
import 'recitation_button.dart';
import 'verse_search.dart';
import 'tafsir_screen.dart';
import '../core/data/quran_repository.dart';
import 'reader_controls.dart';
import 'settings_screen.dart';
import '../core/arabic.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({
    super.key,
    required this.databases,
    this.onFocusChanged,
    this.initialPage,
    this.initialAyah,
  });
  final int? initialPage, initialAyah;
  final AppDatabases databases;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  PageController? _controller;
  final _swipeSnapshot = SnapshotController();
  int _page = 1;
  bool _hidden = false;
  (int, int?)? _spoken;
  final _revealed = <int, int>{};
  QuranAyah? _match;
  final _startOffsets = <int, int>{};
  int _selection = 0;

  void _selectStart(int page, int? ayah) {
    final offset = ayah == null
        ? 0
        : widget.databases.quran
              .pageLines(page)
              .expand((line) => line.words)
              .takeWhile((w) => w.ayahId < ayah)
              .length;
    _startOffsets[page] = offset;
    _revealed[page] = offset;
    _selection++;
  }

  Future<void> _search() async {
    final ayah = await Navigator.push<QuranAyah>(
      context,
      MaterialPageRoute(
        builder: (_) => VerseSearch(quran: widget.databases.quran),
      ),
    );
    if (ayah == null || !mounted) return;
    setState(() {
      _match = ayah;
      _selectStart(ayah.page, ayah.id);
    });
    _controller?.jumpToPage(ayah.page - 1);
  }

  Set<int> _bookmarks = {};
  String? _error;
  bool _bookmarkSaving = false;
  bool _focus = false;
  void _toggleFocus() {
    setState(() => _focus = !_focus);
    widget.onFocusChanged?.call(_focus);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page =
          widget.initialPage ?? await widget.databases.user.readingPage();
      final bookmarks = await widget.databases.user.bookmarks();
      if (!mounted) return;
      setState(() {
        _page = page;
        _selectStart(page, widget.initialAyah);
        final id = widget.initialAyah;
        if (id != null) {
          _match = widget.databases.quran.readRange(id, id).single;
        }
        _bookmarks = bookmarks;
        _controller = PageController(initialPage: page - 1);
        _error = null;
      });
      _preload(page);
      if (widget.initialPage != null) {
        await widget.databases.user.saveReadingPage(page);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر استعادة موضع القراءة.');
      }
    }
  }

  void _preload(int page) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final next in [page - 1, page + 1]) {
        MushafPage.preload(
          widget.databases.quran,
          next,
        ).catchError((Object _) {});
      }
    });
  }

  @override
  void dispose() {
    _swipeSnapshot.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _bookmark() async {
    final page = _page;
    final enabled = !_bookmarks.contains(page);
    setState(() => _bookmarkSaving = true);
    try {
      await widget.databases.user.setBookmark(page, enabled);
      if (mounted) {
        setState(() {
          if (enabled) {
            _bookmarks.add(page);
          } else {
            _bookmarks.remove(page);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر حفظ العلامة.')));
      }
    } finally {
      if (mounted) setState(() => _bookmarkSaving = false);
    }
  }

  Future<void> _navigate() async {
    int? firstAyah;
    final page = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      clipBehavior: Clip.antiAlias,
      builder: (_) => FractionallySizedBox(
        heightFactor: .9,
        child: _QuranIndex(
          databases: widget.databases,
          bookmarks: _bookmarks,
          currentSurah: widget.databases.quran
              .pageLabel(_page)
              .split(' · ')
              .first,
          onSurah: (id) => firstAyah = id,
        ),
      ),
    );
    if (page != null && mounted) {
      setState(() => _selectStart(page, firstAyah));
      _controller?.jumpToPage(page - 1);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_focus,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _focus) _toggleFocus();
    },
    child: Scaffold(
      backgroundColor: const Color(0xfffaf9f6),
      body: SafeArea(
        child: Column(
          children: [
            ReaderControls(
              reserveSpace: true,
              visible: !_focus,
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'الإعدادات',
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SettingsScreen(databases: widget.databases),
                        ),
                      ),
                      icon: const Icon(Icons.menu),
                    ),
                    Expanded(
                      child: Material(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _controller == null ? null : _navigate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.databases.quran
                                            .pageLabel(_page)
                                            .split(' · ')
                                            .first,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    const Icon(Icons.expand_more, size: 16),
                                  ],
                                ),
                                Text(
                                  'صفحة $_page · ${widget.databases.quran.pageLabel(_page).split(' · ').last}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تفسير الصفحة',
                      icon: const Icon(Icons.library_books_outlined),
                      onPressed: _controller == null
                          ? null
                          : () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TafsirScreen(
                                  quran: widget.databases.quran,
                                  page: _page,
                                  initialAyah: _match?.id,
                                ),
                              ),
                            ),
                    ),
                    IconButton(
                      tooltip: 'بحث في الآيات',
                      onPressed: _controller == null ? null : _search,
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: _bookmarks.contains(_page)
                          ? 'إزالة العلامة'
                          : 'حفظ علامة',
                      onPressed: _bookmarkSaving || _controller == null
                          ? null
                          : _bookmark,
                      icon: Icon(
                        _bookmarks.contains(_page)
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _controller == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _load,
                              child: Text('$_error إعادة المحاولة'),
                            ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (notice) {
                        if (notice.depth == 0 &&
                            notice is ScrollStartNotification) {
                          _swipeSnapshot.allowSnapshotting = true;
                        }
                        if (notice.depth == 0 &&
                            notice is ScrollEndNotification) {
                          _swipeSnapshot.allowSnapshotting = false;
                        }
                        return false;
                      },
                      child: PageView.builder(
                        allowImplicitScrolling: true,
                        controller: _controller,
                        reverse: false,
                        itemCount: 604,
                        onPageChanged: (index) async {
                          setState(() {
                            _page = index + 1;
                            if (_match?.page != _page) _match = null;
                          });
                          _preload(index + 1);
                          try {
                            await widget.databases.user.saveReadingPage(
                              index + 1,
                            );
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تعذر حفظ موضع القراءة.'),
                                ),
                              );
                            }
                          }
                        },
                        itemBuilder: (_, index) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleFocus,
                          child: MushafPage(
                            quran: widget.databases.quran,
                            page: index + 1,
                            swipeSnapshot: _swipeSnapshot,
                            highlightedAyah: _match?.page == index + 1
                                ? _match?.id
                                : null,
                            hidden: _hidden,
                            spokenGlyph: _spoken?.$1 == index + 1
                                ? _spoken?.$2
                                : null,
                            revealFrom: _startOffsets[index + 1] ?? 0,
                            revealedWordCount: _revealed[index + 1] ?? 0,
                          ),
                        ),
                      ),
                    ),
            ),
            ReaderControls(
              reserveSpace: true,
              visible: !_focus,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  height: 48,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      SizedBox(
                        width: 30,
                        child: _page.isEven ? Text('$_page') : null,
                      ),
                      IconButton(
                        tooltip: _hidden ? 'إظهار الآيات' : 'إخفاء الآيات',
                        onPressed: () => setState(() {
                          _hidden = !_hidden;
                          _selection++;
                          _spoken = null;
                          if (_hidden) {
                            _revealed
                              ..clear()
                              ..addAll(_startOffsets);
                          }
                        }),
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                      const Spacer(),
                      if (_page.isOdd)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text('$_page'),
                        ),
                      if (_controller != null)
                        RecitationButton(
                          onStart: () => setState(() {
                            _hidden = true;
                            _match = null;
                          }),
                          onSpoken: (page, glyph) =>
                              setState(() => _spoken = (page, glyph)),
                          onRecited: widget.databases.creditRecitation,
                          key: ValueKey(_selection),
                          quran: widget.databases.quran,
                          page: _page,
                          restartOffset: _startOffsets[_page] ?? 0,
                          revealed: _revealed[_page] ?? 0,
                          onReveal: (page, n) =>
                              setState(() => _revealed[page] = n),
                          advancePage: (page) {
                            if (page >= 604) return null;
                            final next = page + 1;
                            _revealed[next] = 0;
                            _startOffsets.remove(next);
                            _controller!.jumpToPage(next - 1);
                            return next;
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuranIndex extends StatelessWidget {
  const _QuranIndex({
    required this.databases,
    required this.bookmarks,
    required this.currentSurah,
    required this.onSurah,
  });
  final ValueChanged<int> onSurah;
  final AppDatabases databases;
  final Set<int> bookmarks;
  final String currentSurah;

  @override
  Widget build(BuildContext context) {
    final surahs = databases.quran.surahs();
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تصفح القرآن'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'السور'),
              Tab(text: 'الجزء'),
              Tab(text: 'العلامات'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: const _PageJumpField(),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView.separated(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 64),
                    itemCount: surahs.length,
                    itemBuilder: (context, index) {
                      final surah = surahs[index];
                      final current = surah.name == currentSurah;
                      return ListTile(
                        selected: current,
                        selectedTileColor: colors.primaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          width: 40,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: current
                                ? colors.primary
                                : colors.surfaceContainerHigh,
                            borderRadius: const BorderRadiusDirectional.only(
                              topStart: Radius.circular(6),
                              topEnd: Radius.circular(14),
                              bottomStart: Radius.circular(6),
                              bottomEnd: Radius.circular(6),
                            ),
                          ),
                          child: Text(
                            '${surah.number}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: current
                                      ? colors.onPrimary
                                      : colors.onSurfaceVariant,
                                ),
                          ),
                        ),
                        trailing: Icon(
                          current
                              ? Icons.menu_book_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: current ? 20 : 14,
                        ),
                        title: Text(
                          surah.name,
                          textDirection: TextDirection.rtl,
                        ),
                        subtitle: Text(
                          '${surah.ayahCount} آية · الصفحة ${surah.page}',
                        ),
                        onTap: () {
                          onSurah(
                            1 +
                                surahs
                                    .take(index)
                                    .fold<int>(0, (n, s) => n + s.ayahCount),
                          );
                          Navigator.pop(context, surah.page);
                        },
                      );
                    },
                  ),
                  ListView.builder(
                    itemCount: 30,
                    itemBuilder: (context, index) => ListTile(
                      title: Text('الجزء ${index + 1}'),
                      trailing: Text(
                        'الصفحة ${databases.quran.pageForJuz(index + 1)}',
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        databases.quran.pageForJuz(index + 1),
                      ),
                    ),
                  ),
                  bookmarks.isEmpty
                      ? const Center(
                          child: Text('احفظ علامة على صفحة لتجدها هنا.'),
                        )
                      : ListView(
                          children: [
                            for (final page in bookmarks.toList()..sort())
                              ListTile(
                                leading: const Icon(Icons.bookmark),
                                title: Text('الصفحة $page'),
                                subtitle: Text(databases.quran.pageLabel(page)),
                                onTap: () => Navigator.pop(context, page),
                              ),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageJumpField extends StatefulWidget {
  const _PageJumpField();

  @override
  State<_PageJumpField> createState() => _PageJumpFieldState();
}

class _PageJumpFieldState extends State<_PageJumpField> {
  final input = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  int? pageNumber(String text) {
    final page = int.tryParse(normalizeDigits(text.trim()));
    return page != null && page >= 1 && page <= 604 ? page : null;
  }

  void jump(String text) {
    final page = pageNumber(text);
    if (page != null) Navigator.pop(context, page);
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: input,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.go,
    decoration: InputDecoration(
      labelText: 'رقم الصفحة · 1–604',
      prefixIcon: const Icon(Icons.find_in_page_outlined),
      suffixIcon: ValueListenableBuilder<TextEditingValue>(
        valueListenable: input,
        builder: (_, value, _) => IconButton(
          tooltip: 'انتقل إلى الصفحة',
          onPressed: pageNumber(value.text) == null
              ? null
              : () => jump(value.text),
          icon: const Icon(Icons.arrow_forward),
        ),
      ),
    ),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (value) =>
        value != null && value.isNotEmpty && pageNumber(value) == null
        ? 'أدخل صفحة بين 1 و604'
        : null,
    onFieldSubmitted: jump,
  );
}
