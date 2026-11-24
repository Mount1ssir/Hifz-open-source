import 'package:material_ui/material_ui.dart';

import 'core/data/app_databases.dart';
import 'core/data/quran_repository.dart';
import 'domain/riwayah.dart';
import 'features/hifz_screen.dart';
import 'features/quran_screen.dart';
import 'features/recitation_button.dart';
import 'features/goals_screen.dart';
import 'features/adhkar/adhkar_screen.dart';
import 'features/reviews_screen.dart';
import 'features/reader_controls.dart';

class HifzApp extends StatefulWidget {
  const HifzApp({super.key, this.openDatabases});
  final Future<AppDatabases> Function()? openDatabases;

  @override
  State<HifzApp> createState() => _HifzAppState();
}

class _HifzAppState extends State<HifzApp> {
  late Future<AppDatabases> _opening = _open();

  Future<AppDatabases> _open() async {
    final databases =
        await (widget.openDatabases?.call() ??
            AppDatabases.open(riwayah: Riwayah.hafs));
    debugPrint('Hifz database open: ${databases.openTime.inMilliseconds} ms');
    return databases;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حفظ',
      navigatorObservers: [recitationRoutes],
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff226653),
          primary: const Color(0xff226653),
          primaryContainer: const Color(0xffe6eee6),
          surface: const Color(0xfffaf9f5),
        ),
        scaffoldBackgroundColor: const Color(0xfff8f6ef),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xfff3f6f1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xffdce5dd)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xffeef2ec),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Color(0xfff4f6f0),
          indicatorColor: Color(0xffcce8d8),
        ),
        useMaterial3: true,
      ),
      home: FutureBuilder<AppDatabases>(
        future: _opening,
        builder: (context, snapshot) {
          if (snapshot.hasData) return _Home(databases: snapshot.data!);
          return Scaffold(
            appBar: AppBar(title: const Text('حفظ')),
            body: Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('تعذر فتح بيانات القرآن.'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => setState(() => _opening = _open()),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('جارٍ فتح القرآن…'),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.databases});
  final AppDatabases databases;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with WidgetsBindingObserver {
  int _index = 0;
  bool _adhkarOpen = false;

  Future<void> _selectDestination(int index) async {
    if (index == 3) {
      if (_adhkarOpen) return;
      _adhkarOpen = true;
      try {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => AdhkarScreen(quran: widget.databases.quran),
          ),
        );
      } finally {
        _adhkarOpen = false;
      }
      return;
    }
    setState(() {
      _goalAyah = null;
      _index = index;
    });
  }

  QuranAyah? _goalAyah;
  bool _focus = false;
  void _setFocus(bool value) => setState(() => _focus = value);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.databases.reminders.openHifz.value > 0) _index = 1;
    widget.databases.reminders.openHifz.addListener(_openHifz);
    if (widget.databases.reminders.openReviews.value > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openReviews());
    }
    widget.databases.reminders.openReviews.addListener(_openReviews);
  }

  void _openHifz() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _index = 1;
      _focus = false;
    });
  }

  void _openReviews() {
    if (mounted) {
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewsScreen(databases: widget.databases),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.databases.reminders.sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.databases.reminders.openHifz.removeListener(_openHifz);
    widget.databases.reminders.openReviews.removeListener(_openReviews);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: switch (_index) {
      0 => QuranScreen(
        databases: widget.databases,
        onFocusChanged: _setFocus,
        initialPage: _goalAyah?.page,
        initialAyah: _goalAyah?.id,
      ),
      1 => HifzScreen(databases: widget.databases, onFocusChanged: _setFocus),
      _ => GoalsScreen(
        databases: widget.databases,
        onOpenAyah: (ayah) => setState(() {
          _goalAyah = ayah;
          _index = 0;
        }),
      ),
    },
    bottomNavigationBar: ReaderControls(
      reserveSpace: _index == 0,
      visible: !_focus,
      child: NavigationBar(
        height: _index < 2 ? 52 : 60,
        selectedIndex: _index,
        onDestinationSelected: _selectDestination,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'القرآن',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'الحفظ',
          ),
          NavigationDestination(
            icon: const Icon(Icons.flag_outlined),
            selectedIcon: const Icon(Icons.flag_outlined),
            label: 'التثبيت',
          ),
          const NavigationDestination(
            icon: Icon(Icons.wb_twilight),
            label: 'الأذكار',
          ),
        ],
      ),
    ),
  );
}
