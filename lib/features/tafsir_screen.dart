import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/data/quran_repository.dart';

class TafsirScreen extends StatefulWidget {
  const TafsirScreen({
    super.key,
    required this.quran,
    required this.page,
    this.initialAyah,
  });
  final QuranRepository quran;
  final int page;
  final int? initialAyah;
  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen> {
  late final ids = widget.quran
      .pageLines(widget.page)
      .expand((line) => line.words)
      .map((w) => w.ayahId)
      .toSet()
      .toList();
  late final ayahs = widget.quran.readRange(ids.first, ids.last);
  late int selected = ayahs
      .indexWhere((a) => a.id == widget.initialAyah)
      .clamp(0, ayahs.length - 1);
  late Future<List<String>> chapter = load();
  Future<List<String>> load() async => (jsonDecode(
    await rootBundle.loadString('assets/tafsir/${ayahs[selected].surah}.json'),
  ) as List).cast<String>();
  @override
  Widget build(BuildContext context) {
    final ayah = ayahs[selected];
    final theme = Theme.of(context);
    String label(QuranAyah a) =>
        '${widget.quran.surahs()[a.surah - 1].name} · الآية ${a.number}';
    return Scaffold(
      appBar: AppBar(title: const Text('تفسير الجلالين')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<int>(
              initialValue: selected,
              decoration: InputDecoration(
                labelText: 'آيات الصفحة ${widget.page}',
              ),
              items: [
                for (final entry in ayahs.indexed)
                  DropdownMenuItem(
                    value: entry.$1,
                    child: Text(label(entry.$2)),
                  ),
              ],
              onChanged: (i) {
                if (i != null) {
                  setState(() {
                    final old = ayah.surah;
                    selected = i;
                    if (old != ayahs[i].surah) chapter = load();
                  });
                }
              },
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  ayah.text,
                  style: theme.textTheme.titleLarge?.copyWith(height: 1.9),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<String>>(
              future: chapter,
              builder: (_, snap) {
                if (snap.hasError) {
                  return TextButton(
                    onPressed: () => setState(() => chapter = load()),
                    child: const Text('إعادة تحميل التفسير'),
                  );
                }
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SelectableText(
                  snap.requireData[ayah.number - 1],
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.9),
                );
              },
            ),
            const Divider(height: 32),
            const Text(
              'تفسير الجلالين · جلال الدين المحلي وجلال الدين السيوطي',
            ),
          ],
        ),
      ),
    );
  }
}
