import 'package:material_ui/material_ui.dart';

import '../core/data/app_databases.dart';
import 'baseline_screen.dart';
import '../core/arabic.dart';
import 'reviews_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.databases});
  final AppDatabases databases;
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _enabled;
  bool _saving = false;
  int _dailyMinute = -1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await widget.databases.reminders.enabled();
    final minute = await widget.databases.reminders.dailyMinute();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _dailyMinute = minute;
      });
    }
  }

  TimeOfDay get _dailyTime => _dailyMinute < 0
      ? TimeOfDay.now()
      : TimeOfDay(hour: _dailyMinute ~/ 60, minute: _dailyMinute % 60);

  Future<void> _daily(bool enabled) async {
    int minute = -1;
    if (enabled) {
      final time = await showTimePicker(
        context: context,
        initialTime: _dailyTime,
      );
      if (time == null || !mounted) return;
      minute = time.hour * 60 + time.minute;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.databases.reminders.setDailyMinute(minute);
      if (!mounted) return;
      if (saved) {
        setState(() => _dailyMinute = minute);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('اسمح بالإشعارات لتفعيل تذكير الحفظ.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر حفظ وقت التذكير.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.language),
                title: Text('اللغة العربية'),
                subtitle: Text('لغة الواجهة الحالية'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.menu_book),
                title: const Text('المصحف'),
                subtitle: const Text('ألوان التجويد'),
                value: widget.databases.quran.tajweed.value,
                onChanged: _saving
                    ? null
                    : (enabled) async {
                        setState(() => _saving = true);
                        try {
                          await widget.databases.user.setPreference(
                            'tajweed_colors',
                            enabled ? 1 : 0,
                          );
                          widget.databases.quran.tajweed.value = enabled;
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تعذر حفظ إعداد ألوان التجويد.'),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('تذكير ورد الحفظ اليومي'),
                value: _dailyMinute >= 0,
                onChanged: _saving || _enabled == null ? null : _daily,
              ),
              if (_dailyMinute >= 0)
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('وقت التذكير'),
                  trailing: Text(normalizeDigits(_dailyTime.format(context))),
                  onTap: _saving ? null : () => _daily(true),
                ),
              SwitchListTile(
                title: const Text('تذكيرات تثبيت الحفظ'),
                subtitle: const Text(
                  'قد يؤخر الهاتف التنبيهات قليلًا لتوفير الطاقة.',
                ),
                value: _enabled ?? false,
                onChanged: _enabled == null || _saving
                    ? null
                    : (value) async {
                        setState(() => _saving = true);
                        try {
                          final enabled = await widget.databases.reminders
                              .setEnabled(value);
                          if (mounted) setState(() => _enabled = enabled);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تعذر تفعيل الإشعارات. تحقق من إذنها في إعدادات الهاتف.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
              ),
              ValueListenableBuilder<String?>(
                valueListenable: widget.databases.reminders.error,
                builder: (_, error, _) => error == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(error),
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('جلسات التثبيت وأوقاتها'),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewsScreen(databases: widget.databases),
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('تعديل المحفوظ السابق'),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BaselineScreen(databases: widget.databases),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('المصادر والتراخيص'),
                onTap: () =>
                    showLicensePage(context: context, applicationName: 'حفظ'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
