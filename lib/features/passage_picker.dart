import 'package:material_ui/material_ui.dart';

import '../core/data/quran_repository.dart';

/// Scrollable surah and ayah wheels restricted to the offered passage.
Future<int?> pickVerse(
  BuildContext context,
  QuranRepository quran,
  List<QuranAyah> verses,
  int initial,
) => showModalBottomSheet<int>(
  context: context,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _VersePicker(quran, verses, initial),
);

class _VersePicker extends StatefulWidget {
  const _VersePicker(this.quran, this.verses, this.initial);
  final QuranRepository quran;
  final List<QuranAyah> verses;
  final int initial;
  @override
  State<_VersePicker> createState() => _VersePickerState();
}

class _VersePickerState extends State<_VersePicker> {
  late final names = widget.quran.surahs();
  late final groups = <int, List<QuranAyah>>{};
  late final List<int> surahs;
  late int chapter, verse;
  late final FixedExtentScrollController chapters;
  late FixedExtentScrollController numbers;
  @override
  void initState() {
    super.initState();
    for (final a in widget.verses) {
      (groups[a.surah] ??= []).add(a);
    }
    surahs = groups.keys.toList();
    final a = widget.verses.firstWhere(
      (a) => a.id == widget.initial,
      orElse: () => widget.verses.first,
    );
    chapter = surahs.indexOf(a.surah);
    verse = groups[a.surah]!.indexOf(a);
    chapters = FixedExtentScrollController(initialItem: chapter);
    numbers = FixedExtentScrollController(initialItem: verse);
  }

  @override
  void dispose() {
    chapters.dispose();
    numbers.dispose();
    super.dispose();
  }

  Widget wheel(
    FixedExtentScrollController controller,
    int count,
    String Function(int) label,
    ValueChanged<int> change,
  ) => ListWheelScrollView.useDelegate(
    controller: controller,
    itemExtent: 44,
    physics: const FixedExtentScrollPhysics(),
    onSelectedItemChanged: change,
    childDelegate: ListWheelChildBuilderDelegate(
      childCount: count,
      builder: (_, i) => InkWell(
        onTap: () => controller.jumpToItem(i),
        child: Center(child: Text(label(i))),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final list = groups[surahs[chapter]]!, a = list[verse];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              a.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text('صفحة ${a.page} · الجزء ${a.juz}'),
            Flexible(
              child: SizedBox(
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: wheel(
                            chapters,
                            surahs.length,
                            (i) =>
                                '${surahs[i]} · ${names[surahs[i] - 1].name}',
                            (i) {
                              if (numbers.hasClients) numbers.jumpToItem(0);
                              setState(() {
                                chapter = i;
                                verse = 0;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: wheel(
                            numbers,
                            list.length,
                            (i) => 'آية ${list[i].number}',
                            (i) => setState(
                              () => verse = i.clamp(
                                0,
                                groups[surahs[chapter]]!.length - 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, a.id),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
  }
}
