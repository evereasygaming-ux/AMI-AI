package com.ami.ami_ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.view.WindowManager
import kotlin.math.abs
import kotlin.math.max

class FloatingOrbService : Service() {

    companion object {
        private const val CHANNEL_ID = "ami_floating_robot"
        private const val NOTIFICATION_ID = 7813
        const val ACTION_STOP = "com.ami.ami_ai.STOP_FLOATING_ROBOT"

        @Volatile
        var instance: FloatingOrbService? = null
            private set

        @Volatile
        var isRunning: Boolean = false
            private set

        var tapListener: (() -> Unit)? = null

        fun start(context: Context) {
            if (isRunning) return
            val intent = Intent(context, FloatingOrbService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FloatingOrbService::class.java))
        }
    }

    private lateinit var windowManager: WindowManager
    private var robotView: RobotOrbView? = null
    private lateinit var layoutParams: WindowManager.LayoutParams
    private var startX = 0
    private var startY = 0
    private var touchX = 0f
    private var touchY = 0f
    private var dragging = false
    private val touchSlop: Int by lazy {
        ViewConfiguration.get(this).scaledTouchSlop
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        startForegroundNotification()
        showRobot()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    private fun showRobot() {
        val view = RobotOrbView(this)
        robotView = view
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val size = dp(88)
        val height = dp(100)
        val metrics = resources.displayMetrics
        layoutParams = WindowManager.LayoutParams(
            size,
            height,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = metrics.widthPixels - size - dp(12)
            y = metrics.heightPixels / 2 - height / 2
        }

        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    startX = layoutParams.x
                    startY = layoutParams.y
                    touchX = event.rawX
                    touchY = event.rawY
                    dragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - touchX).toInt()
                    val dy = (event.rawY - touchY).toInt()
                    if (abs(dx) > touchSlop || abs(dy) > touchSlop) {
                        dragging = true
                    }
                    layoutParams.x = startX + dx
                    layoutParams.y = startY + dy
                    clampPosition()
                    windowManager.updateViewLayout(view, layoutParams)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!dragging) onRobotTapped()
                    true
                }
                else -> false
            }
        }

        windowManager.addView(view, layoutParams)
        isRunning = true
        view.start()
    }

    private fun clampPosition() {
        val metrics = resources.displayMetrics
        val maxX = max(0, metrics.widthPixels - layoutParams.width)
        val maxY = max(0, metrics.heightPixels - layoutParams.height)
        layoutParams.x = layoutParams.x.coerceIn(0, maxX)
        layoutParams.y = layoutParams.y.coerceIn(0, maxY)
    }

    private fun onRobotTapped() {
        val listener = tapListener
        if (ScreenCaptureService.isRunning && listener != null) {
            listener.invoke()
            return
        }
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(MainActivity.EXTRA_ORB_ACTION, MainActivity.ORB_ACTION_READ_SCREEN)
        }
        try {
            startActivity(intent)
        } catch (_: Throwable) {
        }
    }

    private fun startForegroundNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Floating robot",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the AMI floating robot on screen"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        val openIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val stopIntent = Intent(this, FloatingOrbService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setContentTitle("AMI robot is floating")
            .setContentText("Tap the robot to read your screen aloud.")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Stop",
                stopPendingIntent
            )
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        isRunning = false
        instance = null
        robotView?.let { view ->
            view.stop()
            try {
                windowManager.removeView(view)
            } catch (_: Throwable) {
            }
        }
        robotView = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
