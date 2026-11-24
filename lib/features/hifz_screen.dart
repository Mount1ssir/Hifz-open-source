import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import '../core/data/quran_repository.dart';
import '../domain/hifz_planner.dart';
import '../domain/range_set.dart';
import '../domain/riwayah.dart';
import 'quran_reader.dart';
import 'baseline_screen.dart';
import 'reviews_screen.dart';

class HifzScreen extends StatefulWidget {
  const HifzScreen({
    super.key,
    required this.databases,
    this.onFocusChanged,
    this.practice = false,
  });
  final AppDatabases databases;
  final bool practice;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends State<HifzScreen> with WidgetsBindingObserver {
  List<QuranAyah> _ayahs = [];
  int _quota = 5;
  QuotaUnit _unit = QuotaUnit.ayahs;
  int _memorized = 0;
  int _remainingSessions = 0;
  bool _loading = true;
  bool _setupPending = false;
  bool _saving = false;
  bool _completed = false;
  Set<int> _known = {};
  List<PlannedPortion> _plan = [];
  String? _error;
  Timer? _midnight;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
    _load();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleMidnight();
      if (!_saving) _load();
    }
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(midnight.difference(now), () {
      _scheduleMidnight();
      _load();
    });
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    try {
      await widget.databases.reminders.sync();
      final setupPending =
          !widget.practice && await widget.databases.user.needsHifzSetup();
      final quota = await widget.databases.user.dailyQuota();
      final unit = await widget.databases.user.dailyQuotaUnit();
      final progress = await widget.databases.user.progress(Riwayah.hafs);
      final now = DateTime.now();
      final today = await widget.databases.user.completedToday(
        Riwayah.hafs,
        now,
      );
      final known = {
        ...await widget.databases.user.memorizedBaseline(Riwayah.hafs),
        ...progress.map((entry) => entry.ayahId),
      };
      final baseline = RangeSet(known.map((id) => AyahRange(id, id)));
      final plan = HifzPlanner().plan(
        riwayah: Riwayah.hafs,
        memorized: baseline,
        quota: _dailyQuota(quota, unit),
      );
      final ids = today.isNotEmpty
          ? today
          : plan.isEmpty
          ? <int>[]
          : plan.first.ayahs.ids.toList();
      final ayahs = [
        for (final id in ids) widget.databases.quran.readRange(id, id).single,
      ];
      if (!mounted || version != _loadVersion) return;
      if (_ayahs.isNotEmpty && _ayahs.first.id != ayahs.firstOrNull?.id) {
        widget.onFocusChanged?.call(false);
      }
      setState(() {
        _setupPending = setupPending;
        _quota = quota;
        _unit = unit;
        _memorized = baseline.length;
        _remainingSessions = plan.length;
        _known = known;
        _plan = plan;
        _completed = today.isNotEmpty;
        _ayahs = ayahs;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted && version == _loadVersion) {
        setState(() {
          _loading = false;
          _error = 'تعذر تحميل محفوظك. أعد المحاولة.';
        });
      }
    }
  }

  Future<void> _settings() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('إعدادات الحفظ')),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('مقدار الحفظ اليومي'),
                subtitle: Text('$_quota ${_unitLabel(_unit)} يوميًا'),
                onTap: () => Navigator.pop(context, 0),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('محفوظي السابق'),
                subtitle: Text('$_memorized آية محفوظة'),
                onTap: () => Navigator.pop(context, 1),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('خطة الحفظ كاملة'),
                subtitle: Text('$_remainingSessions وردًا متبقيًا'),
                onTap: () => Navigator.pop(context, 2),
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('جدول المراجعة'),
                onTap: () => Navigator.pop(context, 3),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 0:
        await _editQuota();
      case 1:
        await _editBaseline();
      case 2:
        await _syllabus();
      case 3:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ReviewsScreen(databases: widget.databases),
          ),
        );
    }
  }

  Future<void> _editBaseline() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BaselineScreen(databases: widget.databases),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _syllabus() async {
    final all = widget.databases.quran.readRange(1, Riwayah.hafs.totalAyahs);
    final surahs = widget.databases.quran.surahs();
    final portionNumbers = <int, int>{
      for (var i = 0; i < _plan.length; i++)
        for (final id in _plan[i].ayahs.ids) id: i + 1,
    };
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(title: const Text('خطة الحفظ كاملة')),
            body: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('✓ محفوظ'),
                ),
                for (final surah in surahs)
                  Builder(
                    builder: (context) {
                      final ayahs = all
                          .where((a) => a.surah == surah.number)
                          .toList();
                      final count = ayahs
                          .where((a) => _known.contains(a.id))
                          .length;
                      final groups = <List<QuranAyah>>[];
                      for (final ayah in ayahs) {
                        if (groups.isEmpty ||
                            _known.contains(groups.last.last.id) !=
                                _known.contains(ayah.id) ||
                            portionNumbers[groups.last.last.id] !=
                                portionNumbers[ayah.id]) {
                          groups.add([]);
                        }
                        groups.last.add(ayah);
                      }
                      return ExpansionTile(
                        title: Text(
                          surah.name,
                          style: TextStyle(
                            color: count == ayahs.length
                                ? Colors.green.shade800
                                : null,
                          ),
                        ),
                        subtitle: Text('$count من ${ayahs.length} آية محفوظة'),
                        leading: count == ayahs.length
                            ? Icon(
                                Icons.check_circle,
                                color: Colors.green.shade800,
                              )
                            : Text('${surah.number}'),
                        children: [
                          for (final group in groups)
                            ListTile(
                              title: Text(
                                'الآيات ${group.first.number} – ${group.last.number}',
                                style: TextStyle(
                                  color: _known.contains(group.first.id)
                                      ? Colors.green.shade800
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                _known.contains(group.first.id)
                                    ? 'محفوظ'
                                    : 'الورد ${portionNumbers[group.first.id]} · لم يُحفظ بعد',
                              ),
                              leading: _known.contains(group.first.id)
                                  ? Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade800,
                                    )
                                  : const Icon(Icons.menu_book_outlined),
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuranReader(
                                    onRecited:
                                        widget.databases.creditRecitation,
                                    quran: widget.databases.quran,
                                    ayahs: group,
                                    showPreviousAyah: true,
                                    fitPortion: true,
                                    showNextAyah: true,
                                    title:
                                        '${surah.name} · ${group.first.number}–${group.last.number}',
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _unitLabel(QuotaUnit unit) => switch (unit) {
    QuotaUnit.ayahs => 'آيات',
    QuotaUnit.lines => 'أسطر',
    QuotaUnit.pages => 'صفحات',
    QuotaUnit.halfPages => 'نصف صفحة',
  };

  late final Map<int, int> _lineWeights = widget.databases.quran.lineWeights();

  DailyQuota _dailyQuota(int amount, QuotaUnit unit) => switch (unit) {
    QuotaUnit.ayahs => DailyQuota.ayahs(amount),
    QuotaUnit.lines => DailyQuota.lines(amount, _lineWeights),
    QuotaUnit.halfPages => DailyQuota.printedHalfPages(
      amount,
      widget.databases.quran.printedPageWeights,
    ),
    QuotaUnit.pages => DailyQuota.printedHalfPages(
      amount * 2,
      widget.databases.quran.printedPageWeights,
    ),
  };

  (int, QuotaUnit)? _parseQuota(String input, QuotaUnit unit) {
    var normalized = input.trim().replaceAll('٫', '.');
    for (var i = 0; i < 10; i++) {
      normalized = normalized.replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
    }
    var amount = double.tryParse(normalized) ?? 0;
    if (unit == QuotaUnit.pages && amount % 1 != 0) {
      unit = QuotaUnit.halfPages;
      amount *= 2;
    }
    if (!amount.isFinite || amount < 1 || amount > 100 || amount % 1 != 0) {
      return null;
    }
    return (amount.toInt(), unit);
  }

  String _quotaPreview(String input, QuotaUnit unit) {
    final quota = _parseQuota(input, unit);
    if (quota == null) return 'أدخل مقدارًا صحيحًا لعرض موعد الإتمام المتوقع.';
    final plan = HifzPlanner().plan(
      riwayah: Riwayah.hafs,
      memorized: RangeSet(_known.map((id) => AyahRange(id, id))),
      quota: _dailyQuota(quota.$1, quota.$2),
    );
    if (plan.isEmpty) return 'أتممت حفظ القرآن الكريم.';
    final now = DateTime.now();
    final finish = DateTime(
      now.year,
      now.month,
      now.day + plan.length - (_completed ? 0 : 1),
    );
    return '${plan.length} وردًا متبقيًا · الإتمام المتوقع: ${finish.year}/${finish.month}/${finish.day}\nتقدير بافتراض ورد واحد كل يوم دون أيام راحة.';
  }

  Future<void> _editQuota() async {
    var input = '$_quota';
    var selectedUnit = _unit;
    String? validation;
    final result = await showDialog<(int, QuotaUnit)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('مقدار الحفظ اليومي'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<QuotaUnit>(
                  value: selectedUnit,
                  isExpanded: true,
                  items: [
                    for (final unit in QuotaUnit.values)
                      DropdownMenuItem(
                        value: unit,
                        child: Text(_unitLabel(unit)),
                      ),
                  ],
                  onChanged: (unit) => update(() => selectedUnit = unit!),
                ),
                TextFormField(
                  initialValue: input,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'المقدار',
                    errorText: validation,
                  ),
                  onChanged: (value) => update(() {
                    input = value;
                    validation = null;
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  _quotaPreview(input, selectedUnit),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 12),
                const Text(
                  'ينتهي الورد عند نهاية الآية.',
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = _parseQuota(input, selectedUnit);
                if (parsed == null) {
                  update(
                    () => validation = 'أدخل عددًا صحيحًا من 1 إلى 100؛ الصفحات تقبل أنصافًا أيضًا.',
                  );
                  return;
                }
                Navigator.pop(context, parsed);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.databases.user.setDailyQuota(result.$1, unit: result.$2);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر حفظ مقدار الورد.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openHistory() async {
    final route = Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => HifzScreen(databases: widget.databases, practice: true),
      ),
    );
    final reminders = widget.databases.reminders;
    try {
      await reminders.acknowledgeHistory();
    } catch (_) {
      // The current visit still acknowledges the dot in memory.
    }
    await route;
  }

  Future<void> _startPlan() async {
    setState(() => _saving = true);
    try {
      await widget.databases.user.finishHifzSetup();
      if (mounted) setState(() => _setupPending = false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر بدء الخطة. حاول مجددًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_setupPending && !_loading && _error == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('إعداد خطة الحفظ')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('محفوظي السابق'),
                subtitle: Text('$_memorized آية'),
                onTap: _saving ? null : _editBaseline,
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('مقدار الحفظ اليومي'),
                subtitle: Text('$_quota ${_unitLabel(_unit)}'),
                onTap: _saving ? null : _editQuota,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _startPlan,
                child: const Text('بدء الخطة'),
              ),
            ],
          ),
        ),
      );
    }
    final actions = [
      IconButton(
        tooltip: widget.practice ? 'جدول التثبيت' : 'إعدادات الحفظ',
        icon: const Icon(Icons.settings_outlined),
        onPressed: _loading || _saving
            ? null
            : widget.practice
            ? () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewsScreen(databases: widget.databases),
                ),
              )
            : _settings,
      ),
    ];
    if (!_loading && _error == null && _ayahs.isNotEmpty) {
      return QuranReader(
        onRecited: widget.databases.creditRecitation,
        showPreviousAyah: true,
        fitPortion: true,
        showNextAyah: !widget.practice && _plan.length > (_completed ? 0 : 1),
        nextLink: _plan.length > (_completed ? 0 : 1)
            ? _plan[_completed ? 0 : 1].ayahs.ids.first
            : null,
        startHidden: widget.practice,
        key: ValueKey((
          _ayahs.map((a) => a.id).join(','),
          _plan.elementAtOrNull(_completed ? 0 : 1)?.ayahs.ids.first,
        )),
        quran: widget.databases.quran,
        ayahs: _ayahs,
        title: 'ورد اليوم',
        embedded: true,
        dueReviews: widget.databases.reminders.dueCount,
        actions: actions,
        onFocusChanged: widget.onFocusChanged,
        status: _completed && !widget.practice ? 'تم حفظ ورد اليوم ✓' : null,
        onReview: widget.practice ? null : _openHistory,
        onComplete: widget.practice || _completed
            ? null
            : () => widget.databases.user.completePortion(
                Riwayah.hafs,
                _ayahs.map((a) => a.id),
                DateTime.now(),
              ),
        onSaved: _load,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('الحفظ'), actions: actions),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : _error != null
            ? TextButton(
                onPressed: _load,
                child: Text('$_error إعادة المحاولة'),
              )
            : const Text(
                'أتممت حفظ القرآن الكريم',
                textDirection: TextDirection.rtl,
              ),
      ),
    );
  }
}
