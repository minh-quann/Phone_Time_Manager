import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../services/usage_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../models/app_usage.dart';
import 'stats_page.dart';

class HomePage extends StatefulWidget {
  final Future<void> Function(ThemeMode) onChangeThemeMode;
  final ThemeMode currentThemeMode;

  const HomePage({
    super.key,
    required this.onChangeThemeMode,
    required this.currentThemeMode,
  });

  @override
  State createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.example.screen_time');

  double targetHours = 6.87; // Mục tiêu mặc định 6 giờ 52 phút (6.87 giờ)
  Duration currentUsage = Duration.zero;
  Timer? _timer;
  int consecutiveDays = 0;
  ConfettiController? _confettiController;

  // Mock data cho categories và apps
  List<CategoryUsage> categories = [];
  List<AppUsage> topApps = [];
  List<AppUsage> allApps = []; // Danh sách tất cả apps đã sử dụng

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _confettiController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    try {
      final granted = await _isUsagePermissionGranted();
      if (granted) {
        await _loadAppUsageData();
        await _updateUsageAndCheck();
      }
    } catch (e) {
      print('Error on resume check: $e');
    }
  }

  Future<void> _initApp() async {
    await NotificationService.init();
    await PreferencesService.loadPrefs();
    setState(() {
      targetHours = PreferencesService.targetHours;
      consecutiveDays = PreferencesService.consecutiveDays;
    });

    final granted = await _isUsagePermissionGranted();
    if (!granted) {
      await _openUsageSettings();
      return;
    }

    await UsageService.checkYesterdayAndUpdate(targetHours, context, _confettiController);
    await _loadAppUsageData();
    _startMonitoring();
  }

  Future<bool> _isUsagePermissionGranted() async {
    try {
      final res = await platform.invokeMethod<bool>('isUsageAccessGranted');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _openUsageSettings() async {
    try {
      await platform.invokeMethod('openUsageSettings');
    } catch (e) {
      print('Error opening usage settings: $e');
    }
  }

  void _startMonitoring() {
    _timer?.cancel();
    _updateUsageAndCheck();
    _timer = Timer.periodic(Duration(seconds: 60), (_) => _updateUsageAndCheck());
  }

  Future<void> _updateUsageAndCheck() async {
    final usage = await UsageService.getTodayUsage();
    await _loadAppUsageData();
    setState(() {
      currentUsage = usage;
      // Cập nhật categories dựa trên usage thực tế
      _updateCategoriesFromUsage(usage);
    });
    await UsageService.checkTargetAndNotify(usage, targetHours);
  }

  Future<void> _loadAppUsageData() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final appList = await UsageService.getAppUsageList(startOfDay, now);
      
      print('Số lượng app từ hệ thống: ${appList.length}');
      
      setState(() {
        allApps = appList.map((appData) {
          final packageName = appData['packageName'] as String;
          final appName = appData['appName'] as String;
          final usageTime = (appData['usageTime'] as num).toInt();
          final duration = Duration(milliseconds: usageTime);
          
          return AppUsage(
            name: appName,
            packageName: packageName,
            duration: duration,
            icon: _getAppIcon(packageName),
            iconColor: _getAppColor(packageName),
          );
        }).toList();
        
        // Sắp xếp theo thời gian sử dụng giảm dần trước khi lấy top 3
        allApps.sort((a, b) => b.duration.compareTo(a.duration));
        
        // Lấy top 3 apps
        topApps = allApps.take(3).toList();
        
        print('Số lượng allApps: ${allApps.length}');
        print('Số lượng topApps: ${topApps.length}');
        if (topApps.isNotEmpty) {
          print('Top app đầu tiên: ${topApps[0].name} - ${topApps[0].duration.inMinutes} phút');
        }
      });
    } catch (e) {
      print('Lỗi load app usage data: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  IconData _getAppIcon(String packageName) {
    // Map các package name phổ biến với icon
    final iconMap = {
      'com.zhiliaoapp.musically': Icons.music_note, // TikTok
      'com.facebook.katana': Icons.people, // Facebook
      'com.facebook.orca': Icons.chat, // Messenger
      'com.zing.zalo': Icons.chat_bubble, // Zalo
      'com.google.android.youtube': Icons.play_circle, // YouTube
      'com.google.android.gm': Icons.email, // Gmail
      'com.coccoc.trinhduyet': Icons.language, // Cốc Cốc
      'com.android.chrome': Icons.language, // Chrome
      'com.microsoft.office.word': Icons.description, // Word
      'com.microsoft.office.excel': Icons.table_chart, // Excel
    };
    return iconMap[packageName] ?? Icons.apps;
  }

  Color _getAppColor(String packageName) {
    // Map các package name với màu sắc
    final colorMap = {
      'com.zhiliaoapp.musically': Colors.black, // TikTok
      'com.facebook.katana': Color(0xFF1877F2), // Facebook
      'com.facebook.orca': Color(0xFF0084FF), // Messenger
      'com.zing.zalo': Color(0xFF0068FF), // Zalo
      'com.google.android.youtube': Color(0xFFFF0000), // YouTube
      'com.google.android.gm': Color(0xFFEA4335), // Gmail
      'com.coccoc.trinhduyet': Color(0xFF00C853), // Cốc Cốc
      'com.android.chrome': Color(0xFF4285F4), // Chrome
      'com.microsoft.office.word': Color(0xFF2B579A), // Word
      'com.microsoft.office.excel': Color(0xFF217346), // Excel
    };
    return colorMap[packageName] ?? Colors.blueGrey;
  }

  void _updateCategoriesFromUsage(Duration totalUsage) {
    // Phân loại apps vào categories dựa trên package name và thời gian sử dụng
    final totalMinutes = totalUsage.inMinutes;
    if (totalMinutes == 0 || allApps.isEmpty) {
      categories = [];
      return;
    }
    
    Duration videoDuration = Duration.zero;
    Duration socialDuration = Duration.zero;
    Duration productivityDuration = Duration.zero;
    
    // Danh sách package name cho từng category
    final videoPackages = ['com.google.android.youtube', 'com.zhiliaoapp.musically', 'video'];
    final socialPackages = ['com.facebook.katana', 'com.facebook.orca', 'com.zing.zalo', 'com.whatsapp'];
    final productivityPackages = ['com.google.android.gm', 'com.microsoft.office', 'com.android.chrome', 'com.coccoc.trinhduyet'];
    
    for (var app in allApps) {
      final packageName = app.packageName.toLowerCase();
      if (videoPackages.any((p) => packageName.contains(p))) {
        videoDuration += app.duration;
      } else if (socialPackages.any((p) => packageName.contains(p))) {
        socialDuration += app.duration;
      } else if (productivityPackages.any((p) => packageName.contains(p))) {
        productivityDuration += app.duration;
      } else {
        // Mặc định cho vào "Khác" hoặc phân loại dựa trên thời gian
        if (app.duration.inMinutes > totalMinutes * 0.1) {
          videoDuration += app.duration; // Nếu app dùng nhiều, cho vào Video
        }
      }
    }
    
    categories = [];
    if (videoDuration.inMinutes > 0) {
      categories.add(CategoryUsage(
        name: 'Video',
        duration: videoDuration,
        color: Color(0xFF14B8A6),
      ));
    }
    if (socialDuration.inMinutes > 0) {
      categories.add(CategoryUsage(
        name: 'Xã hội',
        duration: socialDuration,
        color: Color(0xFF3B82F6),
      ));
    }
    if (productivityDuration.inMinutes > 0) {
      categories.add(CategoryUsage(
        name: 'Năng suất và tài chính',
        duration: productivityDuration,
        color: Color(0xFFA855F7),
      ));
    }
    
    // Nếu không có category nào, tạo một category tổng hợp
    if (categories.isEmpty && totalMinutes > 0) {
      categories.add(CategoryUsage(
        name: 'Tổng hợp',
        duration: totalUsage,
        color: Color(0xFF14B8A6),
      ));
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) {
      return '$h giờ ${m.toString().padLeft(2, '0')} phút';
    }
    return '$m phút';
  }

  String _formatDurationShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) {
      return '$h giờ $m p';
    }
    return '$m p';
  }

  @override
  Widget build(BuildContext context) {
    final totalUsage = currentUsage;
    final targetMinutes = (targetHours * 60).toInt();
    final remainingMinutes = (targetMinutes - totalUsage.inMinutes).clamp(0, targetMinutes);
    final progress = (totalUsage.inMinutes / targetMinutes).clamp(0.0, 1.0);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _updateUsageAndCheck,
        color: colorScheme.primary,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar.large(
              title: const Text('Quản lý thời gian'),
              actions: [
                IconButton(
                  tooltip: 'Thống kê theo ngày',
                  icon: const Icon(Icons.bar_chart_rounded),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsPage()));
                  },
                ),
                IconButton(
                  tooltip: 'Đổi chế độ sáng/tối',
                  icon: Icon(_themeIconFor(widget.currentThemeMode)),
                  onPressed: _cycleThemeMode,
                ),
              ],
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.08),
                          colorScheme.secondary.withOpacity(0.06),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    _buildUsageHeroCard(totalUsage, progress, targetMinutes),
                    SizedBox(height: 16),
                    _buildCategorySection(),
                    SizedBox(height: 16),
                    _buildTopAppsCarousel(),
                    SizedBox(height: 16),
                    _buildScreenTimeGoalCard(progress, remainingMinutes, targetMinutes),
                    SizedBox(height: 16),
                    _buildAppStatsCard(),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleThemeMode() {
    final next = () {
      switch (widget.currentThemeMode) {
        case ThemeMode.system:
          return ThemeMode.light;
        case ThemeMode.light:
          return ThemeMode.dark;
        case ThemeMode.dark:
          return ThemeMode.system;
      }
    }();
    widget.onChangeThemeMode(next);
  }

  IconData _themeIconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_rounded;
      case ThemeMode.dark:
        return Icons.dark_mode_rounded;
      case ThemeMode.system:
        return Icons.brightness_auto_rounded;
    }
  }

  // New modern hero usage section with animated ring and gradient
  Widget _buildUsageHeroCard(Duration totalUsage, double progress, int targetMinutes) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final targetDuration = Duration(minutes: targetMinutes);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.10),
              colorScheme.secondary.withOpacity(0.08),
            ],
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hôm nay',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _formatDuration(totalUsage),
                      key: ValueKey(totalUsage.inMinutes),
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Mục tiêu ${_formatDuration(targetDuration)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 120,
              height: 120,
              child: _AnimatedProgressRing(
                progress: progress.clamp(0, 1),
                color: colorScheme.primary,
                background: colorScheme.surfaceVariant.withOpacity(0.3),
                child: Text('${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    if (categories.isEmpty) {
      return SizedBox.shrink();
    }
    final totalMinutes = categories.fold<int>(0, (s, c) => s + c.duration.inMinutes).toDouble();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Phân loại sử dụng', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Spacer(),
                Text(_formatDuration(categories.fold(Duration.zero, (s, c) => s + c.duration)),
                    style: theme.textTheme.bodyMedium),
              ],
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: categories.map((c) {
                  final w = ((c.duration.inMinutes / totalMinutes) * 1000).clamp(1, 1000).round();
                  return Expanded(
                    flex: w,
                    child: Container(height: 12, color: c.color.withOpacity(0.9)),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: categories.map((c) {
                return Chip(
                  label: Text('${c.name} • ${_formatDurationShort(c.duration)}'),
                  backgroundColor: c.color.withOpacity(0.15),
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  side: BorderSide(color: c.color.withOpacity(0.4)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppsCarousel() {
    if (topApps.isEmpty) return SizedBox.shrink();
    final theme = Theme.of(context);
    final apps = List<AppUsage>.from(topApps)..sort((a, b) => b.duration.compareTo(a.duration));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Ứng dụng nổi bật', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) {
              final app = apps[i];
              return Container(
                width: 220,
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: app.iconColor == Colors.black
                                ? Colors.white
                                : app.iconColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            app.icon,
                            color: app.iconColor == Colors.black ? Colors.black : app.iconColor,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(app.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(height: 4),
                              Text(_formatDuration(app.duration), style: theme.textTheme.bodySmall),
                              SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _relativeAppUsage(app.duration),
                                minHeight: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => SizedBox(width: 12),
            itemCount: apps.length,
          ),
        ),
      ],
    );
  }

  double _relativeAppUsage(Duration d) {
    final max = allApps.isEmpty ? 1 : allApps.map((a) => a.duration).reduce((a, b) => a > b ? a : b).inMinutes.toDouble();
    if (max == 0) return 0;
    return (d.inMinutes / max).clamp(0.0, 1.0);
  }

  // Removed legacy _buildTotalUsageCard (superseded by _buildUsageHeroCard and _buildCategorySection)

  // Removed legacy _buildTopAppsCard (superseded by _buildTopAppsCarousel)

  Widget _buildScreenTimeGoalCard(double progress, int remainingMinutes, int targetMinutes) {
    final remainingDuration = Duration(minutes: remainingMinutes);
    final targetDuration = Duration(minutes: targetMinutes);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mục tiêu thời gian sáng màn hình',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showEditTargetDialog(context),
                    child: Text(
                      'Mục tiêu ${_formatDuration(targetDuration)}',
                      style: TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _formatDuration(remainingDuration),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Còn lại',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 20),
            // Biểu đồ tròn
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
                    builder: (_, value, __) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 14,
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                      );
                    },
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTargetDialog(BuildContext context) {
    final currentTargetMinutes = (targetHours * 60).toInt();
    int tempHours = currentTargetMinutes ~/ 60;
    int tempMinutes = currentTargetMinutes % 60;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Chỉnh sửa mục tiêu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Đặt mục tiêu thời gian sử dụng màn hình hàng ngày',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Giờ
                      Column(
                        children: [
                          Text(
                            'Giờ',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              physics: FixedExtentScrollPhysics(),
                              diameterRatio: 1.5,
                              controller: FixedExtentScrollController(initialItem: tempHours),
                              onSelectedItemChanged: (index) {
                                setDialogState(() {
                                  tempHours = index;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  final isSelected = index == tempHours;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                                childCount: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 16),
                      Text(
                        ':',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 16),
                      // Phút
                      Column(
                        children: [
                          Text(
                            'Phút',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 40,
                              physics: FixedExtentScrollPhysics(),
                              diameterRatio: 1.5,
                              controller: FixedExtentScrollController(initialItem: tempMinutes),
                              onSelectedItemChanged: (index) {
                                setDialogState(() {
                                  tempMinutes = index;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                builder: (context, index) {
                                  final isSelected = index == tempMinutes;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                },
                                childCount: 60,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Mục tiêu: ${tempHours.toString().padLeft(2, '0')}:${tempMinutes.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Hủy',
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newTargetHours = tempHours + (tempMinutes / 60.0);
                    if (newTargetHours > 0) {
                      setState(() {
                        targetHours = newTargetHours;
                        PreferencesService.saveTargetHours(newTargetHours);
                      });
                    }
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAppStatsCard() {
    // Sắp xếp apps theo thời gian sử dụng giảm dần
    final sortedApps = List<AppUsage>.from(allApps);
    sortedApps.sort((a, b) => b.duration.compareTo(a.duration));

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống kê ứng dụng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Danh sách tất cả các ứng dụng bạn đã sử dụng hôm nay',
              style: TextStyle(
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            ...sortedApps.asMap().entries.map((entry) {
              final index = entry.key;
              final app = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: index < sortedApps.length - 1 ? 12 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: app.iconColor == Colors.black
                            ? Colors.white
                            : (app.name == 'Facebook' 
                                ? app.iconColor 
                                : app.iconColor.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        app.icon,
                        color: app.iconColor == Colors.black 
                            ? Colors.black 
                            : (app.name == 'Facebook' ? Colors.white : app.iconColor),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDuration(app.duration),
                            style: TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hiển thị phần trăm so với tổng thời gian
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_getUsagePercentage(app.duration).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _getUsagePercentage(Duration appDuration) {
    final totalMinutes = allApps.fold<int>(
      0,
      (sum, app) => sum + app.duration.inMinutes,
    );
    if (totalMinutes == 0) return 0;
    return (appDuration.inMinutes / totalMinutes) * 100;
  }

  // Animated progress ring used in hero
}

class _AnimatedProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final Color background;
  final Widget child;
  const _AnimatedProgressRing({
    required this.progress,
    required this.color,
    required this.background,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      builder: (context, value, _) {
        return CustomPaint(
          painter: _RingPainter(progress: value, color: color, background: background),
          child: Center(child: child),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color background;
  _RingPainter({required this.progress, required this.color, required this.background});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 12.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = background;
    final fgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -3.14 / 2,
        endAngle: -3.14 / 2 + 6.28,
        colors: [color, color.withOpacity(0.6)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // background circle
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      6.28318,
      false,
      bgPaint,
    );
    // foreground arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      6.28318 * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.background != background;
  }
}
