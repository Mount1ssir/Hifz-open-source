import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import '../domain/riwayah.dart';

/// Existing knowledge is separate from completed daily sessions and reviews.
class BaselineScreen extends StatefulWidget {
  const BaselineScreen({super.key, required this.databases});
  final AppDatabases databases;
  @override
  State<BaselineScreen> createState() => _BaselineScreenState();
}

class _BaselineScreenState extends State<BaselineScreen> {
  Set<int>? _selected;
  Set<int> _baseline = {}, _completed = {};
  bool _saving = false;
  String? _error;
  late final _all = widget.databases.quran.readRange(1, 6236);
  late final _surahs = widget.databases.quran.surahs();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final selected = await widget.databases.user.memorizedBaseline(
        Riwayah.hafs,
      );
      final completed = await widget.databases.user.progress(Riwayah.hafs);
      if (mounted) {
        setState(() {
          _baseline = selected;
          _completed = completed.map((a) => a.ayahId).toSet();
          _selected = {...selected, ..._completed};
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل المحفوظ. حاول مجددًا.');
    }
  }

  Future<void> _range(int surah, String name) async {
    final ayahs = _all.where((a) => a.surah == surah).toList();
    var first = 1;
    var last = ayahs.length;
    final selected = ayahs.where((a) => _selected!.contains(a.id)).toList();
    final editingRange =
        selected.isNotEmpty &&
        selected.last.number - selected.first.number + 1 == selected.length;
    if (editingRange) {
      first = selected.first.number;
      last = selected.last.number;
    } else if (selected.isNotEmpty) {
      first = last = ayahs.firstWhere((a) => !_selected!.contains(a.id)).number;
    }
    String? error;
    final firstController = TextEditingController(text: '$first');
    final lastController = TextEditingController(text: '$last');
    final result = await showModalBottomSheet<(int, int)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          void inputChanged() {
            int? number(String text) {
              for (var i = 0; i < 10; i++) {
                text = text.replaceAll('٠١٢٣٤٥٦٧٨٩'[i], '$i');
              }
              return int.tryParse(text);
            }

            final a = number(firstController.text);
            final b = number(lastController.text);
            update(() {
              error =
                  a == null || b == null || a < 1 || b > ayahs.length || a > b
                  ? 'أدخل نطاقًا صحيحًا داخل السورة'
                  : null;
              if (error == null) {
                first = a!;
                last = b!;
              }
            });
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$name · $first – $last',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${last - first + 1} آية · الصفحات ${ayahs[first - 1].page} – ${ayahs[last - 1].page}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ayahs[first - 1].text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const Icon(Icons.more_vert),
                  Text(
                    ayahs[last - 1].text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 22),
                  ),
                  RangeSlider(
                    values: RangeValues(first.toDouble(), last.toDouble()),
                    min: 1,
                    max: ayahs.length.toDouble(),
                    divisions: ayahs.length - 1,
                    labels: RangeLabels('$first', '$last'),
                    onChanged: (values) => update(() {
                      first = values.start.round();
                      last = values.end.round();
                      firstController.text = '$first';
                      lastController.text = '$last';
                      error = null;
                    }),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'من الآية',
                          ),
                          onChanged: (_) => inputChanged(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: lastController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'إلى الآية',
                          ),
                          onChanged: (_) => inputChanged(),
                        ),
                      ),
                    ],
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: error != null
                        ? null
                        : () => Navigator.pop(context, (first, last)),
                    child: const Text('تطبيق'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (editingRange) _selected!.removeAll(selected.map((a) => a.id));
        final ids = ayahs
            .where((a) => a.number >= result.$1 && a.number <= result.$2)
            .map((a) => a.id);
        _selected!.addAll(ids);
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    firstController.dispose();
    lastController.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.databases.user.saveMemorizedBaseline(Riwayah.hafs, {
        ..._selected!.difference(_completed),
        ..._baseline.intersection(_selected!),
      }, removedProgress: _completed.difference(_selected!));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر الحفظ. حاول مجددًا.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surahs = _surahs;
    final all = _all;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('محفوظي السابق'),
            actions: [
              TextButton(
                onPressed: _selected == null || _saving ? null : _save,
                child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
              ),
            ],
          ),
          body: _selected == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : TextButton(onPressed: _load, child: Text(_error!)),
                )
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('اختر سورة كاملة أو حدّد الآيات.'),
                    ),
                    if (_error != null) Text(_error!),
                    Text('${_selected!.length} آية محفوظة'),
                    Expanded(
                      child: ListView.builder(
                        itemCount: surahs.length,
                        itemBuilder: (context, index) {
                          final surah = surahs[index];
                          final ids = all
                              .where((a) => a.surah == surah.number)
                              .map((a) => a.id)
                              .toSet();
                          final count = ids.intersection(_selected!).length;
                          return ListTile(
                            leading: Checkbox(
                              tristate: true,
                              value: count == 0
                                  ? false
                                  : count == ids.length
                                  ? true
                                  : null,
                              onChanged: _saving
                                  ? null
                                  : (_) => setState(() {
                                      if (ids.every(_selected!.contains)) {
                                        _selected!.removeAll(ids);
                                      } else {
                                        _selected!.addAll(ids);
                                      }
                                    }),
                            ),
                            title: Text(surah.name),
                            subtitle: Text('$count / ${ids.length} آية'),
                            trailing: IconButton(
                              tooltip: 'تحديد الآيات',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: _saving
                                  ? null
                                  : () => _range(surah.number, surah.name),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
