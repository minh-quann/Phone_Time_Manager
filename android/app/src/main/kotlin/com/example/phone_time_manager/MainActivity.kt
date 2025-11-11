package com.example.phone_time_manager

import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.screen_time"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "openUsageSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open usage settings: ${e.message}", null)
                    }
                }

                "isUsageAccessGranted" -> {
                    try {
                        val granted = isUsageAccessGranted()
                        result.success(granted)
                    } catch (e: Exception) {
                        result.error("ERROR", "check failed: ${e.message}", null)
                    }
                }

                "getUsageForPeriod" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("INVALID_ARGS", "Arguments expected", null)
                        return@setMethodCallHandler
                    }
                    val start = (args["start"] as? Number)?.toLong() ?: run {
                        result.error("INVALID_ARGS", "start missing or invalid", null); return@setMethodCallHandler
                    }
                    val end = (args["end"] as? Number)?.toLong() ?: run {
                        result.error("INVALID_ARGS", "end missing or invalid", null); return@setMethodCallHandler
                    }
                    try {
                        val total = getUsageForPeriod(start, end)
                        result.success(total) // milliseconds
                    } catch (e: Exception) {
                        result.error("ERROR", "getUsageForPeriod failed: ${e.message}", null)
                    }
                }

                "getAppUsageList" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("INVALID_ARGS", "Arguments expected", null)
                        return@setMethodCallHandler
                    }
                    val start = (args["start"] as? Number)?.toLong() ?: run {
                        result.error("INVALID_ARGS", "start missing or invalid", null); return@setMethodCallHandler
                    }
                    val end = (args["end"] as? Number)?.toLong() ?: run {
                        result.error("INVALID_ARGS", "end missing or invalid", null); return@setMethodCallHandler
                    }
                    try {
                        val appList = getAppUsageList(start, end)
                        result.success(appList)
                    } catch (e: Exception) {
                        result.error("ERROR", "getAppUsageList failed: ${e.message}", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isUsageAccessGranted(): Boolean {
        // Cách đơn giản: query một khoảng thời gian ngắn, nếu list rỗng thì không có quyền
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return false
        val now = System.currentTimeMillis()
        val begin = now - 60_000L // 1 phút trước
        val stats: List<UsageStats> = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, begin, now)
        return stats != null && stats.isNotEmpty()
    }

    private fun getUsageForPeriod(start: Long, end: Long): Long {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return 0L

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val aggregated: Map<String, UsageStats> = usm.queryAndAggregateUsageStats(start, end)
            var total = 0L
            for ((_, usage) in aggregated) {
                total += usage.totalTimeInForeground
            }
            return total
        }
        return 0L
    }

    private fun getAppUsageList(start: Long, end: Long): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val appList = mutableListOf<Map<String, Any>>()
        val pm = packageManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val aggregated: Map<String, UsageStats> = usm.queryAndAggregateUsageStats(start, end)
            
            android.util.Log.d("UsageStats", "Tổng số app trong aggregated: ${aggregated.size}")
            
            // Lọc và sắp xếp theo thời gian sử dụng
            val sortedApps = aggregated.toList().sortedByDescending { it.second.totalTimeInForeground }
            
            android.util.Log.d("UsageStats", "Số app sau khi sắp xếp: ${sortedApps.size}")
            
            for ((packageName, usage) in sortedApps) {
                // Bỏ qua system apps và apps không có thời gian sử dụng
                if (usage.totalTimeInForeground <= 0) continue
                
                try {
                    val appInfo = pm.getApplicationInfo(packageName, 0)
                    
                    // Bỏ qua system apps (tùy chọn, có thể bỏ comment để hiển thị)
                    // if ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0) continue
                    
                    val appName = pm.getApplicationLabel(appInfo).toString()
                    
                    android.util.Log.d("UsageStats", "App: $appName ($packageName) - ${usage.totalTimeInForeground}ms")
                    
                    appList.add(mapOf(
                        "packageName" to packageName,
                        "appName" to appName,
                        "usageTime" to usage.totalTimeInForeground // milliseconds
                    ))
                } catch (e: Exception) {
                    // App không tồn tại hoặc không thể truy cập, bỏ qua
                    android.util.Log.d("UsageStats", "Lỗi khi lấy thông tin app $packageName: ${e.message}")
                    continue
                }
            }
        }
        
        android.util.Log.d("UsageStats", "Tổng số app trả về: ${appList.size}")
        return appList
    }
}
