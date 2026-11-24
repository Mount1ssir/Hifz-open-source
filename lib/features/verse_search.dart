import 'package:material_ui/material_ui.dart';

import '../core/data/quran_repository.dart';

class VerseSearch extends StatefulWidget {
  const VerseSearch({super.key, required this.quran});
  final QuranRepository quran;

  @override
  State<VerseSearch> createState() => _VerseSearchState();
}

class _VerseSearchState extends State<VerseSearch> {
  final input = TextEditingController();
  Future<List<QuranAyah>>? results;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void search() {
    final query = input.text.trim();
    FocusScope.of(context).unfocus();
    setState(
      () => results = query.isEmpty ? null : widget.quran.searchVerses(query),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بحث في الآيات')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: input,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => search(),
              onChanged: (_) {
                if (results != null) setState(() => results = null);
              },
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: 'بحث',
                  onPressed: search,
                ),
              ),
            ),
          ),
          if (results != null)
            Expanded(
              child: FutureBuilder<List<QuranAyah>>(
                future: results,
                builder: (context, state) {
                  if (state.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: search,
                        child: const Text('إعادة المحاولة'),
                      ),
                    );
                  }
                  final ayahs = state.requireData;
                  if (ayahs.isEmpty) {
                    return const Center(child: Text('لا توجد آيات مطابقة'));
                  }
                  final surahs = widget.quran.surahs();
                  final colors = Theme.of(context).colorScheme;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: ayahs.length,
                    itemBuilder: (_, i) {
                      final ayah = ayahs[i];
                      return Card.outlined(
                        margin: EdgeInsets.zero,
                        color: colors.surface,
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          title: Text(ayah.text),
                          subtitle: Text(
                            '${surahs[ayah.surah - 1].name} · الآية ${ayah.number} · صفحة ${ayah.page}',
                          ),
                          onTap: () => Navigator.pop(context, ayah),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
