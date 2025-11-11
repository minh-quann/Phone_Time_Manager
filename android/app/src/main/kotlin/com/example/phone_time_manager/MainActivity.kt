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
            var aggregated: Map<String, UsageStats> = usm.queryAndAggregateUsageStats(start, end)

            // Fallback: một số thiết bị trả về rỗng với queryAndAggregateUsageStats cho khoảng nhỏ.
            // Khi đó tự tổng hợp từ queryUsageStats.
            if (aggregated.isEmpty()) {
                android.util.Log.d("UsageStats", "Aggregated rỗng, dùng fallback queryUsageStats")
                val raw: List<UsageStats> = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end) ?: emptyList()
                val map = mutableMapOf<String, UsageStats>()
                for (u in raw) {
                    val exist = map[u.packageName]
                    if (exist == null) {
                        map[u.packageName] = u
                    } else {
                        // Cộng dồn thời gian foreground/visible
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            exist.totalTimeVisible += u.totalTimeVisible
                        }
                        exist.totalTimeInForeground += u.totalTimeInForeground
                    }
                }
                aggregated = map
            }

            android.util.Log.d("UsageStats", "Tổng số app sau aggregate: ${aggregated.size}")

            // Tính tổng thời gian theo package bằng map riêng (tránh sửa trường val của UsageStats)
            val totals = mutableMapOf<String, Long>()
            if (aggregated.isNotEmpty()) {
                for ((pkg, usage) in aggregated) {
                    val t = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        maxOf(usage.totalTimeVisible, usage.totalTimeInForeground)
                    } else {
                        usage.totalTimeInForeground
                    }
                    if (t > 0) totals[pkg] = (totals[pkg] ?: 0L) + t
                }
            } else {
                // fallback path: đã có 'raw' phía trên
                val raw: List<UsageStats> = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end) ?: emptyList()
                for (u in raw) {
                    val t = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        maxOf(u.totalTimeVisible, u.totalTimeInForeground)
                    } else {
                        u.totalTimeInForeground
                    }
                    if (t > 0) totals[u.packageName] = (totals[u.packageName] ?: 0L) + t
                }
            }

            val sortedApps = totals.toList().sortedByDescending { it.second }
            for ((packageName, timeMs) in sortedApps) {
                try {
                    val appInfo = pm.getApplicationInfo(packageName, 0)
                    val appName = pm.getApplicationLabel(appInfo).toString()
                    android.util.Log.d("UsageStats", "App: $appName ($packageName) - ${timeMs}ms")
                    appList.add(mapOf(
                        "packageName" to packageName,
                        "appName" to appName,
                        "usageTime" to timeMs
                    ))
                } catch (e: Exception) {
                    android.util.Log.d("UsageStats", "Fallback label for $packageName: ${e.message}")
                    appList.add(mapOf(
                        "packageName" to packageName,
                        "appName" to packageName,
                        "usageTime" to timeMs
                    ))
                }
            }
        }
        
        android.util.Log.d("UsageStats", "Tổng số app trả về: ${appList.size}")
        return appList
    }
}
