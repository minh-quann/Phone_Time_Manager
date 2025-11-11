import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../models/app_usage.dart';

class StatsPage extends StatefulWidget {
  final DateTime? initialDay;
  const StatsPage({super.key, this.initialDay});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late DateTime _selectedDay;
  Duration _totalUsage = Duration.zero;
  List<AppUsage> _apps = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay ?? DateTime.now();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final total = await UsageService.getUsageForDay(_selectedDay);
    final list = await UsageService.getAppUsageForDay(_selectedDay);
    final apps = list.map((e) {
      final name = e['appName'] as String? ?? (e['packageName'] as String? ?? 'Unknown');
      final pkg = e['packageName'] as String? ?? name;
      final usage = Duration(milliseconds: ((e['usageTime'] as num?)?.toInt() ?? 0));
      return AppUsage(
        name: name,
        packageName: pkg,
        duration: usage,
        icon: Icons.apps,
        iconColor: Colors.blueGrey,
      );
    }).toList();
    apps.sort((a, b) => b.duration.compareTo(a.duration));
    if (mounted) {
      setState(() {
        _totalUsage = total;
        _apps = apps;
        _loading = false;
      });
    }
  }

  List<DateTime> _buildRecentDays() {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final d = today.subtract(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    }).reversed.toList();
  }

  String _formatDay(DateTime d) {
    final isToday = _isSameDay(d, DateTime.now());
    if (isToday) return 'Hôm nay';
    final weekday = ['T2','T3','T4','T5','T6','T7','CN'][d.weekday - 1];
    return '$weekday ${d.day}/${d.month}';
    }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '$h giờ ${m.toString().padLeft(2, '0')} phút';
    return '$m phút';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final days = _buildRecentDays();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê theo ngày'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date selector
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, index) {
                  final day = days[index];
                  final selected = _isSameDay(day, _selectedDay);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? colorScheme.primary.withOpacity(0.15) : colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? colorScheme.primary : colorScheme.surfaceVariant.withOpacity(0.4),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _selectedDay = day;
                        });
                        _load();
                      },
                      child: Center(
                        child: Text(
                          _formatDay(day),
                          style: TextStyle(
                            color: selected ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: days.length,
              ),
            ),
            const SizedBox(height: 16),
            // Total
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng thời gian sáng màn hình',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _formatDuration(_totalUsage),
                              key: ValueKey(_totalUsage.inMinutes),
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: (_totalUsage.inMinutes / 720).clamp(0.0, 1.0),
                        strokeWidth: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Apps list
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thống kê theo ứng dụng',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_apps.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Không có ứng dụng nào đạt 1 phút sử dụng trong ngày này.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      )
                    else
                      ..._apps.asMap().entries.map((entry) {
                        final i = entry.key;
                        final app = entry.value;
                        final pct = _apps.fold<int>(0, (s, a) => s + a.duration.inMinutes) == 0
                            ? 0.0
                            : app.duration.inMinutes /
                                _apps.fold<int>(0, (s, a) => s + a.duration.inMinutes);
                        return Padding(
                          padding: EdgeInsets.only(bottom: i < _apps.length - 1 ? 12 : 0),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: app.iconColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(app.icon, color: app.iconColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            app.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(_formatDuration(app.duration)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: pct.clamp(0.0, 1.0),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


