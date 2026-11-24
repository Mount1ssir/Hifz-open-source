import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as zones;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/review_scheduler.dart';
import '../data/user_database.dart';

/// Absolute UTC instants preserve the schedule across device time-zone changes.
/// Android restores its persisted alarms after reboot using the plugin receiver.
class ReviewReminders {
  ReviewReminders(this.user, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;
  final DateTime Function() _now;
  final UserDatabase user;
  final _plugin = FlutterLocalNotificationsPlugin();
  final dueCount = ValueNotifier<int>(0);
  static const _dailyId = -1;
  static const _dailyPrefix = 'daily-hifz|';
  final openHifz = ValueNotifier<int>(0);
  bool _zonesReady = false;
  final openReviews = ValueNotifier<int>(0);
  final error = ValueNotifier<String?>(null);
  bool _ready = false;
  Timer? _timer;
  int _badgeRevision = 0;
  int _seenThrough = 0;
  static const _seenKey = 'hifz_history_seen_through';

  Future<void> _queue = Future<void>.value();

  Future<void> initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_review'),
        ),
        onDidReceiveNotificationResponse: (response) => _open(response.payload),
      );
      _ready = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _open(launch?.notificationResponse?.payload);
      }
      await sync();
    } catch (_) {
      error.value = 'تعذر تشغيل التذكيرات. يمكنك إعادة المحاولة من الإعدادات.';
    }
  }

  void _open(String? payload) {
    if (payload?.startsWith(_dailyPrefix) ?? false) {
      openHifz.value++;
    } else {
      openReviews.value++;
    }
  }

  Future<int> dailyMinute() =>
      user.preference('daily_hifz_minute', fallback: -1);

  Future<bool> _permission() async =>
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;

  Future<bool> setDailyMinute(int minute) async {
    RangeError.checkValueInInterval(minute, -1, 1439);
    if (!_ready) await initialize();
    if (minute >= 0 && (!_ready || !await _permission())) return false;
    await user.setPreference('daily_hifz_minute', minute);
    await sync();
    return true;
  }

  Future<void> _syncDaily(PendingNotificationRequest? existing) async {
    final minute = await dailyMinute();
    if (minute < 0) {
      if (existing != null) await _plugin.cancel(_dailyId);
      return;
    }
    if (!_zonesReady) {
      zones.initializeTimeZones();
      _zonesReady = true;
    }
    final name = await const MethodChannel('hifz/device')
        .invokeMethod<String>('timeZone');
    final location = tz.getLocation(name!);
    final payload = '$_dailyPrefix$minute|$name';
    if (existing?.payload == payload) return;
    final now = tz.TZDateTime.from(_now(), location);
    tz.TZDateTime at(int day) => tz.TZDateTime(
      location,
      now.year,
      now.month,
      day,
      minute ~/ 60,
      minute % 60,
    );
    final today = at(now.day);
    await _plugin.zonedSchedule(
      _dailyId,
      'ورد الحفظ',
      'حان وقت وردك اليومي.',
      today.isAfter(now) ? today : at(now.day + 1),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_hifz',
          'ورد الحفظ اليومي',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<bool> enabled() async =>
      await user.preference('review_notifications') == 1;

  Future<bool> setEnabled(bool value) async {
    if (!_ready) await initialize();
    if (value) {
      final granted = await _permission();
      if (!granted) {
        error.value =
            'لم يُسمح بالإشعارات. فعّلها من إعدادات الهاتف لتلقي التذكيرات.';
        await user.setPreference('review_notifications', 0);
        await sync();
        return false;
      }
    }
    error.value = null;
    await user.setPreference('review_notifications', value ? 1 : 0);
    await sync();
    return value;
  }

  Future<List<(String, ScheduledReview)>> _pending({bool badge = false}) async {
    final settings = await user.reviewSettings();
    final now = _now();
    final result = <(String, ScheduledReview)>[];
    for (final session in await user.sessions()) {
      final history = await user.attempts(session.id);
      for (final review in ReviewScheduler().pending(
        startedAt: session.startedAt,
        attempts: history
            .map(
              (a) =>
                  RecallAttempt(a.completedAt, RecallRating.values[a.rating]),
            )
            .toList(),
        settings: settings,
        // The history shortcut uses the configured times. Reopening the app
        // must not move its next dot forward when a recall is still overdue.
        now: badge ? session.startedAt : now,
      )) {
        result.add((session.id, review));
      }
    }
    return result;
  }

  Future<void> acknowledgeHistory() async {
    final opened = _now().microsecondsSinceEpoch;
    _seenThrough = opened;
    _badgeRevision++;
    dueCount.value = 0;
    try {
      await user.setPreference(_seenKey, opened);
    } finally {
      await refreshBadge();
    }
  }

  Future<void> refreshBadge() async {
    final revision = ++_badgeRevision;
    try {
      final stored = await user.preference(_seenKey);
      final pending = await _pending(badge: true);
      if (revision != _badgeRevision) return;
      if (stored > _seenThrough) _seenThrough = stored;
      final now = _now();
      var count = 0;
      DateTime? next;
      for (final (_, review) in pending) {
        final due = review.dueAt;
        if (due.microsecondsSinceEpoch <= _seenThrough) continue;
        if (due.isAfter(now)) {
          if (next == null || due.isBefore(next)) next = due;
        } else {
          count++;
        }
      }
      dueCount.value = count;
      _timer?.cancel();
      if (next != null) _timer = Timer(next.difference(now), refreshBadge);
    } catch (_) {
      // A failed read can be retried on the next schedule or lifecycle update.
    }
  }

  Future<void> sync() {
    // Serialize updates so an older reschedule cannot restore cancelled alarms.
    _queue = _queue.then((_) async {
      try {
        await refreshBadge();
        if (!_ready) return;
        final alarms = await _plugin.pendingNotificationRequests();
        String? dailyError;
        try {
          await _syncDaily(alarms.where((n) => n.id == _dailyId).firstOrNull);
        } catch (_) {
          dailyError =
              'تعذرت جدولة تذكير ورد الحفظ. أعد المحاولة من الإعدادات.';
        }
        for (final alarm in alarms.where((n) => n.id != _dailyId)) {
          await _plugin.cancel(alarm.id);
        }
        if (!await enabled()) {
          if (dailyError != null || await dailyMinute() >= 0) {
            error.value = dailyError;
          }
          return;
        }
        final pending = await _pending();
        final now = _now();
        for (final entry in pending) {
          final review = entry.$2;
          // Schedule only future Android alerts.
          if (!review.dueAt.isAfter(now)) continue;
          final bytes = sha256
              .convert(utf8.encode('${entry.$1}:${review.ordinal}'))
              .bytes;
          final id =
              ((bytes[0] << 24) |
                  (bytes[1] << 16) |
                  (bytes[2] << 8) |
                  bytes[3]) &
              0x7fffffff;
          await _plugin.zonedSchedule(
            id,
            'حان وقت تثبيت الحفظ',
            'الجلسة ${review.ordinal + 1}: استرجع وردك ثم قيّم تذكرك.',
            tz.TZDateTime.from(review.dueAt, tz.UTC),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'hifz_reviews',
                'مراجعة الحفظ',
                channelDescription: 'تذكيرات جلسات تثبيت الحفظ',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: entry.$1,
          );
        }
        error.value = dailyError;
      } catch (_) {
        error.value =
            'حُفظ جدولك، لكن تعذرت جدولة التنبيهات. أعد المحاولة من الإعدادات.';
      }
    });
    return _queue;
  }

  void dispose() {
    _badgeRevision++;
    _timer?.cancel();
    dueCount.dispose();
    openHifz.dispose();
    openReviews.dispose();
    error.dispose();
  }
}
