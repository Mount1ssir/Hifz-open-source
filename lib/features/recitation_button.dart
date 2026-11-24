import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/data/quran_repository.dart';
import '../domain/recitation.dart';

final recitationRoutes = RouteObserver<ModalRoute<dynamic>>();

class RecitationButton extends StatefulWidget {
  const RecitationButton({
    super.key,
    required this.quran,
    required this.page,
    this.selected,
    this.additionalPages = const [],
    required this.revealed,
    required this.onReveal,
    this.onRecited,
    this.advancePage,
    this.onStart,
    this.restartOffset = 0,
    this.onSpoken,
  });
  final VoidCallback? onStart;
  final void Function(int page, int? glyph)? onSpoken;
  final QuranRepository quran;
  final int page, revealed, restartOffset;
  final Set<int>? selected;
  final List<int> additionalPages;
  final void Function(int page, int count) onReveal;
  final int? Function(int page)? advancePage;
  final Future<void> Function(int page, Set<int> ayahs)? onRecited;
  @override
  State<RecitationButton> createState() => _RecitationButtonState();
}

class _RecitationButtonState extends State<RecitationButton>
    with RouteAware, WidgetsBindingObserver {
  static const channel = MethodChannel('hifz/recitation');
  static int sequence = 0;
  int? session;
  bool ready = false;
  ModalRoute<dynamic>? route;
  RecitationFollower? follower;
  final heardPositions = <int, Set<int>>{};
  int drawn = 0;
  int activePage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context);
    if (route == current) return;
    recitationRoutes.unsubscribe(this);
    route = current;
    if (current != null) recitationRoutes.subscribe(this, current);
  }

  @override
  void didPushNext() => stop();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      stop();
    }
  }

  @override
  void didUpdateWidget(RecitationButton old) {
    super.didUpdateWidget(old);
    if (session != null &&
        (widget.page != activePage ||
            (old.revealed != widget.revealed && widget.revealed != drawn))) {
      stop(redraw: false);
    }
  }

  void stop({bool redraw = true}) {
    final id = session;
    if (id == null) return;
    session = null;
    final page = activePage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && session == null) widget.onSpoken?.call(page, null);
    });
    channel.setMethodCallHandler(null);
    unawaited(channel.invokeMethod<void>('stop', id).catchError((Object _) {}));
    if (redraw && mounted) setState(() {});
  }

  void fail(String reason) {
    stop();
    if (reason == 'stopped' || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reason == 'permission'
              ? 'اسمح باستخدام الميكروفون للتسميع.'
              : 'تعذر بدء التسميع. حاول مجددًا.',
        ),
      ),
    );
  }

  Future<void> start() async {
    activePage = widget.page;
    final words = pageRecitationWords(
      widget.quran,
      widget.page,
      widget.selected,
      additionalPages: widget.additionalPages,
    );
    drawn = widget.revealed;
    follower = RecitationFollower(words, drawn);
    if (words.isEmpty) return;
    if (follower!.finished) {
      drawn = widget.restartOffset;
      follower = RecitationFollower(words, drawn);
      widget.onReveal(activePage, drawn);
    }
    heardPositions.clear();
    widget.onStart?.call();
    final id = ++sequence;
    setState(() {
      session = id;
      ready = false;
    });
    channel.setMethodCallHandler((call) async {
      final data = call.arguments as Map;
      if (!mounted || session != id || data['id'] != id) return;
      if (call.method == 'ready') {
        setState(() => ready = true);
        return;
      }
      if (call.method == 'failure') {
        fail(data['reason'] as String);
        return;
      }
      if (call.method != 'words') return;
      final completed = <int, Set<int>>{};
      final messenger = ScaffoldMessenger.of(context);
      final credit = widget.onRecited;
      int? latest;
      for (final raw in data['words'] as List) {
        final word = (text: raw['text'] as String, ms: raw['ms'] as int);
        final tracker = follower!;
        final end = tracker.hear(word.text, word.ms);
        if (end == null) continue;
        latest = end;
        final match = tracker.words[tracker.index - 1];
        widget.onSpoken?.call(
          activePage,
          end - (match.position == match.length - 1 ? 1 : 0),
        );
        for (var i = tracker.matchedFrom; i < tracker.index; i++) {
          final heard = tracker.words[i];
          final positions = heardPositions.putIfAbsent(
            heard.ayahId,
            () => <int>{},
          );
          if (positions.add(heard.position) &&
              positions.length == heard.length) {
            (completed[heard.page] ??= {}).add(heard.ayahId);
          }
        }
        if (tracker.finished) {
          widget.onReveal(activePage, end);
          latest = null;
          final next = widget.advancePage?.call(activePage);
          if (next == null) {
            stop();
            break;
          }
          activePage = next;
          drawn = 0;
          heardPositions.clear();
          follower = RecitationFollower(
            pageRecitationWords(widget.quran, next, widget.selected),
            0,
            lastTime: tracker.lastTime,
          );
        }
      }
      if (latest != null) {
        drawn = latest;
        widget.onReveal(activePage, drawn);
      }
      for (final entry in completed.entries) {
        try {
          await credit?.call(entry.key, entry.value);
        } catch (_) {
          for (final id in entry.value) {
            heardPositions.remove(id);
          }
          if (messenger.mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('تعذر حفظ تقدم التسميع في الأهداف.'),
              ),
            );
          }
        }
      }
    });
    try {
      await channel.invokeMethod<void>('start', id);
    } catch (_) {
      if (mounted && session == id) fail('audio');
    }
  }

  @override
  void dispose() {
    stop(redraw: false);
    recitationRoutes.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: session == null ? 'بدء التسميع' : 'إيقاف التسميع',
    child: FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size(100, 48)),
      onPressed: session == null ? start : () => stop(),
      icon: session != null && !ready
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(session == null ? Icons.mic : Icons.stop_rounded),
      label: Text(session == null ? 'تسميع' : 'إيقاف'),
    ),
  );
}
