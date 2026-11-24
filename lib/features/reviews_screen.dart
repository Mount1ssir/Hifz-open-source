import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import '../core/data/user_database.dart';
import '../domain/review_scheduler.dart';
import 'quran_reader.dart';
import '../core/arabic.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({
    super.key,
    required this.databases,
    this.todayOnly = false,
  });
  final AppDatabases databases;
  final bool todayOnly;

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen>
    with WidgetsBindingObserver {
  List<(ReviewSession, List<ReviewAttempt>)> _sessions = [];
  ReviewSettings _settings = ReviewSettings();
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      await widget.databases.reminders.sync();
      final settings = await widget.databases.user.reviewSettings();
      final sessions = await widget.databases.user.sessions();
      final rows = <(ReviewSession, List<ReviewAttempt>)>[];
      for (final session in sessions) {
        final now = DateTime.now();
        final day = session.startedAt.toLocal();
        if (widget.todayOnly &&
            (day.year != now.year ||
                day.month != now.month ||
                day.day != now.day)) {
          continue;
        }
        rows.add((session, await widget.databases.user.attempts(session.id)));
      }
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _sessions = rows;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل جلسات التثبيت.';
          _loading = false;
        });
      }
    }
  }

  String _time(DateTime time) {
    final local = time.toLocal();
    final labels = MaterialLocalizations.of(context);
    return normalizeDigits(
      '${labels.formatShortDate(local)} · ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
    );
  }

  Future<void> _settingsDialog() async {
    var count = '${_settings.intervals.length}';
    var minutes = '${_settings.intervals.first.inMinutes}';
    var adaptive = _settings.adaptive;
    var notify =
        await widget.databases.user.preference(
              'review_notification_configured',
            ) ==
            0 ||
        await widget.databases.reminders.enabled();
    String? error;
    if (!mounted) return;
    ReviewSettings parse() {
      final repetitions = int.parse(normalizeDigits(count));
      final gap = int.parse(normalizeDigits(minutes));
      if (repetitions < 1 ||
          repetitions > 8 ||
          gap < 1 ||
          gap * repetitions > 1440) {
        throw const FormatException();
      }
      return ReviewSettings(
        intervals: List.filled(repetitions, Duration(minutes: gap)),
        adaptive: adaptive,
      );
    }

    final result = await showDialog<ReviewSettings>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          return AlertDialog(
            title: const Text('جلسات تثبيت الحفظ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: count,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'عدد الجلسات خلال اليوم',
                    ),
                    onChanged: (value) => update(() => count = value),
                  ),
                  TextFormField(
                    initialValue: minutes,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الفاصل بين حصص المراجعة',
                      suffixText: 'دقيقة',
                    ),
                    onChanged: (value) => update(() => minutes = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تعديل الفواصل حسب التذكر'),
                    value: adaptive,
                    onChanged: (value) => update(() => adaptive = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('إرسال إشعار لكل جلسة'),
                    value: notify,
                    onChanged: (value) => update(() => notify = value),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
                  try {
                    Navigator.pop(context, parse());
                  } catch (_) {
                    update(
                      () => error = 'اختر من 1 إلى 8 جلسات بفاصل دقيقة على الأقل، ضمن 24 ساعة.',
                    );
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null) return;
    try {
      await widget.databases.user.saveReviewSettings(result);
      await widget.databases.user.setPreference(
        'review_notification_configured',
        1,
      );
      await widget.databases.reminders.setEnabled(notify);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديث التذكيرات. تحقق من إعدادات الإشعارات.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تثبيت الحفظ'),
        actions: [
          IconButton(
            onPressed: _settingsDialog,
            tooltip: 'إعداد جلسات التثبيت',
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: _load,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${_settings.intervals.length} جلسات لكل ورد · ${_settings.adaptive ? "فواصل تتكيف مع التذكر" : "فواصل ثابتة"}',
                  ),
                  ValueListenableBuilder<String?>(
                    valueListenable: widget.databases.reminders.error,
                    builder: (_, error, _) => error == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(error),
                          ),
                  ),
                  const SizedBox(height: 24),
                  if (_sessions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('تبدأ جلسات التثبيت بعد حفظ الورد.'),
                      ),
                    ),
                  for (final row in _sessions)
                    _sessionCard(row.$1, row.$2, now),
                ],
              ),
            ),
    );
  }

  Widget _sessionCard(
    ReviewSession session,
    List<ReviewAttempt> attempts,
    DateTime now,
  ) {
    final pending = ReviewScheduler().pending(
      startedAt: session.startedAt,
      attempts: [
        for (final a in attempts)
          RecallAttempt(a.completedAt, RecallRating.values[a.rating]),
      ],
      settings: _settings,
      now: now,
    );
    final ids = (jsonDecode(session.ayahIds) as List<dynamic>).cast<int>();
    final due = pending.isNotEmpty && pending.first.isDue(now);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ids.length} آية · ${normalizeDigits(MaterialLocalizations.of(context).formatShortDate(session.startedAt.toLocal()))}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final range in widget.databases.quran.readRangesBySurah(
              ids,
              pages: false,
            ))
              Text(range),
            Text('${attempts.length} جلسات مكتملة'),
            for (final attempt in attempts)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '✓ ${recallLabel(RecallRating.values[attempt.rating])} · ${_time(attempt.completedAt)}',
                ),
              ),
            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('اكتملت جلسات تثبيت هذا الورد.'),
              )
            else ...[
              const Divider(height: 32),
              Text(
                due
                    ? 'حان وقت استرجاع الورد'
                    : 'الجلسة التالية · ${_time(pending.first.dueAt)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final review in pending.skip(1))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('ثم تقريبًا ${_time(review.dueAt)}'),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: due
                    ? () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuranReader(
                              onRecited: widget.databases.creditRecitation,
                              quran: widget.databases.quran,
                              title: 'الجلسة ${pending.first.ordinal + 1}',
                              ayahs: [
                                for (final id in ids)
                                  widget.databases.quran
                                      .readRange(id, id)
                                      .single,
                              ],

                              startHidden: true,
                              showPreviousAyah: true,
                              onRecall: (rating) =>
                                  widget.databases.user.recordRecall(
                                    session.id,
                                    pending.first.ordinal,
                                    rating,
                                    DateTime.now(),
                                  ),
                            ),
                          ),
                        );
                        if (mounted) await _load();
                      }
                    : null,
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('ابدأ الاسترجاع'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
