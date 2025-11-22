package com.example.video_manager_app  // 确保包名和 MainActivity 一致

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import android.content.pm.ServiceInfo

class ForegroundService : Service() {
    private lateinit var wakeLock: PowerManager.WakeLock
    private val CHANNEL_ID = "server_keep_alive_channel"
    private val NOTIFICATION_ID = 1001

    override fun onCreate() {
        super.onCreate()
        // 初始化唤醒锁（PARTIAL_WAKE_LOCK：保持CPU运行，屏幕可以熄灭）
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ON_AFTER_RELEASE,
            "ServerApp:SoonwinVideoServer"  // 标签名，可自定义
        ).apply {
            // 长期持有唤醒锁（服务器运行期间一直持有，直到服务停止）
            if (!isHeld) {
                acquire()  // 不设置超时，直到主动释放
            }
        }

        createNotificationChannel()  // 创建通知渠道（Android O+ 必需）
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 启动前台服务（必须显示通知）
        try {
            val notification = createNotification()
            when {
                // Android 14+（API 34）：使用官方常量
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE -> {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                }
                // Android 12-13（API 31-33）：使用官方常量
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                }
                // Android 11 及以下：无需指定服务类型
                else -> {
                    startForeground(NOTIFICATION_ID, notification)
                }
            }
        } catch (e: SecurityException) {
            e.printStackTrace()
            stopSelf() // 权限不足时停止服务
            return START_NOT_STICKY
        }

        // 返回 START_STICKY：服务被杀死后，系统会尝试重启（可选，根据需求调整）
        return START_STICKY
    }

    // 创建通知渠道（Android O+ 必需）
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "服务器保活服务",  // 渠道名称（用户可见）
                NotificationManager.IMPORTANCE_LOW  // 低优先级，不打扰用户
            ).apply {
                description = "保持Soonwin视频服务器在后台持续运行"  // 渠道描述
                setSound(null, null)  // 关闭通知声音（可选）
                enableVibration(false) // 关闭震动
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    // 创建前台服务通知（必须显示，否则会崩溃）
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Soonwin Video Server")
            .setContentText("Running . . .")
            .setSmallIcon(R.mipmap.ic_launcher)  // 必须设置图标（用你的应用图标）
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)  // 设为持续通知（用户不能手动清除）
            .setShowWhen(false) // 隐藏时间戳
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        // 释放唤醒锁（服务停止时必须释放，否则会耗电）
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
        // 停止前台服务（移除通知）
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onBind(intent: Intent): IBinder? {
        return null  // 不需要绑定服务，返回 null
    }
}
