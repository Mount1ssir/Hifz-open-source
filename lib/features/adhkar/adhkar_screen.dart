import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import '../../core/arabic.dart';
import '../../core/data/quran_repository.dart';
import 'adhkar_store.dart';
import '../surah_heading.dart';

const _dailyNames = {'morning': 'أذكار الصباح', 'evening': 'أذكار المساء'};

List<Dhikr> _catalog(QuranRepository quran, String group) => [
  for (final (surah, start, end) in [
    (112, 6222, 6225),
    (113, 6226, 6230),
    (114, 6231, 6236),
  ])
    (
      id: 'surah-$surah',
      text: quran.readRange(start, end).map((a) => a.text).join('\n'),
      source: 'سورة ${quran.surahs()[surah - 1].name} · سنن أبي داود 5082',
      target: 3,
    ),
  (
    id: 'dua-$group',
    text: group == 'morning'
        ? 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ'
        : 'اللَّهُمَّ بِكَ أَمْسَيْنَا وَبِكَ نَحْيَا وَبِكَ نَمُوتُ وَإِلَيْكَ النُّشُورُ',
    source: 'سنن أبي داود 5068',
    target: 1,
  ),
  (
    id: 'bismillah',
    text: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
    source: 'جامع الترمذي 3388',
    target: 3,
  ),
  (
    id: 'tasbih',
    text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
    source: 'صحيح مسلم 2692',
    target: 100,
  ),
];

class AdhkarScreen extends StatefulWidget {
  const AdhkarScreen({
    super.key,
    required this.quran,
    this.directory = getApplicationSupportDirectory,
  });
  final Future<Directory> Function() directory;
  final QuranRepository quran;
  @override
  State<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends State<AdhkarScreen>
    with WidgetsBindingObserver {
  late final catalogs = {
    for (final key in _dailyNames.keys) key: _catalog(widget.quran, key),
  };
  AdhkarStore? store;
  bool error = false;
  int tab = 0;
  Timer? midnight;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    open();
    schedule();
  }

  void schedule() {
    midnight?.cancel();
    final now = DateTime.now();
    midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        setState(() {});
        schedule();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      schedule();
    }
  }

  Future<void> open() async {
    Database? db;
    try {
      final dir = await widget.directory();
      if (!mounted) return;
      db = sqlite3.open(p.join(dir.path, 'adhkar.db'));
      final loaded = AdhkarStore(db);
      setState(() {
        store = loaded;
        error = false;
      });
    } catch (_) {
      db?.close();
      if (mounted) setState(() => error = true);
    }
  }

  @override
  void dispose() {
    midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    store?.db.close();
    super.dispose();
  }

  void write(void Function() action) {
    try {
      action();
      setState(() {});
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التغيير. حاول مجددًا.')),
      );
    }
  }

  Future<void> read(
    String key,
    String title,
    List<Dhikr> items, {
    String? personal,
    bool daily = false,
  }) async {
    try {
      final db = store!;
      while (mounted) {
        final session = key;
        db.start(session, items);
        final again = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => _Session(
              store: db,
              quran: widget.quran,
              session: session,
              title: title,
              canRestart: personal != null && !daily,
            ),
          ),
        );
        if (!mounted || again != true || personal == null) break;
        db.nextRound(personal);
        key = db.personalKey(personal);
      }
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الأذكار. حاول مجددًا.')),
        );
      }
    }
  }

  Future<void> edit([Dhikr? d]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _Editor(store: store!, initial: d),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> remove(Dhikr d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إزالة الذكر؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) write(() => store!.archive(d.id));
  }

  Widget personalTile(AdhkarStore db, Dhikr d, bool daily) {
    final progress = daily
        ? db.entries(db.personalKey(d.id)).firstOrNull
        : null;
    final count = progress?.count ?? 0, target = progress?.target ?? d.target;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            daily
                ? (count == target ? Icons.check : Icons.event_repeat)
                : Icons.bookmark_outline,
          ),
        ),
        title: Text(d.text, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          daily ? 'يومي · $count من $target' : 'شخصي · ${d.target} تكرار',
        ),
        onTap: () => read(
          db.personalKey(d.id),
          'ذكر شخصي',
          [d],
          personal: d.id,
          daily: daily,
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'إجراءات الذكر',
          onSelected: (v) => v == 'edit' ? edit(d) : remove(d),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('تعديل')),
            PopupMenuItem(value: 'remove', child: Text('إزالة')),
          ],
        ),
      ),
    );
  }

  void showHistory() {
    final days = store!.dailyHistory();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
          children: [
            Text(
              'سجل الأذكار اليومية',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final (index, day) in days.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  index == 0
                      ? 'اليوم'
                      : normalizeDigits(
                          MaterialLocalizations.of(ctx)
                              .formatMediumDate(day.date),
                        ),
                ),
                trailing: Text('${day.count} تكرار'),
              ),
          ],
        ),
      ),
    );
  }

  Widget content(AdhkarStore db) {
    final recurring = db.recurringIds;
    if (tab == 1) {
      final items = db.personal();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: edit,
              icon: const Icon(Icons.add),
              label: const Text('إضافة ذكر'),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty) const Text('لا توجد أذكار شخصية بعد.'),
          for (final d in items) personalTile(db, d, recurring.contains(d.id)),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final group in _dailyNames.entries)
          Builder(
            builder: (_) {
              final key = db.dailyKey(group.key);
              final catalog = catalogs[group.key]!;
              final entries = db.entries(key);
              final total = entries.isEmpty ? catalog.length : entries.length;
              final done = entries.where((e) => e.count == e.target).length;
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(
                    16,
                    10,
                    16,
                    10,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: group.key == "morning"
                        ? const Color(0xfff1e5cc)
                        : const Color(0xffdce5ed),
                    child: Icon(
                      group.key == 'morning'
                          ? Icons.wb_sunny_outlined
                          : Icons.nights_stay_outlined,
                    ),
                  ),
                  title: Text(group.value),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$done من $total أذكار مكتملة'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: done / total,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    done == total
                        ? Icons.check_circle_outline
                        : Icons.chevron_left,
                  ),
                  onTap: () =>
                      read(db.dailyKey(group.key), group.value, catalog),
                ),
              );
            },
          ),
        if (recurring.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 20, 8, 6),
            child: Text(
              'أذكاري اليومية',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final d in db.personal().where((d) => recurring.contains(d.id)))
            personalTile(db, d, true),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('الأذكار'),
      actions: [
        if (tab == 0 && store != null)
          IconButton(
            onPressed: showHistory,
            tooltip: 'سجل الأذكار اليومية',
            icon: const Icon(Icons.history_rounded),
          ),
      ],
    ),
    body: SafeArea(
      child: store != null
          ? content(store!)
          : Center(
              child: error
                  ? TextButton(
                      onPressed: () {
                        setState(() => error = false);
                        open();
                      },
                      child: const Text('إعادة المحاولة'),
                    )
                  : const CircularProgressIndicator(),
            ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.wb_twilight),
          label: 'الأذكار اليومية',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          label: 'أذكاري',
        ),
      ],
    ),
  );
}

class _Session extends StatefulWidget {
  const _Session({
    required this.store,
    required this.quran,
    required this.session,
    required this.title,
    required this.canRestart,
  });
  final AdhkarStore store;
  final QuranRepository quran;
  final String session, title;
  final bool canRestart;
  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> {
  late List<Entry> entries = widget.store.entries(widget.session);
  late int index = entries.indexWhere((e) => e.count < e.target) < 0
      ? entries.length - 1
      : entries.indexWhere((e) => e.count < e.target);
  late final surahNames = {
    for (final surah in widget.quran.surahs().skip(111))
      'surah-${surah.number}': surah.name,
  };
  late final basmalah = widget.quran
      .readRange(6222, 6222)
      .single
      .basmalahPrefix;
  void change({bool undo = false}) {
    try {
      widget.store.count(widget.session, entries[index], undo: undo);
      setState(() => entries = widget.store.entries(widget.session));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل التكرار. حاول مجددًا.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = entries[index];
    final complete = e.count == e.target;
    final surah = e.id.startsWith('surah-') ? surahNames[e.id] : null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final readingStyle = theme.textTheme.headlineSmall?.copyWith(height: 1.95);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('الذكر ${index + 1} من ${entries.length}'),
                  ),
                  IconButton(
                    tooltip: 'المصدر',
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('المصدر'),
                        content: Text(e.source),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('إغلاق'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  key: ValueKey(e.id),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    if (surah != null) ...[
                      SizedBox(
                        height: MediaQuery.textScalerOf(context).scale(42),
                        child: SurahHeading(
                          name: surah,
                          fontSize: MediaQuery.textScalerOf(context).scale(21),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (basmalah.isNotEmpty && e.text.startsWith(basmalah))
                        Text(
                          basmalah.trim(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.primary,
                            height: 1.6,
                          ),
                        ),
                      const SizedBox(height: 12),
                      _SurahVerses(
                        text: e.text.startsWith(basmalah)
                            ? e.text.substring(basmalah.length)
                            : e.text,
                        style: readingStyle,
                      ),
                    ] else
                      SelectableText(
                        e.text,
                        textAlign: TextAlign.center,
                        style: readingStyle,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (e.target == 3)
                      ExcludeSemantics(
                        child: Row(
                          children: [
                            for (var n = 1; n <= 3; n++)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: 4,
                                ),
                                child: Icon(
                                  n <= e.count
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  size: 18,
                                  color: n <= e.count
                                      ? colors.primary
                                      : colors.outlineVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: e.undo ? () => change(undo: true) : null,
                      icon: const Icon(Icons.undo),
                      label: const Text('تراجع'),
                    ),
                  ],
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(72),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                onPressed: !complete
                    ? () => change()
                    : index + 1 < entries.length
                    ? () => setState(() => index++)
                    : () => Navigator.pop(context),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: SizedBox.square(
                        dimension: 42,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: CircularProgressIndicator(
                                value: e.count / e.target,
                                strokeWidth: 3,
                                color: colors.onPrimary,
                                backgroundColor: colors.onPrimary.withValues(
                                  alpha: .23,
                                ),
                              ),
                            ),
                            Icon(
                              complete
                                  ? Icons.check_rounded
                                  : Icons.touch_app_outlined,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !complete
                                ? 'تسجيل تكرار'
                                : index + 1 < entries.length
                                ? 'التالي'
                                : entries.length == 1
                                ? 'تم الذكر'
                                : 'تمت المجموعة',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Semantics(
                            liveRegion: true,
                            child: Text('${e.count} من ${e.target}'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.canRestart && complete)
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('بدء جولة جديدة'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurahVerses extends StatelessWidget {
  const _SurahVerses({required this.text, required this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final verses = text.split('\n');
    final marker = Theme.of(context).textTheme.titleSmall
        ?.copyWith(color: Theme.of(context).colorScheme.primary);
    return SelectableText.rich(
      TextSpan(
        style: style,
        children: [
          for (final (i, verse) in verses.indexed) ...[
            TextSpan(text: verse),
            TextSpan(text: ' ﴿${i + 1}﴾ ', style: marker),
          ],
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    );
  }
}

class _Editor extends StatefulWidget {
  const _Editor({required this.store, this.initial});
  final AdhkarStore store;
  final Dhikr? initial;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late String text = widget.initial?.text ?? '';
  late String target = (widget.initial?.target ?? 1).toString();
  late final initialDaily =
      widget.initial != null &&
      widget.store.recurringIds.contains(widget.initial!.id);
  late bool daily = initialDaily;
  bool allowExit = false, confirming = false;
  bool get dirty =>
      daily != initialDaily ||
      text != (widget.initial?.text ?? '') ||
      target != (widget.initial?.target ?? 1).toString();
  void leave() {
    setState(() => allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> discard() async {
    if (confirming) return;
    confirming = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تجاهل التغييرات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة الكتابة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تجاهل'),
          ),
        ],
      ),
    );
    confirming = false;
    if (ok == true && mounted) leave();
  }

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(normalizeDigits(target.trim()));
    return PopScope(
      canPop: allowExit || !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) discard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.initial == null ? 'إضافة ذكر' : 'تعديل الذكر'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                initialValue: text,
                minLines: 3,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'نص الذكر'),
                onChanged: (v) => setState(() => text = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: target,
                decoration: const InputDecoration(labelText: 'عدد التكرارات'),
                keyboardType: TextInputType.number,
                onChanged: (v) => setState(() => target = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تكرار يومي'),
                subtitle: const Text('يبدأ العد من جديد كل يوم'),
                value: daily,
                onChanged: (v) => setState(() => daily = v),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed:
                    allowExit || text.trim().isEmpty || n == null || n < 1
                    ? null
                    : () {
                        try {
                          widget.store.save(
                            text,
                            n,
                            id: widget.initial?.id,
                            daily: daily,
                          );
                          leave();
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تعذر حفظ الذكر')),
                          );
                        }
                      },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
