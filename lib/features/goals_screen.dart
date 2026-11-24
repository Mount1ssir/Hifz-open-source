import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'passage_picker.dart';
import '../core/arabic.dart';
import '../core/data/app_databases.dart';
import '../domain/reading_goal.dart';
import '../domain/hifz_planner.dart';
import '../domain/revision_partitioner.dart';
import '../domain/quarter_boundaries.dart';
import '../domain/riwayah.dart';
import '../core/data/quran_repository.dart';

String _pageAmount(QuranRepository quran, List<int> ids) {
  final weight = ids.fold(0, (sum, id) => sum + quran.printedPageWeights[id]!);
  final amount = weight / DailyQuota.pageScale;
  if (amount > 0 && amount < 0.01) return 'أقل من 0.01 صفحة';
  return '${double.parse(amount.toStringAsFixed(2)) == amount.round() ? amount.round() : amount.toStringAsFixed(2)} صفحة';
}

Future<void> _showPlan(
  BuildContext context,
  ReadingGoal goal,
  QuranRepository quran,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (sheet) => Column(
    children: [
      Text('جدول المراجعة', style: Theme.of(sheet).textTheme.titleLarge),
      Expanded(
        child: ListView.builder(
          itemCount: goal.durationDays,
          itemBuilder: (_, index) {
            final ids = goal.plannedAyahs(index + 1);
            final ranges = quran.readRangesBySurah(ids, pages: false);
            return ListTile(
              title: Text(
                ids.isEmpty
                    ? 'اليوم ${index + 1}'
                    : 'اليوم ${index + 1} · ${_pageAmount(quran, ids)}',
              ),
              subtitle: Text(ranges.isEmpty ? 'راحة' : ranges.join('\n')),
            );
          },
        ),
      ),
    ],
  ),
);

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    required this.databases,
    required this.onOpenAyah,
  });
  final AppDatabases databases;
  final ValueChanged<QuranAyah> onOpenAyah;
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with WidgetsBindingObserver {
  late Future<List<ReadingGoal>> goals = widget.databases.user.readingGoals();
  Timer? timer;
  int today = ReadingGoal.day(DateTime.now());
  @override
  void initState() {
    super.initState();
    widget.databases.goalProgress.addListener(reload);
    WidgetsBinding.instance.addObserver(this);
    _midnight();
  }

  void _midnight() {
    timer?.cancel();
    final now = DateTime.now();
    final day = ReadingGoal.day(now);
    if (today != day) {
      today = day;
      reload();
    }
    timer = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      _midnight,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _midnight();
  }

  @override
  void dispose() {
    widget.databases.goalProgress.removeListener(reload);
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  void reload() => setState(() => goals = widget.databases.user.readingGoals());
  Future<void> create() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _NewGoal(db: widget.databases)),
    );
    if (mounted && saved == true) reload();
  }

  Future<void> record(ReadingGoal goal) async {
    final quran = widget.databases.quran;
    final ids = goal.anchors.toSet();
    final verses = quran
        .readRange(1, 6236)
        .where((a) => ids.contains(a.id))
        .toList();
    final unread = goal.unread.toList();
    var first = unread.first, last = first;
    final names = quran.surahs();
    final labels = {
      for (final a in verses)
        a.id: goal.pages
            ? 'صفحة ${a.page}'
            : '${names[a.surah - 1].name} · ${a.number}',
    };
    final range = await showModalBottomSheet<(int, int)>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (_, update) {
          final count = unread.where((id) => id >= first && id <= last).length;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'تسجيل القراءة · ${goal.name}',
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                  for (final start in [true, false])
                    ListTile(
                      title: Text(
                        goal.pages
                            ? (start ? 'صفحة البداية' : 'صفحة النهاية')
                            : (start ? 'آية البداية' : 'آية النهاية'),
                      ),
                      trailing: ActionChip(
                        label: Text(labels[start ? first : last]!),
                        onPressed: () async {
                          final chosen = await pickVerse(
                            sheet,
                            quran,
                            start
                                ? verses
                                : verses.where((a) => a.id >= first).toList(),
                            start ? first : last,
                          );
                          if (chosen != null && sheet.mounted) {
                            update(() {
                              if (start) {
                                first = chosen;
                                if (last < first) last = first;
                              } else {
                                last = chosen;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  Text(
                    count == 0 ? 'مسجل سابقًا' : 'سيُضاف $count ${goal.unit}',
                  ),
                  FilledButton(
                    onPressed: count == 0
                        ? null
                        : () => Navigator.pop(sheet, (first, last)),
                    child: const Text('تأكيد الجلسة'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (range == null) return;
    try {
      await widget.databases.user.logGoalRange(goal, range.$1, range.$2);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر التسجيل. تحقق من مقدار التقدم ثم أعد المحاولة.',
            ),
          ),
        );
      }
    }
    if (mounted) reload();
  }

  Future<void> _delete(ReadingGoal goal) async {
    try {
      await widget.databases.user.deleteReadingGoal(goal.id);
      if (mounted) reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حذف الهدف. حاول مجددًا.')),
        );
      }
    }
  }

  Future<void> edit(ReadingGoal goal) async {
    var name = goal.name, days = goal.durationDays, repeat = goal.repeat;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (_, update) => AlertDialog(
          title: const Text('تعديل الهدف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'اسم الهدف'),
                  onChanged: (v) => update(() => name = v),
                ),
                if (goal.durationDays > 0) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: days.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'مدة الهدف بالأيام',
                    ),
                    onChanged: (v) => update(
                      () => days = int.tryParse(normalizeDigits(v.trim())) ?? 0,
                    ),
                  ),
                  CheckboxListTile(
                    title: const Text('تكرار الهدف بعد إتمامه'),
                    value: repeat,
                    onChanged: (v) => update(() => repeat = v ?? false),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed:
                  name.trim().isEmpty ||
                      goal.durationDays > 0 && (days < 1 || days > 0x7fffffff)
                  ? null
                  : () => Navigator.pop(dialog, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;
    try {
      var assigned = goal.assignedDays;
      if (!goal.pages && days != goal.durationDays) {
        final weights = widget.databases.quran.printedPageWeights;
        assigned = RevisionPartitioner().assignedDays([
          for (final id in goal.anchors) weights[id]!,
        ], days);
      }
      await widget.databases.user.editReadingGoal(
        goal.id,
        name,
        days,
        repeat,
        assigned,
      );
      if (mounted) reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر حفظ الهدف')));
      }
    }
  }

  Widget card(ReadingGoal g) {
    final session = g.sessionAyahs(today);
    final first = session.firstOrNull;
    final next = first == null
        ? null
        : widget.databases.quran.readRange(first, first).single;
    return _SwipeGoal(
      key: ValueKey(g.id),
      onDelete: () => _delete(g),
      onEdit: () => edit(g),
      onComplete: g.due(today) == 0
          ? null
          : () async {
              try {
                await widget.databases.user.completeGoalDay(g, today);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذر تسجيل ورد اليوم.')),
                  );
                }
              }
              if (mounted) reload();
            },
      builder: (actions) => Card(
        child: ExpansionTile(
          key: PageStorageKey(g.id),
          title: Row(
            children: [
              Expanded(child: Text(g.name)),
              actions,
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${g.read} / ${g.anchors.length} ${g.unit} ${g.flexible ? '' : '· المطلوب اليوم ${g.due(today)}'}',
              ),
              LinearProgressIndicator(value: g.read / g.anchors.length),
            ],
          ),
          children: [
            ListTile(
              title: Text(
                g.durationDays > 0
                    ? 'خطة من ${g.durationDays} يوم · الجلسة ${(today - g.startDay + 1).clamp(0, g.durationDays)}/${g.durationDays}${g.repeat ? ' · تتكرر' : ''}'
                    : g.flexible
                    ? 'تقدم القراءة'
                    : '${g.quota} ${g.unit} كل ${g.interval} يوم',
              ),
              subtitle: next == null
                  ? null
                  : g.assignedDays != null
                  ? Text(
                      widget.databases.quran
                          .readRangesBySurah(session, pages: false)
                          .join('\n'),
                    )
                  : Text(
                      'التالي: ${widget.databases.quran.surahs()[next.surah - 1].name}، الآية ${next.number} · صفحة ${next.page}',
                    ),
            ),
            if (g.durationDays > 0 && !g.pages)
              TextButton.icon(
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('جدول المراجعة'),
                onPressed: () => _showPlan(context, g, widget.databases.quran),
              ),
            if (g.remaining > 0 && today >= g.startDay)
              Wrap(
                spacing: 10,
                children: [
                  if (next != null)
                    OutlinedButton(
                      onPressed: () => widget.onOpenAyah(next),
                      child: const Text('بدء الجلسة'),
                    ),
                  FilledButton(
                    onPressed: () => record(g),
                    child: const Text('تسجيل ما قرأت'),
                  ),
                ],
              ),
            for (final summary in widget.databases.quran.readRangesBySurah(
              g.recorded ?? g.anchors.take(g.read),
              pages: g.pages,
            ))
              ListTile(
                dense: true,
                leading: const Icon(Icons.check),
                title: Text(summary),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('أهداف التثبيت'),
      actions: [
        TextButton.icon(
          onPressed: create,
          icon: const Icon(Icons.add),
          label: const Text('هدف جديد'),
        ),
      ],
    ),
    body: FutureBuilder(
      future: goals,
      builder: (_, state) {
        if (state.hasError) {
          return Center(
            child: TextButton(
              onPressed: reload,
              child: const Text('إعادة المحاولة'),
            ),
          );
        }
        if (!state.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.data!.isEmpty) {
          return Center(
            child: FilledButton.icon(
              onPressed: create,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('إنشاء أول هدف'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final group in [
              (
                'أهداف مفتوحة',
                state.data!.where((g) => g.flexible && g.remaining > 0),
              ),
              ('أهداف اليوم', state.data!.where((g) => g.due(today) > 0)),
              (
                'القادمة',
                state.data!.where(
                  (g) => !g.flexible && g.remaining > 0 && g.due(today) == 0,
                ),
              ),
              ('المكتملة', state.data!.where((g) => g.remaining == 0)),
            ])
              if (group.$2.isNotEmpty) ...[
                ListTile(title: Text(group.$1)),
                ...group.$2.map(card),
              ],
          ],
        );
      },
    ),
  );
}

class _SwipeGoal extends StatefulWidget {
  const _SwipeGoal({
    super.key,
    required this.builder,
    required this.onDelete,
    required this.onEdit,
    required this.onComplete,
  });
  final Widget Function(Widget actions) builder;
  final Future<void> Function() onDelete, onEdit;
  final Future<void> Function()? onComplete;
  @override
  State<_SwipeGoal> createState() => _SwipeGoalState();
}

class _SwipeGoalState extends State<_SwipeGoal> {
  double get width => widget.onComplete == null ? 72 : 144;
  double offset = 0;
  bool dragging = false;
  bool deleting = false;

  Future<void> perform(Future<void> Function() action) async {
    if (deleting) return;
    setState(() => deleting = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          deleting = false;
          offset = 0;
        });
      }
    }
  }

  void settle(double velocity) => setState(() {
    dragging = false;
    offset = (velocity.abs() > 350 ? velocity > 0 : offset > width / 2)
        ? width
        : 0;
  });

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [
        if (offset > 0)
          Positioned(
            left: 4,
            top: 4,
            bottom: 4,
            width: width,
            child: Row(
              textDirection: TextDirection.ltr,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final complete in [
                  false,
                  if (widget.onComplete != null) true,
                ])
                  Expanded(
                    child: Material(
                      color: complete
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(
                        tooltip: complete ? 'إتمام ورد اليوم' : 'حذف الهدف',
                        icon: Icon(
                          complete ? Icons.done_all : Icons.remove_circle,
                          color: complete
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onError,
                        ),
                        onPressed: dragging || deleting
                            ? null
                            : () => perform(
                                complete ? widget.onComplete! : widget.onDelete,
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        AnimatedContainer(
          duration: dragging
              ? Duration.zero
              : const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(offset, 0, 0),
          child: GestureDetector(
            onHorizontalDragStart: (_) => setState(() => dragging = true),
            onHorizontalDragUpdate: (details) => setState(
              () => offset = (offset + details.delta.dx).clamp(0.0, width),
            ),
            onHorizontalDragEnd: (details) =>
                settle(details.velocity.pixelsPerSecond.dx),
            onHorizontalDragCancel: () => settle(0),
            child: widget.builder(
              PopupMenuButton<String>(
                tooltip: 'إجراءات الهدف',
                enabled: !deleting,
                onSelected: (action) => perform(switch (action) {
                  'edit' => widget.onEdit,
                  'complete' => widget.onComplete!,
                  _ => widget.onDelete,
                }),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('تعديل الهدف'),
                  ),
                  if (widget.onComplete != null)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('إتمام ورد اليوم'),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف الهدف'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _NewGoal extends StatefulWidget {
  const _NewGoal({required this.db});
  final AppDatabases db;
  @override
  State<_NewGoal> createState() => _NewGoalState();
}

class _NewGoalState extends State<_NewGoal> {
  late final all = widget.db.quran.readRange(1, 6236);
  String name = '', scope = 'القرآن كاملًا', kind = 'الآية';
  int left = 1, right = 1;
  int? days;
  bool repeat = false;
  bool busy = false, editingRange = true;
  late final surahs = widget.db.quran.surahs();
  Set<int>? known;
  final ranges = <(int, int)>[];
  String? error;
  @override
  void initState() {
    super.initState();
    loadKnown();
  }

  Future<void> loadKnown() async {
    try {
      final ids = {
        ...await widget.db.user.memorizedBaseline(Riwayah.hafs),
        ...(await widget.db.user.progress(Riwayah.hafs)).map((a) => a.ayahId),
      };
      if (mounted) setState(() => known = ids);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر تحميل المحفوظ');
    }
  }

  int group(int id) {
    final a = all[id - 1];
    return switch (kind) {
      'السورة' => a.surah,
      'الجزء' => a.juz,
      'الصفحة' => a.page,
      'الآية' => a.id,
      _ =>
        kind == 'الحزب'
            ? (quarterStarts.lastIndexWhere((v) => v <= id) ~/ 4) + 1
            : quarterStarts.lastIndexWhere((v) => v <= id) + 1,
    };
  }

  String endpointLabel(int id) => kind == 'السورة'
      ? surahs[group(id) - 1].name
      : kind == 'الآية'
      ? '${surahs[all[id - 1].surah - 1].name}، آية ${all[id - 1].number}'
      : '$kind ${group(id)}';
  Future<void> chooseEndpoint(bool start) async {
    final items = start
        ? all
        : all.where((a) => group(a.id) >= group(left)).toList();
    int? result;
    if (kind == 'الآية') {
      result = await pickVerse(
        context,
        widget.db.quran,
        items,
        start ? left : right,
      );
    } else {
      final options = <int, int>{};
      for (final a in items) {
        options.putIfAbsent(group(a.id), () => a.id);
      }
      final values = options.values.toList();
      result = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => ListView.builder(
          itemCount: values.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(endpointLabel(values[i])),
            onTap: () => Navigator.pop(sheet, values[i]),
          ),
        ),
      );
    }
    if (result == null || !mounted) return;
    setState(() {
      editingRange = true;
      if (start) {
        left = result!;
        if (group(right) < group(left)) right = left;
      } else {
        right = result!;
      }
    });
  }

  (int, int) currentRange() => (
    all.firstWhere((a) => group(a.id) == group(left)).id,
    all.lastWhere((a) => group(a.id) == group(right)).id,
  );

  List<int> anchors() {
    final result = <int>[];
    final selected = [
      ...ranges,
      if (scope == 'نطاقات محددة' && editingRange) currentRange(),
    ];

    for (final a in all) {
      if (scope == 'محفوظي' && !(known?.contains(a.id) ?? false)) continue;
      if (scope == 'نطاقات محددة' &&
          !selected.any((r) => r.$1 <= a.id && a.id <= r.$2)) {
        continue;
      }
      result.add(a.id);
    }
    return result;
  }

  Widget choice(
    String label,
    String selected,
    List<String> options,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    initialValue: selected,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final v in options) DropdownMenuItem(value: v, child: Text(v)),
    ],
    onChanged: (v) {
      if (v != null) setState(() => change(v));
    },
  );
  String ref(int id) {
    final a = all[id - 1];
    return '${surahs[a.surah - 1].name} · ${a.number}';
  }

  @override
  Widget build(BuildContext context) {
    final units = anchors();
    final valid =
        units.isNotEmpty && days != null && days! > 0 && days! <= 0x7fffffff;
    final assigned = valid
        ? RevisionPartitioner().assignedDays([
            for (final id in units) widget.db.quran.printedPageWeights[id]!,
          ], days!)
        : null;
    final plan = valid
        ? ReadingGoal(
            0,
            name,
            false,
            units,
            0,
            1,
            0,
            0,
            null,
            days!,
            repeat,
            assigned,
          )
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('هدف تثبيت جديد')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'اسم الهدف'),
              onChanged: (v) => setState(() => name = v),
            ),
            const SizedBox(height: 10),
            choice('النطاق', scope, [
              'القرآن كاملًا',
              'محفوظي',
              'نطاقات محددة',
            ], (v) => scope = v),
            if (scope == 'نطاقات محددة') ...[
              const SizedBox(height: 10),
              choice(
                'تحديد حسب',
                kind,
                ['السورة', 'الجزء', 'الحزب', 'الربع', 'الصفحة', 'الآية'],
                (v) {
                  kind = v;
                  editingRange = true;
                  left = right = 1;
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                runSpacing: 8,
                spacing: 8,
                children: [
                  for (final start in [true, false])
                    ActionChip(
                      label: Text(
                        '${start ? 'من' : 'إلى'} ${endpointLabel(start ? left : right)}',
                      ),
                      onPressed: () => chooseEndpoint(start),
                    ),
                ],
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('إضافة النطاق'),
                onPressed: () {
                  final range = currentRange();
                  setState(() {
                    if (!ranges.contains(range)) ranges.add(range);
                    editingRange = false;
                    error = null;
                  });
                },
              ),
              Wrap(
                children: [
                  for (final r in ranges)
                    InputChip(
                      label: Text('${ref(r.$1)} – ${ref(r.$2)}'),
                      onDeleted: () => setState(() => ranges.remove(r)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'مدة الهدف بالأيام'),
              onChanged: (v) => setState(
                () => days = int.tryParse(normalizeDigits(v.trim())),
              ),
            ),
            if (plan != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'ورد اليوم الأول · ${_pageAmount(widget.db.quran, plan.plannedAyahs(1))}',
                ),
                subtitle: Text(
                  widget.db.quran
                      .readRangesBySurah(plan.plannedAyahs(1), pages: false)
                      .join('، '),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'عرض جدول المراجعة',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () => _showPlan(context, plan, widget.db.quran),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تكرار الهدف بعد إتمامه'),
              value: repeat,
              onChanged: (v) => setState(() => repeat = v ?? false),
            ),
            if (scope == 'محفوظي' && known != null && units.isEmpty)
              const Text('لا يوجد محفوظ مسجل.'),
            if (error != null) Text(error!),
            FilledButton(
              onPressed: valid && name.trim().isNotEmpty && !busy
                  ? () async {
                      setState(() => busy = true);
                      try {
                        await widget.db.user.createReadingGoal(
                          name,
                          false,
                          units,
                          0,
                          1,
                          durationDays: days!,
                          repeat: repeat,
                          assignedDays: assigned,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            busy = false;
                            error = 'تعذر حفظ الهدف';
                          });
                        }
                      }
                    }
                  : null,
              child: const Text('حفظ الهدف'),
            ),
          ],
        ),
      ),
    );
  }
}
