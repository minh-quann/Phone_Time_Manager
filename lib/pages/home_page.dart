import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../services/usage_service.dart';
import '../services/notification_service.dart';
import '../services/preferences_service.dart';
import '../models/app_usage.dart';

class HomePage extends StatefulWidget {
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _updateUsageAndCheck,
          backgroundColor: Color(0xFF1E1E1E),
          color: Colors.green,
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phần 1: Tổng thời gian sử dụng và phân loại
                _buildTotalUsageCard(totalUsage, categories),
                SizedBox(height: 16),

                // Phần 2: Ứng dụng được dùng nhiều nhất
                _buildTopAppsCard(),
                SizedBox(height: 16),

                // Phần 3: Mục tiêu thời gian sáng màn hình
                _buildScreenTimeGoalCard(progress, remainingMinutes, targetMinutes),
                SizedBox(height: 16),

                // Phần 4: Thống kê ứng dụng
                _buildAppStatsCard(),
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalUsageCard(Duration totalUsage, List<CategoryUsage> categories) {
    final totalMinutes = categories.fold<int>(
      0,
      (sum, cat) => sum + cat.duration.inMinutes,
    );
    final totalMinutesDouble = totalMinutes.toDouble();

    return Card(
      color: Color(0xFF1E1E1E),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDuration(totalUsage),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            // Thanh tiến trình phân loại
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 24,
                child: Row(
                  children: categories.map((cat) {
                    final width = (cat.duration.inMinutes / totalMinutesDouble).clamp(0.0, 1.0);
                    return Expanded(
                      flex: (width * 1000).round(),
                      child: Container(
                        color: cat.color,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            SizedBox(height: 12),
            // Danh sách categories
            ...categories.map((cat) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: cat.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      cat.name,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Spacer(),
                    Text(
                      _formatDurationShort(cat.duration),
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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

  Widget _buildTopAppsCard() {
    // Đảm bảo topApps được sắp xếp đúng
    final sortedTopApps = List<AppUsage>.from(topApps);
    sortedTopApps.sort((a, b) => b.duration.compareTo(a.duration));
    
    if (sortedTopApps.isEmpty) {
      return Card(
        color: Color(0xFF1E1E1E),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ứng dụng được dùng nhiều nhất',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Chưa có dữ liệu sử dụng ứng dụng',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      color: Color(0xFF1E1E1E),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ứng dụng được dùng nhiều nhất',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            ...sortedTopApps.map((app) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12),
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
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDuration(app.duration),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
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

  Widget _buildScreenTimeGoalCard(double progress, int remainingMinutes, int targetMinutes) {
    final remainingDuration = Duration(minutes: remainingMinutes);
    final targetDuration = Duration(minutes: targetMinutes);

    return Card(
      color: Color(0xFF1E1E1E),
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
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => _showEditTargetDialog(context),
                    child: Text(
                      'Mục tiêu ${_formatDuration(targetDuration)}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white70,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _formatDuration(remainingDuration),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Còn lại',
                    style: TextStyle(
                      color: Colors.white70,
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
                  CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 14,
                    backgroundColor: Color(0xFF2D2D2D),
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)), // Green
                  ),
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
              backgroundColor: Color(0xFF1E1E1E),
              title: Text(
                'Chỉnh sửa mục tiêu',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Đặt mục tiêu thời gian sử dụng màn hình hàng ngày',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
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
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Color(0xFF2D2D2D),
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
                                        color: isSelected ? Colors.white : Colors.white54,
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
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 16),
                      // Phút
                      Column(
                        children: [
                          Text(
                            'Phút',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Color(0xFF2D2D2D),
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
                                        color: isSelected ? Colors.white : Colors.white54,
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
                      color: Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Mục tiêu: ${tempHours.toString().padLeft(2, '0')}:${tempMinutes.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.white,
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
                    style: TextStyle(color: Colors.white70),
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
                    backgroundColor: Color(0xFF22C55E),
                    foregroundColor: Colors.white,
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
      color: Color(0xFF1E1E1E),
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
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Danh sách tất cả các ứng dụng bạn đã sử dụng hôm nay',
              style: TextStyle(
                color: Colors.white70,
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
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _formatDuration(app.duration),
                            style: TextStyle(
                              color: Colors.white70,
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
                        color: Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_getUsagePercentage(app.duration).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: Colors.white70,
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
}
